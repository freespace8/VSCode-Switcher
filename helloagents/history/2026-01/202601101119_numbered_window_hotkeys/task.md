# 任务清单: 窗口编号与 Option+数字 快速切换

目录: `helloagents/history/2026-01/202601101119_numbered_window_hotkeys/`

---

## 1. 编号映射（存储/业务）
- [√] 1.1 在 `VSCode-Switcher/VSCode_SwitcherApp.swift` 增加编号映射存储：`VSCodeSwitcher.numberMapping`（`[Int: WindowBookmark]` JSON）。
- [√] 1.2 实现 `windowNumberAssignment(for:)`、`setWindowNumberAssignment(_:for:)`、`focus(number:)`。

## 2. 快捷键
- [√] 2.1 注册 `Option+1..9` 热键并派发为 `focusNumber`。
- [√] 2.2 若编号未映射，不做任何操作（安全失败）。

## 3. UI
- [√] 3.1 在 `VSCode-Switcher/ContentView.swift` 的每行窗口增加编号菜单（1~9/清空）。

## 4. 验证
- [√] 4.1 `xcodebuild` 编译通过。
- [ ] 4.2 手工：绑定编号后 `Option+N` 可切换；清空后不触发；冲突覆盖符合预期。

---

## 任务状态符号
- `[ ]` 待执行
- `[√]` 已完成
- `[X]` 执行失败
- `[-]` 已跳过
- `[?]` 待确认
