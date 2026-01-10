# 变更提案: 移除 Dock 右侧区域（回归纯侧栏）

## 需求背景

Dock 模式会在切换窗口时调整 VSCode 窗口位置/大小，并引入右侧显示区域。当前迭代希望界面始终保持“系统设置”式的纯左侧列表：整个窗口只保留侧栏区域，不再展示/维护右侧 Dock，也不再尝试对齐/停靠 VSCode 窗口。

## 变更内容
1. UI 改为单列侧栏：窗口列表占满整个窗口
2. 删除 Dock 相关的状态、坐标采集与窗口几何设置逻辑

## 影响范围
- `VSCode-Switcher/ContentView.swift`
- `VSCode-Switcher/VSCode_SwitcherApp.swift`
- 文档：移除 Dock 模式描述

