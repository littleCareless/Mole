#!/bin/bash
# 快速传输 Mole 代码到 Linux 机器

set -euo pipefail

echo "=========================================="
echo "  传输 Mole 到 Linux 机器"
echo "=========================================="
echo ""

# 配置
read -p "请输入 Linux 机器地址 (例: user@192.168.1.100): " REMOTE_HOST
read -p "请输入目标目录 (默认: ~/mole-test): " REMOTE_DIR
REMOTE_DIR=${REMOTE_DIR:-~/mole-test}

echo ""
echo "📦 准备传输..."
echo "  源: $(pwd)"
echo "  目标: $REMOTE_HOST:$REMOTE_DIR"
echo ""

# 创建临时目录
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# 导出 linux 分支到临时目录
echo "📁 导出 linux 分支..."
git archive --format=tar linux | tar -x -C "$TEMP_DIR"

# 复制测试脚本（确保可执行）
chmod +x "$TEMP_DIR/tests"/*.sh 2>/dev/null || true

# 使用 rsync 传输（保留权限）
echo ""
echo "🚀 传输文件到 Linux 机器..."
echo ""

if command -v rsync &>/dev/null; then
    rsync -avz --progress \
        --exclude='.git' \
        --exclude='node_modules' \
        --exclude='bin/*-darwin-*' \
        "$TEMP_DIR/" "$REMOTE_HOST:$REMOTE_DIR/"
else
    # 回退到 scp
    scp -r "$TEMP_DIR"/* "$REMOTE_HOST:$REMOTE_DIR/"
fi

if [[ $? -eq 0 ]]; then
    echo ""
    echo "=========================================="
    echo "✅ 传输成功！"
    echo "=========================================="
    echo ""
    echo "在 Linux 机器上运行以下命令："
    echo ""
    echo "  ssh $REMOTE_HOST"
    echo "  cd $REMOTE_DIR"
    echo "  ./tests/test_platform_simple.sh"
    echo ""
    echo "或者直接远程执行："
    echo ""
    echo "  ssh $REMOTE_HOST 'cd $REMOTE_DIR && ./tests/test_platform_simple.sh'"
    echo ""
else
    echo ""
    echo "❌ 传输失败，请检查："
    echo "  1. SSH 连接是否正常"
    echo "  2. 目标目录是否有写权限"
    echo "  3. 网络连接是否稳定"
    echo ""
fi
