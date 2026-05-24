"""Shared console symbol/print helpers for the Google Drive recovery module family."""

import sys


class ConsoleHelper:
    """Provides emoji/ASCII symbols and stderr/stdout print methods.

    Constructed with an args namespace; reads ``args.no_emoji`` to choose
    between Unicode emoji and plain-ASCII fallback labels.
    """

    def __init__(self, args) -> None:
        self._args = args

    def use_emoji(self) -> bool:
        return not getattr(self._args, "no_emoji", False)

    def sym_fail(self) -> str:
        return "❌" if self.use_emoji() else "ERROR"

    def sym_warn(self) -> str:
        return "⚠️" if self.use_emoji() else "WARN"

    def sym_info(self) -> str:
        return "ℹ️" if self.use_emoji() else "INFO"

    def sym_ok(self) -> str:
        return "✓" if self.use_emoji() else "OK"

    def sym_scope(self) -> str:
        return "📊" if self.use_emoji() else "SCOPE"

    def sym_search(self) -> str:
        return "🔍" if self.use_emoji() else "SEARCH"

    def sym_done(self) -> str:
        return "✅" if self.use_emoji() else "DONE"

    def sym_limit(self) -> str:
        """Signal that a search-limit cap was reached (discovery flows)."""
        return "⛳" if self.use_emoji() else "LIMIT"

    def sym_progress(self) -> str:
        return "📈" if self.use_emoji() else "PROGRESS"

    def sym_plan(self) -> str:
        return "📋" if self.use_emoji() else "PLAN"

    def print_err(self, msg: str) -> None:
        print(f"{self.sym_fail()} {msg}", file=sys.stderr)

    def print_warn(self, msg: str) -> None:
        print(f"{self.sym_warn()} {msg}", file=sys.stderr)

    def print_info(self, msg: str) -> None:
        print(f"{self.sym_info()} {msg}")
