# 技术设计: 侧栏默认窄窗口 + Dock 按需展开

## 技术方案

### UI 展开策略
- 当 `dockedWindowTitle == nil` 时，仅渲染侧栏（不创建右侧 Dock 区域）
- 当 `dockedWindowTitle != nil` 时，渲染 `HSplitView`（左侧固定窄栏 + 右侧 Dock 区域）

### 全局热键持续生效
- `HotKeyManager` 使用 Carbon HotKey，本身是全局热键（不依赖本窗口是否激活）
- 为避免用户关闭窗口导致 App 退出，增加：
  - `applicationShouldTerminateAfterLastWindowClosed` 返回 `false`

