#!/bin/bash
# 推送 linux 分支到 GitHub

set -euo pipefail

echo "=========================================="
echo "  推送 Mole Linux 分支到 GitHub"
echo "=========================================="
echo ""

# 检查当前分支
current_branch=$(git branch --show-current)
if [[ "$current_branch" != "linux" ]]; then
    echo "❌ 当前不在 linux 分支，正在切换..."
    git checkout linux
fi

# 检查是否有未提交的更改
if ! git diff-index --quiet HEAD --; then
    echo "⚠️  检测到未提交的更改"
    echo ""
    git status --short
    echo ""
    read -p "是否提交这些更改? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git add -A
        read -p "请输入提交信息: " commit_msg
        git commit -m "$commit_msg"
    else
        echo "❌ 请先提交或暂存更改"
        exit 1
    fi
fi

# 推送到远程
echo ""
echo "📤 推送 linux 分支到 origin..."
echo ""

if git push -u origin linux; then
    echo ""
    echo "=========================================="
    echo "✅ 推送成功！"
    echo "=========================================="
    echo ""
    echo "在 Linux 机器上运行以下命令："
    echo ""
    echo "  git clone https://github.com/tw93/Mole.git"
    echo "  cd Mole"
    echo "  git checkout linux"
    echo "  ./tests/test_platform_simple.sh"
    echo ""
else
    echo ""
    echo "❌ 推送失败，可能需要先 fork 仓库"
    echo ""
    echo "如果这是你的 fork，请运行："
    echo "  git remote set-url origin https://github.com/YOUR_USERNAME/Mole.git"
    echo "  git push -u origin linux"
    echo ""
fi
