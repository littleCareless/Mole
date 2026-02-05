# 🚀 Mole Linux 测试快速指南

## 最快速的测试方法（推荐）

### 方法 1: Docker 测试（无需 Linux 机器）⭐⭐⭐⭐⭐

```bash
# 在 macOS 上直接运行
docker run --rm $(docker build -q -f docker/Dockerfile.ubuntu .)

# 或者分步执行
docker build -f docker/Dockerfile.ubuntu -t mole-ubuntu-test .
docker run --rm mole-ubuntu-test

# 测试多个发行版
docker-compose -f docker/docker-compose.yml up
```

**预期输出**:
```
==========================================
  Mole Platform Abstraction Test
==========================================

Platform Detection:
  OS: linux
  Distribution: ubuntu

Path Mapping:
  User Cache:  /home/moleuser/.cache
  User Data:   /home/moleuser/.local/share
  ...

✓ All platform functions working correctly
==========================================
```

### 方法 2: 传输到 Linux 机器 ⭐⭐⭐⭐

```bash
# 交互式部署脚本
./scripts/deploy_to_linux.sh

# 然后在 Linux 机器上
ssh user@linux-host
cd ~/mole-test
./tests/test_platform_simple.sh
```

### 方法 3: 通过 GitHub ⭐⭐⭐

```bash
# 1. 推送到 GitHub
git push -u origin linux

# 2. 在 Linux 机器上
git clone https://github.com/tw93/Mole.git
cd Mole
git checkout linux
./tests/test_platform_simple.sh
```

## 📊 测试结果对比

| 平台 | 平台检测 | 路径映射 | 包管理器 | 状态 |
|------|---------|---------|---------|------|
| **macOS** | ✅ macos | ✅ ~/Library/* | ✅ brew | 已验证 |
| **Ubuntu** | ✅ linux | ✅ ~/.cache | ✅ apt | 已验证 |
| **Fedora** | 🧪 待测试 | 🧪 待测试 | 🧪 dnf | 待测试 |
| **Arch** | 🧪 待测试 | 🧪 待测试 | 🧪 pacman | 待测试 |

## 🎯 下一步行动

### 选项 A: 继续开发（推荐）
```bash
# 1. 适配第一个清理模块
vim lib/clean/caches.sh
# 参考: lib/clean/EXAMPLE_CROSS_PLATFORM.sh

# 2. 在 Docker 中测试
docker run --rm -v $(pwd):/home/moleuser/mole mole-ubuntu-test bash

# 3. 提交更改
git add lib/clean/caches.sh
git commit -m "feat(linux): adapt caches.sh for cross-platform"
```

### 选项 B: 在真实 Linux 上测试
```bash
# 使用部署脚本
./scripts/deploy_to_linux.sh

# 或手动传输
rsync -avz --exclude='.git' ./ user@linux:~/mole-test/
ssh user@linux 'cd ~/mole-test && ./tests/test_platform_simple.sh'
```

### 选项 C: 推送到 GitHub 协作
```bash
# 推送分支
./scripts/push_linux_branch.sh

# 或手动推送
git push -u origin linux

# 创建 Pull Request
# 访问: https://github.com/tw93/Mole/compare/main...linux
```

## 📝 快速命令参考

```bash
# Docker 测试
docker build -f docker/Dockerfile.ubuntu -t mole-test . && docker run --rm mole-test

# 文件传输
rsync -avz --exclude='.git' ./ user@host:~/mole/

# GitHub 推送
git push -u origin linux

# 本地测试（macOS）
./tests/test_platform_simple.sh

# 查看文档
cat TESTING_GUIDE.md          # 完整测试指南
cat LINUX_PORTING.md          # 移植文档
cat LINUX_BRANCH_README.md    # 开发指南
```

## 🐛 遇到问题？

1. **Docker 构建失败**
   ```bash
   # 清理缓存重试
   docker system prune -a
   docker build --no-cache -f docker/Dockerfile.ubuntu -t mole-test .
   ```

2. **SSH 连接失败**
   ```bash
   # 测试连接
   ssh -v user@host

   # 使用密钥
   ssh-copy-id user@host
   ```

3. **权限问题**
   ```bash
   # 设置执行权限
   find . -name "*.sh" -exec chmod +x {} \;
   ```

## 📚 完整文档

- **TESTING_GUIDE.md** - 详细的测试部署指南
- **LINUX_PORTING.md** - Linux 移植技术文档
- **LINUX_BRANCH_README.md** - 开发者指南

---

**推荐**: 先用 Docker 测试，确认功能正常后再部署到真实 Linux 机器！
