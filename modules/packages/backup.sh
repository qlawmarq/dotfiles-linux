#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

. "$DOTFILES_DIR/lib/utils.sh"
. "$DOTFILES_DIR/lib/package.sh"

check_linux

print_info "Backing up installed packages..."

PM=$(detect_package_manager)
OUTPUT_FILE="$SCRIPT_DIR/.packages.backup"

# Export installed packages list
list_installed_packages > "$OUTPUT_FILE"

print_success "Package list backed up to $OUTPUT_FILE"
print_info "Total packages: $(wc -l < "$OUTPUT_FILE")"
