# 变更提案: 侧栏默认窄窗口 + Dock 按需展开

## 需求背景

Dock 模式下右侧显示区域并非总是需要。希望应用在未选中/未停靠窗口时只展示类似“系统设置”那样的窄侧栏；当用户点击切换某个 VSCode 窗口后，再展开右侧 Dock 区域用于对齐停靠，获得更接近“一体化”的体验。

同时，快捷键应为全局生效：即使本应用窗口不在前台，也能通过 `Option+数字` 切换并停靠目标 VSCode 窗口。

## 变更内容
1. 默认只显示窄侧栏（窗口列表）
2. 当选中/切换某 VSCode 窗口并进入 Dock 时，自动展开右侧 Dock 区域
3. 关闭最后一个窗口时不退出 App，确保全局热键持续可用

## 影响范围
- `VSCode-Switcher/ContentView.swift`
- `VSCode-Switcher/VSCode_SwitcherApp.swift`

## 风险评估
- 仍依赖 Accessibility API 与非 Sandbox 配置；否则可能无法枚举窗口并 Dock。

