# 技术设计: 项目评审与改进路线图（VSCode-Switcher）

## 技术方案

### 核心原则（严格执行）
- **KISS/YAGNI**：先删后加；能删除就不改结构；能局部修就不做抽象层。
- **失败可恢复**：任何 AX/NSWorkspace 调用失败都应安全返回；不崩溃、不写坏持久化。
- **语义统一**：UI 展示、热键行为、持久化顺序三者必须使用同一套“窗口选择/排序”规则。

### 现状结构（以代码为准）
- UI：`ContentView` + `VSCodeWindowsViewModel`（MainActor，负责 refresh/聚焦/排序/别名入口）
- 系统交互：`VSCodeWindowSwitcher`（AX 枚举/聚焦/平铺/顺序&别名持久化）
- 快捷键：`HotKeyManager(Carbon)` + `AppDelegate`（全局热键 → 调用 switcher）
- 工程：Xcode project，`ENABLE_APP_SANDBOX = NO`（符合 AX 访问实际需求）

## 实现要点（按优先级）

### 1) 移除/整合遗留编号映射逻辑（语义对齐）
现状：
- 热键入口实际走 `handleHotKeyFocusNumber(_:)`，按“列表顺序前 10 项”选择窗口。
- 旧的“编号映射”（`VSCodeSwitcher.numberMapping`、`focus(number:)`、`windowNumberAssignment` 等）已不再被热键使用，UI 也不再提供配置入口；但相关代码仍保留，造成维护成本与语义噪音。

推荐（最小、最干净）：
- 明确当前产品语义：**热键 = 列表前 10 项的顺序编号（⌃⌥1..0）**，不提供自定义绑定。
- 删除未使用的映射代码与持久化键读写（不做迁移；旧值留在 UserDefaults 也无害）。
- 同步更新知识库文档（模块描述/数据模型/Changelog）以消除“曾经支持手动编号”的残留表述。

备选（更复杂，不推荐默认做）：
- 恢复“手动编号”UI，并让热键走 `focus(number:)` 的映射路径；同时还要定义映射与顺序的优先级与冲突规则。这会增加交互复杂度与数据状态面，不符合当前工具定位。

### 2) 降低 refresh 的 AX 成本（避免重复枚举）
现状：
- `VSCodeWindowsViewModel.refresh()` 会调用：
  - `listOrderedVSCodeWindows()`（内部会 `listOpenVSCodeWindows()` → AX 枚举）
  - `diagnosticsSummary()`（再次枚举 running apps + AXWindows）
  - `frontmostVSCodeWindow()`（focusedWindow）
- 这等于“每次 refresh 至少 2 次 AX 枚举 + 1 次 focusedWindow”，在系统通知频繁触发时属于浪费。

推荐（最小改动路径）：
- 将 `diagnosticsSummary()` 从“默认 refresh 计算”改为“按需计算”：
  - 选项 A：仅在 Debug 构建显示（`#if DEBUG`）或通过按钮触发。
  - 选项 B：保留函数，但 ViewModel 不再把它塞进常规刷新；需要时单独调用并缓存。
- 对通知触发的刷新做分级：
  - `didActivateApplication`：只更新 `activeWindow`（避免全量枚举）
  - `didLaunch/didTerminate`：再全量 refresh
- 保留手动 Refresh 作为兜底，不引入更复杂的 debounce/队列（除非真实观察到卡顿）。

### 3) 窗口 ID 与字典构建的防崩溃处理
现状风险点：
- `listOrderedVSCodeWindows()` 使用 `Dictionary(uniqueKeysWithValues:)`，若出现重复 id 会直接 trap。
- SwiftUI 的 `ForEach` 也依赖 `Identifiable.id` 唯一性，重复会导致渲染异常甚至崩溃。
- 当 `AXWindowNumber` 获取失败时，目前 id 回退到 `title`，在同一进程内出现相同 title（尤其是 `(Untitled)`）并非不可能。

推荐（KISS 防线）：
- **第一层（必做）**：避免 `Dictionary(uniqueKeysWithValues:)` 的致命行为：
  - 使用 `Dictionary(_:uniquingKeysWith:)` 或 `reduce(into:)` 来“保留第一项/最后一项”，确保不崩溃。
- **第二层（视风险决定）**：对 `windowNumber == nil` 的窗口采取降级策略：
  - 选项 A（更保守）：直接跳过此类窗口，不参与列表/持久化（牺牲边缘可用性换稳定）。
  - 选项 B（更温和）：在同 pid 内对重复 title 追加一个稳定但弱的 disambiguator（例如枚举序号），只保证“当前会话不崩溃”，并在文档中明确弱稳定性。

默认建议：先做第一层，实际观察到 `windowNumber == nil` 才做第二层（避免提前复杂化）。

### 4) 工程配置校正（只碰明显异常）
现状：
- `project.pbxproj` 中 `MACOSX_DEPLOYMENT_TARGET = 26.1` 看起来异常（除非维护者明确目标就是该版本线）。

推荐：
- 在改动前先确认目标受众的最低 macOS 版本（例如 13/14/15…）。
- 只要确认后再改 pbxproj；否则先把此项记录为“阻塞风险”，不做盲改。

## 安全与合规
- 不新增权限：继续仅依赖 Accessibility 权限；不引入 Apple Events/Automation。
- 不采集/外传数据：UserDefaults 仅保存窗口标识/顺序/别名，不保存窗口内容。
- AX 调用失败必须可恢复：任何 set/copy 失败都应安全返回（必要时 Debug log，Release 静默）。

## 测试与部署
- **手工验收优先**（AX/多窗口/多屏组合不适合纯单测覆盖）。
- 建议补充最小的“纯函数”单元测试（可选）：例如顺序合并算法（order + windows → ordered），不涉及 AX。
- 构建验证：`xcodebuild -project VSCode-Switcher.xcodeproj -scheme VSCode-Switcher build`

## 可选增强（按需，非本轮必做）

以下内容价值不低，但会扩大改动面；建议在“可靠性/性能清理”完成后再按需选择：
- **状态栏入口（Menu Bar）**：提供 Show/Hide、Refresh、Open Accessibility Settings、Quit，解决“关闭窗口但进程常驻”时的可发现性问题。
- **搜索/过滤**：顶部增加 search field，按 alias/title/appDisplayName 过滤（纯 UI 逻辑，风险低）。
- **平铺行为开关**：将“点击行/热键切换时是否自动平铺”做成开关并持久化（避免侵入式窗口移动）。
- **更多 bundle id 支持**：如 VSCodium 等（需确认 bundleIdentifier，保持白名单策略）。
- **UI 文案统一/国际化**：当前中英混用；建议统一语言并预留 Localizable（不影响核心逻辑）。
