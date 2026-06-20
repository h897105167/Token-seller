# Tasks

- [x] Task 1: 项目结构与 BigNumber 工具
  - [x] SubTask 1.1: 创建目录结构 `scripts/`、`scenes/`、`data/`、`autoload/`、`ui/`
  - [x] SubTask 1.2: 实现 `BigNumber.gd` 工具类，支持加减乘除、比较、格式化（科学计数法 1.5E3）、与普通数值互转
  - [x] SubTask 1.3: 编写 BigNumber 单元测试场景验证 1E30 - 2E29 = 8E29 等用例

- [x] Task 2: 物品与科技数据定义
  - [x] SubTask 2.1: 在 `data/items.gd` 定义 20 种物品（id、名称、初始售价、基础 TPS、介绍），按 READ.md 表格录入
  - [x] SubTask 2.2: 在 `data/techs.gd` 定义输入行为科技（12 种）、通用科技（9 种），含效果类型、效果值、售价、解锁条件、介绍
  - [x] SubTask 2.3: 在 `data/techs.gd` 定义 20 种物品各自的 15 个专属科技（共 300 个），含三类效果：每持有其他物品 TPS+1%、每持有本物品其他物品 TPS+1%、本物品 TPS 翻倍
  - [x] SubTask 2.4: 定义科技解锁条件枚举（累计输入 tokens 阈值、持有物品数量阈值、累计登录天数）

- [x] Task 3: 核心游戏状态管理器（GameState 单例）
  - [x] SubTask 3.1: 创建 `autoload/GameState.gd` 单例，持有 tokens、total_tokens、物品数量字典、已购科技数组、人品值、累计输入 tokens、累计登录天数、后台累计时长
  - [x] SubTask 3.2: 实现购买物品逻辑：校验解锁条件、计算指数价格（单买与批量 1/10/100）、扣款、增加数量、触发 TPS 重算信号
  - [x] SubTask 3.3: 实现购买科技逻辑：校验解锁与前置科技、扣款、记录已购、从商店移除、触发参数重算信号
  - [x] SubTask 3.4: 实现累计 total_tokens 更新与物品解锁判定

- [x] Task 4: TPS 计算引擎
  - [x] SubTask 4.1: 创建 `scripts/TPSCalculator.gd`，实现指数倍数（2^n）、线性倍率（持有物品数 × 科技数 × 100%）计算
  - [x] SubTask 4.2: 实现物品 TPS = 基础 TPS × 指数倍数 × (1 + 线性倍率) × 通用科技倍数(2^k)
  - [x] SubTask 4.3: 实现总 TPS = Σ(物品数量 × 物品 TPS)，提供 `recalculate()` 方法，监听 GameState 信号自动重算
  - [x] SubTask 4.4: 实现行为获得倍率、行为线性倍率计算，供输入系统使用

- [x] Task 5: 输入行为监听系统
  - [x] SubTask 5.1: 创建 `autoload/InputMonitor.gd` 单例，使用 `_unhandled_input` / `_input` 监听键盘与鼠标事件
  - [x] SubTask 5.2: 区分单字符敲击与组合键（检测 Ctrl/Shift/Alt 等修饰键），分别奖励 1 / 5 基础 tokens
  - [x] SubTask 5.3: 累计鼠标移动距离，每 100 像素奖励 0.2 基础 tokens；监听滚轮事件奖励 2 基础 tokens
  - [x] SubTask 5.4: 调用行为获得公式：`基础 × (1+行为线性倍率) + 总TPS × 行为获得倍率`，并处理暴击与奖励时间加成
  - [x] SubTask 5.5: 暴击判定（1% 概率），暴击倍数 = randf(2,5) + 人品值/1000，暴击后人品值 +1

- [x] Task 6: 暴击、人品值、奖励时间系统
  - [x] SubTask 6.1: 在 GameState 中维护人品值，提供暴击触发接口（暴击后人品值+1）
  - [x] SubTask 6.2: 实现奖励时间触发逻辑：后台连续 30 分钟触发，时长 = 1min + 20×(1 - e^-(人品值/1000))，奖励倍数 = 人品值/1000 × 100%
  - [x] SubTask 6.3: 奖励时间内禁用暴击，行为获得 tokens 乘以 (1 + 奖励倍数)

- [x] Task 7: 后台运行与离线收益系统
  - [x] SubTask 7.1: 监听 `NOTIFICATION_WM_FOCUS_OUT` / `MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT` 检测切后台，记录时间戳
  - [x] SubTask 7.2: 后台期间持续按 TPS（含加成）累加 tokens，并自动安排升级物品与科技（按可负担的最高性价比）
  - [x] SubTask 7.3: 监听 `NOTIFICATION_WM_FOCUS_IN` 切回前台，计算离线时长、获得的 tokens、自动升级列表
  - [x] SubTask 7.4: 弹出后台运行汇总对话框，展示获得的 tokens 与升级的科技

- [x] Task 8: 存档系统
  - [x] SubTask 8.1: 创建 `autoload/SaveSystem.gd` 单例，使用 `FileAccess` + JSON 序列化所有 GameState 数据
  - [x] SubTask 8.2: 实现 `save()` 与 `load()`，支持 BigNumber 序列化（存为 {mantissa, exponent}）
  - [x] SubTask 8.3: 实现自动存档（定时 + 退出时）与登录天数累计

- [x] Task 9: 主场景与 UI 布局
  - [x] SubTask 9.1: 创建 `scenes/Main.tscn` 主场景，左右分栏布局：左侧 2D 背景占位 + 看板娘占位
  - [x] SubTask 9.2: 顶部栏：tokens 显示（BigNumber 格式化）、TPS 显示，实时更新
  - [x] SubTask 9.3: 右侧商店面板：物品/科技 Tab 切换、批量购买模式按钮组（1/10/100）
  - [x] SubTask 9.4: 物品列表项：图标占位、名称、当前价格（按批量模式）、持有数量、TPS 贡献，悬停显示介绍 Tooltip
  - [x] SubTask 9.5: 科技列表项：名称、价格、效果、解锁状态，悬停显示介绍，购买后从列表移除
  - [x] SubTask 9.6: 后台返回汇总对话框场景

- [x] Task 10: 集成与主循环
  - [x] SubTask 10.1: 在 `project.godot` 注册 autoload 单例（GameState、InputMonitor、SaveSystem）
  - [x] SubTask 10.2: 主场景 `_process` 中按 TPS 累加 tokens，更新 UI
  - [x] SubTask 10.3: 连接所有信号：购买→TPS重算→UI更新；输入→tokens增加→UI更新
  - [x] SubTask 10.4: 设置主场景为 `Main.tscn`，初始 tokens 500、初始物品键盘×1

- [x] Task 11: 验证与调试
  - [x] SubTask 11.1: 运行游戏验证初始状态（500 tokens、1 键盘、TPS=1）
  - [x] SubTask 11.2: 验证输入行为获得 tokens、暴击触发、人品值增长
  - [x] SubTask 11.3: 验证物品购买（单买/批量）、价格指数增长、TPS 重算
  - [x] SubTask 11.4: 验证科技购买、解锁条件、效果生效
  - [x] SubTask 11.5: 验证存档/读档、后台返回汇总

# Task Dependencies
- Task 2 依赖 Task 1（需要 BigNumber）
- Task 3 依赖 Task 1、Task 2
- Task 4 依赖 Task 2、Task 3
- Task 5 依赖 Task 3、Task 4
- Task 6 依赖 Task 3、Task 5
- Task 7 依赖 Task 3、Task 4、Task 6
- Task 8 依赖 Task 1、Task 3
- Task 9 依赖 Task 3、Task 4
- Task 10 依赖 Task 3-9
- Task 11 依赖 Task 10
- Task 1、Task 8 可与早期任务部分并行
