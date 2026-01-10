# 技术设计: VSCode 窗口列表与一键切换

## 技术方案

### 核心技术
- SwiftUI（UI）
- AppKit（激活应用/打开系统设置）
- ApplicationServices / Accessibility（枚举与聚焦跨进程窗口）

### 实现要点

#### 1) 窗口枚举（列表数据来源）
- 目标应用限定为 `supportedBundleIdentifiers`（默认包含 `com.microsoft.VSCode` 与 `com.microsoft.VSCodeInsiders`）
- 使用 `NSRunningApplication.runningApplications(withBundleIdentifier:)` 获取运行实例
- 对每个实例：
  - `AXUIElementCreateApplication(pid)` 创建 AX 应用元素
  - 读取 `kAXWindowsAttribute` 得到窗口数组
  - 对每个窗口：
    - 读取 `kAXTitleAttribute` 作为展示标题（缺失时用占位）
    - 读取 `AXWindowNumber`（优先匹配字段，用于后续聚焦）
    - 组合为 `VSCodeWindowItem(bundleIdentifier, pid, windowNumber, title, appDisplayName)`
- 对列表做稳定排序（按应用名/标识，再按 title）

#### 2) 一键聚焦（切换到前台）
- 权限前置：任何窗口操作前调用 `ensureAccessibilityPermission()`
- 应用激活：
  - 通过 `bundleIdentifier + pid` 找到 `NSRunningApplication`
  - 调用 `app.activate(options: [.activateAllWindows])`
- 窗口定位与聚焦：
  - 再次读取 `kAXWindowsAttribute` 得到当前窗口列表（避免使用陈旧引用）
  - 优先按 `windowNumber` 精确匹配
  - 若缺失/匹配失败，回退按 `title` 匹配（有同名风险）
  - 最终回退聚焦第一个窗口
  - 聚焦动作：
    - 如窗口最小化，先取消最小化（`kAXMinimizedAttribute = false`）
    - 设置 `kAXFocusedWindowAttribute`
    - 设置窗口 `kAXMainAttribute = true`
    - 对窗口执行 `kAXRaiseAction`

#### 3) 权限与引导 UI
- 权限检查：
  - `AXIsProcessTrusted()` 判断是否已授权
  - 未授权时调用 `AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt: true])` 触发系统弹窗
- 引导：
  - 提供打开系统设置入口：`x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`
  - 使用“一次性提示”避免重复打扰（通过 `UserDefaults` 标记）

#### 4) UI 结构（最小可用）
- `VSCodeWindowsViewModel`：
  - `refresh()`：更新权限状态与窗口列表
  - `focus(window)`：调用 switcher 聚焦
- `ContentView`：
  - Header：标题 + Refresh
  - 权限缺失：引导页（Open System Settings / Try Again）
  - 无窗口：空状态提示
  - 有窗口：`List` 展示每行标题与来源应用名，右侧 `Switch` 按钮

## 架构决策 ADR

### ADR-001: 使用 Accessibility API 枚举与聚焦 VSCode 窗口
**上下文:** 需要“列出窗口 + 聚焦到前台”。  
**决策:** 使用 `AXUIElement` 访问 VSCode 进程的 `kAXWindowsAttribute`，并通过 `kAXRaiseAction` 等动作聚焦。  
**理由:** 只有 Accessibility API 提供跨进程窗口级操作能力；`CGWindowListCopyWindowInfo` 只能列出窗口无法聚焦；AppleScript/Automation 需要额外权限且稳定性差。  
**替代方案:** `CGWindowListCopyWindowInfo` → 拒绝原因: 无法完成“切换到前台”的核心动作。  
**影响:** 必须申请“辅助功能”权限；跨 Space 行为受系统设置影响（可接受约束）。

## 安全与性能
- **安全:** 不读取/保存窗口内容，仅使用标题与窗口编号用于定位；权限用途在 UI 中明确告知。
- **性能:** 枚举窗口为 O(窗口数)；仅在用户刷新/点击时调用，默认开销可忽略。

## 测试与部署
- **测试（手工）:**
  - 未授权：应展示引导页；点击按钮能跳转系统设置；授权后可刷新
  - 多窗口：列表应完整；点击 Switch 应聚焦对应窗口
  - 最小化窗口：点击 Switch 应先解除最小化再置前
  - Stable/Insiders：能分别列出并正确聚焦
- **部署:** 常规 macOS App 打包；注意首次运行需要用户授予“辅助功能”权限。

