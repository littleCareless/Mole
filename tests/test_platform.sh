#!/bin/bash
# Platform Abstraction Layer Test Suite
# Tests platform detection, path mapping, and package manager functions

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Load platform modules
source "$PROJECT_ROOT/lib/core/base.sh"
source "$PROJECT_ROOT/lib/core/log.sh"
source "$PROJECT_ROOT/lib/core/platform.sh"
source "$PROJECT_ROOT/lib/core/package_manager.sh"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Colors (use different names to avoid conflicts with base.sh)
TEST_RED='\033[0;31m'
TEST_GREEN='\033[0;32m'
TEST_YELLOW='\033[1;33m'
TEST_BLUE='\033[0;34m'
TEST_NC='\033[0m'

# Test helper functions
test_start() {
    local test_name="$1"
    echo -ne "${TEST_BLUE}[TEST]${TEST_NC} $test_name ... "
    ((TESTS_RUN++))
}

test_pass() {
    echo -e "${TEST_GREEN}✓ PASS${TEST_NC}"
    ((TESTS_PASSED++))
}

test_fail() {
    local reason="$1"
    echo -e "${TEST_RED}✗ FAIL${TEST_NC}: $reason"
    ((TESTS_FAILED++))
}

test_skip() {
    local reason="$1"
    echo -e "${TEST_YELLOW}⊘ SKIP${TEST_NC}: $reason"
}

# ============================================================================
# Platform Detection Tests
# ============================================================================

test_platform_detection() {
    test_start "Platform detection"

    local platform
    platform=$(detect_platform)

    if [[ "$platform" == "macos" || "$platform" == "linux" ]]; then
        test_pass
    else
        test_fail "Unknown platform: $platform"
    fi
}

test_platform_check_functions() {
    test_start "Platform check functions (is_macos/is_linux)"

    if is_macos || is_linux; then
        test_pass
    else
        test_fail "Neither is_macos nor is_linux returned true"
    fi
}

test_linux_distro_detection() {
    test_start "Linux distribution detection"

    if is_linux; then
        local distro
        distro=$(detect_linux_distro)

        if [[ -n "$distro" ]]; then
            echo -ne "(detected: $distro) "
            test_pass
        else
            test_fail "Empty distro string"
        fi
    else
        test_skip "Not running on Linux"
    fi
}

# ============================================================================
# Path Mapping Tests
# ============================================================================

test_user_cache_dir() {
    test_start "User cache directory"

    local cache_dir
    cache_dir=$(get_user_cache_dir)

    if [[ -n "$cache_dir" && -d "$cache_dir" ]]; then
        echo -ne "($cache_dir) "
        test_pass
    else
        test_fail "Invalid cache dir: $cache_dir"
    fi
}

test_user_data_dir() {
    test_start "User data directory"

    local data_dir
    data_dir=$(get_user_data_dir)

    if [[ -n "$data_dir" ]]; then
        echo -ne "($data_dir) "
        test_pass
    else
        test_fail "Empty data dir"
    fi
}

test_user_config_dir() {
    test_start "User config directory"

    local config_dir
    config_dir=$(get_user_config_dir)

    if [[ -n "$config_dir" ]]; then
        echo -ne "($config_dir) "
        test_pass
    else
        test_fail "Empty config dir"
    fi
}

test_system_paths() {
    test_start "System paths (cache, log, tmp)"

    local sys_cache sys_log sys_tmp
    sys_cache=$(get_system_cache_dir)
    sys_log=$(get_system_log_dir)
    sys_tmp=$(get_system_tmp_dir)

    if [[ -n "$sys_cache" && -n "$sys_log" && -n "$sys_tmp" ]]; then
        test_pass
    else
        test_fail "One or more system paths are empty"
    fi
}

test_browser_cache_dirs() {
    test_start "Browser cache directories"

    local count=0
    while IFS= read -r browser_cache; do
        ((count++))
    done < <(get_browser_cache_dirs)

    if [[ $count -gt 0 ]]; then
        echo -ne "($count browsers) "
        test_pass
    else
        test_fail "No browser cache directories returned"
    fi
}

test_trash_dir() {
    test_start "Trash directory"

    local trash_dir
    trash_dir=$(get_trash_dir)

    if [[ -n "$trash_dir" ]]; then
        echo -ne "($trash_dir) "
        test_pass
    else
        test_fail "Empty trash dir"
    fi
}

# ============================================================================
# Package Manager Tests
# ============================================================================

test_package_manager_detection() {
    test_start "Package manager detection"

    local managers
    managers=$(detect_package_managers)

    if [[ -n "$managers" ]]; then
        echo -ne "(found: $managers) "
        test_pass
    else
        test_fail "No package managers detected"
    fi
}

test_primary_package_manager() {
    test_start "Primary package manager"

    local primary
    primary=$(get_primary_package_manager)

    if [[ -n "$primary" && "$primary" != "unknown" ]]; then
        echo -ne "($primary) "
        test_pass
    else
        test_fail "Primary package manager is unknown"
    fi
}

test_package_manager_cache_paths() {
    test_start "Package manager cache paths"

    local primary cache_path
    primary=$(get_primary_package_manager)
    cache_path=$(get_package_cache_dir "$primary")

    if [[ -n "$cache_path" ]]; then
        echo -ne "($cache_path) "
        test_pass
    else
        test_fail "Empty cache path for $primary"
    fi
}

test_homebrew_detection() {
    test_start "Homebrew detection"

    if has_package_manager "brew"; then
        local brew_prefix
        brew_prefix=$(get_homebrew_prefix)
        echo -ne "($brew_prefix) "
        test_pass
    else
        test_skip "Homebrew not installed"
    fi
}

# ============================================================================
# Environment Variable Tests
# ============================================================================

test_exported_variables() {
    test_start "Exported environment variables"

    if [[ -n "$MOLE_PLATFORM" && -n "$MOLE_USER_CACHE_DIR" ]]; then
        test_pass
    else
        test_fail "Required environment variables not set"
    fi
}

# ====================================================================== Integration Tests
# ====================================================================

test_path_consistency() {
    test_start "Path consistency (function vs env var)"

    local func_cache env_cache
    func_cache=$(get_user_cache_dir)
    env_cache="$MOLE_USER_CACHE_DIR"

    if [[ "$func_cache" == "$env_cache" ]]; then
        test_pass
    else
        test_fail "Mismatch: $func_cache != $env_cache"
    fi
}

test_platform_specific_functions() {
    test_start "Platform-specific functions"

    if is_macos; then
        # Test macOS-specific
        if [[ -x /usr/libexec/PlistBuddy ]]; then
            test_pass
        else
            test_fail "PlistBuddy not found on macOS"
        fi
    elif is_linux; then
        # Test Linux-specific
        if [[ -f /etc/os-release ]]; then
            test_pass
        else
            test_fail "/etc/os-release not found on Linux"
        fi
    fi
}

# ============================================================================
# Main Test Runner
# ============================================================================

run_all_tests() {
    echo ""
    echo "=================================="
    echo "  Mole Platform Abstraction Test Suite"
    echo "=========================================="
    echo ""

    # Platform info
    echo -e "${TEST_BLUE}Platform Information:${TEST_NC}"
    echo "  OS: $MOLE_PLATFORM"
    if is_linux; then
        echo "  Distribution: $MOLE_LINUX_DISTRO"
    fi
    echo "  Primary Package Manager: $(get_primary_package_manager)"
    echo ""

    # Run tests
    echo -e "${TEST_BLUE}Running Tests:${TEST_NC}"
    echo ""

    # Platform detection
    test_platform_detection
    test_platform_check_functions
    test_linux_distro_detection

    # Path mapping
    test_dir
    test_user_data_dir
    test_user_config_dir
    test_system_paths
    test_browser_cache_dirs
    test_trash_dir

    # Package managers
    test_package_manager_detection
    test_primary_package_manager
    test_package_manager_cache_paths
    test_homebrew_detection

    # Environment
    test_exported_variables

    # Integration
    test_path_consistency
    test_platform_specific_functions

    # Summary
    echo ""
    echo "=========================================="
    echo -e "${TEST_BLUE}Test Summary:${TEST_NC}"
    echo "  Total:  $TESTS_RUN"
    echo -e "  ${TEST_GREEN}Passed: $TESTS_PASSED${TEST_NC}"

    if [[ $TESTS_FAILED -gt 0 ]]; then
        echo -e "  ${TEST_RED}Failed: $TESTS_FAILED${TEST_NC}"
        echo "=========================================="
        exit 1
    else
        echo "  Failed: 0"
        echo "=========================================="
        echo -e "${TEST_GREEN}All tests passed!${TEST_NC}"
        echo ""
        exit 0
    fi
}

# Run tests
run_all_tests
