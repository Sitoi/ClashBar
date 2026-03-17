## v0.2.0

![macOS](https://img.shields.io/badge/macOS-Supported-000000?style=flat-square&logo=apple) ![Version](https://img.shields.io/badge/Release-v0.2.0-10B981?style=flat-square) ![Core](https://img.shields.io/badge/Core-Mihomo-6366f1?style=flat-square)

> 本次更新主要聚焦在 **菜单栏交互稳定性与性能修复**：重点解决代理分组悬停时 CPU 异常飙高、Popover 悬停判定不稳、System 页面提示条布局跳动，以及 TUN 与系统代理状态在恢复场景下不同步的问题；同时继续优化活动数据缓存和界面细节，让整体菜单栏体验更顺滑。

### 📝 更新日志 (Changelog)

**✨ 新增功能 (New Features)**

- ![Feature](https://img.shields.io/badge/Feature-10B981?style=flat-square) **暂无内容**：当前版本未新增独立功能项，更新重点为稳定性、性能与交互体验修复。

**🚀 优化改进 (Improvements)**

- ![Optimize](https://img.shields.io/badge/Optimize-3B82F6?style=flat-square) **活动数据缓存**：为 Activity 页和菜单栏相关派生数据增加缓存与预计算，减少列表刷新和统计展示时的额外开销。
- ![Optimize](https://img.shields.io/badge/Optimize-3B82F6?style=flat-square) **实时连接状态处理**：整理实时连接与 WebSocket 数据流处理逻辑，降低 `AppState` 与页面刷新逻辑的耦合，提升 Activity、Proxy、Rules 等页面的刷新稳定性。
- ![Optimize](https://img.shields.io/badge/Optimize-3B82F6?style=flat-square) **菜单栏视觉打磨**：继续细化菜单栏界面的间距、标题区、Sparkline 和 System 页展示细节，整体观感更统一。

**🐞 修复问题 (Bug Fixes)**

- ![Fix](https://img.shields.io/badge/Fix-EF4444?style=flat-square) **代理分组悬停高占用**：修复鼠标悬停代理分组时可能触发 CPU 占用飙升的问题，显著减轻卡顿与发热。
- ![Fix](https://img.shields.io/badge/Fix-EF4444?style=flat-square) **Popover 悬停稳定性**：修复附着式 Popover 在鼠标移动过程中的悬停判定不稳定问题，减少误闪动和意外收起。
- ![Fix](https://img.shields.io/badge/Fix-EF4444?style=flat-square) **System 页布局跳动**：修复反馈提示条出现或消失时导致的 System 页面布局偏移问题。
- ![Fix](https://img.shields.io/badge/Fix-EF4444?style=flat-square) **TUN 状态同步**：修复持久化的 TUN 开关状态与真实运行状态可能不一致的问题，避免界面显示和实际状态脱节。
- ![Fix](https://img.shields.io/badge/Fix-EF4444?style=flat-square) **系统代理恢复竞态**：增强 Helper 恢复阶段的容错处理，减少系统代理状态恢复过程中的偶发异常。
- ![Fix](https://img.shields.io/badge/Fix-EF4444?style=flat-square) **Fallback 分组排序**：修复 Fallback 代理组在刷新后的排序不稳定问题，让列表顺序更可预期。

## v0.1.9

![macOS](https://img.shields.io/badge/macOS-Supported-000000?style=flat-square&logo=apple) ![Version](https://img.shields.io/badge/Release-v0.1.9-10B981?style=flat-square) ![Core](https://img.shields.io/badge/Core-Mihomo-6366f1?style=flat-square)

> 本次更新集中修正了 **状态栏显示稳定性**：速度文本改为模板图像渲染，减少频繁重绘；同时修复状态栏宽度与弹出面板高度在切换场景下容易抖动、跳变的问题，让菜单栏体验更稳。

### 📝 更新日志 (Changelog)

**✨ 新增功能 (New Features)**

- ![Feature](https://img.shields.io/badge/Feature-10B981?style=flat-square) **模板化速度文本渲染**：状态栏上下行速率文本改为缓存模板图像渲染，保留系统原生的高亮/变暗行为，同时减少文本逐帧绘制开销。

**🚀 优化改进 (Improvements)**

- ![Optimize](https://img.shields.io/badge/Optimize-3B82F6?style=flat-square) **状态栏渲染路径**：整理状态栏显示刷新与渲染辅助逻辑，宽度计算与运行态图标切换更直接，后续维护成本更低。
- ![Optimize](https://img.shields.io/badge/Optimize-3B82F6?style=flat-square) **Popover 尺寸跟随**：菜单弹出面板改为使用标准边界尺寸，并更及时响应高度变化，减少内容变化后的尺寸滞后。

**🐞 修复问题 (Bug Fixes)**

- ![Fix](https://img.shields.io/badge/Fix-EF4444?style=flat-square) **状态栏宽度抖动**：修复状态栏在图标/速率模式切换时宽度容易波动的问题，显示更稳定。
- ![Fix](https://img.shields.io/badge/Fix-EF4444?style=flat-square) **弹出面板跳变**：修复菜单栏弹出面板在不同屏幕参数和内容高度变化下尺寸不稳定的问题，避免打开后出现跳一下的体验。

## v0.1.8

![macOS](https://img.shields.io/badge/macOS-Supported-000000?style=flat-square&logo=apple) ![Version](https://img.shields.io/badge/Release-v0.1.8-10B981?style=flat-square) ![Core](https://img.shields.io/badge/Core-Mihomo-6366f1?style=flat-square)

> 本次更新集中在 **代理页面体验提升**：新增 Proxy Group 排序切换（延迟排序 / 原始顺序），重新设计了代理订阅行的信息展示；同时修复了多显示器下状态栏图标不跟随系统变暗的问题，并加固了 Helper XPC 认证安全性。

### 📝 更新日志 (Changelog)

**✨ 新增功能 (New Features)**

- ![Feature](https://img.shields.io/badge/Feature-10B981?style=flat-square) **代理组排序切换**：在 Proxy 页面工具栏新增排序切换，可在延迟排序与默认节点顺序之间切换，同时仍遵循隐藏不可用节点的过滤规则。
- ![Feature](https://img.shields.io/badge/Feature-10B981?style=flat-square) **状态栏运行状态图标**：更新品牌图标资源，状态栏图标区分运行（Running）与休眠（Sleeping）两种状态。

**🚀 优化改进 (Improvements)**

- ![Optimize](https://img.shields.io/badge/Optimize-3B82F6?style=flat-square) **订阅信息重设计**：重新设计代理订阅（Proxy Provider）行，直接展示更新时间、刷新状态、到期信息和用量进度，信息一目了然。
- ![Optimize](https://img.shields.io/badge/Optimize-3B82F6?style=flat-square) **Provider 状态精简**：移除 Provider 节点级别的延迟、测试、展开等冗余状态追踪，保持订阅行聚焦于摘要信息，减少不必要的内存占用。

**🐞 修复问题 (Bug Fixes)**

- ![Fix](https://img.shields.io/badge/Fix-EF4444?style=flat-square) **状态栏图标变暗**：为状态栏图标启用 `isTemplate` 模式，修复多显示器切换焦点时图标不跟随系统自动变暗的问题，行为与系统电池、Wi-Fi 图标保持一致。
- ![Fix](https://img.shields.io/badge/Fix-EF4444?style=flat-square) **Helper XPC 认证**：XPC 认证改为基于代码签名要求（Code Signing Requirement），替代原有的 PID 签名校验方式，提升安全性与可靠性。

---

## v0.1.7

![macOS](https://img.shields.io/badge/macOS-Supported-000000?style=flat-square&logo=apple) ![Version](https://img.shields.io/badge/Release-v0.1.7-10B981?style=flat-square) ![Core](https://img.shields.io/badge/Core-Mihomo-6366f1?style=flat-square)

> 本次更新重点补上了 **系统代理状态恢复** 这块一直该做但没做干净的事情：重启应用后不再莫名掉代理；同时顺手把 `System` 页快捷键和启动后的分组延迟探测补齐，让常用操作更顺手。

### 📝 更新日志 (Changelog)

**✨ 新增功能 (New Features)**

- ![Feature](https://img.shields.io/badge/Feature-10B981?style=flat-square) **系统页快捷键**：新增 `Command + ,` 快捷键，支持从菜单命令快速切换到 `System` 页面，更符合 macOS 用户习惯。

**🚀 优化改进 (Improvements)**

- ![Optimize](https://img.shields.io/badge/Optimize-3B82F6?style=flat-square) **启动延迟探测**：内核启动完成后会自动触发 Proxy Group 延迟测试，用户打开面板时能更快看到各组节点状态。
- ![Optimize](https://img.shields.io/badge/Optimize-3B82F6?style=flat-square) **退出清理流程**：应用退出时会主动清理系统代理，减少异常退出后系统仍残留无效代理状态的情况。

**🐞 修复问题 (Bug Fixes)**

- ![Fix](https://img.shields.io/badge/Fix-EF4444?style=flat-square) **系统代理恢复**：修复 ClashBar 重新启动后系统代理状态丢失的问题；如果退出前已开启代理，应用恢复运行后会自动按上次状态恢复。

## v0.1.6

![macOS](https://img.shields.io/badge/macOS-Supported-000000?style=flat-square&logo=apple) ![Version](https://img.shields.io/badge/Release-v0.1.6-10B981?style=flat-square) ![Core](https://img.shields.io/badge/Core-Mihomo-6366f1?style=flat-square)

> 本次更新重点把 **Mihomo 内核升级** 直接做进了菜单栏底部，运行中的用户无需再手动折腾；同时补齐了升级结果反馈、版本刷新与新版检测时机，减少“点了没反应”和版本信息滞后的问题。

### 📝 更新日志 (Changelog)

**✨ 新增功能 (New Features)**

- ![Feature](https://img.shields.io/badge/Feature-10B981?style=flat-square) **内核一键升级**：在菜单栏底部新增 Mihomo 内核升级入口，支持在运行中直接检查并执行升级操作。

**🚀 优化改进 (Improvements)**

- ![Optimize](https://img.shields.io/badge/Optimize-3B82F6?style=flat-square) **升级反馈**：为内核升级补充进行中、成功、已是最新版、失败等明确状态提示，并同步写入日志，减少黑盒体验。
- ![Optimize](https://img.shields.io/badge/Optimize-3B82F6?style=flat-square) **版本同步**：升级完成后自动刷新内核版本号，底部显示的 Mihomo 版本会尽快与实际运行版本保持一致。
- ![Optimize](https://img.shields.io/badge/Optimize-3B82F6?style=flat-square) **版本检查时机**：应用新版检测改为在面板展开时刷新，避免后台无效轮询，同时保证用户打开菜单时能看到最新版本提示。

**🐞 修复问题 (Bug Fixes)**

- ![Fix](https://img.shields.io/badge/Fix-EF4444?style=flat-square) **升级响应兼容性**：兼容 Mihomo `/upgrade` 接口的多种响应与错误文案，正确识别“已是最新版”场景，避免把正常结果误判为失败。
