# API 手册

## 概述

本项目不提供对外网络 API。核心能力来自 macOS 系统 API（Accessibility / AppKit）与内部 Swift 类型。

## 内部接口（稳定性以代码为准）
- `VSCodeWindowSwitcher.listOpenVSCodeWindows() -> [VSCodeWindowItem]`
- `VSCodeWindowSwitcher.focus(window: VSCodeWindowItem)`
- `VSCodeWindowSwitcher.focus(number: Int) -> Bool`
