# SDKShift for Duo

[English](README.md) | **简体中文**

通过覆写 LaunchServices 中记录的应用 SDK 版本标记，探索 iPhone Duo 的显示兼容性。快捷操作默认目标跟随当前设备的 iOS 版本（27.1 → 27.1.0；27.2.1 → 27.2.1），也可逐应用自定义 SDK 标记。本工具不会重新编译应用、升级 iOS，也不保证实现原生 Duo 布局。

> **应用修改后，请完整重启 iPhone。** 单独注销 SpringBoard 不能保证 SDK 相关服务和应用状态重新加载。数据库写入验证成功不等于界面已生效；本项目尚未验证可靠的免重启刷新方式。

> **能否生效取决于漏洞，而非签名。** 写入 LaunchServices 数据库依赖 `worse_query`（沙盒逃逸 PoC）。签名只决定应用能否安装和启动，不提供写入系统数据库的能力；写入能否成功取决于该漏洞在目标 iOS 版本上是否有效。

## 功能

- 三页界面：应用、记录、关于。变更审阅、预检和写入已合并到应用页；有待处理操作时才显示底部操作栏，展开数量可检查或移除条目。检查报告始终可从应用页工具栏打开。
- 每个应用可设置不同 SDK，包括已达到或高于当前默认版本的应用；逐应用添加修改或还原操作，在写入前审阅新旧版本。
- 输入 `主版本.次版本` 或 `主版本.次版本.修订版`，主版本范围 1–99，其余 0–99；两段版本自动补零。编辑器阻止无效输入及相同值提交，并提示降级。这些是格式范围，不代表对应 SDK 已发布或兼容。
- 不写入预检：检查候选数据库，报告写权限和文件锁结果。预检仍创建应用内临时文件并访问缓存，不是完全无副作用的离线检查。
- 原始 SDK 与上次写入值分开保存，支持早期 SDKShift 恢复记录迁移。
- 写入前复查 SDK 快照、串行访问引擎，最多保存 30 条本地操作记录。
- 使用设备内名称生成字母头像，不联网查询图标。
- **默认英文，支持简体中文、繁体中文、日语、韩语、西班牙语、法语、德语、越南语，共九种语言。** 在首页顶部的 **应用语言** 中切换，选择会保存并立即生效，不影响 SDK 设置或恢复记录。新增七种语言覆盖界面与操作提示，底层引擎错误暂时回退英文；简体中文另有引擎错误翻译。技术日志及已有报告快照保留原文，便于排查。

## 安装（预编译 IPA）

[Releases](https://github.com/beinglida/SDKShift-for-Duo/releases) 页面提供一个**未签名**的预编译 IPA。它刻意不签名，方便你用自己的证书签。

1. 从最新 release 下载 `SDKShift-unsigned.ipa`。
2. 用你自己的证书重签——企业证书，或通过 Sideloadly 等工具用个人/开发者账号签。**签名时启用 App Groups 能力，带上任意一个在你团队名下的 `group.*`。** 应用启动时会读取签名里携带的 App Group，因此**不需要改源码**。
3. 安装签名后的 IPA（企业分发用 MDM 或 `itms-services://` manifest；个人签名由签名工具自行安装）。
4. 在 iPhone 上「设置 → 通用 → VPN与设备管理」里信任该证书。
5. 打开应用，加入并写入一个变更，然后**完整重启 iPhone**。

若应用提示找不到可用的 App Group，说明签名里没有 App Groups 能力——重签时启用即可。描述文件（provisioning profile）也必须包含 App Groups 能力，只有证书是不够的。

## 从源码构建

需要 macOS + Xcode 27.2（iOS 27 SDK），最低部署版本 iOS 27.0。

**用 Xcode 跑到真机：** 打开 `SDKShift.xcodeproj`，在 Signing & Capabilities 选你的 Team，添加 App Groups 能力并填一个你自己的 `group.*`，连接并信任 iPhone，开启开发者模式，构建运行。

**生成未签名 IPA**（供后续重签和分发）：

```sh
./build-unsigned-ipa.sh      # 产物：build/SDKShift-unsigned.ipa
```

脚本在关闭代码签名的情况下编译 Release，再把 `.app` 打包成未签名 IPA。

### App Group 处理方式

App Group 标识**不再写死**。应用启动时从自己的代码签名里读取 `com.apple.security.application-groups`，取第一个 `group.*`，因此任何签名方都能用自己的 App Group，无需改源码或重新编译。`SDKShift.entitlements` 用 `group.$(PRODUCT_BUNDLE_IDENTIFIER)` 作为源码构建的默认值；重签工具会用它们自己的组覆盖。

工程已加入 AI 生成的原创深青色图标，以折叠双屏和双向箭头表达 SDK 兼容标记切换，没有沿用 ForceDuo 图标。

## 使用流程

1. 在「应用」页面扫描，默认显示所有应用；可打开筛选仅显示低于当前默认版本的条目。
2. 点击应用卡片的「自定义 SDK」，输入如 `27.3.1`，点击「加入变更」。再次打开编辑器可修改待处理目标；「使用 [版本号]」可填入系统对应的默认值。在「应用」页底部展开「待处理」，检查每个应用的新旧版本。更高的标记不会添加 API，也不代表对应 SDK 已兼容。
3. 执行「1. 预检，不写入」。检查完整报告，尤其是写权限和文件锁结果，不要仅依赖完成标题。
4. 执行「2. 写入变更」并确认，然后**完整重启手机**。
5. 检查目标应用的内外屏、横竖屏和操作表现。
6. 需要还原时，在符合条件的应用卡片点击「还原」，审阅并写入还原队列，然后再次重启。

重新扫描会清空待处理队列，避免继续应用旧快照。应用更新或数据库重建可能移除覆写。SDKShift 使用独立数据容器，不自动导入其他工具保存的原值；请先在原工具中还原之前的修改，再交由 SDKShift 管理。

应用页顶部显示**已修改 SDK**分组，下方为**其他应用**，同一应用不重复显示。已修改分组依据 SDKShift 保存的恢复记录：当前 SDK 必须与记录的写入值一致，且不同于原值；卡片显示原值 → 当前值。搜索同时作用于两个分组，「低于当前默认版本」筛选只作用于其他应用。仅加入队列尚未写入的应用不会被视为已修改；还原后会移出该分组。

## 架构

| 文件 | 职责 |
| --- | --- |
| `Sources/ShiftInterface.swift` | 卡片应用库及内嵌变更操作栏、操作记录、设置与语言选择 |
| `Sources/ShiftWorkspace.swift` | 变更请求、恢复点、持久化与旧数据迁移 |
| `Sources/CacheGateway.swift` | 串行引擎适配、版本复查、运行时本地化 |
| `Sources/FDEngine.m/.h` | 注明来源的数据库访问、解析和验证写入引擎；启动时从签名的 entitlements 解析 App Group |
| `Sources/worse_query.m/.h` | 第三方沙盒扩展实现 |
| `Sources/*.lproj` | 九种界面语言与本地化消息 |

应用层已重写；数据库引擎和 worse_query 仍是注明来源的依赖，不宣称全部独立原创。

## 为什么不将注销作为生效流程

引擎写入 `.csstore` 并回读验证，但没有实现经过验证的系统级缓存失效协议。SpringBoard、LaunchServices 和应用进程可能保留不同状态；桌面重新加载不等于所有使用方都刷新。

这不证明注销在任何情况下都无效，也不证明单独重启 `lsd` 就足够。完整重启仍是本项目支持的使用流程。worse_query 提供特定目录访问能力，不提供通用系统服务管理权限。

## 近期已测试应用

记录日期：**2026 年 11 月 15 日**。以下根据项目所有者提供的两张截图及测试清单整理。本次会话中报告的环境为 **iPhone Duo / iOS 27.2**，覆写目标为 **SDK 27.2.0**。

截图展示的是早期 ForceDuo 风格界面，并非 SDKShift 重构后的 UI。以下 13 个去重后的应用均显示 **SDK 27.2 / Forced**。这记录了用户报告的测试清单与截图中的覆写状态，不代表仅凭截图就确认每个应用重启后的布局、横屏表现及全部功能均正常。尚未提供应用版本号、构建号及逐应用显示效果结论。Mystro 在两张图中重复出现，表中仅列一次。

| 应用 | Bundle ID | 截图状态 |
| --- | --- | --- |
| Amazon | `com.amazon.Amazon` | SDK 27.2 · Forced |
| Apple Store | `com.apple.store.Jolly` | SDK 27.2 · Forced |
| Canvas | `com.instructure.icanvas` | SDK 27.2 · Forced |
| Chrome | `com.google.chrome.ios` | SDK 27.2 · Forced |
| eBay | `com.ebay.iphone` | SDK 27.2 · Forced |
| Honor of Kings（国际版） | `com.levelinfinite.sgameGlobal` | SDK 27.2 · Forced |
| Mystro | `MystroDriver.MystroDriverMobile` | SDK 27.2 · Forced |
| Poe | `com.quora.app.Experts` | SDK 27.2 · Forced |
| Uber Driver | `com.ubercab.UberPartner` | SDK 27.2 · Forced |
| X | `com.atebits.Tweetie2` | SDK 27.2 · Forced |
| 夸克 | `com.quark.browser` | SDK 27.2 · Forced |
| 抖音 | `com.ss.iphone.ugc.Aweme` | SDK 27.2 · Forced |
| 王者荣耀（中国版） | `com.tencent.smoba` | SDK 27.2 · Forced |

应用或系统更新后需重新检查覆写状态与显示效果。应用修改后请完整重启手机，再逐一验证内外屏及横竖屏表现。

### iOS 27.3 Beta 缓存扫描排查

本 fork 参考 [ForceDuoApp 1.2 的修复](https://github.com/34306/ForceDuoApp/commit/5b65200015f7ed0a0fdf34708bd857e4a34e1f80)，将原本从 inode 16 向上扫描的兜底逻辑改为：创建短暂的本地探测文件估算最新 inode，然后向下扫描，发现首个缓存后继续检查附近 inode。检查报告现在会区分扫描超时、完全找不到缓存、以及找到候选缓存但无法访问。

**注意：** 这只改善缓存定位和错误诊断，不代表 iOS 27.3 Beta 已通过真机验证，也不保证能够获取系统数据库读写权限。扫描应用或预检不等于已修改系统缓存；确认数据库可读取后，写入前仍需审阅原始 SDK 记录。SDKShift 无法自动恢复其他工具写错的原始 SDK 值。

## 验证与限制

此前实现曾在 iPhone Duo / iOS 27.2 上读取到 604 字节 Bundle 记录，解析出 400 个应用。早期 SDKShift 已完成签名、安装和启动。重写界面和双语版本通过本地编译，但不代表所有目标应用效果或所有屏幕尺寸都已完成视觉验证。

回归检查覆盖版本解析与范围、逐应用目标、降级、预检、连续修改、失败后的恢复点保留、旧数据迁移、还原、SDK 漂移、忙碌状态保护、持久化及重新扫描清空队列。启动时不会自动写入 SDK。卸载前请保存恢复数据。

在 macOS 上运行以下检查，不访问手机或写入真实系统缓存：

```sh
swiftc -parse-as-library Sources/ShiftWorkspace.swift Tests/WorkspaceChecks.swift -o /tmp/sdkshift-workspace-checks
/tmp/sdkshift-workspace-checks
python3 Tests/check_localizations.py
```

默认值在本机读取 `ProcessInfo.operatingSystemVersion`，包含修订版本号，不查询网上最新 SDK，也不取编译工具的 SDK 版本。iOS 更新后，下次启动本应用时采用新系统版本；不会自动改写之前设置过的应用 SDK 或恢复记录。

## 来源与许可

- [ForceDuoApp](https://github.com/34306/ForceDuoApp)，基准提交 `65e8b68`：缓存引擎和早期界面的来源。下载快照中未找到 LICENSE 文件。注明来源不等同于获得再分发授权；应厘清授权，或独立替换相关实现。
- [worse_query](https://github.com/forcequitOS/worse_query)：随附源码声明 GPL-3.0-or-later，原版权声明已保留，任何分发都须遵守该许可。
- [社区 SDK 实验](https://www.reddit.com/r/sideloaded/comments/1xvhqh4/release_experimental_duo_sdk_remove_the_black/)：思路参考，不是通用兼容性保证。

本项目为衍生原型，以未签名 IPA 形式分发供个人重签。若你再分发，请遵守 worse_query 的 GPL-3.0 条款，并注意 ForceDuo 衍生引擎尚未厘清的授权问题。
