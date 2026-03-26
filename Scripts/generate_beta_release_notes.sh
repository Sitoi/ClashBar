#!/usr/bin/env bash

set -euo pipefail

if [[ $# -lt 2 || $# -gt 3 ]]; then
  echo "Usage: $0 <tag> <version> [output_path]" >&2
  exit 1
fi

tag="$1"
version="$2"
output_path="${3:-release.md}"
source_branch="${SOURCE_BRANCH:-beta}"

if [[ -z "${GITHUB_REPOSITORY:-}" ]]; then
  echo "GITHUB_REPOSITORY is required" >&2
  exit 1
fi

commit_sha="$(git rev-parse --short HEAD)"
commit_subject="$(git log -1 --pretty=%s)"
commit_date="$(git log -1 --date=iso-strict --pretty=%cd)"
repo_url="https://github.com/${GITHUB_REPOSITORY}"
download_base="${repo_url}/releases/download/${tag}"

cat >"$output_path" <<EOF
## Beta 预览

该构建来自 \`${source_branch}\` 分支最新提交，CI 每次成功后都会原地更新这个 beta 发布通道。

- 版本号：\`${version}\`
- 提交：\`${commit_sha}\` ${commit_subject}
- 提交时间：${commit_date}

### 📥 下载地址 (Downloads)

请根据您的 Mac 处理器芯片选择对应的版本下载（普通用户建议下载带有 **[内置内核]** 的版本）：

| 🖥 平台架构 (Architecture) | 📦 内置 Mihomo 内核 (默认推荐) | 🛠️ 无内核纯净版 (适合高阶用户) |
| :--- | :--- | :--- |
| ![Apple Silicon](https://img.shields.io/badge/Apple_Silicon-M系列芯片-0071E3?style=flat-square&logo=apple&logoColor=white) | [ClashBar-${version}-apple-silicon.dmg](${download_base}/ClashBar-${version}-apple-silicon.dmg) | [ClashBar-${version}-apple-silicon-no-core.dmg](${download_base}/ClashBar-${version}-apple-silicon-no-core.dmg) |
| ![Intel](https://img.shields.io/badge/Intel-x86__64-0071C5?style=flat-square&logo=intel&logoColor=white) | [ClashBar-${version}-intel.dmg](${download_base}/ClashBar-${version}-intel.dmg) | [ClashBar-${version}-intel-no-core.dmg](${download_base}/ClashBar-${version}-intel-no-core.dmg) |
EOF
