## v0.2.2

![macOS](https://img.shields.io/badge/macOS-Supported-000000?style=flat-square&logo=apple) ![Version](https://img.shields.io/badge/Release-v0.2.2-10B981?style=flat-square) ![Core](https://img.shields.io/badge/Core-Mihomo-6366f1?style=flat-square)

> 本次更新主要围绕 **远程配置订阅、Proxy 节点延迟探测与远程目标状态一致性** 展开：现在可以把远程配置当作订阅来管理，支持自动更新、手动刷新、复制订阅链接与删除清理；Proxy 页面补上节点级延迟测试和更明确的终端代理命令目标；同时重做远程机器管理面板，并修复远程切换后的速率显示、离线切换保护和核心模式持久化等问题。

### 📝 更新日志 (Changelog)

**✨ 新增功能 (New Features)**

- ![Feature](https://img.shields.io/badge/Feature-10B981?style=flat-square) **远程订阅配置管理**：新增远程配置订阅元数据管理，导入 URL 时可设置自动更新与更新间隔，并支持按项刷新、批量刷新、复制订阅链接和删除时同步清理订阅信息。
- ![Feature](https://img.shields.io/badge/Feature-10B981?style=flat-square) **节点级延迟测试**：在 Proxy Group 的节点列表中新增单节点延迟测试，切换前可以直接比较具体节点的实时延迟表现。

**🚀 优化改进 (Improvements)**

- ![Optimize](https://img.shields.io/badge/Optimize-3B82F6?style=flat-square) **远程机器管理器重做**：重构远程机器管理面板与编辑器，补上本地/远程分区、连接预览和更直接的切换反馈，管理多控制端时更清晰。
- ![Optimize](https://img.shields.io/badge/Optimize-3B82F6?style=flat-square) **远程目标状态可视化**：Header、配置切换菜单和 System Proxy 行会更明确地展示当前本地/远程目标、订阅刷新状态以及下次自动更新时间，减少跨目标操作时的混淆。
- ![Optimize](https://img.shields.io/badge/Optimize-3B82F6?style=flat-square) **终端代理命令导出**：复制终端代理命令时可分别选择本地 `127.0.0.1` 或当前控制端地址；在 `allow-lan` 打开且控制器绑定到 `0.0.0.0` / `localhost` 时，也会尽量解析当前设备 IPv4，导出的命令更可用。

**🐞 修复问题 (Bug Fixes)**

- ![Fix](https://img.shields.io/badge/Fix-EF4444?style=flat-square) **远程切换速率显示**：修复本地/远程目标切换后状态栏速率文本可能不更新的问题，避免远程目标实际可用但界面仍显示已停止。
- ![Fix](https://img.shields.io/badge/Fix-EF4444?style=flat-square) **离线远程切换保护**：修复远程机器离线时仍可能被切换或导出错误代理地址的问题，降低误操作风险。
- ![Fix](https://img.shields.io/badge/Fix-EF4444?style=flat-square) **核心模式持久化**：修复 Settings 快照未保存当前 Core Mode 的问题，减少重启、切换配置或同步后模式状态不一致的情况。

## v0.2.1

![macOS](https://img.shields.io/badge/macOS-Supported-000000?style=flat-square&logo=apple) ![Version](https://img.shields.io/badge/Release-v0.2.1-10B981?style=flat-square) ![Core](https://img.shields.io/badge/Core-Mihomo-6366f1?style=flat-square)

> 本次更新主要围绕 **远程机器管理、菜单栏交互重构与系统代理恢复链路** 展开：新增远程控制端管理与本地/远程快速切换，Proxy、Rules、Connections、Logs、System 等页面会围绕当前目标自动切换；同时重做顶部模式/标签分段控件、代理详情与连接列表排版，并加强系统代理 Helper 的健康检查、恢复与提示，让多端点场景下的操作更清晰、状态更可信。

### 📝 更新日志 (Changelog)

**✨ 新增功能 (New Features)**

- ![Feature](https://img.shields.io/badge/Feature-10B981?style=flat-square) **远程机器管理**：在菜单栏中新增远程机器管理面板，支持添加、编辑、删除远程控制端，并可在本地 Mihomo 与远程机器之间快速切换。
- ![Feature](https://img.shields.io/badge/Feature-10B981?style=flat-square) **远程目标感知视图**：顶部 Header 会显示当前连接目标与连通状态，Proxy、Logs、Connections、System 页面也会围绕当前目标自动刷新，多控制端场景下不容易混淆。
- ![Feature](https://img.shields.io/badge/Feature-10B981?style=flat-square) **远程场景只读保护**：连接远程机器时，涉及本地应用或仅应作用于本地内核的设置会明确标注为只读或本地生效，减少误操作风险。

**🚀 优化改进 (Improvements)**

- ![Optimize](https://img.shields.io/badge/Optimize-3B82F6?style=flat-square) **菜单栏分段控件重做**：顶部模式切换与标签栏改为自定义分段控件，选中态、悬停反馈和整体层次更统一，菜单栏交互更贴近原生体验。
- ![Optimize](https://img.shields.io/badge/Optimize-3B82F6?style=flat-square) **代理与概览展示**：重新整理 Proxy 页的流量概览、快捷操作、Provider/Group 行信息和节点类型展示，查看节点状态、切换配置与复制代理命令时更直观。
- ![Optimize](https://img.shields.io/badge/Optimize-3B82F6?style=flat-square) **连接与日志信息密度**：Connections 页补充过滤、排序、链路与流量摘要展示；Logs、Rules、System 页的列表与卡片布局也同步细化，在固定宽度菜单栏里能承载更多信息。
- ![Optimize](https://img.shields.io/badge/Optimize-3B82F6?style=flat-square) **系统代理状态可视化**：系统代理入口现在会同时展示后台项目授权、Helper 进程与当前生效地址等状态，定位问题和确认代理指向都更直接。
- ![Optimize](https://img.shields.io/badge/Optimize-3B82F6?style=flat-square) **工程结构与构建链路**：将应用进一步整理为 App / Session / Domain / Infrastructure / Features 等分层，并补充 beta DMG 预发布流程、二进制瘦身和打包优化，为后续迭代与分发打下更稳的基础。

**🐞 修复问题 (Bug Fixes)**

- ![Fix](https://img.shields.io/badge/Fix-EF4444?style=flat-square) **系统代理恢复链路**：修复系统代理在启动、唤醒或切换场景下可能出现“开关已开但系统未生效”的问题，必要时会自动补齐配置并刷新真实状态。
- ![Fix](https://img.shields.io/badge/Fix-EF4444?style=flat-square) **Helper 自恢复与预热**：修复系统代理 Helper 可能未及时拉起、注册状态失效或连接超时的问题，应用激活时会主动预热，并在连接失败后尝试恢复。
- ![Fix](https://img.shields.io/badge/Fix-EF4444?style=flat-square) **授权与安装提示**：针对未放入“应用程序”目录、后台项目未允许、Helper 未注册或签名异常等场景补充更明确的错误提示，减少“打不开系统代理但不知道原因”的情况。
- ![Fix](https://img.shields.io/badge/Fix-EF4444?style=flat-square) **远程切换状态一致性**：修复本地/远程目标切换时系统代理、快捷操作和页面状态可能不同步的问题，避免显示目标与实际控制端不一致。
- ![Fix](https://img.shields.io/badge/Fix-EF4444?style=flat-square) **远程场景快捷操作适配**：修复复制终端代理命令、TUN/System Proxy 等快捷操作在远程使用场景下的适配问题，降低误用本地配置的风险。

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
