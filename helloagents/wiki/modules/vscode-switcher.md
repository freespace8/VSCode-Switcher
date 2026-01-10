# 模块: VSCode-Switcher

## 职责

- 提供 macOS 窗口级的 VSCode 列表展示（标题/应用名）
- 点击行将指定 VSCode 窗口切换到前台
- 点击“排序”进入排序模式后可拖拽重排并持久化；新窗口默认追加到列表底部
- 支持为窗口设置别名（右键菜单），优先展示别名
- 支持为窗口分配 1~0 编号，并用 `⌃⌥数字` 快速切换到对应窗口（共 10 个窗口）
- `⌃⌥数字` 切换时按列表顺序聚焦对应 VSCode 窗口（不调整窗口位置/大小）
- 提供状态栏（Menu Bar）入口：显示/隐藏主窗口、刷新窗口列表、打开辅助功能设置、退出

## 关键组件（以当前代码为准）

### UI 层
- `ContentView`: 纯侧栏（header + list/empty/permission）
- `VSCodeWindowsViewModel`: 负责刷新数据、调用切换动作

### 系统交互层
- `VSCodeWindowSwitcher`
  - `listOpenVSCodeWindows()`: 通过 `AXUIElement` 拉取 VSCode 窗口列表，构造 `VSCodeWindowItem`
  - `listOrderedVSCodeWindows()`: 按 `windowOrder` 返回窗口列表；首次初始化顺序；新窗口追加到底部并写回持久化
  - `focus(window:)`: 激活应用并聚焦指定窗口（优先按 `AXWindowNumber` 匹配）
  - `handleHotKeyFocusNumber(_:)`: 热键切换入口；按列表前 10 项聚焦对应 VSCode 窗口
  - `ensureAccessibilityPermission()`: 权限检测/触发系统提示/一次性引导弹窗
  - `windowAliases()/setWindowAlias`: 读写窗口别名（key 为 `VSCodeWindowItem.id`）

### 快捷键层（可选）
- `HotKeyManager`: 使用 Carbon HotKey 注册全局快捷键，转发给业务层
- `AppDelegate`: 启动时 bootstrap；接收热键回调并调用 `VSCodeWindowSwitcher`

## 关键约束/限制

- **必须权限:** “系统设置 → 隐私与安全性 → 辅助功能”授予本应用，否则无法跨进程列出/聚焦 VSCode 窗口。
- **目标应用:** 当前仅匹配 Visual Studio Code.app（`com.microsoft.VSCode`），不包含 Insiders 等变体。
- **跨 Space 行为:** 受系统设置与窗口所在 Space 影响；不使用私有 API 强制跳转 Space。
- **窗口识别:** `AXWindowNumber` 不保证永远存在；缺失时会回退按 `title` 匹配（可能误匹配同名窗口）。
- **编号映射:** 以 `bundleIdentifier + (windowNumber/title)` 做匹配；窗口关闭/重启后可能需要重新绑定。
- **顺序/别名绑定:** 使用 `VSCodeWindowItem.id`；当 `windowNumber == nil` 且 title 变化时，可能出现“顺序/别名丢失或错绑”（可接受约束）。
- **窗口几何:** 当前不会自动移动/缩放 VSCode 窗口（仅聚焦/置前）。
