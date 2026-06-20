# Tasks

- [ ] Task 1: 生成物品图标（20 个）
  - [ ] SubTask 1.1: 为 20 个物品各生成 128×128 动漫风格图标，存入 `assets/icons/items/`
  - [ ] SubTask 1.2: 在 `data/items.gd` 的 ItemData 中添加 `icon_path` 字段并填充路径

- [ ] Task 2: 生成科技图标
  - [ ] SubTask 2.1: 为 12 个输入科技生成 128×128 动漫风格图标，存入 `assets/icons/techs/input/`
  - [ ] SubTask 2.2: 为 9 个通用科技生成 128×128 动漫风格图标，存入 `assets/icons/techs/universal/`
  - [ ] SubTask 2.3: 为 20 个物品各生成 1 个科技线基础图标，存入 `assets/icons/techs/item/`
  - [ ] SubTask 2.4: 生成 5 档华丽度边框叠加图（tier1~tier5），存入 `assets/icons/techs/frames/`
  - [ ] SubTask 2.5: 在 `data/techs.gd` 中添加图标路径与 tier 计算逻辑（t1-t3=tier1, t4-t6=tier2, t7-t9=tier3, t10-t12=tier4, t13-t15=tier5）

- [ ] Task 3: 重构解锁逻辑
  - [ ] SubTask 3.1: 修改 `GameState.is_item_unlocked`：键盘初始解锁，购买物品 N 解锁 N+1、N+2
  - [ ] SubTask 3.2: 修改 `GameState.is_tech_unlocked`：每线首个科技按原条件解锁，购买 N 解锁 N+1、N+2
  - [ ] SubTask 3.3: 新增 `GameState.is_item_visible`（已出现在商店）与 `is_item_purchasable`（可购买）区分
  - [ ] SubTask 3.4: 新增 `GameState.is_tech_visible` 与 `is_tech_purchasable` 区分
  - [ ] SubTask 3.5: 更新 `Main.gd` 商店列表：visible 但非 purchasable 的条目降低亮度

- [ ] Task 4: 主界面 Tab 行扩展
  - [ ] SubTask 4.1: 在 Tab 行添加"已获得"和"设置"按钮
  - [ ] SubTask 4.2: 物品/科技条目左侧添加图标显示
  - [ ] SubTask 4.3: 实现界面切换逻辑（主商店 / 已获得 / 设置）

- [ ] Task 5: 已获得界面
  - [ ] SubTask 5.1: 创建 `scenes/ObtainedView.gd`，构建全屏界面（标题 + 搜索框 + 返回按钮 + 物品栏 + 科技栏）
  - [ ] SubTask 5.2: 物品栏仅显示已购买物品图标，科技栏仅显示已购买科技图标
  - [ ] SubTask 5.3: 实现搜索筛选（按名称匹配，同时筛选物品和科技）
  - [ ] SubTask 5.4: 实现鼠标悬停 tooltip（物品：名称/介绍/数量/TPS/总TPS/已获得tokens；科技：名称/介绍/效果）
  - [ ] SubTask 5.5: 在 GameState 中添加物品已获得 tokens 追踪（per-item 累计）

- [ ] Task 6: 设置界面
  - [ ] SubTask 6.1: 创建 `scenes/SettingsView.gd`，构建全屏界面（标题 + 子分类按钮 + 退出按钮）
  - [ ] SubTask 6.2: 实现子分类切换（声音/图像/控制/语言/其他），点击高亮并显示对应面板
  - [ ] SubTask 6.3: 各子面板放置占位设置项（后续可扩展）

- [ ] Task 7: 验证
  - [ ] SubTask 7.1: 运行 headless 模式确认无编译错误
  - [ ] SubTask 7.2: 验证图标加载无缺失

# Task Dependencies
- Task 3 依赖 Task 1、Task 2（图标路径字段）
- Task 4 依赖 Task 1、Task 2（图标资源）
- Task 5 依赖 Task 4（界面切换逻辑）
- Task 6 依赖 Task 4（界面切换逻辑）
- Task 7 依赖所有前置任务
