# 技术设计: Dock 模式（左右分栏 + 右侧停靠）

## 技术方案

### 核心技术
- SwiftUI：使用 `HSplitView` 实现左右可拖动分栏
- AppKit：用 `NSViewRepresentable` 获取右侧 Dock 区域在屏幕坐标系中的矩形
- Accessibility：用 `kAXPositionAttribute` + `kAXSizeAttribute` 移动/缩放 VSCode 窗口，使其覆盖右侧 Dock 区域

### 实现要点

#### 1) 右侧 Dock 区域坐标采集
- 在右侧显示区域内放置一个不可见的 `NSView`（`DockHostView`）
- 该 view 在以下时机计算屏幕坐标并回调：
  - `layout()`
  - `NSWindow.didMoveNotification`
  - `NSWindow.didResizeNotification`
- 通过 `window.convertToScreen(convert(bounds, to: nil))` 得到 Dock 区域的 `CGRect`

#### 2) Dock 状态与更新
- `VSCodeWindowSwitcher` 内保存：
  - `dockTargetFrame`: 右侧 Dock 区域的屏幕矩形
  - `dockedBookmark`: 当前被停靠的 VSCode 窗口标识（bundle id + pid + windowNumber/title）
- 每次 `dockTargetFrame` 更新时，若存在 `dockedBookmark`，则尝试重新定位窗口（不抢焦点）

#### 3) Dock 触发点
- 用户点击列表 Switch
- 用户按 `Option+数字` 快捷键切换到已编号窗口
- 两种路径都会在聚焦窗口后设置 `dockedBookmark` 并将窗口移动/缩放到 `dockTargetFrame`

#### 4) 关键约束
- 当前实现依赖跨进程 AX 访问与窗口几何设置，要求 `ENABLE_APP_SANDBOX = NO`（Sandbox 下可能出现 `AXWindows cannotComplete`）。

## 安全与性能
- **安全:** 仅使用窗口标题与窗口编号做定位，不读取/保存窗口内容
- **性能:** Dock 更新在窗口移动/缩放与分栏拖动时触发；AX 调用为轻量操作，可接受

## 测试与部署
- 手工验收：
  - 拖动分隔条，确认 VSCode 窗口同步调整并对齐右侧区域
  - 移动/缩放本 App 窗口，确认 VSCode 窗口跟随
  - `Option+数字` 切换时，确认新的窗口会“接管”右侧区域

