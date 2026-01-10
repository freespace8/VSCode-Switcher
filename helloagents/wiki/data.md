# 数据模型

## 概述

本项目无数据库；仅使用内存模型 + UserDefaults 持久化“窗口编号映射”。

## 核心结构

### VSCodeWindowItem

用于 UI 展示与聚焦目标定位。

- `bundleIdentifier: String`（如 `com.microsoft.VSCode`）
- `pid: pid_t`（进程 ID，用于定位具体实例）
- `windowNumber: Int?`（优先匹配字段，来自 `AXWindowNumber`）
- `title: String`（窗口标题，用于展示与回退匹配）
- `appDisplayName: String?`（用于展示）

### WindowBookmark（UserDefaults 持久化）

用于窗口编号映射的窗口“书签”。

- `bundleIdentifier: String`
- `windowNumber: Int?`
- `title: String?`

## 存储键

- `VSCodeSwitcher.numberMapping`：窗口编号映射（`[Int: WindowBookmark]` JSON 编码）
- `VSCodeSwitcher.accessibilityAlertShown`：是否已展示过一次性权限提示
