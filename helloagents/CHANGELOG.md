# Changelog

本文件记录项目所有重要变更。  
格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.0.0/)，版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

## [Unreleased]

### 新增
- 支持列出系统中已打开的 VSCode（含 Insiders）窗口，并在 UI 中一键切换聚焦到前台（需“辅助功能”权限）
- 支持为窗口设置 1~9 编号，并用 Option+数字 直接切换到对应窗口
- `Option+数字` 切换时自动进行左右平铺：本应用窗口靠当前屏幕左侧，VSCode 窗口占满剩余区域并置前
- 关闭窗口不退出，以保持全局热键可用
