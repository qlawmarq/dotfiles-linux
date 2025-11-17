#!/bin/bash

# ====================
# Utility functions for dotfiles scripts (Linux version)
# ====================

# Check if running on Linux
check_linux() {
    if [ "$(uname)" != "Linux" ]; then
        echo "Error: This script must be run on Linux!" >&2
        exit 1
    fi
}

# Detect OS distribution
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"  # ubuntu, debian, fedora, arch, etc.
    else
        echo "unknown"
    fi
}

# Detect distribution version
detect_distro_version() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$VERSION_ID"
    fi
}

# Check if running in WSL
is_wsl() {
    [ -n "$WSL_DISTRO_NAME" ] || grep -qi microsoft /proc/version 2>/dev/null
}

# Copy to clipboard (cross-platform)
copy_to_clipboard() {
    if command_exists xclip; then
        xclip -selection clipboard
    elif command_exists wl-copy; then
        wl-copy
    elif command_exists clip.exe; then  # WSL
        clip.exe
    else
        print_warning "No clipboard utility found. Install xclip or wl-clipboard."
        return 1
    fi
}

# Function to ask for confirmation
confirm() {
    read -p "$1 (y/N): " yn
    case $yn in
        [Yy]* ) return 0;;
        * ) return 1;;
    esac
}

# Function to print colored output
print_info() {
    echo -e "\033[0;34m[INFO]\033[0m $1"
}

print_success() {
    echo -e "\033[0;32m[SUCCESS]\033[0m $1"
}

print_warning() {
    echo -e "\033[0;33m[WARNING]\033[0m $1" >&2
}

print_error() {
    echo -e "\033[0;31m[ERROR]\033[0m $1" >&2
}

# Get script directory
get_script_dir() {
    echo "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
}

# Check command existence
command_exists() {
    command -v "$1" &> /dev/null
}

# Install command if not exists
ensure_command() {
    local cmd="$1"
    local install_cmd="$2"
    
    if ! command_exists "$cmd"; then
        print_info "$cmd is not installed. Installing..."
        eval "$install_cmd"
        if [ $? -ne 0 ]; then
            print_error "Failed to install $cmd"
            return 1
        fi
        print_success "$cmd installed successfully"
    else
        print_info "$cmd is already installed"
    fi
    return 0
}

# Parse JSON and extract value for a key
# Usage: parse_json "key" "json_file"
parse_json() {
    local key="$1"
    local file="$2"
    
    if command_exists "jq"; then
        jq -r ".$key" "$file" 2>/dev/null
    elif command_exists "python3"; then
        python3 -c "import json,sys;obj=json.load(open('$file'));print(obj.get('$key',''))"
    elif command_exists "python"; then
        python -c "import json,sys;obj=json.load(open('$file'));print(obj.get('$key',''))"
    else
        # Fallback to grep (limited functionality)
        grep -o "\"$key\": *\"[^\"]*\"" "$file" | sed -E "s/\"$key\": *\"([^\"]*)\"/\1/"
    fi
}

# Creates a temporary file with auto cleanup
create_temp_file() {
    local tmp_file
    tmp_file=$(mktemp)
    
    # Note: We're removing the trap to avoid issues with multiple traps
    # User must manually remove temp files
    
    echo "$tmp_file"
}

# Function to check minimum version
# Usage: check_version "current_ver" "required_ver"
check_version() {
    local current="$1"
    local required="$2"
    
    if [[ "$current" == "$required" ]]; then
        return 0
    fi
    
    local IFS=.
    local i ver1=($current) ver2=($required)
    
    # Fill empty fields with zeros
    for ((i=${#ver1[@]}; i<${#ver2[@]}; i++)); do
        ver1[i]=0
    done
    
    for ((i=0; i<${#ver1[@]}; i++)); do
        if [[ -z ${ver2[i]} ]]; then
            ver2[i]=0
        fi
        if ((10#${ver1[i]} < 10#${ver2[i]})); then
            return 1
        fi
        if ((10#${ver1[i]} > 10#${ver2[i]})); then
            return 0
        fi
    done
    return 0
}