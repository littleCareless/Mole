#!/bin/bash
# Linux Cache Cleanup Module - Real disk space cleaning
# This module provides practical cache cleaning for Linux systems

set -euo pipefail

# Clean user cache directory (~/.cache)
clean_user_cache() {
    local cache_dir
    cache_dir=$(get_user_cache_dir)

    if [[ ! -d "$cache_dir" ]]; then
        return 0
    fi

    local total_cleaned=0

    # Clean thumbnail cache
    if [[ -d "$cache_dir/thumbnails" ]]; then
        local size
        size=$(du -sb "$cache_dir/thumbnails" 2>/dev/null | awk '{print $1}' || echo 0)
        if [[ "$DRY_RUN" != "true" ]]; then
            rm -rf "$cache_dir/thumbnails"/* 2>/dev/null || true
            echo -e "  ${GREEN}${ICON_SUCCESS}${NC} Thumbnail cache, $((size / 1024 / 1024))MB"
        else
            echo -e "  ${YELLOW}${ICON_DRY_RUN}${NC} Thumbnail cache, would clean $((size / 1024 / 1024))MB"
        fi
        total_cleaned=$((total_cleaned + size))
    fi

    # Clean fontconfig cache
    if [[ -d "$cache_dir/fontconfig" ]]; then
        local size
        size=$(du -sb "$cache_dir/fontconfig" 2>/dev/null | awk '{print $1}' || echo 0)
        if [[ "$DRY_RUN" != "true" ]]; then
            rm -rf "$cache_dir/fontconfig"/* 2>/dev/null || true
            echo -e "  ${GREEN}${ICON_SUCCESS}${NC} Font cache, $((size / 1024 / 1024))MB"
        else
            echo -e "  ${YELLOW}${ICON_DRY_RUN}${NC} Font cache, would clean $((size / 1024 / 1024))MB"
        fi
        total_cleaned=$((total_cleaned + size))
    fi

    # Clean Mesa shader cache (GPU)
    if [[ -d "$cache_dir/mesa_shader_cache" ]]; then
        local size
        size=$(du -sb "$cache_dir/mesa_shader_cache" 2>/dev/null | awk '{print $1}' || echo 0)
        if [[ "$DRY_RUN" != "true" ]]; then
            rm -rf "$cache_dir/mesa_shader_cache"/* 2>/dev/null || true
            echo -e "  ${GREEN}${ICON_SUCCESS}${NC} GPU shader cache, $((size / 1024 / 1024))MB"
        else
            echo -e "  ${YELLOW}${ICON_DRY_RUN}${NC} GPU shader cache, would clean $((size / 1024 / 1024))MB"
        fi
        total_cleaned=$((total_cleaned + size))
    fi

    # Clean pip cache
    if [[ -d "$cache_dir/pip" ]]; then
        local size
        size=$(du -sb "$cache_dir/pip" 2>/dev/null | awk '{print $1}' || echo 0)
        if [[ "$DRY_RUN" != "true" ]]; then
            rm -rf "$cache_dir/pip"/* 2>/dev/null || true
            echo -e "  ${GREEN}${ICON_SUCCESS}${NC} pip cache, $((size / 1024 / 1024))MB"
        else
            echo -e "  ${YELLOW}${ICON_DRY_RUN}${NC} pip cache, would clean $((size / 1024 / 1024))MB"
        fi
        total_cleaned=$((total_cleaned + size))
    fi

    return 0
}

# Clean browser caches
clean_browser_caches() {
    local total_cleaned=0

    while IFS= read -r browser_cache; do
        if [[ -d "$browser_cache" ]]; then
            local browser_name
            browser_name=$(basename "$(dirname "$browser_cache")")

            local size
            size=$(du -sb "$browser_cache" 2>/dev/null | awk '{print $1}' || echo 0)

            if [[ $size -gt 10485760 ]]; then  # Only clean if > 10MB
                if [[ "$DRY_RUN" != "true" ]]; then
                    # Clean cache but keep structure
                    find "$browser_cache" -type f -mtime +7 -delete 2>/dev/null || true
                    echo -e "  ${GREEN}${ICON_SUCCESS}${NC} $browser_name cache, $((size / 1024 / 1024))MB"
                else
                    echo -e "  ${YELLOW}${ICON_DRY_RUN}${NC} $browser_name cache, would clean $((size / 1024 / 1024))MB"
                fi
                total_cleaned=$((total_cleaned + size))
            fi
        fi
    done < <(get_browser_cache_dirs)

    return 0
}

# Clean package manager caches
clean_package_caches() {
    local primary_mgr
    primary_mgr=$(get_primary_package_manager)

    case "$primary_mgr" in
        apt)
            local cache_size
            cache_size=$(du -sb /var/cache/apt/archives 2>/dev/null | awk '{print $1}' || echo "0")
            cache_size=${cache_size//[^0-9]/}  # Remove non-numeric characters
            if [[ ${cache_size:-0} -gt 0 ]]; then
                if [[ "$DRY_RUN" != "true" ]]; then
                    sudo apt-get clean 2>/dev/null || true
                    echo -e "  ${GREEN}${ICON_SUCCESS}${NC} apt cache, $((cache_size / 1024 / 1024))MB"
                else
                    echo -e "  ${YELLOW}${ICON_DRY_RUN}${NC} apt cache, would clean $((cache_size / 1024 / 1024))MB"
                fi
            fi
            ;;
        dnf)
            if [[ "$DRY_RUN" != "true" ]]; then
                sudo dnf clean all 2>/dev/null || true
                echo -e "  ${GREEN}${ICON_SUCCESS}${NC} dnf cache cleaned"
            else
                echo -e "  ${YELLOW}${ICON_DRY_RUN}${NC} dnf cache, would clean"
            fi
            ;;
        pacman)
            local cache_size
            cache_size=$(du -sb /var/cache/pacman/pkg 2>/dev/null | awk '{print $1}' || echo "0")
            cache_size=${cache_size//[^0-9]/}  # Remove non-numeric characters
            if [[ ${cache_size:-0} -gt 0 ]]; then
                if [[ "$DRY_RUN" != "true" ]]; then
                    sudo pacman -Sc --noconfirm 2>/dev/null || true
                    echo -e "  ${GREEN}${ICON_SUCCESS}${NC} pacman cache, $((cache_size / 1024 / 1024))MB"
                else
                    echo -e "  ${YELLOW}${ICON_DRY_RUN}${NC} pacman cache, would clean $((cache_size / 1024 / 1024))MB"
                fi
            fi
            ;;
    esac

    # Clean flatpak cache
    if has_package_manager "flatpak"; then
        if [[ "$DRY_RUN" != "true" ]]; then
            flatpak uninstall --unused -y 2>/dev/null || true
            echo -e "  ${GREEN}${ICON_SUCCESS}${NC} flatpak unused packages removed"
        else
            echo -e "  ${YELLOW}${ICON_DRY_RUN}${NC} flatpak unused packages, would remove"
        fi
    fi

    return 0
}

# Clean systemd journal logs
clean_journal_logs() {
    if ! command -v journalctl &>/dev/null; then
        return 0
    fi

    local journal_size
    journal_size=$(journalctl --disk-usage 2>/dev/null | grep -oP '\d+\.\d+[GM]' | head -1 || echo "0M")

    if [[ "$DRY_RUN" != "true" ]]; then
        # Keep only last 7 days of logs
        sudo journalctl --vacuum-time=7d 2>/dev/null || true
        echo -e "  ${GREEN}${ICON_SUCCESS}${NC} systemd journal logs, $journal_size"
    else
        echo -e "  ${YELLOW}${ICON_DRY_RUN}${NC} systemd journal logs, would clean $journal_size"
    fi

    return 0
}

# Clean temporary files
clean_temp_files() {
    local tmp_dir
    tmp_dir=$(get_system_tmp_dir)

    # Clean old temp files (older than 7 days)
    local count=0
    if [[ -d "$tmp_dir" ]]; then
        count=$(find "$tmp_dir" -type f -mtime +7 2>/dev/null | wc -l || echo 0)
        if [[ $count -gt 0 ]]; then
            if [[ "$DRY_RUN" != "true" ]]; then
                sudo find "$tmp_dir" -type f -mtime +7 -delete 2>/dev/null || true
                echo -e "  ${GREEN}${ICON_SUCCESS}${NC} Old temp files, $count files"
            else
                echo -e "  ${YELLOW}${ICON_DRY_RUN}${NC} Old temp files, would clean $count files"
            fi
        fi
    fi

    return 0
}

# Clean trash
clean_trash() {
    local trash_dir
    trash_dir=$(get_trash_dir)

    if [[ ! -d "$trash_dir" ]]; then
        return 0
    fi

    local size=0
    if [[ -d "$trash_dir/files" ]]; then
        size=$(du -sb "$trash_dir/files" 2>/dev/null | awk '{print $1}' || echo 0)
    else
        size=$(du -sb "$trash_dir" 2>/dev/null | awk '{print $1}' || echo 0)
    fi

    if [[ $size -gt 0 ]]; then
        if [[ "$DRY_RUN" != "true" ]]; then
            rm -rf "$trash_dir/files"/* 2>/dev/null || true
            rm -rf "$trash_dir/info"/* 2>/dev/null || true
            rm -rf "$trash_dir"/* 2>/dev/null || true
            echo -e "  ${GREEN}${ICON_SUCCESS}${NC} Trash, $((size / 1024 / 1024))MB"
        else
            echo -e "  ${YELLOW}${ICON_DRY_RUN}${NC} Trash, would clean $((size / 1024 / 1024))MB"
        fi
    fi

    return 0
}

# Main Linux cache cleaning function
clean_linux_caches() {
    echo ""
    echo -e "${BLUE}Cleaning Linux caches...${NC}"
    echo ""

    # User cache
    echo -e "${GRAY}User cache:${NC}"
    clean_user_cache

    # Browser caches
    echo ""
    echo -e "${GRAY}Browser caches:${NC}"
    clean_browser_caches

    # Package manager caches
    echo ""
    echo -e "${GRAY}Package manager caches:${NC}"
    clean_package_caches

    # System logs
    echo ""
    echo -e "${GRAY}System logs:${NC}"
    clean_journal_logs

    # Temp files
    echo ""
    echo -e "${GRAY}Temporary files:${NC}"
    clean_temp_files

    # Trash
    echo ""
    echo -e "${GRAY}Trash:${NC}"
    clean_trash

    echo ""
    echo -e "${GREEN}${ICON_SUCCESS}${NC} Linux cache cleaning completed"
    echo ""

    return 0
}

# Export function
if is_linux; then
    export -f clean_linux_caches
fi
