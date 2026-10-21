# Validation / 验收记录

Initial local validation: 2026-10-21 (Asia/Shanghai). Subsequent GitHub-hosted validation is recorded in the follow-up at the end.

初次本地验证日期：2026-10-21（亚洲/上海）。后续 GitHub 托管验证结果记录在文末补充部分。

## Environment / 环境

- Apple Silicon ARM64 Mac, macOS 27.
- Xcode 27.1 (27A9275), macOS SDK 27.0, Swift 6.4 compiler in Swift 5 language mode with complete concurrency checking.
- Deployment target: macOS 14.0; build architecture: arm64.
- Zero third-party application dependencies.

## Completed / 已完成

| Check / 检查 | Actual result / 实际结果 |
| --- | --- |
| Xcode Debug tests / Debug 测试 | **7 tests, 0 failures**; `build/Tests-Localization.xcresult`, `build/test-localization.log` |
| Release build / Release 构建 | **BUILD SUCCEEDED**; `build/package-delivery.log` |
| Selected-folder boundary / 目录边界 | Nested apps discovered; unselected sibling, hidden directory, symlink and app-internal bundles excluded by test / 已验证嵌套识别，不扫描未选择的同级目录、隐藏目录、符号链接和应用内部 |
| Metadata and native icons / 元数据与图标 | DisplayName → BundleName → filename priority, identifier/version and persisted PNG data tested / 已测试名称优先级、标识符、版本及 PNG 持久化 |
| Offline retention / 离线保留 | Volume identity mismatch simulated; record ID and icon retained, availability false; restoration returns same record to available / 已模拟卷身份不匹配，记录及图标保留，恢复后同一记录可用 |
| Connected deletion / 在线删除 | Complete refresh removes deleted app and prunes its orphan icon / 完整刷新移除已删除应用记录及无引用图标 |
| JSON integrity / JSON 完整性 | Atomic round trip; corrupt data throws and remains untouched / 保存恢复通过；损坏数据报错并保留 |
| Search and deduplication / 搜索与去重 | Case-insensitive search and overlapping folder display tested; removing one selected root retains the other / 已测试不区分大小写搜索、重叠目录去重及移除单个目录 |
| Language preference / 语言偏好 | Ordered English/Chinese selection, unsupported fallback and Chinese variants tested / 已测试偏好顺序、未支持语言回退及中文变体 |
| Compiled localization / 编译本地化 | English and Simplified Chinese `.lproj` resources read from built app in XCTest; 56 catalog keys audited for both languages / 测试读取已编译资源，56 个资源键均有两种语言 |
| Native folder picker / 原生文件夹选择 | Actual UI selected only `build/UIFixture/Games`; one test app appeared / 实际通过界面选择隔离测试目录，识别一个测试应用 |
| Double-click launch / 双击启动 | Native ARM64 test-only app launched through the actual grid and NSWorkspace; it wrote a launch marker. No user game was used / 实际网格双击启动原生 ARM64 测试应用并写入启动标记，未使用用户游戏 |
| Context menu and info / 右键与信息 | Actual Launch / Show in Finder / Get Info menu observed; info sheet showed correct name, identifier, version, path and volume / 已观察菜单，信息窗口元数据正确 |
| Folder removal / 文件夹移除 | Actual confirmation and removal returned library to empty; test app remained on disk / 实际移除后游戏库为空，测试应用仍在磁盘上 |
| English UI / 英文界面 | Main window, settings, info and folder picker checked; full-size real empty-window screenshot saved / 已检查主界面、设置、信息及选择器，并保存真实英文截图 |
| Chinese UI / 中文界面 | Launched with temporary `(zh-Hant-TW, en)` arguments; main window, native File/Edit/View/Window/Help menus, Settings and folder dialog all used Simplified Chinese / 通过临时参数验证繁体中文偏好下，界面及原生菜单、设置、选择器均为简体中文 |
| Final DMG / 最终镜像 | `hdiutil verify` passed; mounted read-only and inspected: LiteShelf.app, Applications → /Applications, UNNOTARIZED.txt / 校验通过，已只读挂载检查内容 |
| Architecture/version/signature / 架构版本签名 | Mounted app reports arm64, version 1.0.0; `codesign --verify --deep --strict` passes with ad-hoc signature / 已检查 ARM64、1.0.0 版本及临时签名 |
| SHA-256 / 校验值 | Generated checksum matches the DMG / 校验文件与镜像一致 |
| Failure handling / 失败处理 | Invalid semantic version and partial signing configuration both fail before building / 非法版本及不完整签名配置在构建前失败 |
| Scripts/workflows / 脚本工作流 | `bash -n` passes; both workflow YAML files parse; release writes restricted to publish job, dispatch cannot publish, draft protects partial uploads / Shell 语法与 YAML 解析通过，已检查权限与发布条件 |
| Quiet/offline scope / 安静离线 | Source has no network client, store integrations, telemetry, audio module, music or sound-effect assets / 源码无网络客户端、平台集成、遥测、音频模块或声音素材 |

## Delivery artifacts / 交付产物

- `build/delivery/LiteShelf.app` — copied from the verified final DMG; ad-hoc signed, **not notarized**.
- `build/delivery/LiteShelf-1.0.0-macOS-arm64-unnotarized.dmg`.
- `build/delivery/LiteShelf-1.0.0-macOS-arm64-unnotarized.dmg.sha256`.

Build artifacts, XCTest reports and disposable test fixtures are excluded by `.gitignore`. Earlier experimental output directories under `build/` are not the delivery package.

构建产物、测试报告与隔离测试文件均由 `.gitignore` 排除；`build/` 下早期实验目录不是最终交付包。

## Not actually verified / 尚未实测

- Physical Samsung T7 unplug/replug, USB interruptions, renamed mount points and long filesystem stalls. Automated offline recovery uses simulated identity mismatch, not a physical disconnection.
- Launching the user's actual games from the T7, game compatibility, signatures or game-specific Gatekeeper prompts. The actual launch smoke test used a disposable native app on local storage.
- macOS 14–26 runtime behavior, a separate M1 machine, large real game libraries, or measured startup/CPU/memory benchmarks. macOS 14 is the deployment target, not a claim of testing every supported OS.
- Real Developer ID signing, Apple notary submission/stapling, and first launch of a browser-downloaded quarantined DMG. No certificate or Apple credentials were provided. The delivered package must not be described as notarized.
- Manual workflow dispatch remains untested. Hosted CI and tag-triggered publication are now verified; see the follow-up below.
- Full visual QA for dark mode and every error/permission state. Chinese controls and menus were verified through the real UI; background-window thumbnail captures were discarded, so a publishable Chinese screenshot remains to be added.

尚未验证：真实 T7 拔插及挂载路径变化、用户实际游戏、其他系统版本与独立 M1 设备、大规模性能、真实 Developer ID／Apple 公证及下载隔离行为、手动触发工作流、完整深色与异常状态视觉验收。中文界面和原生菜单已实际检查，但丢弃了后台缩略截图，尚待补充可发布的中文截图。GitHub 托管 CI、Tag 发布及资产上传已完成后续验证，见下文。

## Local diagnostic notes / 本地诊断说明

The first sandboxed build could not start SwiftUI compiler plugins. Approved Xcode invocations outside that sandbox built and tested successfully. The compiler reported no remaining Swift source warnings in the final build; Xcode emitted a benign AppIntents extraction notice because this app has no AppIntents dependency. The host also logged unrelated system Shortcut/linkd connection diagnostics while XCTest passed. macOS 27 warns that `hdiutil create` is deprecated; it still successfully produced and verified the DMG, and is retained for compatibility with older build hosts.

初次受限构建无法启动 SwiftUI 编译插件，使用获准的 Xcode 调用后构建测试通过。最终构建无 Swift 源码警告；无 AppIntents 依赖的元数据提取提示及测试时的系统 linkd 日志不影响结果。本地最初可使用旧 `hdiutil create` 命令；托管环境的后续修复见下文。

## Hosted release follow-up / 托管发布补充验证

The v1.0.0 workflow passed tests and compilation but failed in the deprecated `hdiutil create` folder-image entry point with ENOENT. Explicit HFS+ alone did not fix the hosted failure. Version 1.0.1 uses macOS 27's supported `diskutil image create from` command, while older hosts retain the explicit HFS+ path. The local 1.0.1 DMG passed checksum verification and read-only mount checks for its app signature, version and Applications symlink.

- [Hosted CI](https://github.com/ohxiaoguang/liteshelf/actions/runs/39629629307): tests, Release build and DMG smoke test passed.
- [v1.0.1 Release workflow](https://github.com/ohxiaoguang/liteshelf/actions/runs/39630153835): both package and publish jobs passed, including asset upload and checksum verification.
- [v1.0.1 download](https://github.com/ohxiaoguang/liteshelf/releases/tag/v1.0.1): explicitly marked as an **unnotarized prerelease**. No Developer ID or Apple notarization is claimed. The failed v1.0.0 tag was preserved.

v1.0.0 在测试与编译通过后，于旧 `hdiutil create` 目录镜像入口报 ENOENT。仅指定 HFS+ 未能修复托管环境问题。v1.0.1 在 macOS 27 改用 `diskutil image create from`，旧系统保留显式 HFS+ 路径；本地镜像已完成校验与挂载检查。上述 GitHub CI 和 Release 的打包、上传、校验及发布任务均已通过。下载包明确标为未公证预发布版，原失败标签 v1.0.0 保留不变。
