# ClashBar 项目文档

## 1. 项目概述

ClashBar 是一个基于 `SwiftUI + AppKit + SwiftPM` 构建、由 `mihomo` 驱动的原生 macOS 菜单栏代理客户端。项目的核心目标不是做“大而全”的 Clash 系桌面面板，而是提供一个更轻量、更稳定、更贴近 macOS 菜单栏使用习惯的代理管理工具。

从当前仓库实现来看，ClashBar 具备以下产品形态与工程特点：

- 纯菜单栏应用，无传统主窗口，主交互通过状态栏图标和 Popover 面板完成。
- 使用原生 `SwiftUI` 构建界面，必要处结合 `AppKit` 完成菜单栏、系统弹窗、访达打开等桌面能力。
- 使用 `Swift Package Manager` 管理整个工程，没有依赖 Xcode Project 才能构建的复杂工程结构。
- 提供两个可执行目标：
  - `ClashBar`：主应用。
  - `ClashBarProxyHelper`：系统代理修改 Helper。
- 通过 `mihomo` HTTP/WebSocket API 拉取运行态数据，实现实时速率、连接、规则、日志、节点和 Provider 的展示与操作。
- 支持中英文界面切换，当前默认本地化语言为 `zh-Hans`。

## 2. 项目定位与设计目标

### 2.1 产品定位

ClashBar 面向的是这样一类 macOS 用户：

- 希望通过菜单栏快速完成代理管理，而不是频繁打开大体积主窗口。
- 需要稳定的 `mihomo` Core 生命周期管理能力。
- 需要一定的可观测性，能够在代理异常时快速查看规则、连接与日志。
- 希望系统代理、TUN、订阅更新、配置切换这些高频操作尽可能简化。

### 2.2 设计目标

- 轻量：
  - 应用尽量保持较小体积。
  - 无需引入额外庞大的前端运行时。
  - 支持打包带 Core 与不带 Core 两种交付模式。
- 稳定：
  - 启动前校验配置。
  - 切换配置时自动验证并必要时重启 Core。
  - 系统代理状态在应用重启后可自动修复与恢复。
  - 配置目录变化可自动侦测并按需重启 Core。
- 可观测：
  - 展示实时上下行速率。
  - 展示连接数量、连接列表、规则命中、日志与 Provider 状态。
  - 保留 ClashBar 自身日志与 mihomo 日志，并做脱敏处理。
- 原生：
  - 使用 macOS 菜单栏交互模型。
  - 使用 `SMAppService` 处理登录项与 Helper 注册。
  - 使用系统网络配置能力完成系统代理设置。

## 3. 技术栈与交付物

### 3.1 技术栈

- 平台：`macOS 13+`
- 语言：`Swift 6.2`
- UI：`SwiftUI + AppKit`
- 构建：`SwiftPM`
- Core：`mihomo`
- 系统集成：
  - `ServiceManagement`
  - `SystemConfiguration`
  - `Security`
- 网络通信：
  - `URLSession`
  - `URLSessionWebSocketTask`

### 3.2 工程交付物

当前仓库会产出以下核心内容：

- `ClashBar.app`
- `ClashBarProxyHelper` Helper Tools 二进制
- `com.clashbar.helper.plist` LaunchDaemon 配置
- 可选打包的 `mihomo.gz`
- `.dmg` 安装包和对应 `sha256`

## 4. 产品能力总览

| 能力域          | 具体能力                                         | 当前实现说明                                                              |
| --------------- | ------------------------------------------------ | ------------------------------------------------------------------------- |
| Core 生命周期   | Start / Stop / Restart                           | 支持手动启动、停止、重启，并支持自动启动与网络恢复后自动拉起              |
| 配置管理        | 本地配置、远程订阅、配置切换、重载、目录监控     | 配置统一托管在工作目录 `config/` 下，支持本地导入、远程导入和批量远程更新 |
| 模式控制        | `Rule` / `Global` / `Direct`                     | 通过 `/configs` PATCH 切换 `mihomo` 运行模式                              |
| 节点与 Provider | Provider 刷新、分组延迟测试、节点切换            | 支持代理组单测、批量测速、节点切换、隐藏分组控制、按延迟排序              |
| 连接与排障      | Connections、Rules、Logs                         | 支持连接筛选、规则查看、日志过滤与复制                                    |
| 系统集成        | 系统代理、TUN、开机启动                          | 系统代理通过独立 Helper 修改，TUN 通过授权 Core 二进制实现                |
| 设置维护        | 语言、外观、状态栏样式、日志等级、端口、缓存清理 | 支持直接修改部分 `mihomo` 配置并持久化 UI 状态                            |
| 更新维护        | Core 升级、App 版本检查                          | 支持通过 `mihomo /upgrade` 升级内核，并检查 GitHub 最新 App Release       |

## 5. 界面结构与功能说明

### 5.1 顶部 Header

Header 是整个菜单栏面板的控制中心，负责展示运行态并提供高频操作入口。

已实现内容：

- 应用 Logo 与标题 `ClashBar`
- 当前运行状态徽标
  - `Running`
  - `Starting`
  - `Failed`
  - `Stopped`
- 当前 `external-controller` 地址展示
- 当 `external-controller` 为 `0.0.0.0` 时显示安全警告图标
- 通过 Header 中的链接快速跳转到 MetaCubeXD 的控制器配置页面
- Core 操作按钮
  - `Restart`
  - `Stop`,运行中为 `Stop`，未运行时为 `Start`
  - `Quit`

### 5.2 模式切换区

Header 下方提供模式切换与页面 Tab 切换功能。

- 运行模式切换：
  - `Rule`
  - `Global`
  - `Direct`
- 页面 Tab：
  - `Proxy`
  - `Rules`
  - `Connections`
  - `Logs`
  - `System`

### 5.3 Proxy 页面

Proxy 页面是 ClashBar 最核心的日常使用页面，集成了运行态概览、配置管理、系统代理、TUN、Provider 和代理组操作。

#### 运行概览

- 实时速率曲线（Sparkline）
- 当前连接数
- Core 内存占用
- 当前上行速率与累计上行流量
- 当前下行速率与累计下行流量

#### 配置管理

- 展示当前已选中的配置文件
- 展示 `config/` 目录下所有可用配置
- 支持切换配置文件
- 支持重新扫描配置列表
- 支持导入本地配置文件
- 支持导入远程订阅配置
- 支持批量更新所有远程订阅配置
- 支持在访达中显示当前配置文件

配置策略实现要点：

- 仅识别 `.yaml` / `.yml` 文件。
- 配置文件按文件名排序。
- 若没有手动指定，默认选中第一个配置。
- 配置切换前如果 Core 正在运行，会先对目标配置执行校验。
- 如果配置目录中当前生效配置发生变更，系统会自动重启 Core 以同步最新内容。

#### 系统代理

- 支持开启系统代理
- 支持关闭系统代理
- 会根据运行时配置自动解析代理端口
  - 优先使用 `mixed-port`
  - 否则回退到 `port` / `socks-port`
- 系统代理实际由独立 Helper 应用到系统网络服务上

#### TUN

- 支持启用 TUN
- 支持关闭 TUN
- 若启用 TUN 前权限不足，会请求管理员授权
- 启动时会验证 `mihomo` 二进制是否具备 TUN 所需权限
- 若配置中未显式声明 `tun.stack`，会在需要时自动补 `mixed`
- 启用 TUN 时会同步确保 `dns.enable = true`

#### 终端代理

- 一键复制终端环境变量脚本
  - 判断 mixed-port 还是 单独 http port 和 socks port
- 复制结果包含：
  - `https_proxy`
  - `http_proxy`
  - `all_proxy`

#### Proxy Provider

- 展示所有代理 Provider（过滤掉 `default` 和 `Compatible` 类型）
- 显示基础信息
  - Provider 名称
  - 节点数量
  - 最近更新时间
  - 订阅流量信息
  - 订阅过期时间
- 支持单个 Provider 刷新

#### 代理组

- 展示代理组列表
- 展示当前选中节点
- 展示代理组或节点延迟
- 支持展开代理组节点选择面板
- 支持切换代理组当前节点
- 支持单个代理组测速
- 支持所有代理组批量测速
- 支持隐藏或显示 `hidden` 代理组
- 支持节点按延迟排序

### 5.4 Rules 页面

Rules 页面用于查看分流规则与 Rule Provider 状态。

已实现内容：

- 展示规则总数
- 展示规则集 / Rule Provider 总数
- 刷新所有 Rule Provider
- 展示规则列表
  - 规则类型
  - 规则目标
  - 当前策略
  - 关联 Rule Provider 的规则数
  - Provider 最近更新时间

实现细节：

- 当前 UI 最多保留前 `120` 条规则用于展示。
- Rule Provider 信息会建立名称映射，用于将规则项和 Provider 统计关联起来。

### 5.5 Connections 页面

Connections 页面用于查看活动连接并做简单排障。

已实现内容：

- 展示当前连接列表
- 刷新连接列表
- 关闭全部连接
- 关闭单个连接
- 关键字过滤
- 传输协议过滤
  - `All`
  - `TCP`
  - `UDP`
  - `Other`
- 排序方式
  - 默认
  - 最新优先
  - 最旧优先
  - 按上传流量降序
  - 按下载流量降序
  - 按总流量降序
- 支持复制连接相关字段
  - 连接 ID
  - Host

实现细节：

- 当前 UI 最多保留前 `120` 条连接用于展示。
- 连接排序会优先复用解析后的时间戳，避免在比较器中重复解析时间。

### 5.6 Logs 页面

Logs 页面统一展示 ClashBar 自身日志和 mihomo 日志。

已实现内容：

- 日志来源过滤
  - `All`
  - `ClashBar`
  - `Mihomo`
- 日志等级过滤
  - `Info`
  - `Warning`
  - `Error`
- 关键字搜索
- 复制全部日志
- 清空全部日志
- 复制单条日志
- 复制单条日志消息

实现细节：

- 面板展开时，内存中最多保留 `120` 条日志。
- 面板隐藏时，内存中只保留 `20` 条日志，降低后台内存占用。
- mihomo 日志会先进行短时间缓冲，再批量刷新进 UI 和文件。
- 所有日志在写入前会经过脱敏处理。

### 5.7 System 页面

System 页面用于承载应用级设置、Core 运行配置和维护操作。

#### 基础设置

- 开机启动
- Core 自动启动
- 网络断开后自动管理 Core
  - 断网自动停核
  - 网络恢复后自动尝试恢复
- `allow-lan`
- `ipv6`
- `tcp-concurrent`
- 状态栏样式
  - 仅图标
  - 图标 + 速率
  - 仅速率
- 界面语言
  - 简体中文
  - English
- 外观模式
  - 跟随系统
  - 浅色
  - 深色
- 日志等级
  - `silent`
  - `error`
  - `warning`
  - `info`
  - `debug`

#### 代理端口设置

- `port`
- `socks-port`
- `mixed-port`
- `redir-port`
- `tproxy-port`

实现细节：

- 端口字段输入后会触发延迟自动保存。
- 自动保存延时约 `750ms`，避免频繁请求 `/configs`。

#### 维护操作

- 清理 FakeIP 缓存
- 清理 DNS 缓存
- 打开 Core 目录

#### 反馈提示

- 设置保存成功提示
- 端口或日志等级等输入错误提示
- 开机启动授权失败提示

### 5.8 底部 Footer

Footer 承载版本与更新入口。

已实现内容：

- 展示当前 `mihomo` 版本
- 跳转到 `mihomo` GitHub 仓库
- 一键升级 Core
- 展示当前 App 版本
- 检查 GitHub 上是否存在更高版本 Release
- 如果有新版本，则在 Footer 中显示升级提示并跳转到 Release 页面

## 6. 命令菜单与快捷键

主应用在 macOS 菜单栏命令菜单中提供了额外快捷操作。

### 6.1 Core 菜单

- 主 Core 操作：`Command + Shift + R`
- Stop Core：`Command + Shift + .`
- 切换 TUN：`Command + Option + T`

### 6.2 Panel 菜单

- 打开 `Proxy`：`Command + Option + 1`
- 打开 `Rules`：`Command + Option + 2`
- 打开 `Connections`：`Command + Option + 3`
- 打开 `Logs`：`Command + Option + 4`
- 打开 `System`：`Command + Option + 5`
- 快速切到 `System`：`Command + ,`

### 6.3 Actions 菜单

- 刷新当前页面：`Command + Shift + K`
- 复制终端代理命令：`Command + Option + Shift + C`
- 复制全部日志：`Command + Option + Shift + L`
- 清空全部日志：`Command + Option + Shift + Delete`

## 7. 自动化行为与运行机制

### 7.1 应用启动流程

应用启动时的大致流程如下：

1. 使用 `ClashBarAppDelegate` 创建 `AppSession`。
2. 设置 App 为 `accessory` 模式，仅显示菜单栏图标。
3. 创建状态栏控制器 `StatusItemController`。
4. 初始化工作目录：
   - `config/`
   - `logs/`
   - `state/`
   - `core/`
5. 初始化日志文件：
   - `clashbar.log`
   - `mihomo.log`
6. 如果存在内置默认配置，则播种 `ClashBar.yaml`。
7. 恢复上次保存的配置选择、UI 设置与远程订阅映射。
8. 后台拉取一次 API 运行态，尝试恢复运行状态显示。
9. 启动配置目录监控。
10. 根据设置判断是否自动启动 Core。
11. 必要时展示“未内置 Core 的首次引导提示”。

### 7.2 Core 启动流程

当前实现中的 Core 启动逻辑比较完整，大致步骤如下：

1. 解析当前选中的配置文件。
2. 如果启用了 TUN，先进行权限预处理。
3. 使用 `mihomo -t` 对配置执行启动前校验。
4. 从配置文件中解析 `external-controller` 与 `secret`。
5. 按固定工作目录启动 `mihomo`：
   - `-d <working_root>`
   - `-f <config_path>`
   - `-ext-ctl <controller>`
6. 启动完成后：
   - 刷新版本与运行配置
   - 启动流式数据采集
   - 视情况恢复系统代理
   - 视情况恢复 TUN
   - 触发 Provider 刷新
   - 触发代理组延迟探测

### 7.3 Core 停止与退出流程

- 停止 Core 时会取消轮询、流式任务和部分后台任务。
- 退出应用时会：
  - 保存系统代理开关状态
  - 停止网络监控
  - 停止配置目录监控
  - 清理系统代理
  - 停止 `mihomo` 进程

### 7.4 配置校验与自动重启

与配置相关的自动化行为包括：

- 启动前配置校验
- 切换配置前配置校验
- 监控 `config/` 目录文件变更
- 如果当前生效配置被修改，自动重启 Core
- 如果当前正在执行 Core 操作或 TUN 操作，则延后执行重启

### 7.5 网络变化后的自动 Core 管理

项目实现了网络可达性监控：

- 当启用“网络断开后自动管理 Core”时：
  - 断网后自动尝试停止 Core
  - 网络恢复后根据之前状态自动尝试恢复 Core
- 在恢复过程中，会尽量一并恢复系统代理和 TUN 等运行特性

### 7.6 数据采集策略

项目没有粗暴地一直全量拉取数据，而是根据面板可见性和当前 Tab 动态调整数据采集策略。

具体策略如下：

- 面板隐藏时：
  - 保留必要的流量流，供状态栏速率显示使用
  - 关闭内存、连接、日志等高频流
  - 降低后台刷新频率
- 面板展开时：
  - `Proxy` 页会启用流量、内存、连接相关数据
  - `Connections` 页会启用连接流
  - `Logs` 页会启用日志流
  - `Rules` 与 `Proxy` 页会触发较重的规则/Provider 刷新

这套策略的目标是：

- 菜单栏关闭时尽量轻量
- 菜单栏打开时尽量实时

### 7.7 Provider 后台刷新

Provider 刷新并不是简单的“点一下就全串行执行”，而是做了完整的后台流程控制：

- 支持取消上一次刷新任务
- 使用 generation 防止旧任务回写新状态
- 展示刷新阶段、进度、成功/失败/取消状态
- 先尝试 reload config，再分别更新 Proxy Provider 和 Rule Provider

### 7.8 App 更新检查

- 在面板展开时触发 App 最新 Release 检查
- 通过 GitHub Releases API 获取最新版本
- 忽略 draft 和 prerelease
- 如果版本更新，则在 Footer 显示可点击更新徽标

## 8. 运行时目录与数据持久化

### 8.1 工作目录

运行时根目录固定为：

- `~/Library/Application Support/clashbar`

目录结构如下：

| 路径      | 作用                           |
| --------- | ------------------------------ |
| `config/` | 用户配置文件与远程订阅落地目录 |
| `logs/`   | ClashBar 和 mihomo 日志文件    |
| `state/`  | 预留运行状态目录               |
| `core/`   | 运行态使用的 `mihomo` 二进制   |

### 8.2 Core 路径

ClashBar 运行时实际使用的 Core 路径为：

- `~/Library/Application Support/clashbar/core/mihomo`

这样做的目的有两个：

- 避免直接改写已签名的 App Bundle 内容
- 让 Core 升级、替换和 TUN 授权都围绕单一运行路径进行

### 8.3 日志文件

当前会维护两份主要日志文件：

- `logs/clashbar.log`
- `logs/mihomo.log`

### 8.4 UserDefaults / AppStorage 持久化内容

当前实现会持久化以下类型的数据：

- 已选择的配置文件名
- 最近一次成功启动的配置路径
- 远程配置来源映射
- 可编辑的 Core 设置快照
- 退出时系统代理开关状态
- UI 语言
- 外观模式
- Core 自动启动开关
- 网络变化自动管理 Core 开关
- 状态栏显示模式
- 代理组 / 节点部分 UI 偏好项

### 8.5 默认配置播种

应用首次运行时，如果 `config/ClashBar.yaml` 不存在，会尝试从资源包中的模板复制一份默认配置文件到工作目录。

## 9. 架构设计

### 9.1 进程控制层

`MihomoProcessManager` 负责：

- 解析并定位运行时 `mihomo` 二进制
- 校验配置文件
- 启动 `mihomo` 进程
- 停止 `mihomo` 进程
- 接收 `stdout/stderr` 并写入日志
- 处理异常退出

关键特征：

- 启动前统一使用 `working root` 作为 `-d` 目录
- 通过 `-t` 执行配置测试
- 使用单独队列处理生命周期操作与配置校验

### 9.2 API 通信层

`MihomoAPIClient` 负责：

- 构造 REST 请求
- 构造 WebSocket 请求
- 注入 `Authorization: Bearer <secret>`
- 管理控制器地址与密钥更新
- 定义所有当前用到的 API Endpoint

当前用到的接口覆盖：

- `/version`
- `/traffic`
- `/memory`
- `/logs`
- `/configs`
- `/group/.../delay`
- `/proxies`
- `/providers/proxies`
- `/providers/rules`
- `/rules`
- `/connections`
- `/cache/fakeip/flush`
- `/cache/dns/flush`
- `/upgrade`

### 9.3 系统代理 Helper 架构

系统代理修改不在主进程直接完成，而是走独立 Helper：

- 主应用通过 `SMAppService.daemon` 注册 Helper
- Helper 通过 `SystemConfiguration` 修改系统网络服务上的代理设置
- 主应用与 Helper 之间通过 `ProxyHelperProtocol` 通信

这样做的意义：

- 权限边界更清晰
- 系统代理改动更稳定
- 更符合 macOS 对后台服务的模型

## 10. 关键流程说明

### 10.1 配置导入流程

本地配置导入：

- 选择本地文件
- 规范化文件名
- 写入 `config/`
- 刷新配置列表
- 如覆盖当前配置，则按需重载

远程配置导入 / 更新：

- 只允许 `http` / `https`
- 对文件名进行规范化，只允许 `.yaml` / `.yml`
- 限制远程响应最大体积为 `5 MB`
- 原子写入目标文件
- 保存“文件名 -> 订阅 URL”映射
- 若更新影响当前配置，则自动触发重载

### 10.2 external-controller 处理流程

当前实现会：

- 从配置文件中解析 `external-controller`
- 对地址格式做校验
- 将 `0.0.0.0` 规范化为本地可访问地址用于客户端通信
- 当发现绑定的不是 loopback 地址时记录安全警告日志
- 从配置中同步解析 `secret`

### 10.3 TUN 启用流程

启用 TUN 时的主要步骤：

1. 检查运行态 `mihomo` 二进制是否存在且可执行。
2. 检查是否满足 TUN 所需权限：
   - owner 为 `root`
   - 含 `setuid`
   - owner 可执行
3. 如果权限不足，则通过 `osascript` 触发管理员授权：
   - `chown root:admin`
   - `chmod u+s`
4. 通过 API PATCH `tun.enable`
5. 在必要时自动补 `stack: mixed`
6. 同步确保 `dns.enable = true`
7. 轮询验证运行态是否真正切换成功

### 10.4 系统代理启用流程

启用系统代理时的流程：

1. 从当前运行配置中解析代理端口。
2. 校验主应用是否来自打包 App。
3. 校验应用是否位于可正常安装 Helper 的环境中。
4. 通过 `SMAppService` 注册或恢复 Helper。
5. 先清理旧代理配置，再写入新的 HTTP / HTTPS / SOCKS 代理设置。
6. 同步刷新 UI 中的系统代理状态。

### 10.5 Core 升级流程

Footer 的 Core 升级按钮会调用：

- `POST /upgrade`

并根据返回结果进入以下状态：

- `idle`
- `running`
- `succeeded`
- `alreadyLatest`
- `failed`

升级结束后会延迟刷新一次 Core 版本号。

## 11. 安全性、容错与稳健性设计

### 11.1 路径安全

`WorkingDirectoryManager` 对所有工作目录路径都做了标准化和根目录约束校验，避免路径逃逸到工作目录之外。

### 11.2 日志脱敏

日志写入前会统一经过 `LogSanitizer` 处理，当前会脱敏以下敏感信息：

- `Authorization: Bearer ...`
- `-secret xxx`
- URL 中的用户信息
- `token` / `secret` / `password` 类查询参数
- JSON 中的敏感字段
- 文本中的敏感赋值语句

### 11.3 Helper 容错恢复

系统代理服务带有恢复重试逻辑：

- 注册失败可尝试恢复
- XPC / Helper 连接失败可触发重试
- 对需要登录项授权的情况会主动跳转系统设置

### 11.4 流式连接容错

WebSocket 流具备：

- 断线重连
- 重连退避
- 断线日志节流
- 进程停止后自动收敛

### 11.5 配置错误防护

- 启动前配置验证
- 切换配置前配置验证
- 配置异常时弹窗提示并写日志
- 防止无效配置直接把运行态拖入不可用状态

### 11.6 无 Core 场景处理

项目支持构建“不内置 Core”的应用包。在这种模式下：

- 如果工作目录中尚未存在受管 `mihomo`
- 则首次启动会弹出引导提示
- 并提示用户打开 Core 目录自行放置 `mihomo`

## 12. 构建、打包与发布流程

### 12.1 构建要求

- macOS 13+
- Swift 6.2
- 可使用 `swift build`
- 打包阶段需要系统提供的 `codesign`、`hdiutil`、`sips`、`iconutil`

### 12.2 SwiftPM Target 结构

- `ProxyHelperShared`
- `ClashBar`
- `ClashBarProxyHelper`

### 12.3 makefile 入口

仓库已经封装了常用命令：

- `make build`
  - 构建 `dist/ClashBar.app`
- `make dist`
  - 构建 App 并生成 DMG
- `make dmg`
  - 基于现有 App 构建 DMG
- `make clean`
  - 清理 `.build`、`dist`、`.swiftpm`、`Packages`

可选参数：

- `WITH_CORE=1`
- `TARGET_ARCH=...`
- `APP_VERSION=...`
- `BUILD_NUMBER=...`
- `DMG_SUFFIX=...`

### 12.4 预处理阶段

`Scripts/preprocess.sh` 负责：

- 复用或下载 `mihomo`
- 根据架构选择对应资产
- 将下载结果转换为本地资源中的 `mihomo`
- 从 Logo 生成 `.icns`

说明：

- 默认可从 `MetaCubeX/mihomo` 最新 Release 自动解析版本并下载。
- 如果本地 `Resources/bin/mihomo` 已存在有效 Mach-O，则优先复用。

### 12.5 App 打包阶段

`Scripts/package_app.sh` 负责：

- 执行 `swift build -c release`
- 收集主程序、资源包、Helper 和 LaunchDaemon plist
- 组装 `.app` 包结构
- 可选将 `mihomo` 以压缩 `mihomo.gz` 的形式打入资源中
- 写入 `Info.plist`
- 写入 `ClashBarBundlesMihomoCore` 标志位
- 对主应用和 Helper 执行 `codesign`

### 12.6 DMG 打包阶段

`Scripts/make_dmg.sh` 负责：

- 从 `dist/ClashBar.app` 构造临时 DMG 内容
- 附加 `/Applications` 快捷方式
- 生成压缩 DMG
- 输出 `.sha256`

## 13. 当前项目实现状态总结

从当前仓库实现来看，ClashBar 已经不再是“只有基础壳子”的早期原型，而是具备以下完整能力的可用项目：

- 有完整的菜单栏产品形态和较成熟的 UI 结构。
- 有完整的 Core 生命周期管理与异常处理。
- 有本地配置、远程订阅、配置监控与自动重载体系。
- 有较完整的系统代理与 TUN 集成能力。
- 有连接、规则、日志、Provider、代理组等排障与运维视图。
- 有动态流式采集和后台刷新节流策略。
- 有打包、签名、DMG 生成、带 Core / 不带 Core 双模式发布链路。

换句话说，当前项目已经覆盖了一个原生 macOS 菜单栏代理客户端在“可日常使用”层面所需的大部分核心能力，后续优化重点更适合放在稳定性、细节体验、更多平台权限兼容性和发布流程完善，而不是从零补全基础功能。
