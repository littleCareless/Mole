# Linux 分支开发指南

本分支包含 Mole 的 Linux 平台适配工作。

## 📁 已完成的工作

### 1. 平台抽象层 ✅

- **`lib/core/platform.sh`** - 平台检测和路径映射
  - 支持 macOS 和 Linux 平台检测
  - XDG Base Directory 规范兼容
  - 跨平台路径映射函数
  - 系统服务管理抽象

- **`lib/core/package_manager.sh`** - 包管理器统一接口
  - 支持 apt, dnf, yum, pacman, flatpak, snap, brew
  - 统一的安装/卸载/清理接口
  - 自动检测主包管理器

- **`lib/core/common.sh`** - 已更新加载新模块

### 2. 测试工具 ✅

- **`tests/test_platform_simple.sh`** - 快速验证脚本
- **`tests/test_platform.sh`** - 完整测试套件

### 3. 文档 ✅

- **`LINUX_PORTING.md`** - 完整的移植指南
- **`lib/clean/EXAMPLE_CROSS_PLATFORM.sh`** - 适配示例代码

## 🚀 快速测试

```bash
# 测试平台抽象层
./tests/test_platform_simple.sh

# 测试平台检测
bash -c "source lib/core/platform.sh && detect_platform"

# 测试路径映射
bash -c "source lib/core/platform.sh && get_user_cache_dir"

# 测试包管理器检测
bash -c "source lib/core/package_manager.sh && get_primary_package_manager"
```

## 📋 待完成的工作

### 阶段 1: 核心模块适配 (优先级: 高)

需要将以下模块中的硬编码路径替换为平台抽象函数：

#### 清理模块 (`lib/clean/*.sh`)

- [ ] `app_caches.sh` - 应用缓存清理
- [ ] `apps.sh` - 应用相关清理
- [ ] `brew.sh` - 包管理器清理（需扩展支持 apt/dnf 等）
- [ ] `caches.sh` - 通用缓存清理
- [ ] `dev.sh` - 开发工具缓存
- [ ] `system.sh` - 系统级清理
- [ ] `user.sh` - 用户级清理

**适配模式参考**: `lib/clean/EXAMPLE_CROSS_PLATFORM.sh`

#### 卸载模块 (`lib/uninstall/*.sh`)

- [ ] `batch.sh` - 批量卸载
- [ ] `brew.sh` - 包管理器卸载（需扩展）

#### 优化模块 (`lib/optimize/*.sh`)

- [ ] `maintenance.sh` - 系统维护
- [ ] `tasks.sh` - 优化任务

### 阶段 2: 功能扩展 (优先级: 中)

- [ ] 实现 Linux 应用扫描逻辑
- [ ] 支持 .desktop 文件解析
- [ ] 支持 Flatpak/Snap 应用管理
- [ ] 实现 systemd 服务管理

### 阶段 3: 测试与优化 (优先级: 中)

- [ ] 在 Ubuntu 22.04+ 测试
- [ ] 在 Fedora 39+ 测试
- [ ] 在 Arch Linux 测试
- [ ] 性能优化
- [ ] 错误处理完善

### 阶段 4: 文档与发布 (优先级: 低)

- [ ] 更新 README.md
- [ ] 创建 Linux 安装脚本
- [ ] 编写用户文档
- [ ] 准备发布说明

## 🛠️ 适配指南

### 基本原则

1. **使用平台抽象函数**，不要硬编码路径
2. **添加平台检测**，处理 macOS/Linux 差异
3. **保持向后兼容**，不破坏现有 macOS 功能
4. **添加错误处理**，确保跨平台稳定性

### 适配步骤

#### 1. 识别硬编码路径

```bash
# 查找 macOS 特定路径
grep -r "Library/Caches" lib/clean/
grep -r "/private/" lib/clean/
grep -r "\.Trash" lib/clean/
```

#### 2. 替换为平台函数

```bash
# 之前
cache_dir="$HOME/Library/Caches"

# 之后
cache_dir=$(get_user_cache_dir)
```

#### 3. 添加平台检测

```bash
if is_macos; then
    # macOS 特定代码
    sudo purge
elif is_linux; then
    # Linux 特定代码
    purge_memory
fi
```

#### 4. 测试验证

```bash
# 语法检查
bash -n lib/clean/modified_file.sh

# 功能测试
source lib/clean/modified_file.sh
# 调用相关函数测试
```

### 常用替换模式

| 原路径 | 替换函数 |
|--------|---------|
| `$HOME/Library/Caches` | `$(get_user_cache_dir)` |
| `$HOME/Library/Application Support` | `$(get_user_data_dir)` |
| `$HOME/Library/Preferences` | `$(get_user_config_dir)` |
| `$HOME/.Trash` | `$(get_trash_dir)` |
| `/Library/Caches` | `$(get_system_cache_dir)` |
| `/private/var/log` | `$(get_system_log_dir)` |
| `/private/tmp` | `$(get_system_tmp_dir)` |

### 包管理器操作

```bash
# 获取主包管理器
primary_mgr=$(get_primary_package_manager)

# 清理缓存
clean_package_cache "$primary_mgr"

# 卸载软件包
remove_package "$primary_mgr" "package-name"

# 列出已安装包
list_installed_packages "$primary_mgr"
```

## 📚 参考资料

- **平台抽象层**: `lib/core/platform.sh`
- **包管理器接口**: `lib/core/package_manager.sh`
- **适配示例**: `lib/clean/EXAMPLE_CROSS_PLATFORM.sh`
- **完整文档**: `LINUX_PORTING.md`

## 🐛 已知问题

1. `tests/test_platform.sh` 在某些环境下可能卡住，使用 `test_platform_simple.sh` 代替
2. 需要在实际 Lin 环境中测试包管理器功能
3. 部分清理模块仍使用硬编码路径，需要逐步适配

## 💡 贡献指南

1. 选择一个待适配的模块
2. 参考 `EXAMPLE_CROSS_PLATFORM.sh` 进行修改
3. 使用 `test_platform_simple.sh` 验证
4. 提交 PR 并说明修改内容

## 📞 联系方式

如有问题，请在 GitHub Issues 中讨论。

---

**当前状态**: 基础架构完成，等待模块适配

**下一步**: 适配 `lib/clean/caches.sh` 作为第一个示例
