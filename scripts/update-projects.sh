#!/usr/bin/env bash
#
# update-projects.sh - Find and update projects generated from copier templates
#
# This script crawls a directory tree looking for projects with a .repo.yml file
# (copier answers file), checks their update status, and optionally applies updates.
#
# Usage:
#   ./update-projects.sh [OPTIONS] <search-root>
#
# Options:
#   -n, --dry-run       Show what would be updated without making changes (default)
#   -u, --update        Actually apply updates to projects
#   -f, --filter TEMPLATE   Only check projects from a specific template source
#   -a, --answers-file NAME Custom answers file name (default: .repo.yml)
#   -q, --quiet         Suppress progress output
#   -h, --help          Show this help message
#
# Examples:
#   ./update-projects.sh ~/projects                    # Dry-run all projects
#   ./update-projects.sh -u ~/projects                 # Apply updates
#   ./update-projects.sh -f claylo-rs ~/projects       # Only claylo-rs template projects
#
set -euo pipefail

# =============================================================================
# Configuration
# =============================================================================

ANSWERS_FILE=".repo.yml"
DRY_RUN=true
QUIET=false
FILTER_TEMPLATE=""
SEARCH_ROOT=""

# Colors (disabled if not a terminal)
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    DIM='\033[2m'
    NC='\033[0m' # No Color
else
    RED='' GREEN='' YELLOW='' BLUE='' CYAN='' BOLD='' DIM='' NC=''
fi

# =============================================================================
# Helper Functions
# =============================================================================

log() {
    [[ "$QUIET" == "true" ]] && return
    echo -e "$@"
}

log_header() {
    log "${BOLD}${BLUE}$1${NC}"
}

log_success() {
    log "  ${GREEN}✓${NC} $1"
}

log_warning() {
    log "  ${YELLOW}⚠${NC} $1"
}

log_error() {
    log "  ${RED}✗${NC} $1"
}

log_info() {
    log "  ${DIM}$1${NC}"
}

usage() {
    cat << 'EOF'
update-projects.sh - Find and update copier-generated projects

Usage:
  ./update-projects.sh [OPTIONS] <search-root>

Options:
  -n, --dry-run           Show what would be updated without making changes (default)
  -u, --update            Actually apply updates to projects
  -f, --filter TEMPLATE   Only check projects from a specific template source
  -a, --answers-file NAME Custom answers file name (default: .repo.yml)
  -q, --quiet             Suppress progress output
  -h, --help              Show this help message

Examples:
  ./update-projects.sh ~/projects                    # Dry-run all projects
  ./update-projects.sh -u ~/projects                 # Apply updates
  ./update-projects.sh -f claylo-rs ~/projects       # Only claylo-rs template projects

The script looks for projects containing a copier answers file (default: .repo.yml)
and checks if updates are available from their source templates.

Requirements:
  - copier (pip install copier)
  - git
  - yq (optional, for better YAML parsing)
EOF
}

# Parse YAML value - uses yq if available, falls back to grep
yaml_get() {
    local file="$1"
    local key="$2"

    if command -v yq &> /dev/null; then
        yq -r ".$key // empty" "$file" 2>/dev/null || echo ""
    else
        # Fallback: simple grep-based extraction (handles basic cases)
        grep -E "^${key}:" "$file" 2>/dev/null | sed 's/^[^:]*: *//' | sed 's/^["'"'"']//' | sed 's/["'"'"']$//' || echo ""
    fi
}

# Check if git working directory is clean
git_is_clean() {
    local dir="$1"
    cd "$dir"
    [[ -z "$(git status --porcelain 2>/dev/null)" ]]
}

# Get current git branch
git_branch() {
    local dir="$1"
    cd "$dir"
    git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown"
}

# Check if a directory is a git repository
is_git_repo() {
    local dir="$1"
    [[ -d "$dir/.git" ]] || git -C "$dir" rev-parse --git-dir &>/dev/null
}

# =============================================================================
# Core Functions
# =============================================================================

# Find all projects with the answers file
find_projects() {
    local root="$1"
    find "$root" -name "$ANSWERS_FILE" -type f 2>/dev/null | while read -r answers_path; do
        dirname "$answers_path"
    done
}

# Check a single project for updates
check_project() {
    local project_dir="$1"
    local answers_file="$project_dir/$ANSWERS_FILE"

    # Extract template info from answers file
    local src_path
    local commit
    src_path=$(yaml_get "$answers_file" "_src_path")
    commit=$(yaml_get "$answers_file" "_commit")

    # Apply filter if specified
    if [[ -n "$FILTER_TEMPLATE" ]] && [[ "$src_path" != *"$FILTER_TEMPLATE"* ]]; then
        return 1  # Skip - doesn't match filter
    fi

    log_header "$(basename "$project_dir")"
    log_info "Path: $project_dir"
    log_info "Template: ${src_path:-unknown}"
    log_info "Version: ${commit:-unknown}"

    # Check if it's a git repo
    if ! is_git_repo "$project_dir"; then
        log_error "Not a git repository - updates may not work correctly"
        echo "skip:not-git"
        return 0
    fi

    # Check git status
    local branch
    branch=$(git_branch "$project_dir")
    log_info "Branch: $branch"

    if ! git_is_clean "$project_dir"; then
        log_warning "Working directory is dirty - skipping"
        log_info "Run 'git status' in $project_dir to see uncommitted changes"
        echo "skip:dirty"
        return 0
    fi
    log_success "Git status: clean"

    # Check for updates using copier
    log "  ${DIM}Checking for updates...${NC}"

    local update_output
    local update_status

    # Run copier update in pretend mode to see what would change
    # We capture both stdout and stderr
    cd "$project_dir"
    if update_output=$(copier update --pretend --defaults --trust 2>&1); then
        update_status="success"
    else
        update_status="error"
    fi

    # Analyze the output to determine if there are changes
    if [[ "$update_output" == *"No changes to apply"* ]] || [[ -z "$update_output" ]]; then
        log_success "Already up to date"
        echo "uptodate"
    elif [[ "$update_status" == "error" ]]; then
        log_error "Update check failed"
        log_info "$(echo "$update_output" | head -5)"
        echo "error"
    else
        log_warning "Updates available"
        # Show a summary of changes
        if [[ "$update_output" == *"conflict"* ]]; then
            log_warning "Conflicts detected - manual review needed"
        fi
        # Count file operations in output
        local creates modifies deletes
        creates=$(echo "$update_output" | grep -c "create" || true)
        modifies=$(echo "$update_output" | grep -c "overwrite\|modify" || true)
        deletes=$(echo "$update_output" | grep -c "delete" || true)
        [[ "$creates" -gt 0 ]] && log_info "  + $creates file(s) to create"
        [[ "$modifies" -gt 0 ]] && log_info "  ~ $modifies file(s) to modify"
        [[ "$deletes" -gt 0 ]] && log_info "  - $deletes file(s) to delete"
        echo "updates-available"
    fi

    return 0
}

# Apply update to a single project
update_project() {
    local project_dir="$1"

    log_header "Updating: $(basename "$project_dir")"

    cd "$project_dir"

    # Create update branch
    local branch_name="template-update-$(date +%Y%m%d-%H%M%S)"
    log_info "Creating branch: $branch_name"
    git checkout -b "$branch_name"

    # Run the actual update
    if copier update --defaults --trust; then
        log_success "Update applied successfully"

        # Show what changed
        if [[ -n "$(git status --porcelain)" ]]; then
            log_info "Changes:"
            git status --short | head -20 | while read -r line; do
                log_info "  $line"
            done

            # Commit the changes
            git add -A
            git commit -m "chore: update from template

Applied template updates using copier update.
"
            log_success "Changes committed to branch: $branch_name"
            log_info "Review changes and merge when ready"
        else
            log_info "No file changes after update"
            git checkout -
            git branch -d "$branch_name"
        fi

        echo "updated"
    else
        log_error "Update failed"
        git checkout -
        git branch -D "$branch_name" 2>/dev/null || true
        echo "failed"
    fi
}

# =============================================================================
# Main
# =============================================================================

main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -u|--update)
                DRY_RUN=false
                shift
                ;;
            -f|--filter)
                FILTER_TEMPLATE="$2"
                shift 2
                ;;
            -a|--answers-file)
                ANSWERS_FILE="$2"
                shift 2
                ;;
            -q|--quiet)
                QUIET=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            -*)
                echo "Unknown option: $1" >&2
                usage
                exit 1
                ;;
            *)
                SEARCH_ROOT="$1"
                shift
                ;;
        esac
    done

    # Validate arguments
    if [[ -z "$SEARCH_ROOT" ]]; then
        echo "Error: search-root is required" >&2
        usage
        exit 1
    fi

    if [[ ! -d "$SEARCH_ROOT" ]]; then
        echo "Error: '$SEARCH_ROOT' is not a directory" >&2
        exit 1
    fi

    # Check for copier
    if ! command -v copier &> /dev/null; then
        echo "Error: copier is not installed" >&2
        echo "Install with: uv tool install copier --with jinja2-time" >&2
        exit 1
    fi

    # Resolve to absolute path
    SEARCH_ROOT=$(cd "$SEARCH_ROOT" && pwd)

    log ""
    log "${BOLD}Copier Project Update Scanner${NC}"
    log "${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    log "Search root:  $SEARCH_ROOT"
    log "Answers file: $ANSWERS_FILE"
    log "Mode:         $(if $DRY_RUN; then echo "dry-run (use -u to apply)"; else echo "${YELLOW}UPDATE${NC}"; fi)"
    [[ -n "$FILTER_TEMPLATE" ]] && log "Filter:       $FILTER_TEMPLATE"
    log ""

    # Find and process projects
    local total=0
    local uptodate=0
    local updates=0
    local skipped=0
    local errors=0
    local updated=0

    local projects
    projects=$(find_projects "$SEARCH_ROOT")

    if [[ -z "$projects" ]]; then
        log "${YELLOW}No projects found with $ANSWERS_FILE${NC}"
        exit 0
    fi

    while IFS= read -r project_dir; do
        ((total++)) || true
        log ""

        result=$(check_project "$project_dir" || echo "filtered")

        case "$result" in
            uptodate)
                ((uptodate++)) || true
                ;;
            updates-available)
                ((updates++)) || true
                if [[ "$DRY_RUN" == "false" ]]; then
                    update_result=$(update_project "$project_dir")
                    if [[ "$update_result" == "updated" ]]; then
                        ((updated++)) || true
                    else
                        ((errors++)) || true
                    fi
                fi
                ;;
            skip:*)
                ((skipped++)) || true
                ;;
            error)
                ((errors++)) || true
                ;;
            filtered)
                ((total--)) || true  # Don't count filtered projects
                ;;
        esac
    done <<< "$projects"

    # Summary
    log ""
    log "${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    log "${BOLD}Summary${NC}"
    log "  Total projects: $total"
    log "  ${GREEN}Up to date:${NC}    $uptodate"
    log "  ${YELLOW}Updates ready:${NC} $updates"
    log "  ${DIM}Skipped:${NC}       $skipped"
    [[ $errors -gt 0 ]] && log "  ${RED}Errors:${NC}        $errors"
    [[ $updated -gt 0 ]] && log "  ${GREEN}Updated:${NC}       $updated"
    log ""

    if [[ "$DRY_RUN" == "true" ]] && [[ $updates -gt 0 ]]; then
        log "${CYAN}Run with -u to apply updates${NC}"
    fi
}

main "$@"
