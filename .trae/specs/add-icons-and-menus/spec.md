# 图标生成、已获得/设置界面与解锁规则重构 Spec

## Why
当前游戏商店只有文字列表，缺乏视觉吸引力；缺少已获得物品/科技的浏览界面和设置界面；解锁逻辑基于 total_tokens 不符合"购买前一级解锁后两级"的设计意图。

## What Changes
- 为所有 20 个物品生成动漫风格图标，放入 `assets/icons/items/`
- 为 12 个输入科技、9 个通用科技生成动漫风格图标，放入 `assets/icons/techs/`
- 为 300 个物品专属科技按"每物品 1 个基础图标 + 5 档华丽度边框"方案生成（20 个基础图标），放入 `assets/icons/techs/`
- **BREAKING** 重构物品解锁逻辑：购买物品 N 解锁物品 N+1、N+2（键盘为初始解锁）
- **BREAKING** 重构科技解锁逻辑：购买科技 N 解锁同线科技 N+1、N+2（每条科技线首个科技按原 unlock_condition 解锁）
- 主界面 Tab 行新增"已获得"、"设置"按钮
- 新增"已获得"全屏界面：标题 + 搜索框 + 返回按钮 + 物品栏 + 科技栏（仅图标，悬停显示详情）
- 新增"设置"全屏界面：标题 + 子分类按钮（声音/图像/控制/语言/其他）+ 退出按钮
- 商店物品/科技条目左侧放置对应图标
- 未解锁（但已出现在商店）的物品/科技降低亮度

## Impact
- Affected code:
  - `scenes/Main.gd` — 新增界面构建、Tab 行扩展、图标加载
  - `autoload/GameState.gd` — 解锁逻辑重构（`is_item_unlocked`、`is_tech_unlocked`）
  - `data/items.gd` — 可能需要添加图标路径字段
  - `data/techs.gd` — 可能需要添加图标路径/tier 字段
  - 新增 `scenes/ObtainedView.gd` — 已获得界面
  - 新增 `scenes/SettingsView.gd` — 设置界面
  - 新增 `assets/icons/` 目录及图标资源

## ADDED Requirements

### Requirement: 物品图标
系统 SHALL 为每个物品生成 128×128 动漫风格图标，风格统一，存放在 `assets/icons/items/<item_id>.png`。

#### Scenario: 商店显示物品图标
- **WHEN** 玩家在商店查看物品列表
- **THEN** 每个物品条目左侧显示对应图标

### Requirement: 科技图标
系统 SHALL 为输入科技和通用科技生成 128×128 动漫风格图标。物品专属科技按"每物品 1 个基础图标 + 5 档华丽度边框"方案，tier 越高边框越华丽。

#### Scenario: 科技图标显示
- **WHEN** 玩家查看科技列表
- **THEN** 每个科技显示对应图标，高 tier 科技图标边框更华丽

### Requirement: 已获得界面
系统 SHALL 提供全屏"已获得"界面，展示已购买的物品和科技图标，支持搜索筛选，鼠标悬停显示详情。

#### Scenario: 浏览已获得内容
- **WHEN** 玩家点击"已获得"按钮
- **THEN** 进入全屏界面，显示已购买物品和科技图标
- **WHEN** 玩家在搜索框输入关键词
- **THEN** 物品栏和科技栏仅显示匹配的图标
- **WHEN** 鼠标悬停在图标上
- **THEN** 显示对应详情（物品：名称/介绍/数量/TPS/总TPS/已获得tokens；科技：名称/介绍/效果）

### Requirement: 设置界面
系统 SHALL 提供全屏"设置"界面，包含声音/图像/控制/语言/其他子分类。

#### Scenario: 进入设置
- **WHEN** 玩家点击"设置"按钮
- **THEN** 进入全屏设置界面，显示子分类按钮
- **WHEN** 点击某子分类按钮
- **THEN** 该按钮高亮并显示对应设置项

### Requirement: 购买解锁链
系统 SHALL 实现"购买前一级解锁后两级"的解锁规则。

#### Scenario: 物品解锁链
- **WHEN** 玩家购买键盘（index 0）
- **THEN** 麦克风（index 1）和程序员（index 2）出现在商店
- **WHEN** 物品已出现在商店但未购买
- **THEN** 该物品条目降低亮度显示

#### Scenario: 科技解锁链
- **WHEN** 玩家购买某科技线的第一个科技
- **THEN** 同线第 2、3 个科技出现在商店
- **WHEN** 购买第 N 个科技
- **THEN** 第 N+1、N+2 个科技出现（若存在）

## MODIFIED Requirements

### Requirement: 物品解锁逻辑
物品解锁不再基于 total_tokens，而是基于购买链：键盘初始解锁，购买物品 N 解锁物品 N+1 和 N+2。已解锁但未购买的物品在商店中以降低亮度显示。

### Requirement: 科技解锁逻辑
科技解锁不再仅基于 unlock_condition 和 prereq_tech_id，而是基于购买链：每条科技线首个科技按原 unlock_condition 解锁，购买科技 N 解锁同线科技 N+1 和 N+2。已解锁但未购买的科技在商店中以降低亮度显示。
