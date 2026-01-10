# VSCode-Switcher

> 一个极小的 macOS 工具：列出已打开的 VSCode 窗口，并提供一键切换聚焦到前台；支持为窗口设置编号并用 Option+数字快速切换。

## 1. 项目概述

### 目标与背景
- 目标：在 VSCode 多窗口/多实例场景下，提供“窗口列表 + 一键切换”的显式入口，降低在 Dock/⌘`/Mission Control 中找窗口的成本。

### 范围
- **范围内:**
  - 列出系统中已运行的 VSCode / VSCode Insiders 的窗口列表（标题 + 应用名）
  - 点击“Switch”将目标窗口激活并置前
  - 权限缺失时的引导与跳转系统设置
- **范围外:**
  - 跨 Space 的强制切换（受系统设置影响，且涉及私有 API，不做）
  - VSCode 内部标签页/编辑器级别切换（不做）

### 干系人
- **负责人:** 本仓库维护者

## 2. 模块索引

| 模块名称 | 职责 | 状态 | 文档 |
|---------|------|------|------|
| VSCode-Switcher | UI + 全局快捷键 + 窗口枚举/聚焦 | 开发中 | [modules/vscode-switcher.md](modules/vscode-switcher.md) |

## 3. 快速链接
- [技术约定](../project.md)
- [架构设计](arch.md)
- [API 手册](api.md)
- [数据模型](data.md)
- [变更历史](../history/index.md)
