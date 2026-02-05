#!/bin/bash
# Example: Cross-Platform Cache Cleanup Module
# This demonstrates how to adapt existing cleanup code to use platform abstraction

set -euo pipefail

# This example shows the pattern for adapting lib/clean/*.sh files

# ============================================================================
# BEFORE (macOS only):
# ============================================================================
# clean_user_caches_old() {
#     local cache_dir="$HOME/Library/Caches"
#     find "$cache_dir" -type f -name "*.cache" -delete
# }

# ============================================================================
# AFTER (Cross-platform):
# ============================================================================
clean_user_caches_new() {
    # Use platform abstraction function instead of hardcoded path
    local cache_dir
    cache_dir=$(get_user_cache_dir)

    if [[ -d "$cache_dir" ]]; then
        find "$cache_dir" -type f -name "*.cache" -delete 2>/dev/null || true
    fi
}

# ============================================================================
# Example: Browser Cache Cleanup
# ============================================================================

# BEFORE (macOS only):
clean_browser_caches_old() {
    local chrome_cache="$HOME/Library/Caches/Google/Chrome"
    local firefox_cache="$HOME/Library/Caches/Firefox"

    [[ -d "$chrome_cache" ]] && rm -rf "$chrome_cache"/*
    [[ -d "$firefox_cache" ]] && rm -rf "$firefox_cache"/*
}

# AFTER (Cross-platform):
clean_browser_caches_new() {
    # Iterate through all browser cache directories for current platform
    while IFS= read -r browser_cache; do
        if [[ -d "$browser_cache" ]]; then
            echo "Cleaning: $browser_cache"
            rm -rf "$browser_cache"/* 2>/dev/null || true
        fi
    done < <(get_browser_cache_dirs)
}

# ============================================================================
# Example: System Cache Cleanup
# ============================================================================

# BEFORE (macOS only):
clean_system_caches_old() {
    sudo rm -rf /Library/Caches/*
    sudo rm -rf /private/var/log/*.log
}

# AFTER (Cross-platform):
clean_system_ca() {
    local sys_cache sys_log
    sys_cache=$(get_system_cache_dir)
    sys_log=$(get_system_log_dir)

    # Clean system cache
    if [[ -d "$sys_cache" ]]; then
        sudo find "$sys_cache" -type f -mtime +7 -delete 2>/dev/null || true
    fi

    # Clean system logs
    if [[ -d "$sys_log" ]]; then
        sudo find "$sys_log" -type f -name "*.log" -mtime +30 -delete 2>/dev/null || true
    fi
}

# ============================================================================
# Example: Package Manager Cache Cleanup
# ============================================================================

# BEFORE (macOS only - Homebrew):
clean_package_cache_old() {
    if command -v brew &>/dev/null; then
        brew cleanup -s
    fi
}

# AFTER (Cross-platform):
clean_package_cache_new() {
    local primary_mgr
    primary_mgr=$(get_primary_package_manager)

    echo "Cleaning $primary_mgr cache..."
    clean_package_cache "$primary_mgr"

    # Also clean other available package managers
    for mgr in $(detect_package_managers); do
        if [[ "$mgr" != "$primary_mgr" ]]; then
            echo "Cleaning $mgr cache..."
            clean_package_cache "$mgr"
        fi
    done
}

# ============================================================================
# Example: Platform-Specific Operations
# ============================================================================

# BEFORE (macOS only):
optimize_system_old() {
    sudo purge
    sudo update_dyld_shared_cache
    killall Dock
}

# AFTER (Cross-platform):
optimize_system_new() {
    if is_macos; then
        # macOS-specific optimizations
        sudo purge 2>/dev/null || true
        sudo update_dyld_shared_cache -force 2>/dev/null || true
        killall Dock 2>/dev/null || true
    elif is_linux; then
        # Linux-specific opzations
        purge_memory  # Uses platform abstraction
        sudo ldconfig 2>/dev/null || true

        # Restart display manager if needed
        if systemctl is-active --quiet gdm; then
            sudo systemctl restart gdm 2>/dev/null || true
        fi
    fi
}

# ============================================================================
# Example: Trash Cleanup
# ============================================================================

# BEFORE (macOS only):
empty_trash_old() {
    rm -rf "$HOME/.Trash"/*
}

# AFTER (Cross-platform):
empty_trash_new() {
    rash_dir
    trash_dir=$(get_trash_dir)

    if [[ -d "$trash_dir" ]]; then
        echo "Emptying trash: $trash_dir"
        rm -rf "$trash_dir"/* 2>/dev/null || true

        # Linux: also clean trash metadata
        if is_linux && [[ -d "$trash_dir/files" ]]; then
            rm -rf "$trash_dir/files"/* 2>/dev/null || true
            rm -rf "$trash_dir/info"/* 2>/dev/null || true
        fi
    fi
}

# ============================================================================
# Example: Application Data Cleanup
# ============================================================================

# BEFORE (macOS only):
clean_app_data_old() {
    local app_support="$HOME/Library/Application Support"
    rm -rf "$app_support/SomeApp/cache"
}

# AFTER (Cross-platform):
clean_app_data_new() {
    local data_dir
    data_dir=$(get_user_data_dir)

    # Clean application cache
    local app_cache="$data_dir/SomeApp/cache"
    if [[ -d "$app_cache" ]]; then
        echo "Cleaning app cache: $app_cache"
        rm -rf "$app_cache"/* 2>/dev/null || true
    fi
}

# ============================================================================
# Key Patterns for Adaptation:
# ============================================================================
#
# 1. Replace hardcoded paths with platform functions:
#    - "$HOME/Library/Caches" → $(get_user_cache_dir)
#    - "/Library/Caches" → $(get_system_cache_dir)
#    - "$HOME/.Trash" → $(get_trash_dir)
#
# 2. Use platform checks for OS-specific code:
#    - if is_macos; then ... fi
#    - if is_linux; then ... fi
#
# 3. Use package manager abstraction:
#    - clean_package_cache "$(get_primary_package_manager)"
#    - remove_package "apt" "package-name"
#
# 4. Use platform-specific command wrappers:
#    - purge_memory (handles both macOS purge and Linux drop_caches)
#    - restart_service "service-name" (handles launchctl/systemctl)
#
# 5. Always add error handling:
#    - 2>/dev/null || true
#    - [[ -d "$dir" ]] && ...
#
# ============================================================================

echo "This is an example file demonstrating cross-platform adaptation patterns."
echo "See the comments above for before/after comparisons."
