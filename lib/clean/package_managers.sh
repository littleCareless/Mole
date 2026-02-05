#!/bin/bash
# Cross-Platform Package Manager Cleanup Module
# Supports Homebrew (macOS), apt, dnf, pacman, flatpak, snap (Linux)

set -euo pipefail

# Clean Homebrew (macOS and Linux)
clean_homebrew() {
    command -v brew >/dev/null 2>&1 || return 0

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        echo -e "  ${YELLOW}${ICON_DRY_RUN}${NC} Homebrew, would cleanup and autoremove"
        return 0
    fi

    # Skip if cleaned recently (within 7 days)
    local brew_cache_file="${HOME}/.cache/mole/brew_last_cleanup"
    local cache_valid_days=7
    local should_skip=false

    if [[ -f "$brew_cache_file" ]]; then
        local last_cleanup
        last_cleanup=$(cat "$brew_cache_file" 2>/dev/null || echo "0")
        local current_time
        current_time=$(date +%s)
        local time_diff=$((current_time - last_cleanup))
        local days_diff=$((time_diff / 86400))

        if [[ $days_diff -lt $cache_valid_days ]]; then
            should_skip=true
            echo -e "  ${GREEN}${ICON_SUCCESS}${NC} Homebrew cleaned ${days_diff}d ago, skipped"
        fi
    fi

    [[ "$should_skip" == "true" ]] && return 0

    # Run cleanup
    if [[ -t 1 ]]; then
        MOLE_SPINNER_PREFIX="  " start_inline_spinner "Homebrew cleanup..."
    fi

    local output
    output=$(brew cleanup -s 2>&1 || true)

    if [[ -t 1 ]]; then
        stop_inline_spinner
    fi

    # Extract freed space
    local freed_space
    freed_space=$(echo "$output" | grep -o "[0-9.]*[KMGT]B freed" 2>/dev/null | tail -1 || echo "")

    if [[ -n "$freed_space" ]]; then
        echo -e "  ${GREEN}${ICON_SUCCESS}${NC} Homebrew cleanup, $freed_space"
    else
        echo -e "  ${GREEN}${ICON_SUCCESS}${NC} Homebrew cleanup completed"
    fi

    # Update cache timestamp
    ensure_user_file "$brew_cache_file"
    date +%s > "$brew_cache_file"
}

# Clean apt cache (Debian/Ubuntu)
clean_apt() {
    command -v apt-get >/dev/null 2>&1 || return 0

    local cache_dir="/var/cache/apt/archives"
    if [[ ! -d "$cache_dir" ]]; then
        return 0
    fi

    local cache_size
    cache_size=$(du -sb "$cache_dir" 2>/dev/null | awk '{print $1}' || echo "0")
    cache_size=${cache_size//[^0-9]/}

    if [[ ${cache_size:-0} -lt 10485760 ]]; then  # Skip if < 10MB
        echo -e "  ${GREEN}${ICON_SUCCESS}${NC} apt cache small ($((cache_size / 1024 / 1024))MB), skipped"
        return 0
    fi

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        echo -e "  ${YELLOW}${ICON_DRY_RUN}${NC} apt cache, would clean $((cache_size / 1024 / 1024))MB"
        return 0
    fi

    if [[ -t 1 ]]; then
        MOLE_SPINNER_PREFIX="  " start_inline_spinner "Cleaning apt cache..."
    fi

    sudo apt-get clean 2>/dev/null || true
    sudo apt-get autoclean 2>/dev/null || true

    if [[ -t 1 ]]; then
        stop_inline_spinner
    fi

    echo -e "  ${GREEN}${ICON_SUCCESS}${NC} apt cache cleaned, $((cache_size / 1024 / 1024))MB"
}

# Clean dnf cache (Fedora/RHEL)
clean_dnf() {
    command -v dnf >/dev/null 2>&1 || return 0

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        echo -e "  ${YELLOW}${ICON_DRY_RUN}${NC} dnf cache, would clean"
        return 0
    fi

    if [[ -t 1 ]]; then
        MOLE_SPINNER_PREFIX="  " start_inline_spinner "Cleaning dnf cache..."
    fi

    sudo dnf clean all 2>/dev/null || true

    if [[ -t 1 ]]; then
        stop_inline_spinner
    fi

    echo -e "  ${GREEN}${ICON_SUCCESS}${NC} dnf cache cleaned"
}

# Clean pacman cache (Arch Linux)
clean_pacman() {
    command -v pacman >/dev/null 2>&1 || return 0

    local cache_dir="/var/cache/pacman/pkg"
    if [[ ! -d "$cache_dir" ]]; then
        return 0
    fi

    local cache_size
    cache_size=$(du -sb "$cache_dir" 2>/dev/null | awk '{print $1}' || echo "0")
    cache_size=${cache_size//[^0-9]/}

    if [[ ${cache_size:-0} -lt 10485760 ]]; then  # Skip if < 10MB
        echo -e "  ${GREEN}${ICON_SUCCESS}${NC} pacman cache small ($((cache_size / 1024 / 1024))MB), skipped"
        return 0
    fi

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        echo -e "  ${YELLOW}${ICON_DRY_RUN}${NC} pacman cache, would clean $((cache_size / 1024 / 1024))MB"
        return 0
    fi

    if [[ -t 1 ]]; then
        MOLE_SPINNER_PREFIX="  " start_inline_spinner "Cleaning pacman cache..."
    fi

    sudo pacman -Sc --noconfirm 2>/dev/null || true

    if [[ -t 1 ]]; then
        stop_inline_spinner
    fi

    echo -e "  ${GREEN}${ICON_SUCCESS}${NC} pacman cache cleaned, $((cache_size / 1024 / 1024))MB"
}

# Clean flatpak unused packages
clean_flatpak() {
    command -v flatpak >/dev/null 2>&1 || return 0

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        echo -e "  ${YELLOW}${ICON_DRY_RUN}${NC} flatpak, would remove unused packages"
        return 0
    fi

    if [[ -t 1 ]]; then
        MOLE_SPINNER_PREFIX="  " start_inline_spinner "Cleaning flatpak..."
    fi

    local output
    output=$(flatpak uninstall --unused -y 2>&1 || true)

    if [[ -t 1 ]]; then
        stop_inline_spinner
    fi

    if echo "$output" | grep -q "Nothing unused to uninstall"; then
        echo -e "  ${GREEN}${ICON_SUCCESS}${NC} flatpak no unused packages"
    else
        echo -e "  ${GREEN}${ICON_SUCCESS}${NC} flatpak unused packages removed"
    fi
}

# Clean snap (Ubuntu)
clean_snap() {
    command -v snap >/dev/null 2>&1 || return 0

    # Snap automatically keeps only 2 revisions, so we just report status
    local snap_count
    snap_count=$(snap list 2>/dev/null | tail -n +2 | wc -l || echo "0")

    echo -e "  ${GREEN}${ICON_SUCCESS}${NC} snap manages revisions automatically ($snap_count packages)"
}

# Main package manager cleanup function
clean_package_managers() {
    echo ""
    echo -e "${BLUE}Cleaning package manager caches...${NC}"
    echo ""

    local cleaned_any=false

    # Detect and clean based on platform
    if is_macos; then
        if command -v brew >/dev/null 2>&1; then
            clean_homebrew
            cleaned_any=true
        fi
    else
        # Linux: clean all available package managers
        if command -v apt-get >/dev/null 2>&1; then
            clean_apt
            cleaned_any=true
        fi

        if command -v dnf >/dev/null 2>&1; then
            clean_dnf
            cleaned_any=true
        fi

        if command -v pacman >/dev/null 2>&1; then
            clean_pacman
            cleaned_any=true
        fi

        if command -v flatpak >/dev/null 2>&1; then
            clean_flatpak
            cleaned_any=true
        fi

        if command -v snap >/dev/null 2>&1; then
            clean_snap
            cleaned_any=true
        fi

        # Homebrew on Linux
        if command -v brew >/dev/null 2>&1; then
            clean_homebrew
            cleaned_any=true
        fi
    fi

    if [[ "$cleaned_any" == "false" ]]; then
        echo -e "  ${GRAY}${ICON_WARNING}${NC} No package managers found"
    fi

    echo ""
    echo -e "${GREEN}${ICON_SUCCESS}${NC} Package manager cleaning completed"
    echo ""
}

# Export function
export -f clean_package_managers
