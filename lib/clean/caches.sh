#!/bin/bash
# Cache Cleanup Module (Cross-platform: macOS & Linux)
set -euo pipefail

# Preflight TCC prompts once to avoid mid-run interruptions (macOS only).
check_tcc_permissions() {
    # Skip on Linux - no TCC (Transparency, Consent, and Control)
    is_linux && return 0

    [[ -t 1 ]] || return 0
    local permission_flag="$HOME/.cache/mole/permissions_granted"
    [[ -f "$permission_flag" ]] && return 0

    # Use platform abstraction for paths
    local user_cache user_data user_config
    user_cache=$(get_user_cache_dir)
    user_data=$(get_user_data_dir)
    user_config=$(get_user_config_dir)

    local -a tcc_dirs=(
        "$user_cache"
        "$user_data"
        "$user_config"
    )

    # macOS-specific: add Containers directory
    if is_macos; then
        tcc_dirs+=("$HOME/Library/Containers")
    fi

    # Quick permission probe (avoid deep scans).
    local needs_permission_check=false
    if ! ls "$user_cache" > /dev/null 2>&1; then
        needs_permission_check=true
    fi

    if [[ "$needs_permission_check" == "true" ]]; then
        echo ""
        echo -e "${BLUE}First-time setup${NC}"
        echo -e "${GRAY}macOS will request permissions to access Library folders.${NC}"
        echo -e "${GRAY}You may see ${GREEN}${#tcc_dirs[@]} permission dialogs${NC}${GRAY}, please approve them all.${NC}"
        echo ""
        echo -ne "${PURPLE}${ICON_ARROW}${NC} Press ${GREEN}Enter${NC} to continue: "
        read -r
        MOLE_SPINNER_PREFIX="" start_inline_spinner "Requesting permissions..."
        # Touch each directory to trigger prompts without deep scanning.
        for dir in "${tcc_dirs[@]}"; do
            [[ -d "$dir" ]] && command find "$dir" -maxdepth 1 -type d > /dev/null 2>&1
        done
        stop_inline_spinner
        echo ""
    fi
    # Mark as granted to avoid repeat prompts.
    ensure_user_file "$permission_flag"
    return 0
}
# Args: $1=browser_name, $2=cache_path
# Clean Service Worker cache while protecting critical web editors.
clean_service_worker_cache() {
    local browser_name="$1"
    local cache_path="$2"
    [[ ! -d "$cache_path" ]] && return 0
    local cleaned_size=0
    local protected_count=0
    while IFS= read -r cache_dir; do
        [[ ! -d "$cache_dir" ]] && continue
        # Extract a best-effort domain name from cache folder.
        local domain=$(basename "$cache_dir" | grep -oE '[a-zA-Z0-9][-a-zA-Z0-9]*\.[a-zA-Z]{2,}' | head -1 || echo "")
        local size=$(run_with_timeout 5 get_path_size_kb "$cache_dir")
        local is_protected=false
        for protected_domain in "${PROTECTED_SW_DOMAINS[@]}"; do
            if [[ "$domain" == *"$protected_domain"* ]]; then
                is_protected=true
                protected_count=$((protected_count + 1))
                break
            fi
        done
        if [[ "$is_protected" == "false" ]]; then
            if [[ "$DRY_RUN" != "true" ]]; then
                safe_remove "$cache_dir" true || true
            fi
            cleaned_size=$((cleaned_size + size))
        fi
    done < <(run_with_timeout 10 sh -c "find '$cache_path' -type d -depth 2 2> /dev/null || true")
    if [[ $cleaned_size -gt 0 ]]; then
        local spinner_was_running=false
        if [[ -t 1 && -n "${INLINE_SPINNER_PID:-}" ]]; then
            stop_inline_spinner
            spinner_was_running=true
        fi
        local cleaned_mb=$((cleaned_size / 1024))
        if [[ "$DRY_RUN" != "true" ]]; then
            if [[ $protected_count -gt 0 ]]; then
                echo -e "  ${GREEN}${ICON_SUCCESS}${NC} $browser_name Service Worker, ${cleaned_mb}MB, ${protected_count} protected"
            else
                echo -e "  ${GREEN}${ICON_SUCCESS}${NC} $browser_name Service Worker, ${cleaned_mb}MB"
            fi
        else
            echo -e "  ${YELLOW}${ICON_DRY_RUN}${NC} $browser_name Service Worker, would clean ${cleaned_mb}MB, ${protected_count} protected"
        fi
        note_activity
        if [[ "$spinner_was_running" == "true" ]]; then
            MOLE_SPINNER_PREFIX="  " start_inline_spinner "Scanning browser Service Worker caches..."
        fi
    fi
}
# Next.js/Python project caches with tight scan bounds and timeouts.
clean_project_caches() {
    stop_inline_spinner 2> /dev/null || true
    # Fast pre-check before scanning the whole home dir.
    local has_dev_projects=false
    local -a common_dev_dirs=(
        "$HOME/Code"
        "$HOME/Projects"
        "$HOME/workspace"
        "$HOME/github"
        "$HOME/dev"
        "$HOME/work"
        "$HOME/src"
        "$HOME/repos"
        "$HOME/Development"
        "$HOME/www"
        "$HOME/golang"
        "$HOME/go"
        "$HOME/rust"
        "$HOME/python"
        "$HOME/ruby"
        "$HOME/java"
        "$HOME/dotnet"
        "$HOME/node"
    )
    for dir in "${common_dev_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            has_dev_projects=true
            break
        fi
    done
    # Fallback: look for project markers near $HOME.
    if [[ "$has_dev_projects" == "false" ]]; then
        local -a project_markers=(
            "node_modules"
            ".git"
            "target"
            "go.mod"
            "Cargo.toml"
            "package.json"
            "pom.xml"
            "build.gradle"
        )
        local spinner_active=false
        if [[ -t 1 ]]; then
            MOLE_SPINNER_PREFIX="  "
            start_inline_spinner "Detecting dev projects..."
            spinner_active=true
        fi
        # Use platform-specific exclusion paths
        local exclude_paths
        if is_macos; then
            exclude_paths="-not -path '*/Library/*' -not -path '*/.Trash/*'"
        else
            exclude_paths="-not -path '*/.local/share/Trash/*' -not -path '*/snap/*'"
        fi

        for marker in "${project_markers[@]}"; do
            if run_with_timeout 3 sh -c "find '$HOME' -maxdepth 2 -name '$marker' $exclude_paths 2>/dev/null | head -1" | grep -q .; then
                has_dev_projects=true
                break
            fi
        done
        if [[ "$spinner_active" == "true" ]]; then
            stop_inline_spinner 2> /dev/null || true
        fi
        [[ "$has_dev_projects" == "false" ]] && return 0
    fi
    if [[ -t 1 ]]; then
        MOLE_SPINNER_PREFIX="  "
        start_inline_spinner "Searching project caches..."
    fi
    local nextjs_tmp_file
    nextjs_tmp_file=$(create_temp_file)
    local pycache_tmp_file
    pycache_tmp_file=$(create_temp_file)
    local find_timeout=10
    # Parallel scans (Next.js and __pycache__) with platform-specific exclusions
    local trash_dir
    trash_dir=$(get_trash_dir)

    local exclude_pattern
    if is_macos; then
        exclude_pattern="-not -path '*/Library/*' -not -path '$trash_dir/*'"
    else
        exclude_pattern="-not -path '$trash_dir/*' -not -path '*/snap/*' -not -path '*/.local/share/*'"
    fi

    (
        command find "$HOME" -P -mount -type d -name ".next" -maxdepth 3 \
            $exclude_pattern \
            -not -path "*/node_modules/*" \
            -not -path "*/.*" \
            2> /dev/null || true
    ) > "$nextjs_tmp_file" 2>&1 &
    local next_pid=$!
    (
        command find "$HOME" -P -mount -type d -name "__pycache__" -maxdepth 3 \
            $exclude_pattern \
            -not -path "*/node_modules/*" \
            -not -path "*/.*" \
            2> /dev/null || true
    ) > "$pycache_tmp_file" 2>&1 &
    local py_pid=$!
    local elapsed=0
    local check_interval=0.2 # Check every 200ms instead of 1s for smoother experience
    while [[ $(echo "$elapsed < $find_timeout" | awk '{print ($1 < $2)}') -eq 1 ]]; do
        if ! kill -0 $next_pid 2> /dev/null && ! kill -0 $py_pid 2> /dev/null; then
            break
        fi
        sleep $check_interval
        elapsed=$(echo "$elapsed + $check_interval" | awk '{print $1 + $2}')
    done
    # Kill stuck scans after timeout.
    for pid in $next_pid $py_pid; do
        if kill -0 "$pid" 2> /dev/null; then
            kill -TERM "$pid" 2> /dev/null || true
            local grace_period=0
            while [[ $grace_period -lt 20 ]]; do
                if ! kill -0 "$pid" 2> /dev/null; then
                    break
                fi
                sleep 0.1
                ((grace_period++))
            done
            if kill -0 "$pid" 2> /dev/null; then
                kill -KILL "$pid" 2> /dev/null || true
            fi
            wait "$pid" 2> /dev/null || true
        else
            wait "$pid" 2> /dev/null || true
        fi
    done
    if [[ -t 1 ]]; then
        stop_inline_spinner
    fi
    while IFS= read -r next_dir; do
        [[ -d "$next_dir/cache" ]] && safe_clean "$next_dir/cache"/* "Next.js build cache" || true
    done < "$nextjs_tmp_file"
    while IFS= read -r pycache; do
        [[ -d "$pycache" ]] && safe_clean "$pycache"/* "Python bytecode cache" || true
    done < "$pycache_tmp_file"
}
