# VSCode-Switcher

macOS 菜单栏小工具：列出并快速切换 Visual Studio Code（VSCode）窗口。

## 功能
- 列出当前打开的 VSCode 窗口，点击即可聚焦
- 全局快捷键：⌃⌥1..9 / ⌃⌥0（按列表顺序，最多 10 个窗口；0=第 10 个）
- 窗口排序（持久化）
- 窗口别名（持久化）
- 多屏支持：通过“点击列表/快捷键”切换时，将被激活的 VSCode 窗口移动到 VSCode-Switcher 所在屏幕
- 可选：激活后自动平铺（同一屏幕占满：工具窗口左、VSCode 右）

## 安装
1. 从 GitHub Releases 下载 DMG：`https://github.com/freespace8/VSCode-Switcher/releases`
2. 拖拽 `VSCode-Switcher.app` 到 `/Applications`

> 由于未签名/未公证，首次打开可能被系统拦截。

### 解除 quarantine / Gatekeeper（常见于未签名应用）
- Finder：右键 App → 打开
- 或命令行：
  - `sudo xattr -dr com.apple.quarantine /Applications/VSCode-Switcher.app`
- 或使用仓库脚本：
  - `./unq /Applications/VSCode-Switcher.app`

## 首次使用（必须授权）
此应用依赖 macOS “辅助功能”(Accessibility) 权限来读取并聚焦 VSCode 窗口。

1. 启动 VSCode-Switcher（会出现在菜单栏，显示为 `VSCode`）
2. 打开 系统设置 → 隐私与安全性 → 辅助功能，勾选 `VSCode-Switcher`
   - 也可以从状态栏菜单选择“打开辅助功能设置”
3. 打开 Visual Studio Code，回到 VSCode-Switcher 点击 `Refresh` 或菜单“刷新窗口列表”
4. 点击窗口条目切换，或直接用 ⌃⌥数字切换

## 使用
- 状态栏菜单：显示/隐藏、刷新窗口列表、激活后自动平铺、打开辅助功能设置、退出
- 排序：点击“排序”进入模式 → 使用“上移/下移” → 点击“完成”
- 别名：右键窗口 → “编辑别名”/“清空别名”
- 多屏：将 VSCode-Switcher 主窗口放到目标屏幕，通过点击/⌃⌥数字切换窗口即可

## 限制
- 仅支持 VSCode（bundle id：`com.microsoft.VSCode`），不包含 Insiders 等变体
- Releases 目前为 arm64 DMG；Intel 机型需自行编译
