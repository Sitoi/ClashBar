## v0.3.2

![macOS](https://img.shields.io/badge/macOS-Supported-000000?style=flat-square&logo=apple) ![Version](https://img.shields.io/badge/Release-v0.3.2-10B981?style=flat-square) ![Core](https://img.shields.io/badge/Core-Mihomo-6366f1?style=flat-square)

> 本次更新集中在 **延迟趋势可视化与官方文档站上线**：节点延迟从「单次结果」升级为保留最近 4 次样本，代理组列表与节点弹窗以信号条形式展示近期趋势；本地测速与 API/提供者历史会合并保留，刷新后不再轻易丢掉刚测出的结果。同时新增完整的 ClashBar 文档站（快速开始、功能总览、排障等），并重写 README 入口与站内链接。

### 📝 更新日志 (Changelog)

**✨ 新增功能 (New Features)**

- ![Feature](https://img.shields.io/badge/Feature-10B981?style=flat-square) **延迟趋势信号条**：代理组当前节点行与节点弹窗的延迟展示由单色块改为最多 4 根信号条，按时间对齐最近若干次延迟样本并着色；最新一次延迟仍以等宽数字显示，超时继续显示「超时」文案而非 0。
- ![Feature](https://img.shields.io/badge/Feature-10B981?style=flat-square) **官方文档站**：新增基于 Fumadocs 的文档站点，覆盖快速开始（含 Core / 无 Core）、配置与订阅、日常使用、系统代理与 TUN、SSID 策略、远程机器、设置维护、常见问题与关于页；README 同步指向 [clashbar.sitoi.cn](https://clashbar.sitoi.cn)。

**🚀 优化改进 (Improvements)**

- ![Optimize](https://img.shields.io/badge/Optimize-3B82F6?style=flat-square) **延迟样本链路重构**：接口与模型由「仅最新延迟」改为最近 4 次样本序列；组测速 / 单节点测速写入同一套样本，并与 Mihomo API 返回的 history 合并，避免面板刷新后本地测量结果被覆盖。
- ![Optimize](https://img.shields.io/badge/Optimize-3B82F6?style=flat-square) **提供者与嵌套组回填**：解析代理提供者节点的类型与延迟历史，补充展示用类型信息；延迟查询沿选择链回退到实际叶子节点样本，嵌套代理组展示更准确。
- ![Optimize](https://img.shields.io/badge/Optimize-3B82F6?style=flat-square) **文档入口与链接维护**：精简主 README 安装与上手说明，统一官网与 Releases 链接；文档站内链改为 `/docs/*` 绝对路径，避免无尾斜杠路由下相对链接失效。

---

## v0.3.1

![macOS](https://img.shields.io/badge/macOS-Supported-000000?style=flat-square&logo=apple) ![Version](https://img.shields.io/badge/Release-v0.3.1-10B981?style=flat-square) ![Core](https://img.shields.io/badge/Core-Mihomo-6366f1?style=flat-square)

> 本次更新集中在 **代理组图标展示与长期运行稳定性**：代理组现在可展示 Mihomo 配置返回的远程图标，并通过内存与磁盘缓存减少重复下载；同时重构配置文件监听、网络恢复、远程主机探测、日志写入与菜单栏状态刷新，提升配置编辑、网络切换和应用退出等场景下的可靠性与响应效率。

### 📝 更新日志 (Changelog)

**✨ 新增功能 (New Features)**

- ![Feature](https://img.shields.io/badge/Feature-10B981?style=flat-square) **代理组远程图标**：支持读取并展示 Mihomo 代理组返回的图标地址，在代理组列表和节点弹窗标题中呈现对应图标；图标采用内存与磁盘双层缓存，并限制单文件大小、缓存总量与文件数量，减少重复请求和长期磁盘占用。

**🚀 优化改进 (Improvements)**

- ![Optimize](https://img.shields.io/badge/Optimize-3B82F6?style=flat-square) **配置文件监听升级**：使用文件系统事件监听配置目录与当前选中的 YAML 文件，替代持续轮询；新增、删除、重命名及直接编辑配置后可及时刷新列表，并仅在当前配置实际变化时重启本地内核。
- ![Optimize](https://img.shields.io/badge/Optimize-3B82F6?style=flat-square) **网络恢复流程简化**：网络状态监控改为始终启用，断网时自动暂停内核与轮询、网络恢复后自动继续运行，并移除不再需要的「断网停核」开关，减少状态分支和恢复失败风险。
- ![Optimize](https://img.shields.io/badge/Optimize-3B82F6?style=flat-square) **菜单栏刷新性能优化**：拆分代理、流量、日志与状态栏数据的观察范围，仅在数据真正变化时触发对应界面刷新，降低实时流量、日志和代理状态更新造成的无关重绘。
- ![Optimize](https://img.shields.io/badge/Optimize-3B82F6?style=flat-square) **远程主机连接检测优化**：复用网络会话并统一管理连接探测任务，新的检查会取消旧请求，避免过期结果覆盖当前状态；删除或修改远程主机时也会同步清理相关任务。
- ![Optimize](https://img.shields.io/badge/Optimize-3B82F6?style=flat-square) **应用生命周期与日志处理增强**：统一应用依赖和后台任务的启动、取消流程，退出前等待 ClashBar 与 Mihomo 日志写入完成，并保持日志轮转顺序，减少任务残留与日志丢失。

**🐞 修复问题 (Bug Fixes)**

- ![Fix](https://img.shields.io/badge/Fix-EF4444?style=flat-square) **修复直接编辑配置未被发现的问题**：补充对当前配置文件本身的监听，可识别编辑器原地写入以及原子替换文件等保存方式，避免修改后配置列表或内核未刷新。
- ![Fix](https://img.shields.io/badge/Fix-EF4444?style=flat-square) **修复远程图标缓存异常**：合并同一地址的并发下载，校验 HTTP 状态与图片数据，并使用原子写入和缓存清理，避免无效响应、损坏文件或重复请求影响图标显示。
- ![Fix](https://img.shields.io/badge/Fix-EF4444?style=flat-square) **修复远程连接状态被旧请求覆盖的问题**：为探测任务增加取消与代次校验，防止慢请求在目标切换、配置修改或主机删除后写回过期状态。
- ![Fix](https://img.shields.io/badge/Fix-EF4444?style=flat-square) **修复版本信息缺失时的请求标识**：无法读取 Mihomo 版本时使用默认版本作为 User-Agent 回退值，不再发送包含 `unknown` 的请求标识，提高远程配置请求兼容性。

---

## v0.3.0

![macOS](https://img.shields.io/badge/macOS-Supported-000000?style=flat-square&logo=apple) ![Version](https://img.shields.io/badge/Release-v0.3.0-10B981?style=flat-square) ![Core](https://img.shields.io/badge/Core-Mihomo-6366f1?style=flat-square)

> 本次更新集中在 **Geo 数据库一键更新与延迟显示、菜单栏交互细节打磨**：System 维护区新增「更新 Geo 数据库」按钮，内核运行时可直接调用 mihomo `/upgrade/geo` 接口刷新 GeoIP / GeoSite 数据，并带进行中 / 成功 / 失败状态反馈与日志，无需重启内核或手动替换数据库文件；代理组路由行与节点弹窗的延迟徽章改为「迷你色块 + 等宽数字」呈现，纵向对比更整齐、可读性更好，超时节点直接显示「超时」文案而不再展示无意义的 0；顶部品牌图标也变为可点击入口，一键打开项目主页。

### 📝 更新日志 (Changelog)

**✨ 新增功能 (New Features)**

- ![Feature](https://img.shields.io/badge/Feature-10B981?style=flat-square) **Geo 数据库一键更新**：在 System 设置页「系统维护」区域新增「更新 Geo 数据库」按钮，内核运行时可直接触发 mihomo `/upgrade/geo` 接口刷新 GeoIP / GeoSite 数据库；更新过程中按钮展示进行中状态，完成后给出成功 / 失败反馈并写入日志，约 4 秒后自动恢复，无需重启内核或手动替换数据库文件。
- ![Feature](https://img.shields.io/badge/Feature-10B981?style=flat-square) **点击顶部图标访问项目主页**：菜单栏顶部的 ClashBar 品牌图标改为可点击入口，单击即可在浏览器打开项目 GitHub 主页，并补齐悬停提示与无障碍标签。

**🚀 优化改进 (Improvements)**

- ![Optimize](https://img.shields.io/badge/Optimize-3B82F6?style=flat-square) **延迟徽章视觉重做**：代理组路由行与代理组节点弹窗的延迟显示统一改为「迷你色块 + 等宽数字」徽章，色块按延迟高低着色、数字使用等宽字体，多节点纵向对比时更整齐易读；同时移除组路由行末尾冗余的箭头图标并微调列宽，为延迟列留出更多空间。
- ![Optimize](https://img.shields.io/badge/Optimize-3B82F6?style=flat-square) **超时延迟显示文案而非 0**：延迟徽章在节点超时（延迟为 0）时直接显示「超时 / Timeout」文案，不再展示无意义的「0」，节点状态更直观。

---

## v0.2.9

![macOS](https://img.shields.io/badge/macOS-Supported-000000?style=flat-square&logo=apple) ![Version](https://img.shields.io/badge/Release-v0.2.9-10B981?style=flat-square) ![Core](https://img.shields.io/badge/Core-Mihomo-6366f1?style=flat-square)

> 本次更新集中在 **规则页面的筛选检索体验与菜单栏快捷键重构**：分流（Rules）页面新增按类型 / 策略筛选、关键字搜索与按策略分组折叠展示，分组状态本地持久化，规则数量再多也能快速定位；菜单栏命令菜单整合为统一的「快捷操作」菜单，把系统代理、TUN、复制代理命令、重载配置等常用动作集中并补齐快捷键。同时把规则保留上限大幅提升以适配大型规则集，并修复状态栏 M/s 量级速率文本被截断的问题。

### 📝 更新日志 (Changelog)

**✨ 新增功能 (New Features)**

- ![Feature](https://img.shields.io/badge/Feature-10B981?style=flat-square) **规则筛选、搜索与分组**：分流页面新增类型（域名 / IP / 规则集 / 其他）与策略 chip 筛选、关键字搜索，类型 chip 实时显示命中计数；支持按策略分组折叠展示，分组开关状态本地持久化，规则较多时能更快定位目标规则。
- ![Feature](https://img.shields.io/badge/Feature-10B981?style=flat-square) **菜单栏快捷操作菜单**：将原有 Core / Actions 命令菜单整合为统一的「快捷操作」菜单，集中系统代理开关、TUN 模式开关、复制本地 / 当前控制端代理命令、重新加载配置等常用动作，并补齐 `⌘S` / `⌘E` / `⌘C` / `⌘⌥C` / `⌘R` 等快捷键。

**🚀 优化改进 (Improvements)**

- ![Optimize](https://img.shields.io/badge/Optimize-3B82F6?style=flat-square) **规则保留上限提升**：规则保留上限从 100 条提升至 20,000 条（等效无限制），适配大型规则集；该上限仅用于防止异常配置撑爆内存。
- ![Optimize](https://img.shields.io/badge/Optimize-3B82F6?style=flat-square) **筛选组件复用**：提取共享的筛选 chip 组件，日志页改为复用同一实现，筛选交互在规则页与日志页保持一致。

**🐞 修复问题 (Bug Fixes)**

- ![Fix](https://img.shields.io/badge/Fix-EF4444?style=flat-square) **状态栏速率文本截断**：修复状态栏在 M/s 量级速率下文本被截断的问题，将速率显示宽度从 38 调整为 43。

---

## v0.2.8

![macOS](https://img.shields.io/badge/macOS-Supported-000000?style=flat-square&logo=apple) ![Version](https://img.shields.io/badge/Release-v0.2.8-10B981?style=flat-square) ![Core](https://img.shields.io/badge/Core-Mihomo-6366f1?style=flat-square)

> 本次更新集中在 **日志文件体积治理、软链接配置的完整支持、配置校验报错体验与 UI 主题统一**：磁盘日志改为基于大小的滚动归档（单文件 10MB、保留 5 份），彻底告别无限膨胀；软链接配置现在能正确出现在列表中、用自身目录作为内核工作目录并参与外部改动检测；配置校验失败弹窗支持滚动查看长报错、一键复制详情，并针对 GEO 相关错误给出排查提示；同时把全局 UI 收敛到统一主题常量与系统原生配色。

### 📝 更新日志 (Changelog)

**✨ 新增功能 (New Features)**

- ![Feature](https://img.shields.io/badge/Feature-10B981?style=flat-square) **配置校验错误可滚动查看与复制**：配置校验失败弹窗改为可滚动视图，支持完整查看超长错误信息并一键“复制详情”，便于反馈问题；同时针对 GEO 数据库等常见配置错误补充了智能排查提示。

**🚀 优化改进 (Improvements)**

- ![Optimize](https://img.shields.io/badge/Optimize-3B82F6?style=flat-square) **日志策略简化**：移除可配置的“最大日志条目数”设置，应用内 Logs 面板改用固定 5,000 条视窗；磁盘日志体积统一交由基于大小的滚动归档管理，配置项更精简。
- ![Optimize](https://img.shields.io/badge/Optimize-3B82F6?style=flat-square) **UI 主题统一**：将菜单栏界面收敛到统一的主题常量与布局 token，使用系统原生配色替代自定义主题色，字号对齐 macOS HIG，整体观感更一致、维护成本更低。

**🐞 修复问题 (Bug Fixes)**

- ![Fix](https://img.shields.io/badge/Fix-EF4444?style=flat-square) **日志文件无限膨胀** (#78)：修复磁盘日志文件持续增长无上限的问题；现在采用基于大小的滚动归档（单文件超过 10MB 即滚动，最多保留 5 份历史），避免日志占满磁盘。
- ![Fix](https://img.shields.io/badge/Fix-EF4444?style=flat-square) **软链接配置处理修正**：修复软链接配置文件不出现在配置列表、内核工作目录被错误指向链接目标父目录、以及外部编辑无法触发变更检测的问题；现在按解析后的目标类型列出配置，并以配置自身所在目录作为工作目录。

---

## v0.2.7

![macOS](https://img.shields.io/badge/macOS-Supported-000000?style=flat-square&logo=apple) ![Version](https://img.shields.io/badge/Release-v0.2.7-10B981?style=flat-square) ![Core](https://img.shields.io/badge/Core-Mihomo-6366f1?style=flat-square)

> 本次更新集中在 **日志管理、订阅配置验证、配置文件软链接支持与 macOS 26.5.1 兼容性修复**：新增可配置的日志容量设置，默认无限制，用户可根据需要选择 1K 到 50K 条限制；订阅更新现在会验证配置内容，拒绝过期提示等非法内容，避免内核崩溃和日志爆炸；配置目录支持软链接指向外部配置文件，方便跨设备同步；同时修复 macOS 26.5.1+ 菜单栏图标不可见的问题，并优化菜单栏显示逻辑。

### 📝 更新日志 (Changelog)

**✨ 新增功能 (New Features)**

- ![Feature](https://img.shields.io/badge/Feature-10B981?style=flat-square) **可配置的日志容量**：在 System 设置页面新增"最大日志条目数"选项，默认无限制，可选择 1,000 / 5,000 / 10,000 / 20,000 / 50,000 条限制，替代原有硬编码的 200 条上限。
- ![Feature](https://img.shields.io/badge/Feature-10B981?style=flat-square) **订阅配置内容验证** (#80)：订阅更新时会验证返回内容是否为合法的 Clash 配置，拒绝纯文本提示、HTML 页面等非法内容，防止错误配置覆盖导致内核 reload 失败和日志风暴。
- ![Feature](https://img.shields.io/badge/Feature-10B981?style=flat-square) **配置文件软链接支持** (#74)：配置目录现在支持软链接（symlink）指向外部配置文件，方便使用 mackup 等工具进行跨设备配置同步，兼容其他 Clash 客户端的使用习惯。

**🚀 优化改进 (Improvements)**

- ![Optimize](https://img.shields.io/badge/Optimize-3B82F6?style=flat-square) **菜单栏行为优化**：改进菜单栏打开/关闭时的状态清理逻辑，避免代理组信息在重新打开时闪烁；停止内核时清除代理展示状态，避免停止后仍显示过期信息。
- ![Optimize](https://img.shields.io/badge/Optimize-3B82F6?style=flat-square) **远程机器状态管理**：优化远程机器验证会话的失效处理，在切换或断开时正确清理验证状态。

**🐞 修复问题 (Bug Fixes)**

- ![Fix](https://img.shields.io/badge/Fix-EF4444?style=flat-square) **macOS 26.5.1+ 菜单栏图标不可见** (#82)：修复在 macOS 26.5.1 及更高版本上菜单栏图标无法显示的问题；通过设置透明占位图片确保 ControlCenter 识别 status item 有内容并正确渲染。
- ![Fix](https://img.shields.io/badge/Fix-EF4444?style=flat-square) **订阅过期导致日志爆炸** (#80)：修复订阅过期后服务器返回错误提示文本被当作配置写入，导致内核反复 reload 失败、触发 TUN 句柄错误、CPU 占用 100% 和日志文件在短时间内膨胀到数十 GB 的问题。
- ![Fix](https://img.shields.io/badge/Fix-EF4444?style=flat-square) **配置软链接无法识别** (#74)：修复配置目录中的软链接文件无法被识别为有效配置的问题；现在安全检查会验证软链接本身是否在安全目录内，而不是解析到真实路径进行检查。

---

## v0.2.6

![macOS](https://img.shields.io/badge/macOS-Supported-000000?style=flat-square&logo=apple) ![Version](https://img.shields.io/badge/Release-v0.2.6-10B981?style=flat-square) ![Core](https://img.shields.io/badge/Core-Mihomo-6366f1?style=flat-square)

> 本次更新集中在 **菜单栏窗口固定、Proxy 页面操作密度与流量曲线显示稳定性**：Header 新增固定按钮，可让主窗口在切换应用或点击外部时继续保持显示；Proxy Providers 区域支持折叠并记住状态，代理组标题也补上了快捷延迟测试入口；同时流量 Sparkline 改为固定 60 点滑动窗口，避免短序列被拉满整段宽度导致趋势判断失真。

### 📝 更新日志 (Changelog)

**✨ 新增功能 (New Features)**

- ![Feature](https://img.shields.io/badge/Feature-10B981?style=flat-square) **菜单栏窗口固定模式**：Header 新增固定 / 取消固定按钮；固定后主窗口会保留在所有 Space 中，并且点击外部区域不会自动关闭，适合需要持续观察代理状态、连接列表或日志的场景。
- ![Feature](https://img.shields.io/badge/Feature-10B981?style=flat-square) **Proxy Providers 折叠控制**：Proxy 页面中的 Providers 区域新增展开 / 折叠按钮，并通过本地偏好保存折叠状态，订阅较多时可以减少页面占用。
- ![Feature](https://img.shields.io/badge/Feature-10B981?style=flat-square) **代理组快捷延迟测试**：代理组弹出面板标题区新增延迟测试按钮，可以直接对当前代理组触发测速，不必再进入更深层级寻找操作。

**🚀 优化改进 (Improvements)**

- ![Optimize](https://img.shields.io/badge/Optimize-3B82F6?style=flat-square) **流量曲线固定窗口**：状态栏流量 Sparkline 改为固定 60 点滑动窗口，最新数据从右侧推进，历史点按固定间距保留，短数据序列不再被强行铺满整个图表。
- ![Optimize](https://img.shields.io/badge/Optimize-3B82F6?style=flat-square) **流量面积填充对齐真实数据**：Sparkline 面积闭合改为使用首尾真实数据点的横坐标，避免数据不足时填充区域延伸到不存在的时间段。
- ![Optimize](https://img.shields.io/badge/Optimize-3B82F6?style=flat-square) **本地化文案补齐**：补充展开、折叠、固定和取消固定的中英文文案，让新增控件的无障碍标签与悬停提示保持一致。

---

## v0.2.5

![macOS](https://img.shields.io/badge/macOS-Supported-000000?style=flat-square&logo=apple) ![Version](https://img.shields.io/badge/Release-v0.2.5-10B981?style=flat-square) ![Core](https://img.shields.io/badge/Core-Mihomo-6366f1?style=flat-square)

> 本次更新集中在 **Connections 页面偏好持久化与 Mac 休眠唤醒后的 TUN 句柄失效问题**：连接列表现在会记住传输协议过滤器和排序方式，重新打开菜单或重启应用后不再回到默认视图；同时修正 Mac 休眠断网触发停服时的 TUN 运行态关闭顺序，先关闭运行中的 TUN 再停止内核，避免唤醒后 Mihomo 继续读取已被 macOS 释放的旧 TUN / UDP Socket 句柄并刷出 `socket operation on non-socket` 错误。

### 📝 更新日志 (Changelog)

**✨ 新增功能 (New Features)**

- ![Feature](https://img.shields.io/badge/Feature-10B981?style=flat-square) **Connections 过滤与排序偏好持久化**：Connections 页面会保存传输协议过滤器和排序选项；用户重新打开菜单或重启应用后，会自动恢复上次选择的连接列表视图。

**🚀 优化改进 (Improvements)**

- ![Optimize](https://img.shields.io/badge/Optimize-3B82F6?style=flat-square) **Connections 偏好恢复容错**：读取到失效的过滤或排序配置时会回退到默认值并写回，避免旧配置或异常值导致连接列表状态不可预期。

**🐞 修复问题 (Bug Fixes)**

- ![Fix](https://img.shields.io/badge/Fix-EF4444?style=flat-square) **休眠唤醒后 Mihomo 旧句柄刷屏**：修复 Mac 进入休眠后网络连接被系统断开、TUN 虚拟网卡或 UDP Socket 句柄在内核层面失效，但 Mihomo 唤醒后仍尝试读取旧句柄导致 `socket operation on non-socket` 错误持续刷屏的问题；现在断网停服会先尝试关闭 TUN 运行态，再进入内核停止流程。

---

## v0.2.4

![macOS](https://img.shields.io/badge/macOS-Supported-000000?style=flat-square&logo=apple) ![Version](https://img.shields.io/badge/Release-v0.2.4-10B981?style=flat-square) ![Core](https://img.shields.io/badge/Core-Mihomo-6366f1?style=flat-square)

> 本次更新集中修复了 **断网场景下的 WebSocket 重连风暴**：网络断开后会立即取消所有流轮询，并在流协调器的重连判定中加入离线保护，避免 mihomo 在无效连接上持续读写触发日志风暴；同时整理了菜单栏视图的代码结构，提升可读性与后续维护效率。

### 📝 更新日志 (Changelog)

**✨ 新增功能 (New Features)**

- ![Feature](https://img.shields.io/badge/Feature-10B981?style=flat-square) **暂无内容**：当前版本未新增独立功能项，更新重点为稳定性与代码质量修复。

**🚀 优化改进 (Improvements)**

- ![Optimize](https://img.shields.io/badge/Optimize-3B82F6?style=flat-square) **菜单栏视图代码整理**：拆分过长表达式与链式调用，在状态变化回调中直接使用新值，统一布局与阴影参数格式，提升代码可读性与后续维护效率。

**🐞 修复问题 (Bug Fixes)**

- ![Fix](https://img.shields.io/badge/Fix-EF4444?style=flat-square) **断网时 WebSocket 重连风暴**：修复网络断开后 WebSocket 轮询未及时取消的问题，现在断网后会立即停止所有流请求，避免 mihomo 在无效文件描述符上持续读写触发日志风暴。
- ![Fix](https://img.shields.io/badge/Fix-EF4444?style=flat-square) **断网期间竞态重连**：在流协调器重连判定中加入离线状态保护，防止断网期间多条竞态重连路径与网络管理停服流程互相干扰。

---

## v0.2.3

![macOS](https://img.shields.io/badge/macOS-Supported-000000?style=flat-square&logo=apple) ![Version](https://img.shields.io/badge/Release-v0.2.3-10B981?style=flat-square) ![Core](https://img.shields.io/badge/Core-Mihomo-6366f1?style=flat-square)

> 本次更新主要围绕 **Wi-Fi 场景下的配置自动切换、控制器 WebUI 直达、系统代理绕过规则与状态一致性** 展开：现在可以在 Proxy 菜单开启基于当前 Wi-Fi（SSID）的配置自动切换，并把当前网络直接绑定到指定配置；Header 也新增了一键打开控制器 WebUI 的入口，若配置中声明了 `external-ui-url` / `external-ui-name` 会优先打开对应界面，否则也会自动回退到可直接使用的 MetaCubeXD 初始化链接；同时，System 页面新增本地系统代理绕过规则管理，支持编辑、恢复默认并在系统代理重应用时持续保留。除此之外，本次还补上了 `GLOBAL` 代理组在不同模式下的显示一致性、系统代理 Helper 的预热/校验/恢复链路，以及 WebUI 链接跟随控制端变化同步更新等一批细节修复。

### 📝 更新日志 (Changelog)

**✨ 新增功能 (New Features)**

- ![Feature](https://img.shields.io/badge/Feature-10B981?style=flat-square) **SSID 配置自动切换**：在 Proxy 快捷菜单中新增 Wi-Fi 自动切换开关；开启后可以通过配置文件右键菜单直接绑定当前 Wi-Fi（SSID）到指定配置，绑定规则会持久保存，切换网络后会自动命中并切换到对应配置。
- ![Feature](https://img.shields.io/badge/Feature-10B981?style=flat-square) **SSID 绑定可视化与结果反馈**：配置列表项会展示已绑定 Wi-Fi 的 badge，并在右键菜单中提供绑定当前 Wi-Fi、解绑当前 Wi-Fi 与按条目解绑已绑定 Wi-Fi 等操作；当策略真正命中并完成配置切换后，状态栏会显示短暂横幅反馈，确认本次切换来自哪个 Wi-Fi、切到了哪个配置。
- ![Feature](https://img.shields.io/badge/Feature-10B981?style=flat-square) **控制器 WebUI 直达入口**：Header 新增一键打开 WebUI 的快捷按钮；如果当前配置声明了 `external-ui-url` / `external-ui-name`，会优先打开控制器实际配置的 WebUI 路径，不再要求用户自己手动拼 URL。
- ![Feature](https://img.shields.io/badge/Feature-10B981?style=flat-square) **控制器模式下的 WebUI 回退能力**：对于只有 `external-controller` / `secret`、但没有内置 UI 路径的控制器场景，现在也会自动生成可直接使用的 MetaCubeXD 初始化链接，本地或远程控制端场景下都更容易直接进入管理界面。
- ![Feature](https://img.shields.io/badge/Feature-10B981?style=flat-square) **系统代理绕过规则管理**：在 System 页面新增 macOS 系统代理绕过列表，支持新增、编辑、删除、保存与恢复默认例外项；这些规则会写入系统代理绕过域名/网段列表，适合保留 `localhost`、局域网网段或自定义直连域名。

**🚀 优化改进 (Improvements)**

- ![Optimize](https://img.shields.io/badge/Optimize-3B82F6?style=flat-square) **SSID 权限与状态提示**：开启 Wi-Fi 自动切换后，菜单会更明确地展示当前 Wi-Fi 名称或授权状态；首次使用时会主动走权限申请链路，未授权、未连接 Wi-Fi 或命中缺失配置时也会给出更直接的提示与日志反馈，减少“开了但不知道为什么没生效”的困惑。
- ![Optimize](https://img.shields.io/badge/Optimize-3B82F6?style=flat-square) **设置页交互收敛**：将“代理绕过”收纳进可展开区域，并加入规则数量提示、展开/收起动画和更精简的文案；在远程控制端场景下，也会明确标注该区域属于“本地”系统设置，减少误以为会同步到远端机器的情况。
- ![Optimize](https://img.shields.io/badge/Optimize-3B82F6?style=flat-square) **日志保真度提升**：应用内日志改为保留更完整的原始消息内容，并统一时间格式化逻辑；复制整条日志或复制原始消息时会更接近真实输出，对于排查 Mihomo 与 ClashBar 自身问题都更直接。
- ![Optimize](https://img.shields.io/badge/Optimize-3B82F6?style=flat-square) **控制器地址与 WebUI 同步**：当 `external-controller`、`secret`、`external-ui-url` 或 `external-ui-name` 发生变化时，WebUI 入口会跟着刷新；本地配置切换、远程目标切换和轮询刷新后的控制端地址都会尽量保持一致。
- ![Optimize](https://img.shields.io/badge/Optimize-3B82F6?style=flat-square) **系统代理 Helper 健康检查**：围绕系统代理 Helper 增补后台项目授权、进程运行状态、签名/安装位置校验与失败原因透传，在遇到 Helper 未注册、未启动、未获批准或打包环境不正确时，界面与日志会给出更具体的诊断信息。
- ![Optimize](https://img.shields.io/badge/Optimize-3B82F6?style=flat-square) **工程与状态流整理**：围绕 `AppViewModel` 重整应用生命周期、配置、轮询、流式更新、日志、系统代理和持久化链路，并补上更清晰的 stores / services / use cases 划分，为后续继续叠加远程控制、自动化和状态同步功能打下更稳基础。

**🐞 修复问题 (Bug Fixes)**

- ![Fix](https://img.shields.io/badge/Fix-EF4444?style=flat-square) **首次启用 SSID 自动切换**：修复首次开启 Wi-Fi 自动切换时权限请求链路可能漏掉、导致功能看起来已经打开但实际上拿不到当前 SSID 的问题。
- ![Fix](https://img.shields.io/badge/Fix-EF4444?style=flat-square) **失效 SSID 绑定清理**：修复 Wi-Fi 绑定规则在配置文件被删除、移动或不再可用后仍继续保留的情况，现应用会在初始化时清理无效绑定，避免策略反复命中不存在的配置。
- ![Fix](https://img.shields.io/badge/Fix-EF4444?style=flat-square) **WebUI 链接陈旧**：修复切换配置、切换本地/远程控制端或刷新运行时配置后，WebUI 入口仍可能指向旧控制器地址或旧 UI 路径的问题。
- ![Fix](https://img.shields.io/badge/Fix-EF4444?style=flat-square) **`GLOBAL` 代理组显示错误**：修复在 Rule / Direct 等非 Global 模式下，Proxy 列表中仍可能显示 `GLOBAL` 分组的问题；现在只有在真正处于 Global 模式时才会展示，并且模式切换后会立即刷新列表与延迟探测范围。
- ![Fix](https://img.shields.io/badge/Fix-EF4444?style=flat-square) **系统代理绕过项丢失**：修复系统代理重新应用、启动校验或一致性修复过程中，自定义代理绕过规则容易被覆盖或遗漏的问题，确保本地例外项会一并写回 macOS。
- ![Fix](https://img.shields.io/badge/Fix-EF4444?style=flat-square) **系统代理启动一致性**：增强应用启动、回到前台和系统代理已开启场景下的 Helper 预热、注册与配置校验流程，减少“开关仍是开的，但系统代理实际上没生效”或目标地址已变更却未及时修正的情况。
- ![Fix](https://img.shields.io/badge/Fix-EF4444?style=flat-square) **Helper 恢复链路与错误提示**：修复系统代理 Helper 在未放入“应用程序”目录、后台项目未允许、签名不匹配、连接失败或启动超时等场景下反馈不够直观的问题，让恢复路径和失败原因都更清楚。

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
