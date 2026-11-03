# ClashBar 跨平台配置同步协议

> 版本：`schemaVersion = 1`
> 适用：ClashBar for macOS（Swift）↔ ClashBar for Windows（待实现）
> 传输：WebDAV（首个目标服务商：坚果云 Nutstore）

---

## 1. 设计目标

| 目标 | 说明 |
|---|---|
| **多配置可移植** | 本地所有「用户自建」的 mihomo 配置（非订阅派生）在 macOS / Windows 上格式完全一致，打包同步 |
| **设置可解释** | 各平台的原生设置存储不同（UserDefaults vs 注册表/JSON），通过 `settings.json` 做中间层 |
| **低流量** | 只同步 1 个包 + 1 个元信息文件，避免把订阅缓存、规则缓存、mmdb 推到云端 |
| **原子提交** | 多文件打成一个 zip 单次 `PUT`，不会出现「配置传完、设置没传完」的半套状态 |
| **无锁依赖** | 坚果云不支持 `LOCK`/`UNLOCK`，冲突靠时间戳而非 WebDAV 锁 |

### 明确不同步的内容

```
config/ASN.mmdb          8.3 MB   各平台 geo 数据自动下载
config/cache.db          256 KB   mihomo 运行时缓存
config/proxy/*.yaml      数百 KB   订阅节点缓存，各平台各自拉取
config/rule/*.yaml       数 MB     规则缓存，各平台各自拉取
core/mihomo              56 MB     内核二进制，各平台自行安装
logs/*                            本地日志
```

**这些文件平台相关或体积过大，同步会导致流量超限和版本错乱。**

### 订阅派生的配置也不同步内容，只同步订阅本身

本地 `config/` 目录下，文件名出现在 `settings.json.subscriptions[].name` 里的 `.yaml`，
即由某个订阅 URL 拉取生成的配置，**不参与打包**。原因：

- 订阅内容本来就该由每台设备各自按 URL 拉取，云端存一份没有收益
- 多设备更新时间不同步，互相覆盖只会让某一端拿到过期节点列表，还白耗流量

同步的是 `subscriptions[]` 里的 URL / 自动更新开关 / 间隔，接收端据此自行拉取。
判定依据是运行时的 `remoteConfigSubscriptions`（key = 文件名），而不是文件内容特征。

---

## 2. 远端目录结构

```
<webdav-root>/ClashBar/
├── bundle.zip       # 同步包：settings.json + config/<name>.yaml × N（必需）
└── meta.json        # 元信息：用于冲突判定、变化探测、包完整性校验（必需）
```

`bundle.zip` 内部结构：

```
settings.json              # 与第 3 节 schema 一致
config/
├── ClashBar.yaml           # 用户自建配置，文件名即本地文件名
└── 宝可梦星云.yaml           # 若此名字出现在 subscriptions[] 中则不会出现在这里
```

> **为什么是 zip 不是散装文件**：同步的是「本地当前所有非订阅配置」，数量是可变的
> （0 个到 N 个）。散装文件布局下，WebDAV 没有目录级 diff，要知道该删哪个旧文件只能
> `PROPFIND` 全量枚举——而坚果云对 `PROPFIND` 限流最严。打包后，远端内容完全由
> `meta.json` 的清单决定，少了谁 zip 里就没有谁，不需要额外请求去发现要删除的文件。
>
> 配置数量为 0（用户只用订阅）时 zip 里没有 `config/` 目录，只有 `settings.json`。

> 建议 `<webdav-root>` 使用独立目录，例如 `https://dav.jianguoyun.com/dav/ClashBar/`。
> 不要把文件直接放在 WebDAV 根目录，避免和用户其他文件混淆。

### 2.1 旧布局（≤0.3.7-dev，扁平文件）

```
<webdav-root>/ClashBar/
├── config/
│   └── <selectedConfig>.yaml
├── settings.json
└── meta.json          # 无 bundleSha256 字段
```

新版本靠 `meta.json` 是否含 `bundleSha256` 区分新旧布局，详见第 9 节。

---

## 3. `settings.json` Schema

```json
{
  "schemaVersion": 1,
  "updatedAt": "2026-10-30T15:45:00Z",
  "updatedBy": "macbook-air",
  "selectedConfig": "ClashBar.yaml",

  "core": {
    "mode": "rule",
    "allowLan": true,
    "ipv6": false,
    "tcpConcurrent": true,
    "tunEnabled": false,
    "logLevel": "info",
    "ports": {
      "http": 0,
      "socks": 0,
      "mixed": 7890,
      "redir": 0,
      "tproxy": 0
    }
  },

  "subscriptions": [
    {
      "name": "ikuuu.yaml",
      "url": "https://example.com/sub?token=xxx",
      "autoUpdate": true,
      "intervalHours": 6,
      "lastUpdateAt": "2026-10-30T14:20:00Z"
    }
  ],

  "systemProxy": {
    "enabledOnQuit": false,
    "exceptions": [
      "localhost",
      "127.*",
      "10.*",
      "172.16.*",
      "192.168.*",
      "100.64.0.0/10"
    ]
  },

  "ui": {
    "language": "zh-Hans",
    "appearance": "system"
  },

  "ssidRules": [
    {
      "ssid": "CompanyWiFi",
      "action": "direct"
    }
  ]
}
```

`settings.json` 现在只存在于 `bundle.zip` 内部，不再单独出现在 WebDAV 根目录。

### 字段说明

| 字段 | 类型 | 必需 | 平台差异 |
|---|---|---|---|
| `schemaVersion` | Int | ✅ | 协议版本，当前 `1` |
| `updatedAt` | ISO8601 | ✅ | 写入时间，用于冲突判定 |
| `updatedBy` | String | ✅ | 设备名（`hostname`） |
| `selectedConfig` | String | ✅ | 当前激活的配置文件名（可以是本节打包的，也可以是订阅派生的） |
| `core.mode` | String | ✅ | `rule` / `global` / `direct` |
| `core.allowLan` | Bool | ✅ | mihomo `allow-lan` |
| `core.ipv6` | Bool | ✅ | mihomo `ipv6` |
| `core.tcpConcurrent` | Bool | ✅ | mihomo `tcp-concurrent` |
| `core.tunEnabled` | Bool | ✅ | TUN 模式 |
| `core.logLevel` | String | ✅ | `silent`/`error`/`warning`/`info`/`debug` |
| `core.ports.*` | Int | ✅ | `0` 表示不监听 |
| `subscriptions[]` | Array | ✅ | 空数组表示无订阅；`name` 即对应本地文件名，用于判定该文件是否排除在打包之外 |
| `subscriptions[].name` | String | ✅ | 显示名 = 本地文件名，作为唯一键 |
| `subscriptions[].url` | String | ✅ | 订阅地址（含 token） |
| `subscriptions[].autoUpdate` | Bool | ✅ | 是否自动更新 |
| `subscriptions[].intervalHours` | Int | ✅ | 更新间隔，最小 1 |
| `subscriptions[].lastUpdateAt` | ISO8601? | ❌ | 可为 null |
| `systemProxy.enabledOnQuit` | Bool | ✅ | 退出时是否保留系统代理 |
| `systemProxy.exceptions[]` | Array<String> | ✅ | 绕过列表，支持 `*` 通配 |
| `ui.language` | String | ✅ | `zh-Hans` / `en` |
| `ui.appearance` | String | ✅ | `system` / `light` / `dark` |
| `ssidRules[]` | Array | ✅ | macOS 专属逻辑，Windows 可忽略 |
| `ssidRules[].ssid` | String | ✅ | Wi-Fi 名称 |
| `ssidRules[].action` | String | ✅ | `direct` / `proxy` |

### 兼容性原则

- **新增字段**：必须带默认值，旧版本读到未知字段应忽略（不要报错）
- **删除字段**：不删除，标记 `deprecated`，保留至少 2 个版本
- **枚举值**：未知值按默认值处理（例如未知 `mode` 按 `rule`）
- **时间格式**：统一 ISO8601 UTC，`2026-10-30T15:45:00Z`

---

## 4. `meta.json`

用于变化探测、冲突判定、以及解包前的完整性与白名单校验。这是 WebDAV 根目录下
**唯一**不在 zip 里的文件，体积始终很小（几百字节到几 KB，取决于配置数量），
同步前只需 `GET` 它就能判断要不要下载整个 `bundle.zip`。

```json
{
  "schemaVersion": 1,
  "deviceName": "macbook-air",
  "updatedAt": "2026-10-30T15:45:00Z",
  "appVersion": "0.3.7",
  "platform": "macOS",
  "bundleSha256": "7e1c...",
  "bundleBytes": 40570,
  "settingsSha256": "9c1b...",
  "configs": [
    { "name": "ClashBar.yaml", "sha256": "3f2a...", "bytes": 24282 },
    { "name": "ccs-bytevirt-199.yaml", "sha256": "a1b2...", "bytes": 20753 }
  ]
}
```

| 字段 | 用途 |
|---|---|
| `updatedAt` | **冲突判定主依据** |
| `bundleSha256` | 下载后校验 `bundle.zip` 没有被截断/篡改；为空表示旧布局（见第 9 节） |
| `bundleBytes` | 显示用，解压前的粗略大小预期 |
| `configs[]` | **解包白名单**：声明的每个文件名/大小/哈希必须与 zip 内条目逐一对应，多一个少一个都拒绝 |
| `settingsSha256` | 解包后校验 `settings.json` |
| `deviceName` | UI 显示"最后修改设备" |
| `platform` | `macOS` / `Windows` |

> **为什么 `configs[]` 要做白名单而不是只核对总哈希**：zip 包的「整体哈希对得上」只能证明
> 没被篡改，不能证明条目本身是安全的（例如一个条目是指向 `/etc/passwd` 的符号链接）。
> 解包前逐条核对声明的文件名集合，再在解压后核对每个文件的哈希，两层都不能省。

> **为什么用 SHA256**：`updatedAt` 会因"打开设置页点保存"而变化，但内容可能没变。用哈希可以跳过无变化的同步，节省坚果云流量。

---

## 5. 同步协议

### 5.1 上传（Push）

```
1. GET meta.json                         → 判断远端是否为旧布局（见 5.5）
2. 收集本地快照                           → 非订阅的 config/*.yaml + settings
3. 打包：ditto -c -k --norsrc --noextattr --noqtn --zlibCompressionLevel 9
         <暂存目录>/{settings.json, config/*.yaml} → bundle.zip
4. 计算 bundle 与 settings 的 sha256，连同配置清单组成新 meta
5. MKCOL ClashBar/     → 忽略 405（已存在）
6. PUT ClashBar/bundle.zip
7. PUT ClashBar/meta.json                ← 最后写，作为"提交标记"
8. 若上一步 1 判定远端是旧布局：
   DELETE ClashBar/config/<旧 selectedConfig>.yaml
   DELETE ClashBar/config/ClashBar.yaml
   DELETE ClashBar/settings.json
   DELETE ClashBar/config/              （清理旧布局残留，逐条 best-effort，失败不影响本次同步结果）
```

> **`meta.json` 最后写的意义**：如果中途失败（例如 `bundle.zip` 传完、`meta.json` 没传完），
> 远端 `meta.json` 仍指向上一次成功的 bundle。下次同步时本地快照与旧 meta 的哈希不一致，
> 会重新触发完整的 push，不会把半套状态当成已完成的同步。

### 5.2 下载（Pull）

```
1. GET meta.json             → 404 则视为远端为空；无 bundleSha256 走 5.2.1 旧布局分支
2. GET bundle.zip
3. 校验 sha256(bundle.zip) == meta.bundleSha256
4. 用 meta.configs[] 做白名单校验 zip 中央目录条目（见 5.4），通过才解压
5. ditto -x -k bundle.zip → 临时目录
6. 校验 settings.json 与每个 config/*.yaml 的 sha256 == meta 中声明的值
7. 逐个配置备份本地同名文件为 <name>.bak-sync-<timestamp>，再写入
8. 按 settings.core.* 应用运行参数（端口/模式等）
```

#### 5.2.1 旧布局（≤0.3.7-dev）拉取

```
1. GET settings.json                      → 读 selectedConfig 决定要下载哪个配置文件名
2. GET config/<selectedConfig>.yaml       → 404 时回退 config/ClashBar.yaml
3. 校验 sha256(config) == meta.legacyConfigSha256（即旧 meta 的 configSha256 字段）
4. 备份 + 写入本地（只有这一个文件）
```

> 本地不会被远端清单之外的文件影响：**不删除**本地存在、远端没有的配置。可能是本机
> 刚新建还没推送，也可能是别的设备删掉的，自动删除的风险大于收益，交给用户手动处理。

### 5.3 双向同步（Sync）

```
内容完全一致（settings 哈希 + 配置清单逐项相同）→ upToDate，不传输
否则：
  本地 updatedAt > 远端 updatedAt + 30s   → Push
  其余情况（含 30s 容差内）               → Pull，以远端为准
```

> **30 秒容差**：文件系统时间精度 + 网络延迟会导致误判，需要容差。
> 与旧实现的区别：拉取分支现在只下载一次——`sync()` 直接把 `pull()` 的结果带回给调用方，
> 不会被上层再触发一次重复下载。

### 5.4 zip 条目安全校验（解包前，不依赖解压结果）

自己解析 zip 中央目录（不依赖 `unzip -Z1`：它不识别 UTF-8 文件名标志，中文名会变乱码），
在**调用 `ditto -x` 之前**对每个条目做：

```
- 拒绝加密条目、ZIP64 标记（同步包不应出现，出现即视为异常）
- 条目名必须是 "settings.json" 或 "config/<单层文件名>"：
  含 "/"、".."、绝对路径、反斜杠、空名 一律拒绝
- 条目的 unix mode（zip 外部属性高 16 位）不能是符号链接
- 条目集合必须与 meta.configs[] 的文件名集合完全一致，多一个少一个都拒绝
- 累计声明的未压缩大小不能超过 32MB（zip bomb 防护）
```

全部通过才允许解压；解压后再按 5.2 步骤 6 核对哈希。两层校验缺一不可——
先后顺序决定了「恶意条目最坏情况下能不能先被写到磁盘上」。

### 5.5 从旧布局迁移

新版本 `fetchRemoteMetadata()` 读到 `meta.json` 后，用 `bundleSha256` 是否为空
区分新旧布局：

- 为空 → 旧布局，走 5.2.1 读取；本次 push 成功后清理旧布局的全部残留文件
- 非空 → 新布局，正常走 5.1/5.2

**单向兼容**：新版本能读旧布局并自动迁移；旧版本读不了新布局（它只会请求
`config/ClashBar.yaml`，拿到的是 404，因为新布局根本没有这个路径）。升级期间
避免新旧版本的客户端同时对同一个远端目录做自动同步。

### 5.6 冲突处理

坚果云不支持 `LOCK`，所以采用**「后写覆盖 + 本地备份」**策略：

```
检测到冲突（双向都有修改）
  → 拉取前备份本地同名配置为 <name>.bak-sync-<timestamp>
  → 下载远端覆盖本地
  → UI 提示用户："检测到其他设备修改，已下载远端版本，本地备份保留"
```

**不实现自动合并**：配置合并语义复杂（例如两边都改了端口），自动合并容易产生非法配置。宁可让用户手动选。

---

## 6. 坚果云（Nutstore）适配要点

### 6.1 认证

```
端点: https://dav.jianguoyun.com/dav/
认证: HTTP Basic Auth
用户名: 坚果云登录邮箱
密码:   ⚠️ 应用密码（不是登录密码）
```

获取应用密码：坚果云网页 → 账户信息 → 安全选项 → 添加应用 → 生成密码

### 6.2 限制与对策

| 限制 | 数值 | 对策 |
|---|---|---|
| 免费版月上传流量 | 1 GB | 只同步 `bundle.zip` + `meta.json`；N 份本地配置压缩后通常数十 KB |
| 免费版月下载流量 | 3 GB | 同上；`meta.json` 很小，可频繁探测而不下载全量 |
| `PROPFIND` 频率限制 | 较严 | 不使用 `PROPFIND`：bundle 是否要删文件完全由其内部条目决定，无需列目录 |
| 不支持 `LOCK`/`UNLOCK` | — | 用时间戳 + SHA256 判冲突 |
| `MKCOL` 已存在返回 | `405` | 视为成功 |
| 单文件大小 | 有限制 | 本协议对 `bundle.zip` 解压后设 32MB 上限，远低于限制 |

### 6.3 请求频率建议

- 自动同步间隔 **≥ 5 分钟**
- 连续失败后指数退避（1min → 5min → 15min → 1h）
- 遇到 `503` / `429` 立即停止本次同步，等下一轮

---

## 7. 各平台实现映射

### 7.1 macOS（Swift）

| settings.json 字段 | 本地来源 |
|---|---|
| `core.*` | `AppViewModel.EditableSettingsSnapshot` |
| `subscriptions[]` | `clashbar.config.remote.subscriptions.v2`（UserDefaults JSON），其 key 也用于从打包列表中排除对应的 `.yaml` |
| `systemProxy.exceptions[]` | `clashbar.system_proxy.exceptions.v1` |
| `ui.language` | `clashbar.ui.language` |
| `ui.appearance` | `clashbar.ui.appearance.mode` |
| `ssidRules[]` | `clashbar.ssid.strategy.rules.v1` |
| `selectedConfig` | `clashbar.config.selected.filename` |
| 打包的配置清单 | `ConfigDirectoryManager.scanConfigFiles` 扫描结果，过滤掉订阅文件名 |

打包与解包不直接操作 Foundation API，而是 `Process` 调用系统自带的 `/usr/bin/ditto`
（`-c -k --norsrc --noextattr --noqtn` 打包，`-x -k` 解包）：macOS 没有原生 zip 容器 API，
引入第三方 zip 库对这个体量的功能不划算。

### 7.2 Windows（待实现）

| settings.json 字段 | 建议本地来源 |
|---|---|
| `core.*` | 与 mihomo `config.yaml` 双向映射 |
| `subscriptions[]` | 应用自己的 `subscriptions.json` |
| `systemProxy.exceptions[]` | Windows 注册表 `ProxyOverride` |
| `ui.language` / `ui.appearance` | 应用设置文件 |
| `ssidRules[]` | 忽略（Windows 无对应概念）|
| 打包/解包 | .NET 自带 `System.IO.Compression.ZipFile`，无需额外依赖 |

### 7.3 mihomo 配置处理

`config/<name>` **直接原样同步**，不做任何转换：

- macOS 和 Windows 上的 mihomo 使用**完全相同的 YAML 格式**
- 但要注意 **端口一致性**：`mixed-port` 等字段在 `settings.core.ports` 里也有，必须保持一致
- 同步后需重启内核才能生效

---

## 8. 安全说明

> **当前决策：不加密**（与 v2rayN 备份行为一致）

同步到云端的文件包含：

- 订阅 URL 及 token
- 本地自建配置里的节点密码 / UUID（订阅派生的配置内容本身不上传，但 URL 本身可能含 token）
- 系统代理配置

**必须遵守的约束：**

1. 坚果云**应用密码单独保管**，不要复用登录密码
2. 不要把同步目录设为公开分享
3. 传输层由 HTTPS 保护（坚果云强制 TLS），但**静态存储是明文**
4. 解包前必须完成第 5.4 节的条目白名单校验，不能假设对端写入的 `bundle.zip` 是良性的
   （哪怕远端只有自己的设备在写，中间人篡改或账号被盗用的情况下这个假设也不成立）
5. 若未来需要加密，建议在 `settings.json` 外层加 AES-GCM 封装，`bundle.zip` 改为 `bundle.zip.enc`

---

## 9. 版本演进

| schemaVersion | 变更 |
|---|---|
| 1 | 初始版本 |

**未升版的行为变更**（均不改变 `schemaVersion`，因为字段都是新增/新增可选，不是破坏性变更）：

- **未发版（远端布局：扁平文件 → bundle.zip）**：配置从固定 `config/ClashBar.yaml` 单文件，
  改为「本地所有非订阅配置」打包进 `bundle.zip`；`meta.json` 新增 `bundleSha256` / `bundleBytes` /
  `configs[]`，原 `configSha256` 重命名为内部字段 `legacyConfigSha256`（JSON 键名不变，仍是
  `configSha256`，只在旧布局下有意义）。**双向兼容只保证单向**：新版本能读旧布局并自动迁移
  （见 5.5），旧版本读不了新布局（它只会请求 `config/ClashBar.yaml` 和根目录 `settings.json`，
  均拿到 404）。升级期间避免新旧版本混用同一个远端目录。
- **未发版（远端路径变更，在 bundle.zip 之前的一次中间改动，已被上条取代）**：配置文件名从固定
  `config/ClashBar.yaml` 改为 `config/<selectedConfig>`。
- **未发版**：`sync` 的拉取分支只下载一次（此前上层会重复 `pull()` 一次，多算一次流量）。
- **未发版**：订阅派生的配置文件（文件名出现在 `subscriptions[]` 中）不再参与同步内容，
  只同步订阅的 URL/设置。

**升级规则**：
- 高版本写入、低版本读取时，忽略未知字段，保留原值回写（防止降级丢失数据）
- `schemaVersion` 不兼容变更时才 +1；新增可选字段不 +1
