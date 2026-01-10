# 技术设计: 窗口列表交互增强（拖拽排序 / 点击激活 / 别名 / 新窗口追加）

## 技术方案

### 核心技术
- SwiftUI（List 行交互、拖拽、右键菜单/弹窗）
- AppKit / Accessibility（窗口枚举与聚焦：沿用现有 `VSCodeWindowSwitcher`）
- UserDefaults（持久化窗口顺序与别名）

### 实现要点

#### 1) 顺序模型：让“新窗口追加”与“热键绑定”稳定
现状：
- `listOpenVSCodeWindows()` 会做稳定排序（按 appDisplayName/bundleIdentifier，再按 title）。
- `listOrderedVSCodeWindows()` 仅在 `UserDefaults` 中存在已保存顺序时，才会将“新窗口”追加到底部；当顺序为空时，会直接返回排序后的列表，导致新窗口可能插入并引起热键漂移。

改进（最小且一致）：
- 在 `VSCodeWindowSwitcher.listOrderedVSCodeWindows()` 内部建立/维护顺序：
  1. 若 `loadWindowOrder()` 为空：用当前窗口列表的 `id` 初始化顺序并持久化（建立“稳定顺序”的起点）。
  2. 每次列出窗口时：按已保存顺序拼装 `ordered`；对未出现在顺序中的 `id`（新窗口）统一追加到末尾。
  3. 若发现追加了新窗口（order 发生变化）：将扩展后的顺序写回 UserDefaults，确保“追加”的语义在后续 refresh/hotkey 中保持一致。

约束：
- 不做复杂清理/GC；顺序数组允许包含已关闭窗口的旧 id（读取时自然跳过），避免因权限/暂态问题误删用户顺序。

#### 2) 点击激活：整行命中，但排除拖拽手柄
现状：
- 行内 `HStack` 没有撑满整行，导致右侧空白可能不可点击。
- `onTapGesture` 绑定在整行内容上，拖拽手柄区域也可能误触发激活。

改进：
- 将行拆成两块：`DragHandle`（仅负责拖拽） + `RowActionArea`（负责激活）。
- `RowActionArea` 明确撑满剩余宽度：`frame(maxWidth: .infinity, alignment: .leading)` + `contentShape(Rectangle())`，保证右侧空白命中。
- 激活触发使用 `Button`（`.buttonStyle(.plain)`），避免手势竞争与可访问性问题；拖拽区域不附加 tap 行为。

#### 3) 别名：最小持久化与最小 UI 入口
数据存储（建议）：
- 新增 `UserDefaults` 键：`VSCodeSwitcher.windowAliases`
- 值类型：`[String: String]`（key = `VSCodeWindowItem.id`，value = alias）

接口形态（建议放在 `VSCodeWindowSwitcher`）：
- `windowAlias(for:) -> String?`
- `setWindowAlias(_:for:)`（nil/空串表示清空）
- `loadWindowAliases() / saveWindowAliases(_:)`（内部）

UI 入口（两种可选，推荐 A）：
- A（推荐，最少冲突）：行右键菜单 `contextMenu` → “编辑别名/清空别名”，弹出 `alert + TextField` 或小 `sheet` 输入。
  - 优点：不破坏“左键整行激活”的语义；交互成本低；实现简单。
  - 缺点：需要用户使用右键/触控板二指点按。
- B：行内显示一个“编辑”小按钮（如 `pencil`），点击进入行内 `TextField` 编辑并保存。
  - 优点：显式可发现。
  - 缺点：按钮占用区域会与“整行可点”产生例外，需要明确交互边界。

编辑时刷新干扰：
- 方案：编辑态期间暂停 `refresh()` 对 `windows` 的重建（仅更新 `activeWindow`），避免输入焦点丢失。
- 触发点：当 UI 进入别名编辑态，通知 ViewModel（例如 `viewModel.beginEditingAlias(id:) / endEditingAlias()`）。

#### 4) 列表显示策略：标题与别名的展示
展示规则（建议）：
- 主行：若存在 alias 且非空，展示 alias；否则展示 `window.title`
- 副行：展示 `window.title`（当 alias 存在且与 title 不同）或展示热键标签（保持现有信息密度）

（可选）移除 `prefix(10)` 限制，显示全部窗口；热键标签仍仅对前 10 项显示，避免用户误解“只能看 10 个”。

## 架构决策 ADR

### ADR-002: 窗口别名的持久化键使用 `VSCodeWindowItem.id`
**上下文:** 需要把别名绑定到“列表中看到的某个窗口”，并与顺序/热键使用同一标识体系。  
**决策:** `windowAliases` 使用 `VSCodeWindowItem.id` 作为 key（本质是 `bundleIdentifier + pid + windowNumber/title`）。  
**理由:** 与现有顺序持久化（windowOrder）保持一致；实现最小；可在 VSCode 进程存活期间稳定。  
**替代方案:** 使用更复杂的窗口指纹（如解析 title/workspace） → 拒绝原因: 不可靠且引入维护成本，不符合 KISS。  
**影响:** VSCode 重启或 `windowNumber` 缺失/复用时可能丢失/错绑别名（接受，且不影响安全性/稳定性）。

### ADR-003: 在 `listOrderedVSCodeWindows()` 内维护“新窗口追加”的顺序持久化
**上下文:** 热键逻辑与 UI 都依赖 `listOrderedVSCodeWindows()`，但当顺序为空时目前会退回排序列表导致热键漂移。  
**决策:** 在顺序为空时初始化顺序；发现新窗口时将其追加并写回 UserDefaults。  
**理由:** 让顺序语义在 UI 与热键入口统一且稳定；改动局部且可验证。  
**替代方案:** 仅在 UI 侧维护临时顺序 → 拒绝原因: 热键仍会使用不一致顺序，问题不闭环。  
**影响:** 会在窗口列表变化时写入少量 UserDefaults（频率可控，开销可忽略）。

## 数据模型
- 新增：`VSCodeSwitcher.windowAliases`（`[String: String]`）
- 复用：`VSCodeSwitcher.windowOrder`（`[String]`）

## 安全与性能
- **安全:** 不新增权限；别名仅为用户输入字符串；不外传；AX 调用保持“失败可恢复”。
- **性能:** 别名与顺序读写为 O(n)（n=窗口数），窗口数通常很小；仅在 refresh 或窗口变化时写回。

## 测试与部署
- 手工验收为主（见 task.md）。
- 构建验证：`xcodebuild -project VSCode-Switcher.xcodeproj -scheme VSCode-Switcher build`

