# 任务清单: VSCode 窗口列表与一键切换

目录: `helloagents/plan/202601101047_vscode_window_list_switch/`

---

## 1. 窗口枚举（列表数据）
- [√] 1.1 在 `VSCode-Switcher/VSCode_SwitcherApp.swift` 增加/完善 `VSCodeWindowSwitcher.listOpenVSCodeWindows()`：基于 `NSRunningApplication` + `AXUIElement(kAXWindowsAttribute)` 枚举窗口，生成 `[VSCodeWindowItem]`（对应 why.md「需求: 显示 VSCode 窗口列表」）。
- [√] 1.2 实现稳定排序（按 appDisplayName/bundleIdentifier，再按 title），确保 UI 刷新时顺序可预期。

## 2. 聚焦切换（Switch）
- [√] 2.1 在 `VSCode-Switcher/VSCode_SwitcherApp.swift` 增加/完善 `VSCodeWindowSwitcher.focus(window:)`：激活应用后重新获取窗口列表，优先按 `windowNumber` 匹配并执行 Raise/Focus（对应 why.md「需求: 一键切换窗口到前台」）。
- [√] 2.2 增加安全降级路径：`windowNumber` 缺失、同名窗口、窗口已关闭、AX 调用失败时不崩溃（必要时降级聚焦第一个窗口或直接返回）。
- [√] 2.3 处理最小化窗口：聚焦前先取消最小化（`kAXMinimizedAttribute = false`）。

## 3. 权限引导与系统设置跳转
- [√] 3.1 在 `VSCode-Switcher/VSCode_SwitcherApp.swift` 实现 `ensureAccessibilityPermission()`：未授权时触发系统权限提示，并提供“一次性”引导弹窗（对应 why.md「场景: 未授予辅助功能权限」）。
- [√] 3.2 在 `VSCode-Switcher/ContentView.swift` 增加无权限引导页：展示说明、Open System Settings、Try Again。

## 4. UI：窗口列表 + 右侧 Switch 按钮
- [√] 4.1 在 `VSCode-Switcher/ContentView.swift` 引入 `VSCodeWindowsViewModel`：负责 refresh/focus。
- [√] 4.2 实现窗口列表视图：每行左侧显示 `title`/来源应用名，右侧 `Switch` 按钮触发聚焦；支持 Refresh；无窗口时显示空状态。

## 5. 安全检查
- [√] 5.1 检查权限与数据使用：不引入 Automation/Apple Events 权限；不保存敏感信息；所有 AX 调用失败必须可恢复。

## 6. 文档更新
- [√] 6.1 更新 `helloagents/CHANGELOG.md` 的 Unreleased 条目，确保与实现一致。
- [√] 6.2 更新 `helloagents/wiki/modules/vscode-switcher.md` 与 `helloagents/wiki/arch.md`：补齐实现细节与 ADR 索引（如有新增决策）。

## 7. 验收（手工）
- [?] 7.1 未授权启动：显示引导页；“打开系统设置”可跳转；授权后刷新可列出窗口。
- [?] 7.2 打开 3+ 个 VSCode 窗口：列表完整；逐个点击 Switch 均能正确置前。
- [?] 7.3 最小化一个窗口：点击 Switch 能解除最小化并置前。
- [?] 7.4 同时运行 VSCode 与 VSCode Insiders：列表可区分来源；Switch 聚焦正确实例。

---

## 任务状态符号
- `[ ]` 待执行
- `[√]` 已完成
- `[X]` 执行失败
- `[-]` 已跳过
- `[?]` 待确认
