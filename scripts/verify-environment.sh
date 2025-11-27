#!/bin/bash

set -euo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
success() { echo -e "${GREEN}✓${NC} $1"; }
failure() { echo -e "${RED}✗${NC} $1"; }
info() { echo -e "${CYAN}ℹ${NC} $1"; }
warn() { echo -e "${YELLOW}!${NC} $1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${ENV_FILE:-${SCRIPT_DIR}/../.env}"

if [ -f "$ENV_FILE" ]; then
    info "Loading variables from $ENV_FILE"
    # shellcheck disable=SC1090
    set -a
    source "$ENV_FILE"
    set +a
else
    warn "No .env file found at $ENV_FILE (skipping auto-load)"
fi

echo -e "${CYAN}Verifying Environment Configuration...${NC}\n"

all_valid=true

require_var() {
    local var_name=$1
    local description=$2
    local require_path=${3:-}
    local value=${!var_name:-}

    if [ -z "$value" ]; then
        failure "$var_name - $description - NOT SET"
        all_valid=false
        return
    fi

    if [ "$require_path" = "path" ] && [ ! -e "$value" ]; then
        failure "$var_name - $description - Path does not exist: $value"
        all_valid=false
        return
    fi

    success "$var_name - $description - $value"
}

validate_optional() {
    local var_name=$1
    local description=$2
    local default=$3
    local validator=$4
    local value=${!var_name:-}

    if [ -z "$value" ]; then
        info "$var_name - Will use default: $default"
        return
    fi

    if [ -n "$validator" ] && ! eval "$validator"; then
        failure "$var_name - $description - Invalid value: $value"
        all_valid=false
    else
        success "$var_name - $value"
    fi
}

# Required variables
echo -e "${YELLOW}Required Variables:${NC}"
require_var "MY_SCRIPTS_ROOT" "Script root directory" "path"

echo -e "\n${YELLOW}Optional Variables:${NC}"
validate_optional "LOG_LEVEL" "Logging level" "INFO" '[[ "$value" =~ ^(DEBUG|INFO|WARNING|ERROR|CRITICAL)$ ]]'
validate_optional "LOG_DIR" "Log directory" "./logs" ""
validate_optional "BACKUP_RETENTION_DAYS" "Backup retention days" "30" '[[ $value =~ ^[0-9]+$ && $value -gt 0 ]]'
validate_optional "PGHOST" "PostgreSQL host" "localhost" ""
validate_optional "PGPORT" "PostgreSQL port" "5432" '[[ $value =~ ^[0-9]+$ && $value -ge 1 && $value -le 65535 ]]'

# Feature-specific checks
echo -e "\n${YELLOW}Feature-Specific Configuration:${NC}"

if [ -n "${GDRIVE_CREDENTIALS_PATH:-}" ] || [ -n "${GDRIVE_TOKEN_PATH:-}" ]; then
    if [ -n "${GDRIVE_CREDENTIALS_PATH:-}" ] && [ -n "${GDRIVE_TOKEN_PATH:-}" ]; then
        success "Google Drive - Credentials and token paths set"
    else
        warn "Google Drive - Partially configured (set both GDRIVE_CREDENTIALS_PATH and GDRIVE_TOKEN_PATH)"
    fi
else
    info "Google Drive - Not configured (set GDRIVE_CREDENTIALS_PATH and GDRIVE_TOKEN_PATH to enable)"
fi

if [ -n "${GDRT_CREDENTIALS_FILE:-}" ] || [ -n "${GDRT_TOKEN_FILE:-}" ]; then
    success "Google Drive Recovery - Using custom credential paths"
else
    info "Google Drive Recovery - Using defaults (GDRT_CREDENTIALS_FILE/GDRT_TOKEN_FILE)"
fi

if [ -n "${CLOUDCONVERT_PROD:-}" ]; then
    success "CloudConvert - Configured"
else
    info "CloudConvert - Not configured (set CLOUDCONVERT_PROD to enable)"
fi

echo ""
echo "============================================================"
if $all_valid; then
    success "Environment validation passed!"
    echo -e "\nNext steps:"
    echo "  1. Review configuration above"
    echo "  2. Configure optional features as needed"
    echo "  3. Run installation script"
    exit 0
else
    failure "Environment validation failed!"
    echo -e "\n${YELLOW}To fix:${NC}"
    echo "  1. Copy .env.example to .env"
    echo "  2. Edit .env with your values"
    echo "  3. Load environment: source scripts/load-environment.sh"
    echo "  4. Run this script again"
    exit 1
fi
