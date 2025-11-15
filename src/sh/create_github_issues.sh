#!/usr/bin/env bash

###############################################################################
# Script: create_github_issues.sh
# Description: Create GitHub issues from markdown files in github_issues/
# Usage:
#   ./create_github_issues.sh
#   ./create_github_issues.sh --repo OWNER/REPO
#   ./create_github_issues.sh --dry-run
###############################################################################

# Keep it simple for Git Bash – no set -e/pipefail
# We will check errors manually where it matters.

# Colours
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'
BOLD='\033[1m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ISSUES_DIR="${SCRIPT_DIR}/github_issues"

DRY_RUN=false
REPO=""

CREATED_COUNT=0
SKIPPED_COUNT=0
FAILED_COUNT=0

info()    { echo -e "${BLUE}ℹ${NC}  $*"; }
ok()      { echo -e "${GREEN}✓${NC}  $*"; }
warn()    { echo -e "${YELLOW}⚠${NC}  $*"; }
err()     { echo -e "${RED}✗${NC}  $*" >&2; }
step()    { echo -e "\n${BOLD}${MAGENTA}▶${NC} ${BOLD}$*${NC}"; }
line()    { echo -e "${CYAN}──────────────────────────────────────────────────────────────${NC}"; }

header() {
    echo -e "\n${BOLD}${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e   "${BOLD}${CYAN}  GitHub Issue Creator${NC}"
    echo -e   "${BOLD}${CYAN}══════════════════════════════════════════════════════════════${NC}\n"
}

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Options:
  --repo OWNER/REPO   Use this GitHub repository explicitly
  --dry-run           Do not call GitHub; just show what would be done
  -h, --help          Show this help
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --repo)
                REPO="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                err "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
}

check_gh_cli() {
    step "Checking GitHub CLI"
    if ! command -v gh >/dev/null 2>&1; then
        err "GitHub CLI (gh) is not installed."
        echo "Install from https://cli.github.com/ and then run:"
        echo "  gh auth login"
        exit 1
    fi
    ok "GitHub CLI found: $(gh --version | head -n1)"
}

check_gh_auth() {
    step "Checking GitHub authentication"
    if ! gh auth status >/dev/null 2>&1; then
        err "You are not authenticated with GitHub."
        echo "Run:"
        echo "  gh auth login"
        exit 1
    fi
    local user
    user=$(gh auth status 2>&1 | grep "Logged in to" | sed 's/.*as \(.*\) (.*/\1/')
    ok "Authenticated as: ${user}"
}

detect_repo() {
    step "Determining repository"
    if [[ -n "$REPO" ]]; then
        ok "Using repository from CLI: $REPO"
        return
    fi

    if git -C "$SCRIPT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        local url
        url=$(git -C "$SCRIPT_DIR" remote get-url origin 2>/dev/null || echo "")
        if [[ -n "$url" && "$url" =~ github\.com[:/]+([^/]+)/([^/.]+) ]]; then
            REPO="${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
            ok "Detected repository from git remote: $REPO"
            return
        fi
    fi

    warn "Could not detect repository automatically."
    read -r -p "Enter repository (OWNER/REPO): " REPO
    if [[ -z "$REPO" ]]; then
        err "Repository is required."
        exit 1
    fi
    ok "Using repository: $REPO"
}

get_issue_files() {
    step "Checking issue templates directory"
    if [[ ! -d "$ISSUES_DIR" ]]; then
        err "Directory not found: $ISSUES_DIR"
        exit 1
    fi

    shopt -s nullglob
    local files=( "$ISSUES_DIR"/issue* )
    shopt -u nullglob

    if [[ ${#files[@]} -eq 0 ]]; then
        err "No issue* files found in $ISSUES_DIR"
        exit 1
    fi

    ok "Found ${#files[@]} issue file(s) in $ISSUES_DIR"
    ISSUE_FILES=( "${files[@]}" )
}

# Extract labels from a file's "## Labels" section
extract_labels_from_file() {
    local file="$1"
    awk '
        /^## Labels/ { in_labels=1; next }
        /^## / && in_labels { in_labels=0 }
        in_labels && /^[*-] / {
            gsub(/^[*-] +/, "", $0);
            print $0
        }
    ' "$file"
}

collect_all_labels() {
    local lbl
    local all=""

    for f in "${ISSUE_FILES[@]}"; do
        while read -r lbl; do
            [[ -z "$lbl" ]] && continue
            all+="$lbl"$'\n'
        done < <(extract_labels_from_file "$f")
    done

    if [[ -z "$all" ]]; then
        echo ""
        return
    fi

    echo "$all" | sort -u
}

random_color() {
    printf "%06x" $(( (RANDOM * RANDOM) % 16777215 ))
}

ensure_labels_exist() {
    step "Ensuring labels exist in repository"

    local labels
    labels=$(collect_all_labels)

    if [[ -z "$labels" ]]; then
        info "No labels found in templates; skipping label creation."
        return
    fi

    info "Labels found in templates:"
    echo "$labels" | sed 's/^/  - /'

    if [[ "$DRY_RUN" == true ]]; then
        warn "DRY RUN: will NOT create labels on GitHub."
        return
    fi

    info "Fetching existing labels from GitHub..."
    local existing
    existing=$(gh label list --repo "$REPO" --json name --jq '.[].name' 2>/dev/null || echo "")

    local created=0
    local already=0

    while read -r label; do
        [[ -z "$label" ]] && continue

        if printf '%s\n' "$existing" | grep -Fxq -- "$label"; then
            info "Label already exists: $label"
            ((already++))
        else
            local color
            color=$(random_color)
            info "Creating label: \"$label\" (color #$color)"
            if gh label create "$label" --color "$color" --repo "$REPO" >/dev/null 2>&1; then
                ((created++))
            else
                warn "Failed to create label: $label (may already exist or permissions issue)"
            fi
        fi
    done <<< "$labels"

    ok "Label sync complete: $already existing, $created created."
}

extract_title() {
    local file="$1"
    grep -m1 '^# ' "$file" | sed 's/^# //'
}

create_issue_from_file() {
    local file="$1"
    local index="$2"
    local total="$3"
    local fname
    fname=$(basename "$file")

    line
    info "[$index/$total] Processing file: $fname"

    local title
    title=$(extract_title "$file" || echo "")
    if [[ -z "$title" ]]; then
        warn "No title (# heading) found in $fname – skipping."
        ((SKIPPED_COUNT++))
        return
    fi
    info "Title: $title"

    # Build --label args
    local -a label_args=()
    while read -r lbl; do
        [[ -z "$lbl" ]] && continue
        label_args+=( "--label" "$lbl" )
    done < <(extract_labels_from_file "$file")

    if [[ ${#label_args[@]} -gt 0 ]]; then
        # Just show the label names (strip the "--label" tokens)
        local show_labels=""
        local i
        for (( i=0; i<${#label_args[@]}; i+=2 )); do
            show_labels+="${label_args[i+1]} "
        done
        info "Labels: $show_labels"
    else
        info "No labels for this issue."
    fi

    info "Checking for existing issues with same title..."
    local existing
    existing=$(gh issue list \
        --repo "$REPO" \
        --search "$title in:title" \
        --json number,title \
        --jq '.[] | select(.title == "'"$title"'") | .number' 2>/dev/null || echo "")

    if [[ -n "$existing" ]]; then
        warn "Issue already exists (#$existing) with this exact title – skipping."
        ((SKIPPED_COUNT++))
        return
    fi

    if [[ "$DRY_RUN" == true ]]; then
        warn "DRY RUN: would create issue \"$title\" from $fname"
        ((CREATED_COUNT++))
        return
    fi

    info "Creating issue on GitHub..."
    local url
    if url=$(gh issue create \
        --repo "$REPO" \
        --title "$title" \
        --body-file "$file" \
        "${label_args[@]}" 2>/dev/null); then
        ok "Created issue: $url"
        ((CREATED_COUNT++))
    else
        err "Failed to create issue from $fname"
        ((FAILED_COUNT++))
    fi
}

create_all_issues() {
    step "Creating issues from templates"

    local total="${#ISSUE_FILES[@]}"
    local i=0

    for file in "${ISSUE_FILES[@]}"; do
        ((i++))
        create_issue_from_file "$file" "$i" "$total"
    done
}

main() {
    header
    parse_args "$@"

    if [[ "$DRY_RUN" == true ]]; then
        warn "DRY RUN: no changes will be made to GitHub."
    fi

    check_gh_cli
    check_gh_auth
    detect_repo
    get_issue_files
    ensure_labels_exist
    create_all_issues

    line
    echo
    echo "Summary:"
    echo "  Created : $CREATED_COUNT"
    echo "  Skipped : $SKIPPED_COUNT"
    echo "  Failed  : $FAILED_COUNT"
    echo

    if [[ "$DRY_RUN" == true ]]; then
        warn "This was a dry run. Re-run without --dry-run to actually create issues."
    else
        ok "Done. Issues are in https://github.com/${REPO}/issues"
    fi
    echo
}

main "$@"
