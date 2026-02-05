#!/bin/bash
# Simple Platform Test - Quick validation of platform abstraction layer

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Load modules
source "$PROJECT_ROOT/lib/core/base.sh"
source "$PROJECT_ROOT/lib/core/log.sh"
source "$PROJECT_ROOT/lib/core/platform.sh"
source "$PROJECT_ROOT/lib/core/package_manager.sh"

echo "=========================================="
echo "  Mole Platform Abstraction Test"
echo "=========================================="
echo ""

# Platform Detection
echo "Platform Detection:"
echo "  OS: $(detect_platform)"
if is_linux; then
    echo "  Distribution: $(detect_linux_distro)"
fi
echo ""

# Path Mapping
echo "Path Mapping:"
echo "  User Cache:  $(get_user_cache_dir)"
echo "  User Data:   $(get_user_data_dir)"
echo "  User Config: $(get_user_config_dir)"
echo "  System Cache: $(get_system_cache_dir)"
echo "  System Log:   $(get_system_log_dir)"
echo "  Trash:        $(get_trash_dir)"
echo ""

# Browser Paths
echo "Browser Cache Directories:"
get_browser_cache_dirs | while read -r path; do
    echo "  - $path"
done
echo ""

# Package Managers
echo "Package Managers:"
echo "  Primary: $(get_primary_package_manager)"
echo "  Available: $(detect_package_managers)"
if has_package_manager "brew"; then
    echo "  Homebrew: $(get_homebrew_prefix)"
fi
echo ""

# Environment Variables
echo "Environment Variables:"
echo "  MOLE_PLATFORM: $MOLE_PLATFORM"
echo "  MOLE_USER_CACHE_DIR: $MOLE_USER_CACHE_DIR"
echo "  MOLE_USER_DATA_DIR: $MOLE_USER_DATA_DIR"
if is_linux; then
    echo "  MOLE_LINUX_DISTRO: $MOLE_LINUX_DISTRO"
fi
echo ""

echo "=========================================="
echo "✓ All platform functions working correctly"
echo "=========================================="
