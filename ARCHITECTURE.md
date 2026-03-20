# ClashBar Architecture

## 概览

ClashBar 采用 `SwiftUI + AppKit + SwiftPM`，整体架构是：

- `Feature-first MVVM`
- `Clean Architecture`
- `Session-centered application orchestration`

目标不是做一套教科书式的“纯”分层，而是在 macOS 菜单栏应用、`mihomo` Core 控制、系统代理 Helper、运行时流式数据这几个现实约束下，形成一套**长期可维护、边界清晰、可渐进演进**的工程结构。

当前仓库的核心原则是：

1. `Features` 负责 UI、ViewModel 和页面局部状态。
2. `Domain` 定义模型、仓储协议和用例，不依赖具体实现。
3. `Infrastructure` 提供 API、进程、文件系统、系统能力等具体实现。
4. `App/Session` 负责全局会话状态与跨模块协调，但尽量不直接承载底层实现细节。
5. `ProxyHelper` 与主 App 严格分 Target，`ProxyHelperShared` 仅承载跨进程共享协议。

---

## 目录结构

当前主要目录如下：

```text
Sources/
├── ClashBar
│   ├── App
│   │   ├── ClashBarApp.swift
│   │   ├── Composition
│   │   └── Session
│   ├── Domain
│   │   ├── Entities
│   │   ├── Repositories
│   │   └── UseCases
│   ├── Features
│   │   ├── MenuBar
│   │   └── StatusBar
│   ├── Infrastructure
│   │   ├── API
│   │   ├── Config
│   │   ├── Persistence
│   │   ├── Process
│   │   └── System
│   ├── Resources
│   └── Shared
├── ProxyHelper
│   ├── Daemon
│   └── LaunchDaemons
└── ProxyHelperShared
```

### App

`App` 只处理应用入口、对象装配和会话层。

- `ClashBarApp.swift`
  App 入口、CommandMenu、AppDelegate 挂接。
- `Composition`
  负责依赖装配。
  例如 `DependencyContainer.swift`、`AppCommandsViewModel.swift`
- `Session`
  负责全局状态与跨功能编排。
  - `AppSession.swift`
  - `AppSessionTypes.swift`
  - `Coordinators`
  - `Extensions`
  - `Stores`

### Domain

`Domain` 是业务语义中心。

- `Entities`
  领域模型与运行时数据结构。
- `Repositories`
  仓储协议定义。
- `UseCases`
  应用级动作与查询逻辑。

### Features

`Features` 是表现层。

- `MenuBar`
  菜单栏弹层各个页面。
- `StatusBar`
  顶部状态栏图标、Popover、布局模型。

### Infrastructure

`Infrastructure` 是脏活累活的实现层。

- `API/Client`
  低层 API client
- `API/Repositories`
  仓储协议的默认实现
- `Config`
  配置目录和导入逻辑
- `Persistence`
  日志文件、剪贴板等持久化和系统 I/O
- `Process`
  `mihomo` 进程控制
- `System`
  系统代理、TUN、登录项、Reachability、Release 检查

### ProxyHelper / ProxyHelperShared

- `ProxyHelper`
  独立守护进程 Target，负责修改系统网络代理。
- `ProxyHelperShared`
  跨进程共享协议和模型。

这两个 Target 必须与主 App 保持边界清晰，不能混放在 `ClashBar` 内部。

---

## 分层职责

### 1. App / Session 层

`AppSession` 是当前应用的全局会话中心，但它不是 Repository，也不是 API Client。

它负责：

- 暴露全局 `@Published` 状态
- 协调跨模块流程
- 管理页面间共享运行态
- 把 View 层动作转发给 UseCase / Repository

它不应该负责：

- 直接构造网络请求
- 直接访问文件系统细节
- 直接承载大量纯算法逻辑
- 直接承担具体系统能力实现

当某段代码更像“流程编排”时，优先放到 `App/Session/Coordinators`。  
当某段代码只是“围绕 AppSession 的轻量辅助方法”时，才放到 `App/Session/Extensions`。

### 2. Domain 层

`Domain` 不感知 SwiftUI，不依赖 AppKit，不依赖具体资源路径，也不依赖 `mihomo` 的实现类。

它负责：

- 定义业务模型
- 定义仓储协议
- 定义动词明确的 UseCase

当前 UseCase 大致分成几类：

- `Core`
- `Config`
- `Proxy`
- `Providers`
- `Maintenance`
- `Session`
- `Presentation`
- `System`

其中：

- `Presentation` 用于把底层数据加工成 View 可消费的状态
- `Session` 用于运行时编排相关纯逻辑
- `System` 用于系统代理、TUN、登录项等能力封装

### 3. Features 层

`Features` 使用 MVVM。

约定如下：

- `View`
  只负责渲染和事件分发
- `ViewModel`
  负责视图状态、用户动作、局部状态整理
- 复杂页面允许有局部 `State` 或二级 ViewModel

当前仍有一部分 View 直接读取 `AppSession`，这是一个有意保留的过渡态。  
后续如果继续演进，优先方向是：让更多 View 改为只依赖 ViewModel 的输出。

### 4. Infrastructure 层

`Infrastructure` 只做实现，不持有业务决策权。

例如：

- `MihomoAPIClient`
  只负责协议层通信
- `DefaultRuntimeConfigRepository`
  只负责把 `RuntimeConfigRepository` 协议映射到 API
- `MihomoProcessManager`
  只负责进程生命周期
- `SystemProxyService`
  只负责系统代理写入/查询

如果某个实现开始出现“是否要这么做”的业务判断，通常说明这段逻辑应该回到 `UseCase` 或 `Coordinator`。

---

## 依赖方向

严格依赖方向如下：

```text
Features -> App/Session -> Domain -> Infrastructure
```

更准确地说：

- `Features` 可以依赖 `AppSession`、ViewModel、Domain 模型
- `AppSession` 可以依赖 UseCase、Repository 协议、Infrastructure 默认实现
- `Domain` 不能依赖 `Features`、`AppKit`、`SwiftUI`
- `Infrastructure` 可以依赖 `Domain`

禁止的方向：

- `Domain -> Features`
- `Domain -> App`
- `Features -> Infrastructure concrete types`
- `ProxyHelperShared -> ClashBar`

---

## 资源策略

当前资源目录是：

```text
Resources/
├── Assets.xcassets
├── Localizable.xcstrings
├── ConfigTemplates
└── bin
```

### 关于现代资源

仓库已经采用：

- `Assets.xcassets`
- `Localizable.xcstrings`

但需要注意：

当前项目仍然是**纯 SwiftPM 可执行 Target**，不是 Xcode App Project。  
因此 SwiftPM 在当前链路下会把这些资源按文件复制，而不是像 Xcode App 工程那样统一编译成标准 Apple 资源产物。

所以当前实现采用的是：

- 目录结构现代化
- 运行时直接读取 `Assets.xcassets` 中的原始图片文件
- 运行时直接解析 `Localizable.xcstrings`

这不是最标准的 Apple 资源运行方式，但它满足：

- 继续保持纯 SwiftPM
- 不引入 `.xcodeproj`
- 目录结构现代化

### 品牌资源

品牌资源由 `BrandIcon` 统一加载。  
它不直接暴露文件系统细节给上层 View。

### 本地化

本地化由 `L10n` 统一访问。  
当前对外接口仍保持：

```swift
L10n.t("some.key", language: .zhHans)
```

这样做的目的是让上层业务与资源迁移解耦。

---

## 运行时主流程

### App 启动

1. `ClashBarApp` 启动
2. 创建 `DependencyContainer`
3. 创建 `AppSession`
4. 创建状态栏控制器 `StatusItemController`
5. 初始化资源、目录、日志和默认配置
6. 根据策略决定是否自动启动 Core、是否恢复运行态

### 菜单栏打开

1. `StatusItemController` 打开 Popover
2. `AppSession` 标记 `isPanelPresented = true`
3. `PollingCoordinator` 根据当前 tab 调整采集策略
4. `StreamsCoordinator` 视需要打开对应 WebSocket 流

### Core 启动

1. `AppSession` 发起启动请求
2. `Core` UseCase 验证配置
3. `CoreRepository` 调用 `MihomoProcessManager`
4. 启动后刷新运行态、补齐 Provider/ProxyGroups/TUN/SystemProxy 等状态

### Provider / 规则刷新

1. Feature 层发起动作
2. `AppSession` 调度 Provider 相关 coordinator
3. UseCase 调用 `ProvidersRepository`
4. Repository 通过 API client 读取或更新
5. 结果回写到 `AppSession` 的共享状态

---

## 代码规范

### 1. 命名

- 类型名优先表达角色，不重复目录语义
  例如 `Provider.swift`，而不是 `ProviderModels.swift`
- `UseCase` 名称优先表达动作或结果
  例如：
  - `StartCoreUseCase`
  - `FetchMediumFrequencySnapshotUseCase`
  - `BuildProxyGroupsPresentationUseCase`
- `Default...Repository` 统一表示基础设施默认实现

### 2. View / ViewModel

- ViewModel 输出应尽可能面向 State，而不是把 `AppSession` 整个暴露给 View
- View 中不要堆叠复杂业务逻辑、排序逻辑、合并逻辑
- 局部 UI 逻辑可以保留在 Feature 内部，不要过早下沉

### 3. AppSession

- `AppSession` 保持为会话状态中心
- 新增逻辑优先问自己：
  - 这是状态？
  - 这是纯逻辑？
  - 这是流程编排？
  - 这是底层实现？

对应归属：

- 状态：`AppSession`
- 纯逻辑：`UseCase`
- 流程编排：`Coordinators`
- 实现：`Infrastructure`

### 4. Repository

- 协议放 `Domain/Repositories`
- 默认实现放 `Infrastructure`
- 不把 `MihomoAPIClient` 暴露给 ViewModel 或 Feature

### 5. 资源与脚本

- `Scripts` 不应依赖过时资源路径
- 资源路径修改时，必须同步更新：
  - `Package.swift`
  - `Scripts`
  - `README`
  - 运行时资源加载代码

---

## 当前仍保留的技术折中

这份架构不是“绝对纯粹”的 Clean Architecture，而是工程化折中。

当前仍保留的现实妥协包括：

- 部分 View 仍直接观察 `AppSession`
- `AppSession` 仍然比较大
- 纯 SwiftPM 下对 `xcassets/xcstrings` 的支持采用运行时原文件读取

这些不是缺陷，而是当前构建方式和 macOS 能力集成下的现实平衡。

---

## 后续演进建议

如果后续继续优化，优先顺序建议是：

1. 给关键 UseCase、ViewModel 补测试
2. 继续减少 Feature 对 `AppSession` 的直接读取
3. 将部分 `AppSession+Extensions` 继续实体化为 coordinator/service
4. 如果未来接受 Xcode Project，则再把资源链路切回更标准的 Apple 编译资源模式
