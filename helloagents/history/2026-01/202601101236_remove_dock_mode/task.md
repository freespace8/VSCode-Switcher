# 任务清单: 移除 Dock 右侧区域（回归纯侧栏）

目录: `helloagents/history/2026-01/202601101236_remove_dock_mode/`

---

## 1. UI
- [√] 1.1 移除右侧 Dock 区域，仅保留侧栏窗口列表。

## 2. 逻辑清理
- [√] 2.1 删除 DockHostView/坐标采集与 Dock 状态。
- [√] 2.2 删除窗口几何设置（Position/Size）相关实现。

## 3. 验证
- [ ] 3.1 手工：切换窗口后 VSCode 不再被移动/缩放。

