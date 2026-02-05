#!/bin/bash
# Cross-Platform User Data Cleanup Module
# Supports both macOS and Linux

set -euo pipefail

# Clean user cache directories
clean_user_cache_dirs() {
    local cache_dir
    cache_dir=$(get_user_cache_dir)

    if [[ ! -d "$cache_dir" ]]; then
        return 0
    fi

    start_section_spinner "Scanning user caches..."

    if is_macos; then
        # macOS: Clean ~/Library/Caches
        safe_clean "$cache_dir"/* "User app cache"
    else
        # Linux: Clean ~/.cache selectively
        # Clean common cache directories
        for subdir in thumbnails fontconfig mesa_shader_cache pip npm yarn; do
            if [[ -d "$cache_dir/$subdir" ]]; then
                safe_clean "$cache_dir/$subdir"/* "$subdir cache"
            fi
        done
    fi

    stop_section_spinner
}

# Clean user log directories
clean_user_logs() {
    local log_dir
    log_dir=$(get_user_log_dir)

    if [[ ! -d "$log_dir" ]]; then
        return 0
    fi

    if is_macos; then
        # macOS: ~/Library/Logs
        safe_clean "$log_dir"/* "User app logs"
    else
        # Linux: ~/.local/state or ~/.cache/logs
        # Clean old log files (>30 days)
        find "$log_dir" -type f -name "*.log" -mtime +30 -delete 2>/dev/null || true
        echo -e "  ${GREEN}${ICON_SUCCESS}${NC} Old log files (>30 days)"
    fi
}

# Clean trash/recycle bin
clean_trash() {
    local trash_dir
    trash_dir=$(get_trash_dir)

    # Check if whitelist function exists, otherwise skip check
    if command -v is_path_whitelisted >/dev/null 2>&1; then
        if is_path_whitelisted "$trash_dir"; then
            return 0
        fi
    fi

    if is_macos; then
        # macOS: Use Finder to empty trash
        local trash_count
        trash_count=$(osascript -e 'tell application "Finder" to count items in trash' 2>/dev/null || echo "0")
        [[ "$trash_count" =~ ^[0-9]+$ ]] || trash_count="0"

        if [[ "$DRY_RUN" == "true" ]]; then
            [[ $trash_count -gt 0 ]] && echo -e "  ${YELLOW}${ICON_DRY_RUN}${NC} Trash, would empty $trash_count items" || echo -e "  ${GREEN}${ICON_SUCCESS}${NC} Trash already empty"
        elif [[ $trash_count -gt 0 ]]; then
            if osascript -e 'tell application "Finder" to empty trash' >/dev/null 2>&1; then
                echo -e "  ${GREEN}${ICON_SUCCESS}${NC} Trash emptied, $trash_count items"
                note_activity
            else
                # Fallback: manual deletion
                local cleaned_count=0
                while IFS= read -r -d '' item; do
                    if safe_remove "$item" true; then
                        ((cleaned_count++))
                    fi
                done < <(find "$trash_dir" -mindepth 1 -maxdepth 1 -print0 2>/dev/null || true)
                if [[ $cleaned_count -gt 0 ]]; then
                    echo -e "  ${GREEN}${ICON_SUCCESS}${NC} Trash emptied, $cleaned_count items"
                    note_activity
                fi
            fi
        else
            echo -e "  ${GREEN}${ICON_SUCCESS}${NC} Trash already empty"
        fi
    else
        # Linux: Clean ~/.local/share/Trash
        if [[ -d "$trash_dir" ]]; then
            local size=0
            if [[ -d "$trash_dir/files" ]]; then
                size=$(du -sb "$trash_dir/files" 2>/dev/null | awk '{print $1}' || echo "0")
            else
                size=$(du -sb "$trash_dir" 2>/dev/null | awk '{print $1}' || echo "0")
            fi
            size=${size//[^0-9]/}

            if [[ ${size:-0} -gt 0 ]]; then
                if [[ "$DRY_RUN" != "true" ]]; then
                    rm -rf "$trash_dir/files"/* 2>/dev/null || true
                    rm -rf "$trash_dir/info"/* 2>/dev/null || true
                    echo -e "  ${GREEN}${ICON_SUCCESS}${NC} Trash emptied, $((size / 1024 / 1024))MB"
                    note_activity
                else
                    echo -e "  ${YELLOW}${ICON_DRY_RUN}${NC} Trash, would clean $((size / 1024 / 1024))MB"
                fi
            else
                echo -e "  ${GREEN}${ICON_SUCCESS}${NC} Trash already empty"
            fi
        fi
    fi
}

# Clean browser caches (cross-platform)
clean_browser_caches() {
    echo ""
    echo -e "${GRAY}Browser caches:${NC}"

    local cleaned_any=false

    while IFS= read -r browser_cache; do
        if [[ -d "$browser_cache" ]]; then
            local browser_name
            if is_macos; then
                # Extract from path like ~/Library/Caches/Google/Chrome
                browser_name=$(basename "$(dirname "$browser_cache")")
            else
                # Extract from path like ~/.cache/google-chrome
                browser_name=$(basename "$browser_cache")
            fi

            local size
            size=$(du -sb "$browser_cache" 2>/dev/null | awk '{print $1}' || echo "0")
            size=${size//[^0-9]/}

            if [[ ${size:-0} -gt 10485760 ]]; then  # Only clean if > 10MB
                if [[ "$DRY_RUN" != "true" ]]; then
                    # Clean cache but keep structure (delete files older than 7 days)
                    find "$browser_cache" -type f -mtime +7 -delete 2>/dev/null || true
                    echo -e "  ${GREEN}${ICON_SUCCESS}${NC} $browser_name cache, $((size / 1024 / 1024))MB"
                    cleaned_any=true
                else
                    echo -e "  ${YELLOW}${ICON_DRY_RUN}${NC} $browser_name cache, would clean $((size / 1024 / 1024))MB"
                    cleaned_any=true
                fi
            fi
        fi
    done < <(get_browser_cache_dirs)

    if [[ "$cleaned_any" == "false" ]]; then
        echo -e "  ${GREEN}${ICON_SUCCESS}${NC} No large browser caches found"
    fi
}

# Clean download directories (old files)
clean_old_downloads() {
    local downloads_dir="$HOME/Downloads"

    if [[ ! -d "$downloads_dir" ]]; then
        return 0
    fi

    # Clean files older than 90 days
    local old_files
    old_files=$(find "$downloads_dir" -type f -mtime +90 2>/dev/null | wc -l || echo "0")
    old_files=${old_files//[^0-9]/}

    if [[ ${old_files:-0} -gt 0 ]]; then
        if [[ "$DRY_RUN" != "true" ]]; then
            find "$downloads_dir" -type f -mtime +90 -delete 2>/dev/null || true
            echo -e "  ${GREEN}${ICON_SUCCESS}${NC} Old downloads (>90 days), $old_files files"
        else
            echo -e "  ${YELLOW}${ICON_DRY_RUN}${NC} Old downloads (>90 days), would clean $old_files files"
        fi
    else
        echo -e "  ${GREEN}${ICON_SUCCESS}${NC} No old downloads found"
    fi
}

# Clean temporary files
clean_user_temp_files() {
    local tmp_dir
    tmp_dir=$(get_system_tmp_dir)

    if [[ ! -d "$tmp_dir" ]]; then
        return 0
    fi

    # Clean old temp files (older than 7 days)
    local count
    count=$(find "$tmp_dir" -type f -mtime +7 2>/dev/null | wc -l || echo "0")
    count=${count//[^0-9]/}

    if [[ ${count:-0} -gt 0 ]]; then
        if [[ "$DRY_RUN" != "true" ]]; then
            if is_linux; then
                sudo find "$tmp_dir" -type f -mtime +7 -delete 2>/dev/null || true
            else
                find "$tmp_dir" -type f -mtime +7 -delete 2>/dev/null || true
            fi
            echo -e "  ${GREEN}${ICON_SUCCESS}${NC} Old temp files (>7 days), $count files"
        else
            echo -e "  ${YELLOW}${ICON_DRY_RUN}${NC} Old temp files (>7 days), would clean $count files"
        fi
    else
        echo -e "  ${GREEN}${ICON_SUCCESS}${NC} No old temp files found"
    fi
}

# Main user cleanup function (cross-platform)
clean_user_data() {
    echo ""
    echo -e "${BLUE}Cleaning user data...${NC}"
    echo ""

    # User cache
    echo -e "${GRAY}User cache:${NC}"
    clean_user_cache_dirs

    # User logs
    echo ""
    echo -e "${GRAY}User logs:${NC}"
    clean_user_logs

    # Trash
    echo ""
    echo -e "${GRAY}Trash:${NC}"
    clean_trash

    # Browser caches
    clean_browser_caches

    # Old downloads
    echo ""
    echo -e "${GRAY}Old downloads:${NC}"
    clean_old_downloads

    # Temp files
    echo ""
    echo -e "${GRAY}Temporary files:${NC}"
    clean_user_temp_files

    echo ""
    echo -e "${GREEN}${ICON_SUCCESS}${NC} User data cleaning completed"
    echo ""
}

# Export function
export -f clean_user_data
