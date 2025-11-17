#!/bin/bash

# Ensure script runs with Bash (not sh/dash)
if [ -z "$BASH_VERSION" ]; then
    exec bash "$0" "$@"
fi

# Load utils
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/lib/utils.sh" ]; then
    . "$SCRIPT_DIR/lib/utils.sh"
else
    echo "Error: utils.sh not found at $SCRIPT_DIR/lib/utils.sh"
    exit 1
fi

check_linux

# Source menu functions
if [ -f "$SCRIPT_DIR/lib/menu.sh" ]; then
    . "$SCRIPT_DIR/lib/menu.sh"
else
    echo "Error: menu.sh not found at $SCRIPT_DIR/lib/menu.sh"
    exit 1
fi

# List all available backup modules
MODULES=()
MODULES_DIR="$SCRIPT_DIR/modules"

for dir in "$MODULES_DIR"/*; do
    [ -d "$dir" ] || continue
    module_name="$(basename "$dir")"
    # Only modules with backup.sh are included
    if [ -f "$dir/backup.sh" ]; then
        MODULES+=("$module_name")
    fi
done

if [ ${#MODULES[@]} -eq 0 ]; then
    print_error "No backup modules found in $MODULES_DIR. Exiting."
    exit 1
fi

# Select which modules to backup
select_modules "${MODULES[@]}"

# No modules selected
if [ -z "$SELECTED_MODULE_INDICES" ]; then
    print_warning "No modules selected. Exiting."
    exit 0
fi

# Process selected modules
print_info "Starting selected module backup..."

for idx in $SELECTED_MODULE_INDICES; do
    module="${MODULES[$idx]}"
    print_info "Backing up $module..."
    if [ -f "$MODULES_DIR/$module/backup.sh" ]; then
        bash "$MODULES_DIR/$module/backup.sh"
        if [ $? -eq 0 ]; then
            print_success "$module backup completed"
        else
            print_error "$module backup failed"
        fi
    else
        print_error "Backup script for $module not found at $MODULES_DIR/$module/backup.sh"
    fi
    echo ""
done

print_success "All configurations have been backed up!"