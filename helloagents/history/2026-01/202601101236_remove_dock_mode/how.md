# 技术设计: 移除 Dock 右侧区域（回归纯侧栏）

## 技术方案

- `ContentView` 仅保留侧栏布局（header + list/empty/permission）
- `VSCodeWindowSwitcher` 不再维护任何 Dock 状态，也不再对 VSCode 窗口设置 `kAXPositionAttribute/kAXSizeAttribute`

## 验证
- 编译通过
- 切换窗口不再改变 VSCode 位置/大小

