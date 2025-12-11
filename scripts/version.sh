#!/bin/bash

# Version management script for the email services project
# Usage: ./scripts/version.sh [command] [options]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Get current version from git tags
get_current_version() {
    git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0"
}

# Increment version
increment_version() {
    local version=$1
    local strategy=$2
    
    # Remove 'v' prefix if present
    version=${version#v}
    
    # Split version into parts
    IFS='.' read -ra PARTS <<< "$version"
    major=${PARTS[0]:-0}
    minor=${PARTS[1]:-0}
    patch=${PARTS[2]:-0}
    
    case $strategy in
        major)
            major=$((major + 1))
            minor=0
            patch=0
            ;;
        minor)
            minor=$((minor + 1))
            patch=0
            ;;
        patch)
            patch=$((patch + 1))
            ;;
        *)
            log_error "Invalid strategy: $strategy. Use major, minor, or patch."
            exit 1
            ;;
    esac
    
    echo "${major}.${minor}.${patch}"
}

# Show current version
show_current() {
    local current=$(get_current_version)
    log_info "Current version: $current"
    
    # Show what next versions would be
    local next_patch=$(increment_version "$current" "patch")
    local next_minor=$(increment_version "$current" "minor")
    local next_major=$(increment_version "$current" "major")
    
    echo ""
    echo "Next versions would be:"
    echo "  Patch: v$next_patch"
    echo "  Minor: v$next_minor"
    echo "  Major: v$next_major"
}

# Create and push a new version tag
create_tag() {
    local strategy=$1
    local message=$2
    
    if [[ -z "$strategy" ]]; then
        log_error "Strategy required. Use: major, minor, or patch"
        exit 1
    fi
    
    # Check if working directory is clean
    if ! git diff-index --quiet HEAD --; then
        log_error "Working directory is not clean. Please commit or stash changes first."
        exit 1
    fi
    
    local current=$(get_current_version)
    local new_version="v$(increment_version "$current" "$strategy")"
    
    log_info "Creating new $strategy version: $current -> $new_version"
    
    # Create tag with message
    if [[ -n "$message" ]]; then
        git tag -a "$new_version" -m "$message"
    else
        git tag -a "$new_version" -m "Release $new_version"
    fi
    
    log_success "Created tag: $new_version"
    
    # Ask if user wants to push
    read -p "Push tag to remote? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git push origin "$new_version"
        log_success "Pushed tag to remote: $new_version"
        log_info "GitHub Actions will automatically build and deploy this version."
    else
        log_warning "Tag created locally but not pushed. Use 'git push origin $new_version' to push later."
    fi
}

# Show help
show_help() {
    cat << EOF
Version Management Script

Usage: $0 [command] [options]

Commands:
    current                     Show current version and next possible versions
    tag <strategy> [message]    Create a new version tag
                               strategy: major, minor, or patch
                               message: optional tag message

Examples:
    $0 current                          # Show current version
    $0 tag patch                        # Create patch version (1.0.0 -> 1.0.1)
    $0 tag minor "Add new feature"      # Create minor version with message
    $0 tag major                        # Create major version (1.0.0 -> 2.0.0)

The script will:
1. Check that your working directory is clean
2. Calculate the next version based on current git tags
3. Create an annotated git tag
4. Optionally push the tag to trigger automated builds

EOF
}

# Main script logic
case "${1:-}" in
    "current")
        show_current
        ;;
    "tag")
        create_tag "$2" "$3"
        ;;
    "help"|"-h"|"--help"|"")
        show_help
        ;;
    *)
        log_error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac