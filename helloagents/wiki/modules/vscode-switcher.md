# 模块: VSCode-Switcher

## 职责

- 提供 macOS 窗口级的 VSCode 列表展示（标题/应用名）
- 点击按钮将指定 VSCode 窗口切换到前台
- 支持为窗口分配 1~9 编号，并用 `Option+数字` 快速切换到对应窗口

## 关键组件（以当前代码为准）

### UI 层
- `ContentView`: 展示窗口列表、无权限提示、空状态与刷新入口
- `VSCodeWindowsViewModel`: 负责刷新数据、调用切换动作

### 系统交互层
- `VSCodeWindowSwitcher`
  - `listOpenVSCodeWindows()`: 通过 `AXUIElement` 拉取 VSCode 窗口列表，构造 `VSCodeWindowItem`
  - `focus(window:)`: 激活应用并聚焦指定窗口（优先按 `AXWindowNumber` 匹配）
  - `ensureAccessibilityPermission()`: 权限检测/触发系统提示/一次性引导弹窗

### 快捷键层（可选）
- `HotKeyManager`: 使用 Carbon HotKey 注册全局快捷键，转发给业务层
- `AppDelegate`: 启动时 bootstrap；接收热键回调并调用 `VSCodeWindowSwitcher`

## 关键约束/限制

- **必须权限:** “系统设置 → 隐私与安全性 → 辅助功能”授予本应用，否则无法跨进程列出/聚焦 VSCode 窗口。
- **跨 Space 行为:** 受系统设置与窗口所在 Space 影响；不使用私有 API 强制跳转 Space。
- **窗口识别:** `AXWindowNumber` 不保证永远存在；缺失时会回退按 `title` 匹配（可能误匹配同名窗口）。
- **编号映射:** 以 `bundleIdentifier + (windowNumber/title)` 做匹配；窗口关闭/重启后可能需要重新绑定。
