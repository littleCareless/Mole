#!/bin/bash
# Test Linux cache cleaning functionality in Docker

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Load modules
source "$PROJECT_ROOT/lib/core/base.sh"
source "$PROJECT_ROOT/lib/core/log.sh"
source "$PROJECT_ROOT/lib/core/platform.sh"
source "$PROJECT_ROOT/lib/core/package_manager.sh"
source "$PROJECT_ROOT/lib/clean/linux_caches.sh"

echo "=========================================="
echo "  Mole Linux Cache Cleaning Test"
echo "=========================================="
echo ""

# Create test cache files
echo "📦 Creating test cache files..."

# Create user cache test files
cache_dir=$(get_user_cache_dir)
mkdir -p "$cache_dir/thumbnails"
mkdir -p "$cache_dir/fontconfig"
mkdir -p "$cache_dir/pip"

# Create dummy files (10MB each)
dd if=/dev/zero of="$cache_dir/thumbnails/test1.png" bs=1M count=10 2>/dev/null
dd if=/dev/zero of="$cache_dir/fontconfig/test.cache" bs=1M count=5 2>/dev/null
dd if=/dev/zero of="$cache_dir/pip/test.whl" bs=1M count=8 2>/dev/null

echo "✓ Created test cache files"
echo ""

# Show disk usage before
echo "📊 Disk usage before cleaning:"
du -sh "$cache_dir" 2>/dev/null || true
echo ""

# Run dry-run first
echo "🔍 Running dry-run..."
export DRY_RUN=true
clean_linux_caches
echo ""

# Run actual cleaning
echo "🧹 Running actual cleaning..."
export DRY_RUN=false
clean_linux_caches
echo ""

# Show disk usage after
echo "📊 Disk usage after cleaning:"
du -sh "$cache_dir" 2>/dev/null || true
echo ""

echo "=========================================="
echo "✅ Test completed successfully!"
echo "=========================================="
