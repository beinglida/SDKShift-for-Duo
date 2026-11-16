# SDKShift for Duo · 使用教程（简体中文）

本教程介绍如何把项目克隆到本地、编译、签名安装到 iPhone，以及在 App 内的操作流程。配合根目录 `README.zh-CN.md` 一起阅读。

> ⚠️ 重要前提：本工具通过 `worse_query`（沙盒逃逸 PoC）写入 LaunchServices 的 `.csstore` 数据库来覆写应用的 SDK 标记。**签名只决定能否安装和启动，不提供写入系统数据库的能力**——真正生效依赖漏洞在目标 iOS 版本上有效，且**每次修改后必须完整重启 iPhone**。这是一个实验性原型，不保证在任意设备/系统上可用。

---

## 1. 环境准备

| 项目 | 要求 |
| --- | --- |
| 操作系统 | macOS（能运行 Xcode 27.2） |
| Xcode | **27.2**，含 iOS 27 SDK |
| 设备 | iPhone Duo，iOS 27.x，已开启开发者模式 |
| 账号 | 个人/公司开发者账号（真机调试），或企业账号（生成 In-House IPA） |
| 可选 | `xcodegen`（从 `project.yml` 重新生成工程）、`gh`（上传 Release）、Sideloadly（重签安装 IPA） |

检查 Xcode 版本：

```sh
xcodebuild -version
```

---

## 2. 克隆到本地

```sh
git clone https://github.com/beinglida/SDKShift-for-Duo.git
cd SDKShift-for-Duo
```

工程目录结构：

```
SDKShift.xcodeproj      # 已提交的 Xcode 工程，可直接打开
project.yml             # XcodeGen 配置（改签名后可据此重新生成工程）
SDKShift.entitlements   # App Group 授权
Sources/                # 界面、引擎、九种语言本地化
Tests/                  # 本地回归检查（不碰真机）
docs/                   # 本教程
```

---

## 3. 打开工程

**方式 A：直接打开（最简单）**

```sh
open SDKShift.xcodeproj
```

**方式 B：用 XcodeGen 重新生成**（改了 `project.yml` 后用）

```sh
brew install xcodegen   # 如未安装
xcodegen generate
open SDKShift.xcodeproj
```

---

## 4. 配置签名（换成你自己的账号）

工程里写死的是原作者配置，必须全部替换。以下三处的 **App Group 必须完全一致**，否则 App 启动后拿不到数据容器，功能直接失效：

| 位置 | 当前值 | 改成 |
| --- | --- | --- |
| `project.yml` / 工程 `DEVELOPMENT_TEAM` | `GU32528JRC` | 你的 Team ID |
| `PRODUCT_BUNDLE_IDENTIFIER` | `com.sheldonfornet.sdkshift` | 你注册的 Bundle ID |
| `SDKShift.entitlements` 的 App Group | `group.com.sheldonfornet.sdkshift` | 你注册的 App Group |
| `Sources/FDEngine.m` 的 `FDAppGroup` | 同上 | 与 entitlements 保持一致 |

在 Xcode 的 **Signing & Capabilities** 里选择你的 Team，并在开发者后台注册对应的 Bundle ID 与 App Group。改完若用方式 B，记得 `xcodegen generate` 同步。

---

## 5. 编译与安装

### 5a. 真机调试运行（推荐先用这种验证）

1. 用数据线连接并「信任」iPhone，开启开发者模式。
2. Xcode 顶部选中你的设备。
3. `Cmd + R` 构建并运行，首次需在 iPhone「设置 → 通用 → VPN与设备管理」信任你的证书。

### 5b. 生成未签名 IPA（之后用企业证书重签）

项目根目录已带脚本 `build-unsigned-ipa.sh`：

```sh
./build-unsigned-ipa.sh
# 产物：build/SDKShift-unsigned.ipa
```

脚本用 `CODE_SIGNING_ALLOWED=NO` 编译，再把 `.app` 打包成未签名 IPA。拿到后用**企业证书重签**再安装，例如：

- **Sideloadly**：选择证书与描述文件，拖入 IPA 重签安装；
- 或命令行 `codesign` + 重签工具，配上你的 In-House 描述文件（需包含 App Groups 能力）。

企业 IPA 可通过 MDM 或 `itms-services://` manifest 分发，安装后同样要在「VPN与设备管理」里信任企业证书。

---

## 6. 不接手机的本地检查（可选）

验证解析、迁移、本地化等逻辑，不写入真实系统：

```sh
swiftc -parse-as-library Sources/ShiftWorkspace.swift Tests/WorkspaceChecks.swift -o /tmp/sdkshift-workspace-checks
/tmp/sdkshift-workspace-checks
python3 Tests/check_localizations.py
```

---

## 7. App 内操作流程

1. **扫描**：打开「应用」页，默认列出全部应用；可筛选只看低于当前默认版本的条目。
2. **设置目标 SDK**：点应用卡片「自定义 SDK」，输入如 `27.3.1`（主版本 1–99，其余 0–99，两段自动补零），点「加入变更」。在底部「待处理」里复核每个应用的新旧版本。
3. **预检（不写入）**：执行「1. 预检，不写入」，查看完整报告，重点看**写权限**和**文件锁**结果，别只看完成标题。
4. **写入**：执行「2. 写入变更」并确认。
5. **完整重启 iPhone**：单独注销 SpringBoard 不保证生效，必须整机重启。
6. **验证**：逐一检查目标应用的内外屏、横竖屏表现。
7. **还原**：在符合条件的卡片点「还原」，审阅并写入还原队列，再次重启。

> 重新扫描会清空待处理队列；应用更新或数据库重建可能移除覆写；设置更高 SDK 标记不会新增 API，也不代表该版本已兼容。

---

## 8. 常见问题与限制

- **写入成功但界面没变**：数据库写入验证通过 ≠ 界面已刷新，必须完整重启；本项目没有可靠的免重启刷新方式。
- **解析失败/读不到应用**：`.csstore` 记录按设备 iOS 版本匹配布局（如 592/604 字节），版本不符会失败。
- **App Group 报错**：entitlements、`FDEngine.m`、开发者后台三处不一致导致，检查是否完全相同。
- **升级 iOS 后**：下次启动采用新系统版本作为默认值，不会自动改写已设置的应用或恢复记录；但覆写可能被系统更新移除，需重新检查。

---

## 9. 公开发布前的许可提醒

- `Sources/worse_query.*` 为 **GPL-3.0-or-later**，发布时须遵守该许可并保留原版权声明。
- 缓存引擎/早期界面来源于 [ForceDuoApp](https://github.com/34306/ForceDuoApp)，其快照未找到 LICENSE；注明来源不等于获得再分发授权。**公开仓库或分发前请先厘清授权**，必要时独立替换相关实现。
