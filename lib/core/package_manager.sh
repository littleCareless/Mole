#!/bin/bash
# Mole - Package Manager Detection and Operations
# Provides unified interface for different package managers on Linux

set -euo pipefail

# Prevent multiple sourcing
if [[ -n "${MOLE_PKG_MGR_LOADED:-}" ]]; then
    return 0
fi
readonly MOLE_PKG_MGR_LOADED=1

# Source platform detection
_PKG_MGR_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$_PKG_MGR_DIR/platform.sh"

# ============================================================================
# Package Manager Detection
# ============================================================================

# Detect available package managers
# Returns: space-separated list of available package managers
detect_package_managers() {
    local managers=()

    # System package managers
    command -v apt &>/dev/null && managers+=("apt")
    command -v dnf &>/dev/null && managers+=("dnf")
    command -v yum &>/dev/null && managers+=("yum")
    command -v pacman &>/dev/null && managers+=("pacman")
    command -v zypper &>/dev/null && managers+=("zypper")

    # Universal package managers
    command -v flatpak &>/dev/null && managers+=("flatpak")
    command -v snap &>/dev/null && managers+=("snap")

    # macOS package manager
    command -v brew &>/dev/null && managers+=("brew")

    echo "${managers[@]}"
}

# Get primary package manager for the system
# Returns: primary package manager name
get_primary_package_manager() {
    if is_macos; then
        echo "brew"
        return
    fi

    local distro
    distro="$(detect_linux_distro)"

    case "$distro" in
        ubuntu|debian)
            echo "apt"
            ;;
        fedora|rhel)
            if command -v dnf &>/dev/null; then
                echo "dnf"
            else
                echo "yum"
            fi
            ;;
        arch)
            echo "pacman"
            ;;
        *)
            # Fallback: detect first available
            local managers
            managers=($(detect_package_managers))
            if [[ ${#managers[@]} -gt 0 ]]; then
                echo "${managers[0]}"
            else
                echo "unknown"
            fi
            ;;
    esac
}

# Check if a package manager is available
# Usage: has_package_manager <manager_name>
has_package_manager() {
    local manager="$1"
    command -v "$manager" &>/dev/null
}

# ============================================================================
# Package Manager Operations
# ============================================================================

# List installed packages
# Usage: list_installed_packages <manager>
list_installed_packages() {
    local manager="${1:-$(get_primary_package_manager)}"

    case "$manager" in
        apt)
            dpkg --get-selections | grep -v deinstall | awk '{print $1}'
            ;;
        dnf|yum)
            "$manager" list installed 2>/dev/null | tail -n +2 | awk '{print $1}'
            ;;
        pacman)
            pacman -Q | awk '{print $1}'
            ;;
        brew)
            brew list --formula 2>/dev/null
            ;;
        flatpak)
            flatpak list --app --columns=application 2>/dev/null
            ;;
        snap)
            snap list 2>/dev/null | tail -n +2 | awk '{print $1}'
            ;;
        *)
            echo "Unsupported package manager: $manager" >&2
            return 1
            ;;
    esac
}

# Get package cache directory
# Usage: get_package_cache_dir <manager>
get_package_cache_dir() {
    local manager="${1:-$(get_primary_package_manager)}"

    case "$manager" in
        apt)
            echo "/var/cache/apt/archives"
            ;;
        dnf)
            echo "/var/cache/dnf"
            ;;
        yum)
            echo "/var/cache/yum"
            ;;
        pacman)
            echo "/var/cache/pacman/pkg"
            ;;
        brew)
            local brew_prefix
            brew_prefix="$(get_homebrew_prefix)"
            if [[ -n "$brew_prefix" ]]; then
                echo "$brew_prefix/Caches"
            fi
            ;;
        flatpak)
            echo "/var/tmp/flatpak-cache"
            ;;
        snap)
            echo "/var/lib/snapd/cache"
            ;;
        *)
            echo ""
            ;;
    esac
}

# Clean package manager cache
# Usage: clean_package_cache <manager> [--dry-run]
clean_package_cache() {
    local manager="${1:-$(get_primary_package_manager)}"
    local dry_run=false

    if [[ "${2:-}" == "--dry-run" ]]; then
        dry_run=true
    fi

    case "$manager" in
        apt)
            if $dry_run; then
                echo "[DRY RUN] Would clean apt cache"
                du -sh /var/cache/apt/archives 2>/dev/null || true
            else
                sudo apt-get clean 2>/dev/null || true
            fi
            ;;
        dnf)
            if $dry_run; then
                echo "[DRY RUN] Would clean dnf cache"
                du -sh /var/cache/dnf 2>/dev/null || true
            else
                sudo dnf clean all 2>/dev/null || true
            fi
            ;;
        yum)
            if $dry_run; then
                echo "[DRY RUN] Would clean yum cache"
                du -sh /var/cache/yum 2>/dev/null || true
            else
                sudo yum clean all 2>/dev/null || true
            fi
            ;;
        pacman)
            if $dry_run; then
                echo "[DRY RUN] Would clean pacman cache"
                du -sh /var/cache/pacman/pkg 2>/dev/null || true
            else
                sudo pacman -Sc --noconfirm 2>/dev/null || true
            fi
            ;;
        brew)
            if $dry_run; then
                echo "[DRY RUN] Would clean brew cache"
                brew cleanup -n 2>/dev/null || true
            else
                brew cleanup -s 2>/dev/null || true
            fi
            ;;
        flatpak)
            if $dry_run; then
                echo "[DRY RUN] Would clean flatpak cache"
            else
                flatpak uninstall --unused -y 2>/dev/null || true
            fi
            ;;
        snap)
            if $dry_run; then
                echo "[DRY RUN] Would clean snap cache"
            else
                # Snap doesn't have a direct cache clean command
                # Old revisions are cleaned automatically
                true
            fi
            ;;
        *)
            echo "Unsupported package manager: $manager" >&2
            return 1
            ;;
    esac
}

# Remove a package
# Usage: remove_package <manager> <package_name> [--dry-run]
remove_package() {
    local manager="$1"
    local package="$2"
    local dry_run=false

    if [[ "${3:-}" == "--dry-run" ]]; then
        dry_run=true
    fi

    case "$manager" in
        apt)
            if $dry_run; then
                echo "[DRY RUN] Would remove: $package (apt)"
            else
                sudo apt-get remove -y "$package" 2>/dev/null || true
                sudo apt-get autoremove -y 2>/dev/null || true
            fi
            ;;
        dnf)
            if $dry_run; then
                echo "[DRY RUN] Would remove: $package (dnf)"
            else
                sudo dnf remove -y "$package" 2>/dev/null || true
            fi
            ;;
        yum)
            if $dry_run; then
                echo "[DRY RUN] Would remove: $package (yum)"
            else
                sudo yum remove -y "$package" 2>/dev/null || true
            fi
            ;;
        pacman)
            if $dry_run; then
                echo "[DRY RUN] Would remove: $package (pacman)"
            else
                sudo pacman -R --noconfirm "$package" 2>/dev/null || true
            fi
       ;;
        brew)
            if $dry_run; then
                echo "[DRY RUN] Would remove: $package (brew)"
            else
                brew uninstall "$package" 2>/dev/null || true
            fi
            ;;
        flatpak)
            if $dry_run; then
                echo "[DRY RUN] Would remove: $package (flatpak)"
            else
                flatpak uninstall -y "$package" 2>/dev/null || true
            fi
            ;;
        snap)
            if $dry_run; then
                echo "[DRY RUN] Would remove: $package (snap)"
            else
                sudo snap remove "$package" 2>/dev/null || true
            fi
            ;;
        *)
            echo "Unsupported package manager: $manager" >&2
            return 1
            ;;
    esac
}

# Get package information
# Usage: get_package_info <manager> <package_name>
get_package_info() {
    local manager="$1"
    local package="$2"

    case "$manager" in
        apt)
            dpkg -s "$package" 2>/dev/null || apt-cache show "$package" 2>/dev/null
            ;;
        dnf|yum)
            "$manager" info "$package" 2>/dev/null
            ;;
        pacman)
            pacman -Qi "$package" 2>/dev/null || pacman -Si "$package" 2>/dev/null
            ;;
        brew)
            brew info "$package" 2>/dev/null
            ;;
        flatpak)
            flatpak info "$package" 2>/dev/null
            ;;
        snap)
            snap info "$package" 2>/dev/null
            ;;
        *)
            echo "Unsupported package manager: $manager" >&2
            return 1
            ;;
    esac
}

# ============================================================================
# Application Discovery
# ============================================================================

# Find installed applications across all package managers
# Returns: list of application names with their package manager
find_installed_applications() {
    local apps=()

    # Check each available package manager
    for manager in $(detect_package_managers); do
        case "$manager" in
            apt)
                # List GUI applications from apt
                dpkg -l | grep -E "^ii" | awk '{print $2}' | while read -r pkg; do
                    if dpkg -L "$pkg" 2>/dev/null | grep -q "/usr/share/applications/.*\.desktop$"; then
                        echo "$pkg|apt"
                    fi
                done
                ;;
            flatpak)
                # List flatpak applications
                flatpak list --app --columns=application,name 2>/dev/null | while IFS=$'\t' read -r app_id name; do
                    echo "$name|flatpak|$app_id"
                done
                ;;
            snap)
                # List snap applications
                snap list 2>/dev/null | tail -n +2 | awk '{print $1"|snap"}'
                ;;
            brew)
                # List brew casks (GUI applications)
                if is_macos; then
                    brew list --cask 2>/dev/null | awk '{print $1"|brew"}'
                fi
                ;;
        esac
    done
}

# Get application installation path
# Usage: get_app_install_path <app_name> <manager>
get_app_install_path() {
    local app_name="$1"
    local manager="$2"

    case "$manager" in
        apt)
            dpkg -L "$app_name" 2>/dev/null | head -1
            ;;
        flatpak)
            echo "/var/lib/flatpak/app/$app_name"
            ;;
        snap)
            echo "/spp_name"
            ;;
        brew)
            if is_macos; then
                echo "/Applications/$app_name.app"
            fi
            ;;
        *)
            echo ""
            ;;
    esac
}

# ============================================================================
# Export Package Manager Info
# ============================================================================

export MOLE_PRIMARY_PKG_MGR="$(get_primary_package_manager)"
export MOLE_AVAILABLE_PKG_MGRS="$(detect_package_managers)"
