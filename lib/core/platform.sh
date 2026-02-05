#!/bin/bash
# Mole - Platform Detection and Path Mapping Module
# Provides cross-platform compatibility for macOS and Linux

set -euo pipefail

# Prevent multiple sourcing
if [[ -n "${MOLE_PLATFORM_LOADED:-}" ]]; then
    return 0
fi
readonly MOLE_PLATFORM_LOADED=1

# ============================================================================
# Platform Detection
# ============================================================================

# Detect current operating system
# Returns: "macos" or "linux"
detect_platform() {
    case "$(uname -s)" in
        Darwin*)
            echo "macos"
            ;;
        Linux*)
            echo "linux"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Detect Linux distribution
# Returns: "ubuntu", "debian", "fedora", "arch", "rhel", or "unknown"
detect_linux_distro() {
    if [[ "$(detect_platform)" != "linux" ]]; then
        echo "not_linux"
        return
    fi

    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        case "${ID:-unknown}" in
            ubuntu)
                echo "ubuntu"
                ;;
            debian)
                echo "debian"
                ;;
            fedora)
                echo "fedora"
                ;;
            rhel|centos|rocky|almalinux)
                echo "rhel"
                ;;
            arch|manjaro|endeavouros)
                echo "arch"
                ;;
            *)
                echo "unknown"
                ;;
        esac
    else
        echo "unknown"
    fi
}

# Check if running on macOS
is_macos() {
    [[ "$(detect_platform)" == "macos" ]]
}

# Check if running on Linux
is_linux() {
    [[ "$(detect_platform)" == "linux" ]]
}

# ============================================================================
# Path Mapping Functions
# ============================================================================

# Get user cache directory
# macOS: ~/Library/Caches
# Linux: ~/.cache (XDG Base Directory)
get_user_cache_dir() {
    if is_macos; then
        echo "$HOME/Library/Caches"
    else
        echo "${XDG_CACHE_HOME:-$HOME/.cache}"
    fi
}

# Get user data directory
# macOS: ~/Library/Application Support
# Linux: ~/.local/share (XDG Base Directory)
get_user_data_dir() {
    if is_macos; then
        echo "$HOME/Library/Application Support"
    else
        echo "${XDG_DATA_HOME:-$HOME/.local/share}"
    fi
}

# Get user config directory
# macOS: ~/Library/Preferences
# Linux: ~/.config (XDG Base Directory)
get_user_config_dir() {
    if is_macos; then
        echo "$HOME/Library/Preferences"
    else
        echo "${XDG_CONFIG_HOME:-$HOME/.config}"
    fi
}

# Get user log directory
# macOS: ~/Library/Logs
# Linux: ~/.local/state or ~/.cache/logs
get_user_log_dir() {
    if is_macos; then
        echo "$HOME/Library/Logs"
    else
        # XDG Base Directory Specification v0.8
        echo "${XDG_STATE_HOME:-$HOME/.local/state}"
    fi
}

# Get system cache directory
# macOS: /Library/Caches
# Linux: /var/cache
get_system_cache_dir() {
    if is_macos; then
        echo "/Library/Caches"
    else
        echo "/var/cache"
    fi
}

# Get system log directory
# macOS: /Library/Logs or /private/var/log
# Linux: /var/log
get_system_log_dir() {
    if is_macos; then
        echo "/private/var/log"
    else
        echo "/var/log"
    fi
}

# Get system temp directory
# macOS: /private/tmp
# Linux: /tmp
get_system_tmp_dir() {
    if is_macos; then
        echo "/private/tmp"
    else
        echo "/tmp"
    fi
}

# Get system var temp directory
# macOS: /private/var/tmp
# Linux: /var/tmp
get_system_var_tmp_dir() {
    if is_macos; then
        echo "/private/var/tmp"
    else
        echo "/var/tmp"
    fi
}

# Get applications directory
# macOS: /Applications and ~/Applications
# Linux: /usr/share/applications, ~/.local/share/applications, /opt
get_applications_dirs() {
    if is_macos; then
        echo "/Applications"
        echo "$HOME/Applications"
    else
        echo "/usr/share/applications"
        echo "$HOME/.local/share/applications"
        echo "/opt"
        # Snap and Flatpak
        [[ -d /snap ]] && echo "/snap"
        [[ -d "$HOME/.local/share/flatpak" ]] && echo "$HOME/.local/share/flatpak"
        [[ -d /var/lib/flatpak ]] && echo "/var/lib/flatpak"
    fi
}

# Get browser cache directories
# Returns array of browser cache paths for current platform
get_browser_cache_dirs() {
    local user_cache
    user_cache="$(get_user_cache_dir)"

    if is_macos; then
        # macOS browser paths
        echo "$user_cache/Google/Chrome"
        echo "$user_cache/com.apple.Safari"
        echo "$user_cache/Firefox"
        echo "$user_cache/Microsoft Edge"
        echo "$user_cache/Brave"
    else
        # Linux browser paths
        echo "$user_cache/google-chrome"
        echo "$user_cache/chromium"
        echo "$user_cache/mozilla/firefox"
        echo "$user_cache/microsoft-edge"
        echo "$user_cache/BraveSoftware/Brave-Browser"
    fi
}

# Get trash directory
# macOS: ~/.Trash
# Linux: ~/.local/share/Trash
get_trash_dir() {
    if is_macos; then
        echo "$HOME/.Trash"
    else
        echo "$HOME/.local/share/Trash"
    fi
}

# ============================================================================
# Developer Tool Paths
# ============================================================================

# Get Homebrew prefix
# macOS: /opt/homebrew (Apple Silicon) or /usr/local (Intel)
# Linux: /home/linuxbrew/.linuxbrew or ~/.linuxbrew
get_homebrew_prefix() {
    if command -v brew &>/dev/null; then
        brew --prefix 2>/dev/null || echo ""
    elif is_macos; then
        if [[ -d /opt/homebrew ]]; then
            echo "/opt/homebrew"
        else
            echo "/usr/local"
        fi
    else
        if [[ -d /home/linuxbrew/.linuxbrew ]]; then
            echo "/home/linuxbrew/.linuxbrew"
        elif [[ -d "$HOME/.linuxbrew" ]]; then
            echo "$HOME/.linuxbrew"
        else
            echo ""
        fi
    fi
}

# Get npm cache directory
get_npm_cache_dir() {
    if command -v npm &>/dev/null; then
        npm config get cache 2>/dev/null || echo ""
    else
        if is_macos; then
            echo "$HOME/Library/Caches/npm"
        else
            echo "$HOME/.npm"
        fi
    fi
}

# Get yarn cache directory
get_yarn_cache_dir() {
    if command -v yarn &>/dev/null; then
        yarn cache dir 2>/dev/null || echo ""
    else
        if is_macos; then
            echo "$HOME/Library/Caches/Yarn"
        else
            echo "$HOME/.cache/yarn"
        fi
    fi
}

# ============================================================================
# System Service Management
# ============================================================================

# Get service manager command
# macOS: launchctl
# Linux: systemctl
get_service_manager() {
    if is_macos; then
        echo "launchctl"
    else
        echo "systemctl"
    fi
}

# Restart a system service
# Usage: restart_service <service_name>
restart_service() {
    local service="$1"

    if is_macos; then
        # macOS uses launchctl
        sudo launchctl kickstart -k "system/$service" 2>/dev/null || true
    else
        # Linux uses systemctl
        sudo systemctl restart "$service" 2>/dev/null || true
    fi
}

# ============================================================================
# Platform-Specific Commands
# ============================================================================

# Purge memory/caches
# macOS: purge command
# Linux: drop caches via /proc
purge_memory() {
    if is_macos; then
        sudo purge 2>/dev/null || true
    else
        # Linux: drop page cache, dentries and inodes
        sync
        echo 3 | sudo tee /proc/sys/vm/drop_caches >/dev/null 2>&1 || true
    fi
}

# Get disk usage command
# Returns: "du" with appropriate flags
get_disk_usage_cmd() {
    if is_macos; then
        echo "du -sk"
    else
        echo "du -sb"
    fi
}

# ============================================================================
# Export Platform Info
# ============================================================================

# Export platform variables for use in other scripts
export MOLE_PLATFORM="$(detect_platform)"
export MOLE_USER_CACHE_DIR="$(get_user_cache_dir)"
export MOLE_USER_DATA_DIR="$(get_user_data_dir)"
export MOLE_USER_CONFIG_DIR="$(get_user_config_dir)"
export MOLE_USER_LOG_DIR="$(get_user_log_dir)"
export MOLE_SYSTEM_CACHE_DIR="$(get_system_cache_dir)"
export MOLE_SYSTEM_LOG_DIR="$(get_system_log_dir)"
export MOLE_TRASH_DIR="$(get_trash_dir)"

if is_linux; then
    export MOLE_LINUX_DISTRO="$(detect_linux_distro)"
fi
