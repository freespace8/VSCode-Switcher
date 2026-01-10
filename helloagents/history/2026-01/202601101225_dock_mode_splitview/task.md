# 任务清单: Dock 模式（左右分栏 + 右侧停靠）

目录: `helloagents/history/2026-01/202601101225_dock_mode_splitview/`

---

## 1. UI 分栏
- [√] 1.1 将主界面改为 `HSplitView`：左侧窗口列表、右侧 Dock 区域；分隔条可拖动调整宽度。
- [√] 1.2 右侧增加 Dock Header 与 Release 操作。

## 2. Dock 区域坐标采集
- [√] 2.1 实现 `DockHostView`（`NSViewRepresentable`）回调屏幕坐标矩形，并监听 window move/resize。

## 3. VSCode 窗口停靠
- [√] 3.1 在 `VSCodeWindowSwitcher` 中维护 `dockTargetFrame` 与 `dockedBookmark`。
- [√] 3.2 在 `focus(window:)` 与 `focus(number:)` 路径中将目标窗口移动/缩放到 Dock 区域。
- [√] 3.3 Dock 区域变化时自动调整已停靠窗口（不抢焦点）。

## 4. 验证
- [√] 4.1 `xcodebuild` 编译通过。
- [ ] 4.2 手工：拖动分隔条/移动窗口时 VSCode 能保持对齐；Release 后不再跟随。

---

## 任务状态符号
- `[ ]` 待执行
- `[√]` 已完成
- `[X]` 执行失败
- `[-]` 已跳过
- `[?]` 待确认

