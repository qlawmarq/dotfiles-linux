#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Load utils
. "$DOTFILES_DIR/lib/utils.sh"
. "$DOTFILES_DIR/lib/menu.sh"
. "$DOTFILES_DIR/lib/package.sh"

check_linux

print_info "System Package Setup"
echo "====================="

# Detect package manager
PM=$(detect_package_manager)
print_info "Detected package manager: $PM"

if [ "$PM" = "unknown" ]; then
    print_error "No supported package manager found."
    print_info "Supported: apt, dnf, pacman, zypper"
    exit 1
fi

# Read .packages file
PACKAGES_FILE="$SCRIPT_DIR/.packages"
if [ ! -f "$PACKAGES_FILE" ]; then
    print_error "Package list not found at $PACKAGES_FILE"
    exit 1
fi

# Parse packages (exclude comments and empty lines)
packages=()
while IFS= read -r line; do
    # Skip comments and empty lines
    [[ "$line" =~ ^#.*$ ]] && continue
    [[ -z "$line" ]] && continue
    packages+=("$line")
done < "$PACKAGES_FILE"

# Interactive selection
smart_select_items "Select packages to install" "${packages[@]}"
SELECTED_PACKAGES="$SELECTED_ITEMS"

if [ -z "$SELECTED_PACKAGES" ]; then
    print_warning "No packages selected"
    exit 0
fi

# Show selected packages
print_info "Selected packages:"
echo "$SELECTED_PACKAGES" | tr ' ' '\n'
echo ""

if confirm "Install selected packages?"; then
    print_info "Installing packages..."
    install_packages $SELECTED_PACKAGES

    if [ $? -eq 0 ]; then
        print_success "Packages installed successfully"
    else
        print_error "Some packages failed to install"
        exit 1
    fi
else
    print_info "Installation cancelled"
fi
