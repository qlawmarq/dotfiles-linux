#!/bin/bash

# ====================
# Package manager abstraction utilities
# ====================

# Detect package manager
detect_package_manager() {
    if command_exists apt-get; then
        echo "apt"
    elif command_exists dnf; then
        echo "dnf"
    elif command_exists pacman; then
        echo "pacman"
    elif command_exists zypper; then
        echo "zypper"
    else
        echo "unknown"
    fi
}

# Normalize package names across distributions
normalize_package_name() {
    local package="$1"
    local pm=$(detect_package_manager)

    case "$package" in
        build-essential)
            case "$pm" in
                dnf) echo "gcc gcc-c++ make";;
                pacman) echo "base-devel";;
                zypper) echo "patterns-devel-base-devel_basis";;
                *) echo "$package";;
            esac
            ;;
        fd-find)
            case "$pm" in
                dnf|pacman|zypper) echo "fd";;
                *) echo "$package";;
            esac
            ;;
        *)
            echo "$package"
            ;;
    esac
}

# Install a single package
install_package() {
    local package="$1"
    local pm=$(detect_package_manager)
    local normalized=$(normalize_package_name "$package")

    case "$pm" in
        apt)
            sudo apt-get install -y $normalized
            ;;
        dnf)
            sudo dnf install -y $normalized
            ;;
        pacman)
            sudo pacman -S --noconfirm $normalized
            ;;
        zypper)
            sudo zypper install -y $normalized
            ;;
        *)
            print_error "Unknown package manager. Please install $package manually."
            return 1
            ;;
    esac
}

# Install multiple packages
install_packages() {
    local pm=$(detect_package_manager)
    local packages=()

    # Normalize each package
    for pkg in "$@"; do
        local normalized=$(normalize_package_name "$pkg")
        # Expand space-separated packages
        for p in $normalized; do
            packages+=("$p")
        done
    done

    case "$pm" in
        apt)
            sudo apt-get update
            sudo apt-get install -y "${packages[@]}"
            ;;
        dnf)
            sudo dnf install -y "${packages[@]}"
            ;;
        pacman)
            sudo pacman -S --noconfirm "${packages[@]}"
            ;;
        zypper)
            sudo zypper install -y "${packages[@]}"
            ;;
        *)
            print_error "Unknown package manager."
            return 1
            ;;
    esac
}

# List installed packages
list_installed_packages() {
    local pm=$(detect_package_manager)

    case "$pm" in
        apt)
            dpkg --get-selections | grep -v deinstall | awk '{print $1}'
            ;;
        dnf)
            dnf list installed | awk 'NR>1 {print $1}' | sed 's/\.[^.]*$//'
            ;;
        pacman)
            pacman -Q | awk '{print $1}'
            ;;
        zypper)
            zypper search -i | awk 'NR>4 {print $3}'
            ;;
        *)
            print_error "Unknown package manager."
            return 1
            ;;
    esac
}
