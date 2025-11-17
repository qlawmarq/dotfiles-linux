#!/bin/bash

# ====================
# Improved menu functions for dotfiles scripts
# ====================

# Simple Y/N selection for each item in a list
# Usage: yn_select_items "Header message" "item1" "item2" ...
# Returns: Space-separated list of selected items in $SELECTED_ITEMS
yn_select_items() {
    local header="$1"
    shift
    local items=("$@")
    
    echo "$header"
    echo "----------------------------------------"
    
    SELECTED_ITEMS=""
    
    for item in "${items[@]}"; do
        read -p "Include '$item'? (y/N): " yn
        case $yn in
            [Yy]* ) 
                SELECTED_ITEMS="$SELECTED_ITEMS $item"
                echo "✓ Selected: $item"
                ;;
            * ) 
                echo "✗ Skipped: $item"
                ;;
        esac
    done
    
    SELECTED_ITEMS="${SELECTED_ITEMS# }" # Remove leading space
    
    echo "----------------------------------------"
    if [ -n "$SELECTED_ITEMS" ]; then
        echo "Selected items: $SELECTED_ITEMS"
    else
        echo "No items selected."
    fi
}

# Advanced multi-select using tput for arrow keys and space selection
# Usage: tui_multi_select "Header message" "item1" "item2" ...
# Returns: Space-separated list of selected items in $SELECTED_ITEMS
tui_multi_select() {
    # Check if required commands exist
    if ! command_exists "tput" || ! command_exists "stty"; then
        print_warning "tput or stty not found, falling back to simple selection"
        yn_select_items "$@"
        return
    fi
    
    local header="$1"
    shift
    local items=("$@")
    local selected=()
    
    # Initialize selected array with zeros
    for i in $(seq 0 $((${#items[@]}-1))); do
        selected[$i]=0
    done
    
    # Save terminal settings
    local old_stty=$(stty -g)
    
    # Disable echoing of input
    stty -echo
    
    # Hide cursor
    tput civis
    
    # Enable line wrapping
    tput smam
    
    # Current position
    local pos=0
    
    # Clear screen and print header
    clear
    echo "$header"
    echo "Use ↑/↓ arrows to navigate, SPACE to select/deselect, ENTER to confirm"
    echo "----------------------------------------"
    
    # Create more space for messages
    for i in $(seq 1 $((${#items[@]} + 5))); do
        echo ""
    done
    
    # Return cursor to start position
    tput cup 3 0
    
    # Function to print the menu
    print_menu() {
        # Clear the entire screen first
        tput clear
        
        # Print header
        echo "$header"
        echo "Use ↑/↓ arrows to navigate, SPACE to select/deselect, ENTER to confirm"
        echo "----------------------------------------"
        
        local i=0
        # Move cursor to line after header
        tput cup 3 0
        
        # Print each item
        for item in "${items[@]}"; do
            # Clear the current line first
            tput el
            
            if [ $i -eq $pos ]; then
                # Current position highlight
                tput setaf 0  # Black text
                tput setab 7  # White background
            else
                tput sgr0     # Reset colors
            fi
            
            if [ ${selected[$i]} -eq 1 ]; then
                # Selected item
                tput bold
                echo "[✓] $item"
                tput sgr0
            else
                echo "[ ] $item"
            fi
            
            if [ $i -eq $pos ]; then
                tput sgr0  # Reset after line
            fi
            
            i=$((i+1))
        done
        
        tput sgr0 # Reset colors
        
        # Clear the rest of the screen
        tput ed
        
        # Print controls hint at the bottom
        tput cup $((3 + ${#items[@]} + 1)) 0
        echo "Press SPACE to select/deselect, ENTER to confirm"
    }
    
    # Initial menu print
    print_menu
    
    # Handle keyboard input
    while true; do
        # Read a single character
        IFS= read -r -n1 key
        
        # Handle special keys (arrow keys produce escape sequences)
        if [ "$key" = $'\e' ]; then
            # Read the rest of the escape sequence
            read -rsn2 key
            
            case $key in
                '[A') # Up arrow
                    if [ $pos -gt 0 ]; then
                        pos=$((pos-1))
                    fi
                    ;;
                '[B') # Down arrow
                    if [ $pos -lt $((${#items[@]}-1)) ]; then
                        pos=$((pos+1))
                    fi
                    ;;
            esac
        elif [ "$key" = ' ' ]; then # Space key
            # Toggle selection
            if [ ${selected[$pos]} -eq 0 ]; then
                selected[$pos]=1
                
                # Visual feedback for selection
                tput cup $((3 + pos)) 0
                tput setaf 0
                tput setab 2  # Green background
                tput bold
                echo "[✓] ${items[$pos]}"
                tput sgr0

            else
                selected[$pos]=0
                
                # Visual feedback for deselection
                tput cup $((3 + pos)) 0
                tput setaf 0
                tput setab 1  # Red background
                echo "[ ] ${items[$pos]}"
                tput sgr0
                
            fi
        elif [ "$key" = '' ]; then # Enter key
            break
        fi
        
        # Update the menu
        print_menu
    done
    
    # Restore terminal settings
    stty $old_stty
    
    # Show cursor again
    tput cnorm
    
    # Clear screen
    clear
    
    # Build the result
    SELECTED_ITEMS=""
    for i in $(seq 0 $((${#items[@]}-1))); do
        if [ ${selected[$i]} -eq 1 ]; then
            SELECTED_ITEMS="$SELECTED_ITEMS ${items[$i]}"
        fi
    done
    SELECTED_ITEMS="${SELECTED_ITEMS# }" # Remove leading space
    
    # Show the result
    echo "$header"
    echo "----------------------------------------"
    if [ -n "$SELECTED_ITEMS" ]; then
        echo "Selected items:"
        for item in $SELECTED_ITEMS; do
            echo "✓ $item"
        done
    else
        echo "No items selected."
    fi
}

# Smart menu that tries TUI first, falls back to Y/N
# Usage: smart_select_items "Header message" "item1" "item2" ...
# Returns: Space-separated list of selected items in $SELECTED_ITEMS
smart_select_items() {
    # Check if terminal supports advanced features
    if [ -t 0 ] && command_exists "tput" && command_exists "stty"; then
        tui_multi_select "$@"
    else
        yn_select_items "$@"
    fi
}

# Function to select from Brewfile
# Usage: select_from_brewfile "header_message" "brewfile_path"
# Returns: Arrays of selected components in $SELECTED_TAPS, $SELECTED_BREWS, $SELECTED_CASKS, $SELECTED_VSCODE
select_from_brewfile() {
    local header="$1"
    local brewfile="$2"
    
    # Initialize arrays
    SELECTED_TAPS=""
    SELECTED_BREWS=""
    SELECTED_CASKS=""
    SELECTED_VSCODE=""
    
    # Check if file exists
    if [ ! -f "$brewfile" ]; then
        print_error "Brewfile not found: $brewfile"
        return 1
    fi
    
    # Parse Brewfile
    taps=()
    brews=()
    casks=()
    vscode=()
    
    while IFS= read -r line; do
        if echo "$line" | grep -q '^tap\ \+"'; then
            name=$(echo "$line" | sed -E 's/^tap[[:space:]]+"([^"]+)".*/\1/')
            taps+=("$name")
        elif echo "$line" | grep -q '^brew\ \+"'; then
            name=$(echo "$line" | sed -E 's/^brew[[:space:]]+"([^"]+)".*/\1/')
            brews+=("$name")
        elif echo "$line" | grep -q '^cask\ \+"'; then
            name=$(echo "$line" | sed -E 's/^cask[[:space:]]+"([^"]+)".*/\1/')
            casks+=("$name")
        elif echo "$line" | grep -q '^vscode\ \+"'; then
            name=$(echo "$line" | sed -E 's/^vscode[[:space:]]+"([^"]+)".*/\1/')
            vscode+=("$name")
        fi
    done < "$brewfile"
    
    # Print Brewfile components
    echo "$header"
    
    # Process taps
    if [ ${#taps[@]} -gt 0 ]; then
        print_info "Selecting Homebrew taps..."
        smart_select_items "Select Homebrew taps" "${taps[@]}"
        SELECTED_TAPS="$SELECTED_ITEMS"
    fi
    
    # Process brews
    if [ ${#brews[@]} -gt 0 ]; then
        print_info "Selecting Homebrew formulae..."
        smart_select_items "Select Homebrew formulae" "${brews[@]}"
        SELECTED_BREWS="$SELECTED_ITEMS"
    fi
    
    # Process casks
    if [ ${#casks[@]} -gt 0 ]; then
        print_info "Selecting Homebrew casks..."
        smart_select_items "Select Homebrew casks" "${casks[@]}"
        SELECTED_CASKS="$SELECTED_ITEMS"
    fi
    
    # Process vscode extensions
    if [ ${#vscode[@]} -gt 0 ]; then
        print_info "Selecting VSCode extensions..."
        smart_select_items "Select VSCode extensions" "${vscode[@]}"
        SELECTED_VSCODE="$SELECTED_ITEMS"
    fi
}


# Function to select modules for main init script
# Usage: select_modules "modules_array"
# Returns: Selected module indices in $SELECTED_MODULE_INDICES
select_modules() {
    local modules_array=("$@")
    local names=()
    local descriptions=()
    
    # Split module entries into names and descriptions
    for module in "${modules_array[@]}"; do
        name="${module%%:*}"
        description="${module#*:}"
        names+=("$name")
        descriptions+=("$description")
    done
    
    # Print available modules
    echo "Available setup modules:"
    for i in $(seq 0 $((${#names[@]}-1))); do
        echo " - ${descriptions[$i]} (${names[$i]})"
    done
    echo ""
    
    # Select modules
    smart_select_items "Select modules to install" "${descriptions[@]}"
    
    # Convert selected items back to indices
    SELECTED_MODULE_INDICES=""
    
    # Loop through each selected item
    for selected_desc in $SELECTED_ITEMS; do
        # Find the matching index
        for i in $(seq 0 $((${#descriptions[@]}-1))); do
            if [ "${descriptions[$i]}" = "$selected_desc" ]; then
                SELECTED_MODULE_INDICES="$SELECTED_MODULE_INDICES $i"
                break
            fi
        done
    done
    SELECTED_MODULE_INDICES="${SELECTED_MODULE_INDICES# }"
}