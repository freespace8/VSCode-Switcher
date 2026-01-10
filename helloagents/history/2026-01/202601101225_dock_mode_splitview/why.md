# 变更提案: Dock 模式（左右分栏 + 右侧停靠）

## 需求背景

当前工具已能列出 VSCode 窗口并快速切换（含 Option+数字）。下一步希望把“窗口管理”和“使用窗口”尽量融合：左侧是可调整宽度的窗口列表，右侧为显示区域；当激活某个 VSCode 窗口后，让该窗口在右侧区域内呈现出“一体化”的使用体验。

> 约束：macOS 公共 API 无法把外部 App 窗口真正嵌入到本 App 的视图层级中。本方案采用 Dock 方式：通过 Accessibility API 移动/缩放 VSCode 窗口，使其覆盖在右侧显示区域上方，视觉上接近“一体化”。

## 变更内容
1. UI 改为左右分栏：左侧窗口列表，右侧为 Dock 显示区域（分隔条可拖动调整宽度）
2. 当用户在列表中切换/激活某个 VSCode 窗口（含 Option+数字）时：
   - 将该 VSCode 窗口移动并缩放到右侧 Dock 区域
   - 保持右侧区域跟随本 App 的移动/缩放实时更新
3. 提供 Release 操作，停止当前窗口的 Dock（不再跟随调整）

## 影响范围
- **模块:** VSCode-Switcher
- **文件:**
  - `VSCode-Switcher/ContentView.swift`
  - `VSCode-Switcher/VSCode_SwitcherApp.swift`
- **工程配置:**
  - `VSCode-Switcher.xcodeproj/project.pbxproj`（保持 `ENABLE_APP_SANDBOX = NO`，否则 AXWindows 可能持续 `cannotComplete`）

## 核心场景

### 需求: 左侧列表可调宽度
**模块:** VSCode-Switcher

#### 场景: 拖动分隔条
- 预期结果：左侧列表宽度变化；右侧 Dock 区域随之变化；若已停靠窗口则同步调整 VSCode 窗口大小/位置。

### 需求: Dock 到右侧显示区域
**模块:** VSCode-Switcher

#### 场景: 点击 Switch 或按 Option+数字
- 预期结果：目标 VSCode 窗口被激活，并移动/缩放到右侧 Dock 区域内。

#### 场景: 移动/缩放本 App 窗口
- 预期结果：Dock 区域位置变化时，停靠的 VSCode 窗口跟随移动/缩放，保持对齐。

## 风险评估
- **风险:** 依赖 Accessibility API；在开启 App Sandbox 的情况下可能无法稳定获取 `kAXWindowsAttribute`，导致无法停靠。
- **缓解:** 明确将 Sandbox 关闭作为当前版本约束；诊断信息与日志已覆盖常见失败码（如 `cannotComplete`）。

