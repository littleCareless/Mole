#!/bin/bash
# Comprehensive test for all Linux cleaning modules

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Load modules
source "$PROJECT_ROOT/lib/core/base.sh"
source "$PROJECT_ROOT/lib/core/log.sh"
source "$PROJECT_ROOT/lib/core/platform.sh"
source "$PROJECT_ROOT/lib/core/package_manager.sh"
source "$PROJECT_ROOT/lib/clean/linux_caches.sh"
source "$PROJECT_ROOT/lib/clean/user_cross_platform.sh"
source "$PROJECT_ROOT/lib/clean/package_managers.sh"

echo "=========================================="
echo "  Mole Comprehensive Cleaning Test"
echo "=========================================="
echo ""

echo "Platform: $(detect_platform)"
if is_linux; then
    echo "Distribution: $(detect_linux_distro)"
    echo "Package Manager: $(get_primary_package_manager)"
fi
echo ""

# Create test data
echo "📦 Creating test data..."
cache_dir=$(get_user_cache_dir)
mkdir -p "$cache_dir/test_thumbnails"
mkdir -p "$cache_dir/test_fonts"
dd if=/dev/zero of="$cache_dir/test_thumbnails/test.png" bs=1M count=5 2>/dev/null
dd if=/dev/zero of="$cache_dir/test_fonts/test.cache" bs=1M count=3 2>/dev/null
echo "✓ Created 8MB test data"
echo ""

# Show initial disk usage
echo "📊 Initial disk usage:"
du -sh "$cache_dir" 2>/dev/null || true
echo ""

# Test 1: Linux caches cleaning
echo "=========================================="
echo "Test 1: Linux Cache Cleaning"
echo "=========================================="
export DRY_RUN=false
clean_linux_caches

# Test 2: User data cleaning
echo "=========================================="
echo "Test 2: User Data Cleaning"
echo "=========================================="
clean_user_data

# Test 3: Package manager cleaning
echo "=========================================="
echo "Test 3: Package Manager Cleaning"
echo "=========================================="
export DRY_RUN=true  # Use dry-run for package managers to avoid actual changes
clean_package_managers

# Show final disk usage
echo "=========================================="
echo "📊 Final disk usage:"
du -sh "$cache_dir" 2>/dev/null || true
echo ""

echo "=========================================="
echo "✅ All tests completed!"
echo "=========================================="
