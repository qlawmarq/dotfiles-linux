#!/bin/bash

# ====================
# Main dotfiles application script with dependency management
# ====================

# Ensure script runs with Bash (not sh/dash)
# This handles cases where the script is invoked with 'sh apply.sh'
if [ -z "$BASH_VERSION" ]; then
    # Not running in Bash, re-execute with bash
    exec bash "$0" "$@"
fi

# Directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

# Load common utilities
if [ -f "$SCRIPT_DIR/lib/utils.sh" ]; then
    . "$SCRIPT_DIR/lib/utils.sh"
else
    echo "Error: utils.sh not found at $SCRIPT_DIR/lib/utils.sh"
    exit 1
fi

# Source menu functions
if [ -f "$SCRIPT_DIR/lib/menu.sh" ]; then
    . "$SCRIPT_DIR/lib/menu.sh"
else
    echo "Error: menu.sh not found at $SCRIPT_DIR/lib/menu.sh"
    exit 1
fi

# Source dependency management functions
if [ -f "$SCRIPT_DIR/lib/dependencies.sh" ]; then
    . "$SCRIPT_DIR/lib/dependencies.sh"
else
    echo "Error: dependencies.sh not found at $SCRIPT_DIR/lib/dependencies.sh"
    exit 1
fi

# Check if running on Linux
check_linux

# Print welcome message
clear
echo "===================================="
echo "   Linux/WSL Dotfiles Setup Tool    "
echo "===================================="
echo ""

# List all available application modules
MODULES=()
MODULES_DIR="$SCRIPT_DIR/modules"

# Enumerate subdirectories in modules directory
for dir in "$MODULES_DIR"/*; do
    [ -d "$dir" ] || continue
    module_name="$(basename "$dir")"
    MODULES+=("$module_name")
done

if [ ${#MODULES[@]} -eq 0 ]; then
    print_error "No modules found in $MODULES_DIR. Exiting."
    exit 1
fi

# Select which modules to apply
select_modules "${MODULES[@]}"

# No modules selected
if [ -z "$SELECTED_MODULE_INDICES" ]; then
    print_warning "No modules selected. Exiting."
    exit 0
fi

# Convert selected indices to module names
SELECTED_MODULES=""
for idx in $SELECTED_MODULE_INDICES; do
    module="${MODULES[$idx]}"
    SELECTED_MODULES="$SELECTED_MODULES $module"
done
SELECTED_MODULES="${SELECTED_MODULES# }" # Remove leading space

print_info "Selected modules: $SELECTED_MODULES"

# Load module dependencies
DEPS_FILE="$MODULES_DIR/dependencies.txt"
if ! load_dependencies "$DEPS_FILE"; then
    if confirm "Dependencies file not found. Continue without dependency resolution?"; then
        print_warning "Continuing without dependency resolution. Modules may fail if dependencies are not met."
        RESOLVED_MODULES="$SELECTED_MODULES"
    else
        print_error "Aborting due to missing dependencies file."
        exit 1
    fi
else
    # Print dependency information for debugging
    if [ -n "$DEBUG" ]; then
        print_dependency_graph
    fi
    
    # Resolve dependencies into correct order
    RESOLVED_MODULES=$(resolve_dependencies "$SELECTED_MODULES")
    
    # Check if dependency resolution was successful
    if [ $? -ne 0 ]; then
        print_error "Failed to resolve dependencies. Please check for circular dependencies."
        if confirm "Continue with selected modules without dependency resolution?"; then
            print_warning "Continuing without dependency resolution. Some modules may fail."
            RESOLVED_MODULES="$SELECTED_MODULES"
        else
            exit 1
        fi
    fi
fi

# Find which modules are dependencies but not explicitly selected
DEPENDENCY_MODULES=""
for module in $RESOLVED_MODULES; do
    if ! echo " $SELECTED_MODULES " | grep -q " $module "; then
        DEPENDENCY_MODULES="$DEPENDENCY_MODULES $module"
    fi
done
DEPENDENCY_MODULES="${DEPENDENCY_MODULES# }" # Remove leading space

# Skip dependencies option if there are any dependencies
SKIP_DEPENDENCIES=0
if [ -n "$DEPENDENCY_MODULES" ]; then
    echo ""
    print_info "The following modules will be installed as dependencies:"
    for module in $DEPENDENCY_MODULES; do
        echo " - $module"
    done
    echo ""
    print_warning "CAUTION: Skipping dependencies may cause failures in dependent modules."
    if confirm "Would you like to skip installing dependencies?"; then
        SKIP_DEPENDENCIES=1
        print_warning "Dependencies will be skipped. This may cause failures in selected modules."
        # Remove dependencies from resolved modules
        TEMP_RESOLVED=""
        for module in $RESOLVED_MODULES; do
            if echo " $SELECTED_MODULES " | grep -q " $module "; then
                TEMP_RESOLVED="$TEMP_RESOLVED $module"
            fi
        done
        RESOLVED_MODULES="${TEMP_RESOLVED# }" # Remove leading space
    else
        print_info "Dependencies will be installed."
    fi
fi

# Process modules in the resolved order
print_info "Installing modules in the following order:"
for module in $RESOLVED_MODULES; do
    echo " - $module"
done
echo ""

# Track module installation status using strings instead of associative arrays
MODULE_STATUS=""

# Install modules in the correct order
for module in $RESOLVED_MODULES; do
    print_info "Setting up $module..."

    # Check module dependencies
    deps=$(get_module_deps "$module")
    missing_deps=""
    if [ -n "$deps" ] && [ $SKIP_DEPENDENCIES -eq 1 ]; then
        print_warning "$module depends on the following modules that will be skipped:"
        for dep in $deps; do
            echo " - $dep"
        done
        if ! confirm "Continue installing $module anyway?"; then
            print_info "Skipping $module installation"
            MODULE_STATUS="$MODULE_STATUS $module:skipped"
            continue
        fi
    elif [ -n "$deps" ]; then
        # Check if all dependencies were successfully installed
        for dep in $deps; do
            if echo "$MODULE_STATUS" | grep -q "$dep:failed" || echo "$MODULE_STATUS" | grep -q "$dep:missing" || echo "$MODULE_STATUS" | grep -q "$dep:skipped"; then
                missing_deps="$missing_deps $dep"
            fi
        done
        
        if [ -n "$missing_deps" ]; then
            print_warning "$module depends on modules that failed or were skipped:"
            for dep in $missing_deps; do
                echo " - $dep"
            done
            if ! confirm "Continue installing $module anyway?"; then
                print_info "Skipping $module installation"
                MODULE_STATUS="$MODULE_STATUS $module:skipped"
                continue
            fi
        fi
    fi
    
    # Check if module init script exists
    if is_module_executable "$module" "$MODULES_DIR"; then
        # Execute module init script
        if bash "$MODULES_DIR/$module/apply.sh"; then
            print_success "$module setup completed"
            MODULE_STATUS="$MODULE_STATUS $module:success"
        else
            print_error "$module setup failed"
            MODULE_STATUS="$MODULE_STATUS $module:failed"

            # Check if any modules depend on this one
            dependent_modules=""
            for m in $SELECTED_MODULES; do
                all_deps=$(get_all_dependencies "$m")
                if echo " $all_deps " | grep -q " $module "; then
                    dependent_modules="$dependent_modules $m"
                fi
            done
            
            if [ -n "$dependent_modules" ]; then
                print_warning "The following modules may fail because they depend on $module:"
                for m in $dependent_modules; do
                    echo " - $m"
                done
                
                if ! confirm "Continue with installation?"; then
                    print_error "Installation aborted by user."
                    exit 1
                fi
            fi
        fi
    else
        print_error "Apply script for $module not found at $MODULES_DIR/$module/apply.sh"
        MODULE_STATUS="$MODULE_STATUS $module:missing"
    fi
    echo ""
done

# Print installation summary
echo "===================================="
echo "     Installation Summary           "
echo "===================================="

for module in $RESOLVED_MODULES; do
    # Get status for this module
    status=$(echo "$MODULE_STATUS" | grep -o "$module:[a-z]*" | cut -d':' -f2)
    
    case "$status" in
        "success")
            print_success "$module: Successfully installed"
            ;;
        "failed")
            print_error "$module: Installation failed"
            ;;
        "missing")
            print_warning "$module: Init script missing"
            ;;
        "skipped")
            print_warning "$module: Installation skipped"
            ;;
        *)
            print_warning "$module: Unknown status"
            ;;
    esac
done

# Print skipped dependencies if any
if [ $SKIP_DEPENDENCIES -eq 1 ] && [ -n "$DEPENDENCY_MODULES" ]; then
    echo ""
    print_warning "The following dependencies were skipped:"
    for module in $DEPENDENCY_MODULES; do
        echo " - $module"
    done
    echo ""
    print_info "If you encounter issues with installed modules, try installing these dependencies."
fi

# Source profile to apply changes
if [ -f ~/.zprofile ]; then
    print_info "Sourcing ~/.zprofile to apply changes"
    . ~/.zprofile
fi

print_success "Setup completed! Please restart your terminal."
exit 0
