r"""
Google Drive authentication manager.

Houses DriveAuthManager - responsible for OAuth token management, credential
refresh, HTTP transport construction, and Google Drive service initialisation.
Extracted from DriveTrashRecoveryTool (gdrive_recover.py) as part of the
ongoing modularisation effort (issue #789).
"""

import os
import sys
import logging
from pathlib import Path
from threading import local
from typing import Callable, Optional

from gdrive_constants import (
    SCOPES,
    DEFAULT_HTTP_TRANSPORT,
    DEFAULT_HTTP_POOL_MAXSIZE,
    CREDENTIALS_FILE,
    TOKEN_FILE,
)

try:
    from googleapiclient.discovery import build
    from google_auth_oauthlib.flow import InstalledAppFlow
    from google.auth.transport.requests import Request
    from google.oauth2.credentials import Credentials
except ImportError:
    print("ERROR: Required Google API libraries not installed.")
    print(
        "Install with: pip install google-api-python-client google-auth-httplib2 google-auth-oauthlib"
    )
    sys.exit(1)


class DriveAuthManager:
    """Manages OAuth credentials, token caching, and Drive service construction.

    Owns the full authentication lifecycle for DriveTrashRecoveryTool:
    - Loading / refreshing OAuth tokens from disk
    - Running the OAuth flow when no valid token exists
    - Building per-thread or shared Drive service clients
    - Constructing the optional requests-based HTTP transport
    - Hardening token file permissions on Windows
    """

    # --- HTTP transport construction (v1.6.0) ---
    class _RequestsHttpAdapter:
        """Shim to make requests.Session/AuthorizedSession look like httplib2.Http."""

        # Minimal surface-area parity with httplib2.Http
        # Intentionally unsupported in this shim (documented no-ops):
        #   * cache / cachectl
        #   * proxy_info / tlslite, etc.
        #   * custom connection_type
        #
        # Supported pass-throughs:
        #   * timeout (as requests' timeout)
        def __init__(self, session):
            self._session = session
            # common httplib2 attrs some libraries probe for
            self.timeout: float | None = None
            self.ca_certs: str | None = None
            self.disable_ssl_certificate_validation: bool = False

        def request(self, uri, method="GET", body=None, headers=None, **kwargs):
            # Extract a few commonly-seen httplib2 kwargs and map or ignore:
            #  - timeout: map to requests' timeout
            #  - redirections, connection_type, follow_redirects, etc.: ignore (requests handles redirects)
            timeout = kwargs.pop("timeout", None)
            # If instance.timeout is set and no per-call timeout provided, use it
            eff_timeout = timeout if timeout is not None else self.timeout
            # Perform the request; requests will pool per-mounted adapter.
            r = self._session.request(
                method, uri, data=body, headers=headers, timeout=eff_timeout, **kwargs
            )

            class _Resp(dict):
                def __init__(self, resp):
                    super().__init__({k.lower(): v for k, v in resp.headers.items()})
                    self.status = resp.status_code
                    self.reason = resp.reason

            return _Resp(r), r.content

    def __init__(self, args, logger: logging.Logger, execute_fn: Callable):
        self.args = args
        self.logger = logger
        self._execute = execute_fn
        self._service = None  # used when single-client mode
        self._creds = None  # saved creds for per-thread builds
        self._thread_local = local()  # holds .service per thread
        self._client_per_thread = True if getattr(args, "client_per_thread", True) else False
        self._http_transport = getattr(args, "http_transport", DEFAULT_HTTP_TRANSPORT)
        self._http_pool_maxsize = int(getattr(args, "http_pool_maxsize", DEFAULT_HTTP_POOL_MAXSIZE))
        self._authenticated = False
        self._printed_requests_fallback = False
        # credential paths (may be absolute)
        self._credentials_file = CREDENTIALS_FILE
        self._token_file = TOKEN_FILE

    def _build_http(self, creds):
        transport = (self._http_transport or DEFAULT_HTTP_TRANSPORT).lower()
        if transport == "auto":
            transport = "requests"
        if transport == "requests":
            try:
                from google.auth.transport.requests import AuthorizedSession
                import requests

                s = AuthorizedSession(creds)
                try:
                    from requests.adapters import HTTPAdapter

                    a = HTTPAdapter(
                        pool_connections=self._http_pool_maxsize,
                        pool_maxsize=self._http_pool_maxsize,
                    )
                    s.mount("https://", a)
                except Exception:
                    pass
                return self._RequestsHttpAdapter(s)
            except Exception as e:
                self.logger.warning(
                    f"Requests transport unavailable ({e}); falling back to httplib2."
                )
                # One-time console note so users understand how to enable pooling.
                if not self._printed_requests_fallback:
                    self._printed_requests_fallback = True
                    prefix = "ℹ️" if not getattr(self.args, "no_emoji", False) else "INFO"
                    print(
                        f"{prefix} Requests transport could not be enabled; falling back to httplib2.\n"
                        "   To enable connection pooling, install:  pip install requests google-auth[requests]\n"
                        "   and run with:  --http-transport requests"
                    )
                return None  # let discovery pick default
        # default: let discovery build its own httplib2.Http
        return None

    def _get_service(self):
        """Return the shared Google Drive service instance."""
        if not self._authenticated:
            raise RuntimeError("Service not initialized. Call authenticate() first.")
        if self._client_per_thread:
            svc = getattr(self._thread_local, "service", None)
            if svc is None:
                # Lazily build a client for this thread using saved creds
                http = self._build_http(self._creds)
                if http is not None:
                    svc = build("drive", "v3", credentials=None, http=http)
                else:
                    svc = build("drive", "v3", credentials=self._creds)
                self._thread_local.service = svc
            return svc
        return self._service

    def _load_creds_from_token(self, token_file):
        """Load credentials from token.json if it exists (tolerant of corrupt files)."""
        if not os.path.exists(token_file):
            return None
        try:
            return Credentials.from_authorized_user_file(token_file, SCOPES)
        except PermissionError:
            raise
        except Exception:
            # Corrupt or unreadable token—force a fresh OAuth flow.
            return None

    def _refresh_or_flow_creds(self, creds, token_file):
        """Refresh credentials or run OAuth flow if needed."""
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            # Allow an env var override for the client secrets file.
            cred_path = os.getenv("GDRT_CREDENTIALS_FILE", CREDENTIALS_FILE)
            if not os.path.exists(cred_path):
                self.logger.error(
                    f"Credentials file not found: {cred_path}. "
                    "Set GDRT_CREDENTIALS_FILE or GDRIVE_CREDENTIALS_PATH, or place credentials.json next to the script."
                )
                return None
            flow = InstalledAppFlow.from_client_secrets_file(cred_path, SCOPES)
            creds = flow.run_local_server(port=0)
        if creds is None:
            return None
        with open(token_file, "w") as token:
            token.write(creds.to_json())
        self._harden_token_permissions_windows(token_file)
        return creds

    def _build_and_test_service(self, creds):
        """Build the Drive service and test authentication."""
        if self._client_per_thread:
            http = self._build_http(creds)
            if http is not None:
                self._thread_local.service = build("drive", "v3", credentials=None, http=http)
            else:
                self._thread_local.service = build("drive", "v3", credentials=creds)
            test_service = self._thread_local.service
        else:
            http = self._build_http(creds)
            if http is not None:
                self._service = build("drive", "v3", credentials=None, http=http)
            else:
                self._service = build("drive", "v3", credentials=creds)
            test_service = self._service
        # Basic auth check
        about = self._execute(test_service.about().get(fields="user"))
        self.logger.info(
            f"Authenticated as: {about.get('user', {}).get('emailAddress', 'Unknown')}"
        )
        # Best-effort adapter smoke tests: small list + tiny media read (first byte)
        files = None
        try:
            files = self._execute(
                test_service.files().list(pageSize=1, fields="files(id, size, mimeType)")
            )
        except Exception:
            # Some environments might fail list if Drive is empty; ignore.
            pass
        try:
            f = next((x for x in (files or {}).get("files", []) if "size" in x), None)
            if f:
                # Try to fetch a single byte using the underlying HTTP object to validate `get_media` path.
                req = test_service.files().get_media(fileId=f["id"])
                http = getattr(test_service, "_http", None)
                if http is not None:
                    # Use any configured timeout on adapter if present
                    to = getattr(http, "timeout", None)
                    # Range 0-0 avoids large downloads and validates adapter supports media.
                    http.request(req.uri, method="GET", headers={"Range": "bytes=0-0"}, timeout=to)
        except Exception:
            # Non-fatal; purely a smoke test. Keep silent to avoid noise.
            pass
        return True

    def authenticate(self) -> bool:
        """Authenticate with Google Drive API."""
        if self._authenticated:
            return True
        try:
            creds = self._load_creds_from_token(self._token_file)
            if creds:
                self._harden_token_permissions_windows(self._token_file)
            if not creds or not creds.valid:
                creds = self._refresh_or_flow_creds(creds, self._token_file)
                if creds is None:
                    return False
            self._creds = creds
            ok = self._build_and_test_service(creds)
            self._authenticated = ok
            return ok
        except Exception as e:
            self.logger.error(f"Authentication failed: {e}")
            return False

    # --- Windows token hardening (best-effort) ---
    def _harden_token_permissions_windows(self, token_path: str) -> None:
        """
        On Windows, POSIX 0600 is not meaningful. We at least hide the file to
        reduce casual discovery. Advanced ACL hardening is not attempted here.
        """
        try:
            if os.name != "nt":
                return
            import ctypes

            FILE_ATTRIBUTE_HIDDEN = 0x02
            attrs = ctypes.windll.kernel32.GetFileAttributesW(str(Path(token_path)))
            if attrs == -1:
                return
            if (attrs & FILE_ATTRIBUTE_HIDDEN) == 0:
                ctypes.windll.kernel32.SetFileAttributesW(
                    str(Path(token_path)), attrs | FILE_ATTRIBUTE_HIDDEN
                )
                self.logger.info(
                    "Marked token.json as hidden (Windows). Note: use NTFS ACLs for stricter control."
                )
        except Exception as e:
            # Non-fatal; log at debug to avoid noise
            self.logger.debug(f"Could not mark token.json hidden on Windows: {e}")
