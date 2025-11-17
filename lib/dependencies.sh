#!/bin/bash

# ====================
# Dependencies resolution utilities for dotfiles scripts
# ====================

# Globals for dependency management
DEPS_FILE=""          # Path to dependencies file
SORTED_MODULES=""     # Result of topological sort

# Load dependencies from file
# Usage: load_dependencies "path_to_deps_file"
load_dependencies() {
    local deps_file="$1"
    DEPS_FILE="$deps_file"
    
    # Check if dependencies file exists
    if [ ! -f "$deps_file" ]; then
        print_warning "Dependencies file not found at $deps_file"
        return 1
    fi
    
    return 0
}

# Get dependencies for a module
# Usage: get_module_deps "module_name"
get_module_deps() {
    local module="$1"
    local deps=""
    
    if [ -f "$DEPS_FILE" ]; then
        # Parse dependencies file for the specified module
        deps=$(grep "^$module:" "$DEPS_FILE" | cut -d':' -f2 | xargs)
    fi
    
    echo "$deps"
}

# Check if a module is in a list
# Usage: is_module_in_list "module" "list"
is_module_in_list() {
    local module="$1"
    local list="$2"
    
    if [[ " $list " = *" $module "* ]]; then
        return 0  # Found
    else
        return 1  # Not found
    fi
}

# Mark module as visited in the temp array
# Usage: mark_visited "module" "visited_str"
mark_visited() {
    local module="$1"
    local visited_str="$2"
    
    if [[ "$visited_str" != *"|$module|"* ]]; then
        visited_str="$visited_str|$module|"
    fi
    
    echo "$visited_str"
}

# Check if module is visited
# Usage: is_visited "module" "visited_str"
is_visited() {
    local module="$1"
    local visited_str="$2"
    
    if [[ "$visited_str" = *"|$module|"* ]]; then
        return 0  # Found
    else
        return 1  # Not found
    fi
}

# Simple implementation of topological sort
# Usage: resolve_dependencies "selected_modules"
resolve_dependencies() {
    local selected="$1"
    local result=""
    local visited="|"  # Use |module| format to ensure exact matches
    local temp_mark="|"
    
    # Process each module
    for module in $selected; do
        # Skip already visited modules
        if ! is_visited "$module" "$visited"; then
            # Visit module and update visited string
            local visit_result
            visit_result=$(visit_module "$module" "$visited" "$temp_mark")
            
            # Check for errors (empty result indicates cycle)
            if [ -z "$visit_result" ]; then
                print_error "Circular dependency detected involving module $module"
                return 1
            fi
            
            # Update visited string and result
            visited=$(echo "$visit_result" | cut -d';' -f1)
            local new_modules=$(echo "$visit_result" | cut -d';' -f2)
            result="$new_modules $result"
        fi
    done
    
    # Return result
    echo "$result"
    return 0
}

# Visit module and its dependencies recursively
# Usage: visit_module "module" "visited" "temp_mark"
# Returns: "new_visited;new_modules" or empty string if cycle detected
visit_module() {
    local module="$1"
    local visited="$2"
    local temp_mark="$3"
    local new_modules=""
    
    # Check for cycle
    if [[ "$temp_mark" = *"|$module|"* ]]; then
        return 1  # Cycle detected
    fi
    
    # Skip if already visited
    if [[ "$visited" = *"|$module|"* ]]; then
        echo "$visited;"  # No new modules
        return 0
    fi
    
    # Mark temporarily
    temp_mark="$temp_mark$module|"
    
    # Get dependencies
    local deps=$(get_module_deps "$module")
    
    # Visit all dependencies
    for dep in $deps; do
        # Skip if already visited
        if ! is_visited "$dep" "$visited"; then
            # Visit dependency
            local visit_result
            visit_result=$(visit_module "$dep" "$visited" "$temp_mark")
            
            # Check for errors
            if [ -z "$visit_result" ]; then
                return 1  # Propagate cycle detection
            fi
            
            # Update visited and result
            visited=$(echo "$visit_result" | cut -d';' -f1)
            local dep_modules=$(echo "$visit_result" | cut -d';' -f2)
            new_modules="$dep_modules $new_modules"
        fi
    done
    
    # Mark as visited
    visited="$visited$module|"
    
    # Add module to result
    new_modules="$new_modules $module"
    
    # Return result
    echo "$visited;$new_modules"
    return 0
}

# Get all dependencies of a module (direct and transitive)
# Usage: get_all_dependencies "module_name"
get_all_dependencies() {
    local module="$1"
    local deps=$(get_module_deps "$module")
    local all_deps="$deps"
    
    # Recursively get dependencies of dependencies
    for dep in $deps; do
        local sub_deps=$(get_all_dependencies "$dep")
        all_deps="$all_deps $sub_deps"
    done
    
    # Remove duplicates
    all_deps=$(echo "$all_deps" | tr ' ' '\n' | sort | uniq | tr '\n' ' ')
    echo "$all_deps"
}

# Checks if a module is executable (has apply.sh)
# Usage: is_module_executable "module_name" "modules_dir"
is_module_executable() {
    local module="$1"
    local modules_dir="$2"
    
    if [ -f "$modules_dir/$module/apply.sh" ]; then
        return 0
    else
        return 1
    fi
}

# Print dependency graph for debugging
# Usage: print_dependency_graph
print_dependency_graph() {
    print_info "Module Dependency Graph:"
    
    # List all modules from dependencies file
    local modules=$(grep -E "^[^#].*:" "$DEPS_FILE" | cut -d':' -f1 | xargs)
    
    for module in $modules; do
        local deps=$(get_module_deps "$module")
        if [ -z "$deps" ]; then
            echo "  $module: (no dependencies)"
        else
            echo "  $module: $deps"
        fi
    done
}
