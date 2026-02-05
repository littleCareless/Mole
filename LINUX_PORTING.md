# Mole Linux 移植指南

本文档描述了 Mole 从 macOS 移植到 Linux 的架构设计、实现细节和使用说明。

## 📋 目录

- [架构概览](#架构概览)
- [平台适配层](#平台适配层)
- [路径映射](#路径映射)
- [包管理器支持](#包管理器支持)
- [功能适配状态](#功能适配状态)
- [开发指南](#开发指南)
- [已知限制](#已知限制)

## 🏗️ 架构概览

### 设计原则

Mole Linux 版本采用**平台抽象层**设计，通过统一的接口屏蔽 macOS 和 Linux 的差异：

```
┌─────────────────────────────────────┐
│     Mole CLI Commands               │
│  (clean, uninstall, optimize, etc)  │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│     Platform Abstraction Layer      │
│  ┌──────────────┐ ┌───────────────┐ │
│  │ platform.sh  │ │ pkg_manager.sh│ │
│  └──────────────┘ └───────────────┘ │
└──────────────┬──────────────────────┘
               │
       ┌───────┴────────┐
       │                │
┌──────▼──────┐  ┌─────▼──────┐
│   macOS     │  │   Linux    │
│  Darwin API │  │  GNU/Linux │
└─────────────┘  └────────────┘
```

### 核心模块

| 模块 | 文件 | 功能 |
|------|------|------|
| **平台检测** | `lib/core/platform.sh` | 检测操作系统、发行版、路径映射 |
| **包管理器** | `lib/core/package_manager.sh` | 统一的包管理器接口 |
| **文件操作** | `lib/core/file_ops.sh` | 跨平台文件操作 |
| **系统服务** | `lib/core/platform.sh` | systemctl/launchctl 抽象 |

## 🗺️ 平台适配层

### 平台检测

```bash
# 使用示例
source lib/core/platform.sh

# 检测平台
if is_linux; then
    echo "Running on Linux"
    echo "Distribution: $MOLE_LINUX_DISTRO"
elif is_macos; then
    echo "Running on macOS"
fi
```

### 支持的 Linux 发行版

| 发行版 | 检测标识 | 包管理器 | 状态 |
|--------|---------|---------|------|
| Ubuntu | `ubuntu` | apt | ✅ 完全支持 |
| Debian | `debian` | apt | ✅ 完全支持 |
| Fedora | `fedora` | dnf | ✅ 完全支持 |
| RHEL/CentOS | `rhel` | dnf/yum | ✅ 完全支持 |
| Arch Linux | `arch` | pacman | ✅ 完全支持 |
| 其他 | `unknown` | 自动检测 | ⚠️ 部分支持 |

## 📂 路径映射

### XDG Base Directory 规范

Linux 版本遵循 [XDG Base Directory Specification](https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html)：

| 用途 | macOS | Linux (XDG) | 环境变量 |
|------|-------|-------------|---------|
| **用户缓存** | `~/Library/Caches` | `~/.cache` | `$XDG_CACHE_HOME` |
| **用户数据** | `~/Library/Application Support` | `~/.local/share` | `$XDG_DATA_HOME` |
| **用户配置** | `~/Library/Preferences` | `~/.config` | `$XDG_CONFIG_HOME` |
| **用户日志** | `~/Lry/Logs` | `~/.local/state` | `$XDG_STATE_HOME` |
| **回收站** | `~/.Trash` | `~/.local/share/Trash` | - |

### 系统路径映射

| 用途 | macOS | Linux |
|------|-------|-------|
| **系统缓存** | `/Library/Caches` | `/var/cache` |
| **系统日志** | `/private/var/log` | `/var/log` |
| **临时文件** | `/private/tmp` | `/tmp` |
| **临时变量** | `/private/var/tmp` | `/var/tmp` |

### 应用程序路径

| 类型 | macOS | Linux |
|------|-------|-------|
| **系统应用** | `/Applications` | `/usr/share/applications` |
| **用户应用** | `~/Applications` | `~/.local/share/applications` |
| **第三方应用** | - | `/opt` |
| **Snap 应用** | - | `/snap` |
| **Flatpak 应用** | - | `~/.local/share/flatpak`<br>`/var/lib/flatpak` |

### 浏览器缓存路径

| 浏览器 | macOS | Linux |
|--------|-------|-------|
| **Chrome** | `~/Library/Caches/Google/Chrome` | `~/.cache/google-chrome` |
| **Firefox** | `~/Library/Caches/Firefox` | `~/.cache/mozilla/firefox` |
| **Edge** | `~/Library/Caches/Microsoft Edge` | `~/.cache/microsoft-edge` |
| **Brave** | `~/Library/Caches/Brave` | `~/.cache/BraveSoftware/Brave-Browser` |

### 使用路径映射函数

```bash
# 获取用户缓存目录
cache_dir=$(get_user_cache_dir)
# macOS: /Users/username/Library/Caches
# Linux:  /home/username/.cache

# 获取浏览器缓存目录
for browser_cache in $(get_browser_cache_dirs); do
    echo "Browser cache: $browser_cache"
done
```

## 📦 包管理器支持

### 支持的包管理器

| 包管理器 | 发行版 | 功能 | 状态 |
|---------|--------|------|------|
| **apt** | Debian/Ubuntu | 安装、卸载、清理缓存 | ✅ 完全支持 |
| **dnf** | Fedora/RHEL 8+ | 安装、卸载、清理缓存 | ✅ 完全支持 |
| **yum** | RHEL/CentOS 7 | 安装、卸载、清理缓存 | ✅ 完全支持 |
| **pacman** | Arch Linux | 安装、卸载、清理缓存 | ✅ 完全支持 |
| **flatpak** | 通用 | 应用管理 | ✅ 完全支持 |
| **snap** | Ubuntu/通用 | 应用管理 | ✅ 完全支持 |
| **brew** | macOS/Linux | 安装、卸载、清理缓存 | ✅ 完全支持 |

### 包管理器检测

```bash
# 自动检测主包管理器
primary_mgr=$(get_primary_package_manager)
echo "Primary package manager: $primary_mgr"

# 检测所有可用的包管理器
for mgr in $(detect_package_managers); do
    echo "Available: $mgr"
done

# 检查特定包管理器
if has_package_manager "flatpak"; then
    echo "Flatpak is available"
fi
```

### 统一操作接口

```bash
# 清理包管理器缓存
clean_package_cache "apt"           # 清理 apt 缓存
clean_package_cache "apt" --dry-run # 预览清理操作

# 卸载软件包
remove_package "apt" "firefox"           # 卸载 Firefox
remove_package "flatpak" "org.gimp.GIMP" # 卸载 Flatpak 应用

# 获取包信息
get_package_info "apt" "vim"
```

### 包管理器缓存路径

| 包管理器 | 缓存路径 |
|---------|---------|
| apt | `/var/cache/apt/archives` |
| dnf | `/var/cache/dnf` |
| yum | `/var/cache/yum` |
| pacman | `/var/cache/pacman/pkg` |
| brew | `$(brew --prefix)/Caches` |
| flatpak | `/var/tmp/flatpak-cache` |
| snap | `/var/lib/snapd/cache` |

## ✅ 功能适配状态

### 核心功能

| 功能 | macOS | Linux | 说明 |
|------|-------|-------|------|
| **mo clean** | ✅ | 🚧 | 用户缓存清理已适配，系统清理待完善 |
| **mo uninstall** | ✅ | 🚧 | 支持 apt/flatpsnap，待完善 |
| **mo optimize** | ✅ | 🚧 | 基础优化已适配，高级功能待完善 |
| **mo analyze** | ✅ | ✅ | Go 实现，跨平台兼容 |
| **mo status** | ✅ | ✅ | Go 实现，跨平台兼容 |
| **mo purge** | ✅ | ✅ | 项目构建产物清理，跨平台兼容 |
| **mo installer** | ✅ | 🚧 | 待适配 Linux 安装包路径 |

### 清理模块适配

| 清理目标 | macOS | Linux | 实现状态 |
|---------|-------|-------|---------|
| 用户缓存 | ✅ | ✅ | 已适配 XDG 路径 |
| 浏览器缓存 | ✅ | ✅ | 已适配 Linux 浏览器路径 |
| 系统日志 | ✅ | ✅ | 已适配 `/var/log` |
| 临时文件 | ✅ | ✅ | 已适配 `/tmp` |
| 包管理器缓存 | ✅ (brew) | ✅ | 支持 apt/dnf/pacman |
| 开发工具缓存 | ✅ | ✅ | npm/yarn/cargo 等 |
| 回收站 | ✅ | ✅ | 已适配 XDG Trash |

### 优化模块适配

| 优化操作 | macOS | Linux | 实现方式 |
|---------|-------|-------|---------|
| 清理内存缓存 | `sudo purge` | `echo 3 > /proc/sys/vm/drop_caches` | ✅ 已适配 |
| 重建系统数据库 | `sudo update_dyld_shared_cache` | `sudo ldconfig` | 🚧 待实现 |
| 重启系统服务 | `launchctl` | `systemctl` | ✅ 已适配 |
| 清理 DNS 缓存 | `dscacheutil -flushcache` | `systemd-resolve --flush-caches` | 🚧 待实现 |
| 重建 Spotlight | `mdutil -E /` | `updatedb` (mlocate) | 🚧 待实现 |

## 🛠️ 开发指南

### 添加新功能时的注意事项

1. **使用平台抽象函数**
   ```bash
   # ❌ 错误：硬编码 macOS 路径
   cache_dir="$HOME/Library/Caches"

   # ✅ 正确：使用平台抽象
   cache_dir=$(get_user_cache_dir)
   ```

2. **检测平台差异**
   ```bash
 _macos; then
       # macOS 特定逻辑
       sudo purge
   elif is_linux; then
       # Linux 特定逻辑
       sync && echo 3 | sudo tee /proc/sys/vm/drop_caches
   fi
   ```

3. **使用统一的包管理器接口**
   ```bash
   # ❌ 错误：直接调用 apt
   sudo apt-get remove firefox

   # ✅ 正确：使用抽象接口
   remove_package "$(get_primary_package_manager)" "firefox"
   ```

### 测试清单

在提交代码前，请确保：

- [ ] 在 Ubuntu 22.04+ 上测试
- [ ] 在 Fedora 39+ 上测试（如果可能）
- [ ] 使用 `--dry-run` 验证操作安全性
- [ ] 检查路径映射是否正确
- [ ] 验证包管理器检测逻辑
- [ ] 确保不会删除系统关键文件

### 添加新的 Linux 发行版支持

1. 在 `platform.sh` 的 `detect_linux_distr加检测逻辑
2. 在 `package_manager.sh` 的 `get_primary_package_manager()` 中添加映射
3. 测试所有核心功能
4. 更新本文档

## ⚠️ 已知限制

### 当前限制

1. **应用卸载功能**
   - ❌ 不支持从源码编译安装的应用
   - ❌ 不支持 AppImage 应用的自动检测
   - ⚠️ Flatpak/Snap 应用的残留文件清理不完整

2. **系统优化功能**
   - ❌ 不支持 Spotlight 等效功能（mlocate）的重建
   - ❌ 不支持图形界面的刷新（Finder/Dock 等效）
   - ⚠️ DNS 缓存清理依赖 systemd-resolved

3. **权限管理**
   - ⚠️ 需要 sudo 权限执行系统级清理
   - ❌ 不支持 Touch ID（Linux 无此功能）
   - 🚧 PolicyKit 集成待实现

4. **发行版兼容性**
   - ✅ 主流发行版（Ubuntu/Fedora/Arch）完全支持
   - ⚠️ 小众发行版可能需要手动配置
   - ❌ 非 systemd 发行版（如 Void Linux）部分功能不可用

### 安全注意事项

1. **文件删除不可逆**
   - 始终先使用 `--dry-r  - 重要数据请提前备份

2. **系统文件保护**
   - 已内置白名单机制保护关键系统文件
   - 可通过 `mo clean --whitelist` 自定义保护路径

3. **权限要求**
   - 用户级清理：无需 sudo
   - 系统级清理：需要 sudo 权限
   - 包管理器操作：需要 sudo 权限

## 📚 参考资料

- [XDG Base Directory Specification](https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html)
- [Filesystem Hierarchy Standard](https://refspecs.linuxfoundation.org/FHS_3.0/fhs/index.html)
- [systemd Documentation](https://www.freedesktop.org/software/systemd/man/)
- [Flatpak Documentation](https://docs.flatpak.org/)
- [Snap Documentation](https://snapcraft.io/docs)

## 🤝 贡献

欢迎为 Linux 版本贡献代码！请参考：

1. [CONTRIBUTING.md](CONTRIBUTING.md) - 贡献指南
2. [SECURITY_AUDIT.md](SECURITY_AUDIT.md) - 安全审计
3. 本文档的开发指南部分

### 优先级任务

- [ ] 完善 `mo uninstall` 的应用扫描逻辑
- [ ] 实现 `mo installer` 的 Linux 适配
- [ ] 添加 PolicyKit 集成
- [ ] 支持更多 Linux 发行版
- [ ] 完善系统优化功能

## 📝 更新日志

### v1.0-linux (开发中)

- ✅ 创建平台抽象层 (`platform.sh`)
- ✅ 实现包管理器统一接口 (`package_manager.sh`)
- ✅ 适配 XDG Base Directory 规范
- ✅ 支持 apt/dnf/pacman/flatpak/snap
- 🚧 适配核心清理功能
- 🚧 适配应用卸载功能
- 🚧 适配系统优化功能

---

**注意**: 本文档随开发进度持续更新。最新信息请查看 [GitHub Issues](https://github.com/tw93/Mole/issues)。
