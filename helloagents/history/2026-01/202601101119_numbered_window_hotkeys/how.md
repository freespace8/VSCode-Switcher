# 技术设计: 窗口编号与 Option+数字 快速切换

## 技术方案

### 核心技术
- SwiftUI：列表行内提供编号菜单
- Carbon HotKey：注册 `Option+1..9`
- Accessibility：按编号映射聚焦目标窗口
- UserDefaults：持久化编号映射

### 实现要点

#### 1) 编号映射模型
- 维护 `number -> WindowBookmark` 的映射，存储为 `UserDefaults` JSON：
  - key: `VSCodeSwitcher.numberMapping`
  - value: `[Int: WindowBookmark]`

#### 2) 编号设置策略
- 设置编号时先移除该窗口在其它编号下的旧绑定（避免一个窗口占多个号）
- 同一编号被重复设置时覆盖旧窗口绑定（保证一号一窗）

#### 3) 快捷键行为
- `Option+1..9` → 优先 `focus(number:)`
- 若 `number` 未映射 → 不做任何操作（安全失败）

#### 4) 窗口定位
- 聚焦时按 `WindowBookmark` 匹配：
  - 优先 `AXWindowNumber`
  - 回退 `title`

## 安全与性能
- **安全:** 仅保存 bundle id / windowNumber / title，不保存窗口内容
- **性能:** 映射读取与窗口匹配发生在热键触发时，开销可忽略

## 测试与部署
- 手工：为两个窗口分别绑定 `1/2`，按 `Option+1/2` 来回切换；清空后热键不再生效。
