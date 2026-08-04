<div align="center">

<img src="./docs/public/clashbar-logo.png" width="220" alt="ClashBar Logo" />

# ClashBar

Нативный прокси-клиент для строки меню macOS на базе `SwiftUI + AppKit`, работающий на ядре `mihomo`.  
Легковесный и стабильный — управление профилями, узлами, правилами, соединениями и системным прокси прямо из строки меню. ✨

<p align="center">
  <a href="README.md">English</a> | <a href="README_zh.md">简体中文</a> | Русский
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
  🌐 <a href="https://clashbar.sitoi.workers.dev"><strong>Документация</strong></a>
  ·
  📦 <a href="https://github.com/Sitoi/ClashBar/releases"><strong>Релизы</strong></a>
  ·
  💬 <a href="https://t.me/clashbars"><strong>Telegram</strong></a>
</p>

</div>

<p>
  <img src="./docs/public/clashbar-black.png" width="49%" alt="ClashBar Dark" />
  <img src="./docs/public/clashbar-light.png" width="49%" alt="ClashBar Light" />
</p>

## ✨ Особенности

- 🪶 **Легковесный**: Менее 15 МБ с встроенным ядром; менее 3 МБ без ядра
- 🧭 **Ориентация на строку меню**: Импорт и обновление профилей, переключение узлов, тест задержки, правила и диагностика соединений
- 🔐 **Интеграция с системой**: Системный прокси, автозапуск при входе в систему, Keychain для чувствительных данных
- 📊 **Мониторинг**: Трафик в реальном времени, активные соединения, использование памяти и фильтрация логов
- 🌍 **Многоязычность**: Английский / Упрощенный китайский (`zh-Hans`)

### 📏 Сравнение размера приложения (по данным Finder macOS, только для справки)

| Клиент | Размер |
| ---------------------- | -------: |
| ClashBar.app (Без ядра) | 3 МБ |
| ClashBar.app | 14.2 МБ |
| ClashMac.app | 75.2 МБ |
| Clash Verge.app | 128.4 МБ |
| Clash Party.app | 496.7 МБ |

## 📦 Установка

**Требования:** macOS 13+ 🍎

```sh
brew tap Sitoi/tap
brew install --cask clashbar
```

Или скачайте `.dmg` из раздела [Релизы](https://github.com/Sitoi/ClashBar/releases) и перетащите `ClashBar.app` в папку `/Программы` (`/Applications`).

Удаление:

```sh
brew uninstall --cask clashbar
# Полное удаление (включая конфигурации и данные)
brew uninstall --zap --cask clashbar
```

> [!IMPORTANT]
>
> - ⚠️ Убедитесь, что в один момент времени только один клиент на базе mihomo / Clash управляет системным прокси.
> - 📂 Работа системного прокси зависит от запакованного `.app` и разрешений автозапуска; перед использованием поместите приложение в `/Applications`.
> - 🔑 При первом включении системного прокси или автозапуска разрешите ClashBar в меню **Системные настройки → Основные → Объекты входа**.
> - 🔄 В случае сбоев переключения выключите и снова включите фоновое приложение ClashBar в объектах входа или нажмите `Restart` для перезапуска ядра в приложении.

## 🚀 Быстрый старт

1. 🖱️ Нажмите на иконку в строке меню, чтобы открыть панель
2. 📥 Выберите или импортируйте конфигурацию во вкладке Proxy
3. ▶️ Нажмите `Start` / `Restart` для запуска ядра
4. 🎛️ Выберите режим: `Rule` / `Global` / `Direct`
5. 📶 Выберите узел и проверьте задержку; убедитесь в доступности соединения перед включением системного прокси

Подробные руководства на сайте документации: 📖 [Быстрый старт](https://clashbar.sitoi.workers.dev/docs/quick-start) · [Функции](https://clashbar.sitoi.workers.dev/docs/features) · [Устранение неполадок](https://clashbar.sitoi.workers.dev/docs/troubleshooting)

## 🗺️ Обзор возможностей

| Вкладка | Описание |
| -------------- | ----------------------------------------------- |
| 🧭 Proxy | Конфигурации, режимы, системный прокси, переключение узлов, задержка и провайдеры |
| 📚 Rules | Статистика правил, фильтрация, обновление провайдеров |
| 🌐 Connections | Фильтрация и закрытие активных соединений |
| 🪵 Logs | Фильтрация по уровню логов, поиск по ключевым словам |
| ⚙️ System | Язык, строка состояния, порты, `allow-lan` / `ipv6` и др. |

📁 Директория данных: `~/Library/Application Support/clashbar`  
🧩 Встроенное ядро копируется в: `~/Library/Application Support/clashbar/core/mihomo`

## 🛠️ Разработка и сборка

```sh
# Требования: Xcode / Swift 6.2+, macOS 13+
make build                 # Сборка dist/ClashBar.app (по умолчанию без ядра)
make build WITH_CORE=1     # Сборка с встроенным ядром mihomo
make dist WITH_CORE=1      # Создание пакета app + dmg
```

## 🙌 Сообщество

- 🌐 Документация: <https://clashbar.sitoi.workers.dev>
- 💬 Telegram: <https://t.me/clashbars>
- 🐛 Issues / PRs: Будем рады вашим отзывам и пулл-реквистам!

## 👥 Участники разработки

[![Contributors](https://contrib.rocks/image?repo=Sitoi/ClashBar)](https://github.com/Sitoi/ClashBar/graphs/contributors)

## 🙏 Благодарности

Спасибо проекту [MetaCubeX/mihomo](https://github.com/MetaCubeX/mihomo) за предоставление возможностей ядра.

## ⭐ Динамика звёзд (Star History)

[![Star History Chart](https://api.star-history.com/svg?repos=Sitoi/ClashBar&type=date&legend=top-left)](https://www.star-history.com/#Sitoi/ClashBar&type=date&legend=top-left)
