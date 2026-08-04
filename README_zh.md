<div align="center">

<img src="./docs/public/clashbar-logo.png" width="220" alt="ClashBar Logo" />

# ClashBar

原生 macOS 菜单栏代理客户端，基于 `SwiftUI + AppKit`，由 `mihomo` 驱动。  
轻量、稳定，在菜单栏完成配置、节点、规则、连接与系统代理管理。 ✨

<p align="center">
  <a href="README.md">English</a> | 简体中文 | <a href="README_ru.md">Русский</a>
</p>

<p>
  <img alt="Platform" src="https://img.shields.io/badge/macOS-13%2B-111111?style=flat-square&logo=apple" />
  <img alt="Swift" src="https://img.shields.io/badge/Swift-6.2-F05138?style=flat-square&logo=swift" />
  <img alt="Build" src="https://img.shields.io/badge/Build-SwiftPM-0A84FF?style=flat-square" />
  <img alt="i18n" src="https://img.shields.io/badge/i18n-zh--Hans%20%7C%20en-34C759?style=flat-square" />
  <a href="https://github.com/Sitoi/ClashBar/releases" target="_blank" rel="noopener noreferrer">
    <img alt="Version" src="https://img.shields.io/github/v/release/Sitoi/ClashBar?style=flat-square&logo=github" />
  </a>
  <a href="https://github.com/Sitoi/ClashBar/stargazers" target="_blank" rel="noopener noreferrer">
    <img alt="Stars" src="https://img.shields.io/github/stars/Sitoi/ClashBar?style=flat-square&logo=github" />
  </a>
  <a href="https://github.com/Sitoi/ClashBar/issues" target="_blank" rel="noopener noreferrer">
    <img alt="Issues" src="https://img.shields.io/github/issues/Sitoi/ClashBar?style=flat-square&logo=github" />
  </a>
  <a href="https://github.com/Sitoi/ClashBar/pulls" target="_blank" rel="noopener noreferrer">
    <img alt="PRs" src="https://img.shields.io/github/issues-pr/Sitoi/ClashBar?style=flat-square&logo=github" />
  </a>
  <a href="https://github.com/Sitoi/ClashBar/network/members" target="_blank" rel="noopener noreferrer">
    <img alt="Forks" src="https://img.shields.io/github/forks/Sitoi/ClashBar?style=flat-square&logo=github" />
  </a>
  <a href="https://github.com/Sitoi/ClashBar/releases" target="_blank" rel="noopener noreferrer">
    <img alt="Downloads" src="https://img.shields.io/github/downloads/Sitoi/ClashBar/total?style=flat-square&logo=github" />
  </a>
  <a href="https://github.com/Sitoi/ClashBar/commits" target="_blank" rel="noopener noreferrer">
    <img alt="Commit Activity" src="https://img.shields.io/github/commit-activity/m/Sitoi/ClashBar?style=flat-square&logo=github" />
  </a>
  <a href="https://github.com/Sitoi/ClashBar/commits" target="_blank" rel="noopener noreferrer">
    <img alt="Last Commit" src="https://img.shields.io/github/last-commit/Sitoi/ClashBar?style=flat-square&logo=github" />
  </a>
  <a href="https://github.com/Sitoi/ClashBar/blob/main/LICENSE" target="_blank" rel="noopener noreferrer">
    <img alt="License" src="https://img.shields.io/github/license/Sitoi/ClashBar?style=flat-square" />
  </a>
</p>

<p>
  🌐 <a href="https://clashbar.sitoi.workers.dev"><strong>文档站</strong></a>
  ·
  📦 <a href="https://github.com/Sitoi/ClashBar/releases"><strong>Releases</strong></a>
  ·
  💬 <a href="https://t.me/clashbars"><strong>Telegram</strong></a>
</p>

</div>

<p>
  <img src="./docs/public/clashbar-black.png" width="49%" alt="ClashBar Dark" />
  <img src="./docs/public/clashbar-light.png" width="49%" alt="ClashBar Light" />
</p>

## ✨ 特点

- 🪶 **轻量**：含 Core 约 15 MB 内；去掉 Core 约 3 MB 内
- 🧭 **菜单栏优先**：配置导入/更新、节点切换、延迟测试、规则与连接排障
- 🔐 **系统集成**：系统代理、开机启动、Keychain 敏感信息
- 📊 **可观测**：实时流量、连接、内存、日志过滤
- 🌍 **中英双语**：简体中文 / English

### 📏 体积对比（macOS Finder 显示值，仅供参考）

| 客户端                 |     体积 |
| ---------------------- | -------: |
| ClashBar.app (No Core) |     3 MB |
| ClashBar.app           |  14.2 MB |
| ClashMac.app           |  75.2 MB |
| Clash Verge.app        | 128.4 MB |
| Clash Party.app        | 496.7 MB |

## 📦 安装

**要求：** macOS 13+ 🍎

```sh
brew tap Sitoi/tap
brew install --cask clashbar
```

或从 [Releases](https://github.com/Sitoi/ClashBar/releases) 下载 `.dmg`，将 `ClashBar.app` 拖入 `/Applications`。

卸载：

```sh
brew uninstall --cask clashbar
# 同时清除数据
brew uninstall --zap --cask clashbar
```

> [!IMPORTANT]
>
> - ⚠️ 同一时间只让一个 mihomo / Clash 系客户端接管系统代理。
> - 📂 系统代理依赖打包后的 `.app` 与登录项授权；请放到 `/Applications` 后再使用。
> - 🔑 首次开启系统代理或开机启动时，在 **系统设置 → 通用 → 登录项** 允许 ClashBar。
> - 🔄 开关异常时，先在登录项中关闭再打开 ClashBar 后台项目，或在应用内 `Restart` 内核。

## 🚀 快速上手

1. 🖱️ 点击菜单栏图标打开面板
2. 📥 在 Proxy 选择或导入配置
3. ▶️ `Start` / `Restart` 启动内核
4. 🎛️ 选择模式：`Rule` / `Global` / `Direct`
5. 📶 切换节点并测速，确认可用后再开系统代理

更多说明见文档站：📖 [快速开始](https://clashbar.sitoi.workers.dev/docs/quick-start) · [功能说明](https://clashbar.sitoi.workers.dev/docs/features) · [故障排查](https://clashbar.sitoi.workers.dev/docs/troubleshooting)

## 🗺️ 功能一览

| 页面           | 内容                                            |
| -------------- | ----------------------------------------------- |
| 🧭 Proxy       | 配置、模式、系统代理、节点切换、延迟与 Provider |
| 📚 Rules       | 规则统计、筛选、Provider 更新                   |
| 🌐 Connections | 连接过滤与关闭                                  |
| 🪵 Logs        | 级别过滤、关键词检索                            |
| ⚙️ System      | 语言、状态栏、端口、`allow-lan` / `ipv6` 等     |

📁 运行时数据目录：`~/Library/Application Support/clashbar`  
🧩 内置内核会复制到：`~/Library/Application Support/clashbar/core/mihomo`

## 🛠️ 开发构建

```sh
# 依赖：Xcode / Swift 6.2+、macOS 13+
make build                 # 产出 dist/ClashBar.app（默认不含 Core）
make build WITH_CORE=1     # 打包内置 mihomo
make dist WITH_CORE=1      # app + dmg
```

## 🙌 社区

- 🌐 文档：<https://clashbar.sitoi.workers.dev>
- 💬 Telegram：<https://t.me/clashbars>
- 🐛 Issue / PR：欢迎反馈与贡献

## 👥 贡献者

[![Contributors](https://contrib.rocks/image?repo=Sitoi/ClashBar)](https://github.com/Sitoi/ClashBar/graphs/contributors)

## 🙏 致谢

感谢 [MetaCubeX/mihomo](https://github.com/MetaCubeX/mihomo) 提供内核能力。

## ⭐ Star 趋势

[![Star History Chart](https://api.star-history.com/svg?repos=Sitoi/ClashBar&type=date&legend=top-left)](https://www.star-history.com/#Sitoi/ClashBar&type=date&legend=top-left)
