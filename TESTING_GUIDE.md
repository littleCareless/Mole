# Mole Linux 测试部署指南

本文档提供多种方式将 Mole Linux 分支部署到 Linux 机器进行测试。

## 🚀 快速开始

### 方案 1: 通过 GitHub（推荐）

#### 步骤 1: 推送到 GitHub

```bash
# 在 macOS 上执行
./scripts/push_linux_branch.sh

# 或手动推送
git push -u origin linux
```

#### 步骤 2: 在 Linux 机器上克隆

```bash
# 在 Linux 机器上执行
git clone https://github.com/tw93/Mole.git
cd Mole
git checkout linux

# 运行测试
./tests/test_platform_simple.sh
```

### 方案 2: 直接传输文件

```bash
# 在 macOS 上执行交互式脚本
./scripts/deploy_to_linux.sh

# 或手动传输
rsync -avz --exclude='.git' ./ user@linux-host:~/mole-test/
```

### 方案 3: 使用 Docker（最推荐）

```bash
# 在 macOS 上构建并测试
docker build -f docker/Dockerfile.ubuntu -t mole-linux-test .
docker run -it mole-linux-test

# 或使用 docker-compose
docker-compose -f docker/docker-compose.yml up
```

## 📋 详细方案

### 方案 1: GitHub 推送（标准方式）

**优点**:
- ✅ 保留完整 Git 历史
- ✅ 支持团队协作
- ✅ 可以创建 Pull Request

**步骤**:

1. **推送分支**
   ```bash
   # 确保在 linux 分支
   git checkout linux

   # 推送到远程
   git push -u origin linux
   ```

2. **在 Linux 机器上克隆**
   ```bash
   # 克隆仓库
   git clone https://github.com/tw93/Mole.git
   cd Mole

   # 切换到 linux 分支
   git checkout linux

   # 验证分支
   git branch -v
   ```

3. **运行测试**
   ```bash
   # 快速测试
   ./tests/test_platform_simple.sh

   # 完整测试
   ./tests/test_platform.sh

   # 测试特定功能
   bash -c "source lib/core/platform.sh && detect_platform"
   ```

### 方案 2: 直接文件传输（快速方式）

**优点**:
- ✅ 速度快
- ✅ 不需要 GitHub 访问
- ✅ 适合快速迭代

**使用 rsync（推荐）**:

```bash
# 基本传输
rsync -avz --exclude='.git' \
  ~/coding/Mole/ \
  user@192.168.1.100:~/mole-test/

# 带进度显示
rsync -avz --progress --exclude='.git' \
  ~/coding/Mole/ \
  user@192.168.1.100:~/mole-test/

# 只传输 linux 分支的文件
git archive --format=tar linux | \
  ssh user@192.168.1.100 'cd ~/mole-test && tar -xf -'
```

**使用 scp**:

```bash
# 压缩后传输
tar czf mole-linux.tar.gz \
  --exclude='.git' \
  --exclude='node_modules' \
  --exclude='bin/*-darwin-*' \
  .

scp mole-linux.tar.gz user@192.168.1.100:~/

# 在 Linux 机器上解压
ssh user@192.168.1.100 'tar xzf mole-linux.tar.gz -C ~/mole-test'
```

**使用自动化脚本**:

```bash
# 交互式部署
./scripts/deploy_to_linux.sh

# 脚本会提示输入：
# - Linux 机器地址
# - 目标目录
# - 自动传输并设置权限
```

### 方案 3: Docker 容器测试（最佳实践）

**优点**:
- ✅ 环境隔离
- ✅ 可重复测试
- ✅ 支持多发行版
- ✅ 不需要真实 Linux 机器

#### 创建 Dockerfile

**Ubuntu 测试环境**:

```dockerfile
# docker/Dockerfile.ubuntu
FROM ubuntu:22.04

# 安装基础工具
RUN apt-get update && apt-get install -y \
    bash \
    coreutils \
    findutils \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

# 复制代码
WORKDIR /mole
COPY . .

# 设置权限
RUN chmod +x tests/*.sh

# 默认命令
CMD ["./tests/test_platform_simple.sh"]
```

**Fedora 测试环境**:

```dockerfile
# docker/Dockerfile.fedora
FROM fedora:39

RUN dnf install -y \
    bash \
    coreutils \
    findutils \
    git \
    curl \
    && dnf clean all

WORKDIR /mole
COPY . .
RUN chmod +x tests/*.sh

CMD ["./tests/test_platform_simple.sh"]
```

**Arch Linux 测试环境**:

```dockerfile
# docker/Dockerfile.arch
FROM archlinux:latest

RUN pacman -Syu --noconfirm \
    bash \
    coreutils \
    findutils \
    git \
    curl \
    && pacman -Scc --noconfirm

WORKDIR /mole
COPY . .
RUN chmod +x tests/*.sh

CMD ["./tests/test_platform_simple.sh"]
```

#### 使用 Docker Compose

```yaml
# docker/docker-compose.yml
version: '3.8'

services:
  ubuntu:
    build:
      context: ..
      dockerfile: docker/Dockerfile.ubuntu
    container_name: mole-ubuntu-test
    volumes:
      - ..:/mole
    command: ./tests/test_platform_simple.sh

  fedora:
    build:
      context: ..
      dockerfile: docker/Dockerfile.fedora
    container_name: mole-fedora-test
    volumes:
      - ..:/mole
    command: ./tests/test_platform_simple.sh

  arch:
    build:
      context: ..
      dockerfile: docker/Dockerfile.arch
    container_name: mole-arch-test
    volumes:
      - ..:/mole
    command: ./tests/test_platform_simple.sh
```

#### Docker 测试命令

```bash
# 构建镜像
docker build -f docker/Dockerfile.ubuntu -t mole-ubuntu .

# 运行测试
docker run --rm mole-ubuntu

# 交互式测试
docker run -it --rm mole-ubuntu bash

# 测试所有发行版
docker-compose -f docker/docker-compose.yml up

# 测试特定发行版
docker-compose -f docker/docker-compose.yml up ubuntu
```

### 方案 4: 虚拟机测试

**使用 Multipass（推荐）**:
# 安装 Multipass
brew install multipass

# 创建 Ubuntu 虚拟机
multipass launch --name mole-test --cpus 2 --mem 2G --disk 10G

# 传输代码
multipass transfer -r ~/coding/Mole mole-test:/home/ubuntu/

# 进入虚拟机
multipass shell mole-test

# 在虚拟机内测试
cd Mole
./tests/test_platform_simple.sh

# 清理
multipass delete mole-test
multipass purge
```

**使用 Vagrant**:

```ruby
# Vagrantfile
Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/jammy64"

  config.vm.synced_folder ".", "/mole"

  config.vm.provision "shell", inline: <<-SHELL
    cd /mole
    chmod +x tests/*.sh
    ./tests/test_platform_sime.sh
  SHELL
end
```

```bash
# 启动虚拟机
vagrant up

# SSH 进入
vagrant ssh

# 测试
cd /mole
./tests/test_platform_simple.sh
```

## 🧪 测试清单

### 基础功能测试

```bash
# 1. 平台检测
bash -c "source lib/core/platform.sh && detect_platform"
# 预期输出: linux

# 2. 发行版检测
bash -c "source lib/core/platform.sh && detect_linux_distro"
# 预期输出: ubuntu/fedora/arch 等

# 3. 路径映射
bash -c "source lib/core/platform.sh && get_user_cache_dir"
# 预期输出: /home/username/.cache

# 4. 包管理器检测
bash -c "source lib/core/package_manager.sh && get_primary_package_manager"
# 预期输出: apt/dnf/pacman 等

# 5. 完整测试
./tests/test_platform_simple.sh
```

### 功能验证测试

```bash
# 测试浏览器缓存路径
bash -c "source lib/core/platform.sh && get_browser_cache_dirs"

# 测试包管理器缓存路径
bash -c "source lib/core/package_manager.sh && get_package_cache_dir apt"

# 测试环境变量
bash -c "source lib/core/platform.sh && echo \$MOLE_PLATFORM"

# 测试平台特定函数
bash -c "source lib/core/platform.sh && is_linux && echo 'Linux detected'"
```

## 📊 不同发行版测试矩阵

| 发行版 | Docker 镜像 | 包管理器 | 测试状态 |
|--------|------------|---------|---------|
| Ubuntu 22.04 | `ubuntu:22.04` | apt | 🧪 待测试 |
| Ubuntu 24.04 | `ubuntu:24.04` | apt | 🧪 待测试 |
| Fedora 39 | `fed:39` | dnf | 🧪 待测试 |
| Arch Linux | `archlinux:latest` | pacman | 🧪 待测试 |
| Debian 12 | `debian:12` | apt | 🧪 待测试 |

## 🐛 常见问题

### 1. SSH 连接失败

```bash
# 检查 SSH 服务
ssh -v user@host

# 使用密钥认证
ssh-copy-id user@host

# 指定端口
ssh -p 2222 user@host
```

### 2. 权限问题

```bash
# 在 Linux 机器上设置权限
chmod +x tests/*.sh
chmod +x lib/**/*.sh

# 或批量设置
find . -name "*.sh" -exec chmod +x {} \;
```

### 3. 依赖缺失

```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install -y bash coreutils findutils

# Fedora
sudo dnf install -y bash coreutils findutils

# Arch
scman -S bash coreutils findutils
```

### 4. Docker 权限问题

```bash
# 将用户添加到 docker 组
sudo usermod -aG docker $USER

# 重新登录或运行
newgrp docker
```

## 📝 测试报告模板

```markdown
## Mole Linux 测试报告

**测试环境**:
- 发行版: Ubuntu 22.04
- 内核版本: 5.15.0
- 包管理器: apt

**测试结果**:
- [ ] 平台检测: ✅ 通过
- [ ] 路径映射: ✅ 通过
- [ ] 包管理器: ✅ 通过
- [ ] 浏览器路径: ✅ 通过
- [ ] 环境变量: ✅ 通过

**发现的问题**:
1. 问题描述
2. 复现步骤
3. 预期行为
4. 实际行为

**建议改进**:
- 改进建议 1
- 改进建议 2
```

## 🎯 推荐测试流程

1. **本地 Docker 测试** (5 分钟)
   ```bash
   docker build -f docker/Dockerfile.ubuntu -t mole-test .
   docker run --rm mole-test
   ```

2. **真实 Linux 机器测试** (10 分钟)
   ```bash
   ./scripts/deploy_to_linux.sh
   ssh user@host 'cd ~/mole-test && ./tests/test_platform_simple.sh'
   ```

3. **多发行版测试** (15 分钟)
   ```bash
   docker-compose -f docker/docker-compose.yml up
   ```

4. **提交测试报告**
   - 记录测试结果
   - 提交 Issue 或 PR
   - 更新文档

---

**下一步**: 选择一种方案开始测试，建议从 Docker 方案开始！
