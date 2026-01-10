# 任务清单: 项目评审与改进路线图（VSCode-Switcher）

目录: `helloagents/plan/202601101943_project_review_improvement_roadmap/`

---

## 0. 需求确认（避免盲改工程配置）
- [ ] 0.1 确认目标最低 macOS 版本范围（例如 13/14/15/…），用于决定是否调整 `MACOSX_DEPLOYMENT_TARGET`（验证 why.md#需求-工程配置不阻碍构建与运行）。
- [ ] 0.2 确认热键语义取舍：保持“列表前 10 项自动编号（⌃⌥1..0）”还是恢复“手动编号映射”（默认建议前者，符合 KISS）（验证 why.md#需求-热键语义与-ui-一致）。

## 1. 语义对齐：删除遗留编号映射（推荐路径）
- [ ] 1.1 在 `VSCode-Switcher/VSCode_SwitcherApp.swift` 删除未被当前热键路径使用的编号映射逻辑（`numberMapping`/`WindowBookmark` 若仅为映射服务、`windowNumberAssignment`/`setWindowNumberAssignment`/`focus(number:)` 等），确保无引用残留、无行为变化（验证 why.md#需求-热键语义与-ui-一致）。
- [ ] 1.2 在 `VSCode-Switcher/ContentView.swift` / `VSCodeWindowsViewModel` 移除对应的 ViewModel API（若已无 UI 使用），保持 UI 只展示“前 10 项热键标签”（验证 why.md#需求-热键语义与-ui-一致）。
- [ ] 1.3 更新知识库文档，清除“手动编号映射”的历史表述并与当前实现一致：
  - `helloagents/wiki/modules/vscode-switcher.md`
  - `helloagents/wiki/data.md`
  - `helloagents/CHANGELOG.md`

## 2. 性能：减少无谓 AX 枚举与刷新频率
- [ ] 2.1 在 `VSCode-Switcher/ContentView.swift` 调整 `VSCodeWindowsViewModel.refresh()`：将 `diagnosticsSummary()` 从默认刷新移除，改为按需调用（例如 Debug-only 或按钮触发），避免每次 refresh 重复 AX 枚举（验证 why.md#需求-刷新策略不做无谓功）。
- [ ] 2.2 在 `VSCode-Switcher/ContentView.swift` 细化通知触发逻辑：`didActivateApplication` 仅更新 activeWindow；`didLaunch/didTerminate` 才做全量 refresh（验证 why.md#需求-刷新策略不做无谓功）。
- [ ] 2.3 手工验证：频繁切换应用/开关 VSCode 窗口时，本应用 CPU 占用与 UI 卡顿明显下降；列表仍能通过手动 Refresh 兜底（验证 why.md#需求-刷新策略不做无谓功）。

## 3. 可靠性：窗口 ID/顺序合并的防崩溃加固
- [ ] 3.1 在 `VSCode-Switcher/VSCode_SwitcherApp.swift` 将 `Dictionary(uniqueKeysWithValues:)` 替换为不会因重复 key trap 的实现，并明确重复处理策略（保留第一/最后一项均可，但必须一致）（验证 why.md#需求-窗口列表-顺序持久化不崩溃）。
- [ ] 3.2 （可选，按需）若实测存在 `windowNumber == nil` 的窗口：为该类窗口制定“跳过 or 弱标识”的策略，并在 `helloagents/wiki/modules/vscode-switcher.md` 明确限制（验证 why.md#需求-窗口列表-顺序持久化不崩溃）。
- [ ] 3.3 手工验证：打开多个 VSCode 窗口（含同名/Untitled 的极端情况），反复 Refresh/排序/别名编辑，不出现崩溃或列表错乱（验证 why.md#需求-窗口列表-顺序持久化不崩溃）。

## 4. 工程配置（仅在 0.1 确认后执行）
- [ ] 4.1 在 `VSCode-Switcher.xcodeproj/project.pbxproj` 将 `MACOSX_DEPLOYMENT_TARGET` 调整为确认后的目标版本；确认不影响现有 API 使用（验证 why.md#需求-工程配置不阻碍构建与运行）。
- [ ] 4.2 构建验证：`xcodebuild -project VSCode-Switcher.xcodeproj -scheme VSCode-Switcher build`（验证 why.md#需求-工程配置不阻碍构建与运行）。

## 5. 安全检查
- [ ] 5.1 复核：不新增权限、不引入 Apple Events/Automation；UserDefaults 不记录窗口内容，仅保存顺序/别名等必要信息；AX 调用失败路径可恢复（验证 how.md#安全与合规）。

## 6. 文档与历史同步（在实现完成后）
- [ ] 6.1 更新 `helloagents/wiki/arch.md`（如结构有实质变化）与 `helloagents/project.md`（如约定/构建命令有变化）。
- [ ] 6.2 更新 `helloagents/history/index.md`，并将本方案包迁移至 `helloagents/history/YYYY-MM/`（执行阶段完成后按 G11 规则）。

## 7. 可选增强（按需，不建议与核心清理混做）
- [ ] 7.1 在 `VSCode-Switcher/ContentView.swift` 增加搜索/过滤输入框，按 alias/title/appDisplayName 过滤列表（不影响顺序持久化与热键语义）。
- [ ] 7.2 在 `VSCode-Switcher/ContentView.swift` 增加“诊断信息”入口（按钮/折叠区），按需触发 `diagnosticsSummary()` 并展示，默认不计算。
- [ ] 7.3 增加状态栏（Menu Bar）入口：Show/Hide、Refresh、Open Accessibility Settings、Quit（AppKit `NSStatusBar`），解决“窗口关闭但需常驻”可发现性。
- [ ] 7.4 增加“自动平铺”开关：点击行/热键触发是否平铺可配置并持久化（默认保持现状，避免行为突变）。
- [ ] 7.5 扩展支持的 VSCode 家族 bundle id（如 VSCodium），维持白名单策略并补充文档。

---

## 任务状态符号
- `[ ]` 待执行
- `[√]` 已完成
- `[X]` 执行失败
- `[-]` 已跳过
- `[?]` 待确认
