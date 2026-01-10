# 项目技术约定

## 技术栈
- **平台:** macOS
- **语言:** Swift (`SWIFT_VERSION = 5.0`)
- **UI:** SwiftUI
- **系统能力:**
  - App 激活: AppKit (`NSRunningApplication`, `NSWorkspace`)
  - 窗口枚举/聚焦: Accessibility API (`AXUIElement*`, `AXIsProcessTrusted*`)
  - 全局快捷键: Carbon HotKey (`RegisterEventHotKey`)

## 开发约定
- **原则:** KISS，避免引入新依赖；只做 VSCode 窗口“列出 + 切换”所需的最小实现。
- **容错:** 对外部系统 API（AX/NSWorkspace）调用默认失败可恢复：失败时直接返回/降级，不崩溃。
- **窗口标识:** 优先使用 `AXWindowNumber` 匹配目标窗口；缺失时回退使用窗口 `title`（注意同名窗口风险）。
- **权限处理:** 所有跨进程窗口操作都必须先检查“辅助功能”权限；无权限时只展示引导与重试入口。
- **Sandbox:** 当前实现依赖跨进程 AX 访问与窗口几何设置，要求 `ENABLE_APP_SANDBOX = NO`（Sandbox 下可能出现 `AXWindows cannotComplete`）。

## 错误与日志
- **策略:** 默认不弹异常；仅在“权限缺失”场景弹一次性引导提示。
- **调试（可选）:** Debug 环境可按需增加轻量日志（`os_log`），Release 保持静默。

## 测试与流程
- **自动化测试:** 当前无测试目标，优先使用手工验收清单。
- **构建验证:** 使用 Xcode 直接运行，或用 `xcodebuild -project VSCode-Switcher.xcodeproj -scheme VSCode-Switcher build` 验证编译通过。
