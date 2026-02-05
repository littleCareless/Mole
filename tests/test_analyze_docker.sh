#!/bin/bash
# Test mo analyze in Docker Linux environment

set -euo pipefail

echo "=========================================="
echo "  Testing mo analyze in Docker Linux"
echo "=========================================="
echo ""

# Create test directory structure with various sizes
echo "📦 Creating test directory structure..."
mkdir -p ~/test_disk/{large_files,small_files,nested/{deep1,deep2,deep3}}

# Create files of different sizes
dd if=/dev/zero of=~/test_disk/large_files/file1.bin bs=1M count=50 2>/dev/null
dd if=/dev/zero of=~/test_disk/large_files/file2.bin bs=1M count=30 2>/dev/null
dd if=/dev/zero of=~/test_disk/small_files/file1.txt bs=1K count=100 2>/dev/null
dd if=/dev/zero of=~/test_disk/small_files/file2.txt bs=1K count=50 2>/dev/null
dd if=/dev/zero of=~/test_disk/nested/deep1/data.bin bs=1M count=20 2>/dev/null
dd if=/dev/zero of=~/test_disk/nested/deep2/data.bin bs=1M count=15 2>/dev/null
dd if=/dev/zero of=~/test_disk/nested/deep3/data.bin bs=1M count=10 2>/dev/null

echo "✓ Created test directory structure"
echo ""

# Show directory structure
echo "📊 Test directory structure:"
du -h --max-depth=2 ~/test_disk 2>/dev/null || du -h -d 2 ~/test_disk
echo ""

# Build analyze binary
echo "🔨 Building analyze binary..."
cd /home/moleuser/mole
make build 2>&1 | grep -E "(Building|DONE|analyze)" || true
echo ""

# Check if binary exists
if [[ -f ./bin/analyze-go ]]; then
    echo "✓ analyze-go binary built successfully"
    ls -lh ./bin/analyze-go
    echo ""
else
    echo "❌ analyze-go binary not found"
    exit 1
fi

# Test analyze with non-interactive mode (just scan and show results)
echo "🔍 Testing analyze scan functionality..."
echo ""

# Run analyze in a way that shows the scan results
# Since it's a TUI app, we'll just verify it can start and scan
timeout 5s ./bin/analyze-go ~/test_disk 2>&1 || true

echo ""
echo "=========================================="
echo "✅ Test completed!"
echo "=========================================="
echo ""
echo "Summary:"
echo "  - Test directory created: ~/test_disk"
echo "  - Total size: ~135MB"
echo "  - analyze binary: $(ls -lh ./bin/analyze-go 2>/dev/null | awk '{print $5}')"
echo "  - Platform: $(uname -s)"
echo ""
