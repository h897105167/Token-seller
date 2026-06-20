extends Node
## 后台管理器（autoload 单例）
## 实现 Task 6 奖励时间系统与 Task 7 后台运行系统

# ===== 信号 =====
signal reward_time_started(duration: float, multiplier: float)
signal reward_time_ended()

# ===== 常量 =====
const BACKGROUND_BONUS: float = 1.5  # 后台 TPS 加成倍率
const REWARD_TRIGGER_TIME: float = 1800.0  # 连续后台 30 分钟触发奖励时间
const AUTO_UPGRADE_INTERVAL: float = 5.0  # 自动升级检查间隔（秒）

# ===== 奖励时间状态（Task 6） =====
var reward_time_active: bool = false
var reward_time_remaining: float = 0.0
var reward_multiplier: float = 0.0
var background_continuous_time: float = 0.0  # 连续后台时间，用于奖励时间触发判定

# ===== 后台运行状态（Task 7） =====
var is_in_background: bool = false
var background_start_time: float = 0.0  # Time.get_ticks_msec() / 1000.0
var background_tokens_earned: BigNumber  # 本次后台期间获得的 tokens
var background_upgrades: Array  # 自动升级记录：["物品: xxx", "科技: xxx", ...]
var _background_upgrade_timer: float = 0.0
# 自动购买开关（前台 + 后台均生效）
var auto_upgrade_enabled: bool = false
var _foreground_upgrade_timer: float = 0.0


func _init() -> void:
	background_tokens_earned = BigNumber.zero()
	background_upgrades = []


func _process(delta: float) -> void:
	# 奖励时间倒计时
	if reward_time_active:
		reward_time_remaining -= delta
		if reward_time_remaining <= 0.0:
			_end_reward_time()

	# 浮窗渐隐处理
	_process_summary_fade(delta)

	# 前台自动升级（开关开启时）
	if auto_upgrade_enabled and not is_in_background:
		_foreground_upgrade_timer += delta
		if _foreground_upgrade_timer >= AUTO_UPGRADE_INTERVAL:
			_foreground_upgrade_timer = 0.0
			_do_auto_upgrade()

	# 后台运行处理
	if is_in_background:
		background_continuous_time += delta
		# 按后台倍率累积 tokens
		if GameState.tps_calculator != null:
			var tps: float = GameState.tps_calculator.total_tps * BACKGROUND_BONUS
			if tps > 0.0:
				var earned: BigNumber = BigNumber.from_number(tps * delta)
				GameState.add_tokens(earned)
				background_tokens_earned = background_tokens_earned.add(earned)
		# 后台自动升级（开关开启时）
		if auto_upgrade_enabled:
			_background_upgrade_timer += delta
			if _background_upgrade_timer >= AUTO_UPGRADE_INTERVAL:
				_background_upgrade_timer = 0.0
				_do_auto_upgrade()


func _notification(what: int) -> void:
	match what:
		MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT:
			_on_enter_background()
		MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN:
			_on_exit_background()


# ===== 奖励时间系统（Task 6） =====

func _start_reward_time() -> void:
	var luck: int = GameState.luck_value
	# 持续时间 = 60 + 20 × (1 - e^(-luck/1000))
	var duration: float = 60.0 + 20.0 * (1.0 - exp(-float(luck) / 1000.0))
	# 奖励倍率 = luck / 1000（luck=500 → 0.5 = 50%）
	reward_multiplier = float(luck) / 1000.0
	reward_time_remaining = duration
	reward_time_active = true
	# 通知 InputMonitor：奖励时间内禁用暴击，应用奖励倍率
	InputMonitor.reward_time_active = true
	InputMonitor.reward_multiplier = reward_multiplier
	emit_signal("reward_time_started", duration, reward_multiplier)


func _end_reward_time() -> void:
	reward_time_active = false
	reward_time_remaining = 0.0
	InputMonitor.reward_time_active = false
	InputMonitor.reward_multiplier = 0.0
	emit_signal("reward_time_ended")


# ===== 后台运行系统（Task 7） =====

func _on_enter_background() -> void:
	if is_in_background:
		return
	is_in_background = true
	background_start_time = Time.get_ticks_msec() / 1000.0
	background_tokens_earned = BigNumber.zero()
	background_upgrades.clear()
	background_continuous_time = 0.0
	_background_upgrade_timer = 0.0


func _on_exit_background() -> void:
	if not is_in_background:
		return
	is_in_background = false
	var elapsed: float = (Time.get_ticks_msec() / 1000.0) - background_start_time
	# 累加后台时间到 GameState
	GameState.background_time += elapsed
	# 检查是否触发奖励时间（连续后台 >= 30 分钟）
	if background_continuous_time >= REWARD_TRIGGER_TIME:
		_start_reward_time()
	# 显示后台运行摘要
	_show_background_summary(elapsed)


# ===== 自动升级逻辑 =====

func _do_auto_upgrade() -> void:
	var best_type: String = ""
	var best_id: String = ""
	var best_value: float = -1.0

	# 评估所有可购买的物品：价值 = TPS 增量 / 价格
	var all_items: Dictionary = ItemsDB.get_all_items()
	for item_id in all_items:
		if not GameState.can_afford_item(item_id, 1):
			continue
		var item = all_items[item_id]
		var count: int = GameState.get_item_count(item_id)
		var price_float: float = item.base_price * pow(1.15, float(count))
		if price_float <= 0.0:
			continue
		var tps_gain: float = 0.0
		if GameState.tps_calculator != null and GameState.tps_calculator.item_tps.has(item_id):
			tps_gain = GameState.tps_calculator.item_tps[item_id]
		var value: float = tps_gain / price_float
		if value > best_value:
			best_value = value
			best_type = "item"
			best_id = item_id

	# 评估所有可购买且已解锁的科技
	for tech in TechDB.get_all_techs():
		if not GameState.can_afford_tech(tech.id):
			continue
		var tps_gain: float = _estimate_tech_tps_gain(tech)
		var value: float = tps_gain / tech.price if tech.price > 0.0 else 0.0
		if value > best_value:
			best_value = value
			best_type = "tech"
			best_id = tech.id

	# 购买最优选项（每周期仅购买 1 项，避免一次性花光）
	if best_type == "item":
		var item = all_items[best_id]
		if GameState.buy_item(best_id, 1):
			background_upgrades.append("物品: %s" % item.name)
	elif best_type == "tech":
		var tech = TechDB.get_tech_by_id(best_id)
		if tech != null and GameState.buy_tech(best_id):
			background_upgrades.append("科技: %s" % tech.name)


func _estimate_tech_tps_gain(tech) -> float:
	# 简单启发式估算科技带来的 TPS 增量
	if GameState.tps_calculator == null:
		return 0.0
	var total_tps: float = GameState.tps_calculator.total_tps
	match tech.effect_type:
		"item_double":
			# 翻倍目标物品的总 TPS 贡献
			return float(GameState.tps_calculator.item_total_tps.get(tech.target_item_id, 0.0))
		"universal_double":
			# 翻倍全部 TPS
			return total_tps
		"input_gain":
			# 增加行为 token 获取（仅点击时生效，粗略估算为总 TPS 的一半）
			return total_tps * 0.5
		_:
			# 线性加成科技，估算较小
			return total_tps * 0.05


# ===== 后台运行摘要浮窗（左下角渐隐） =====

# 当前活跃的浮窗（同时只允许一个）
var _active_summary_panel: Panel = null
var _summary_fade_timer: float = 0.0
var _summary_fade_duration: float = 5.0
var _summary_is_hovered: bool = false


func _show_background_summary(elapsed: float) -> void:
	var mins: int = int(elapsed) / 60
	var secs: int = int(elapsed) % 60
	var time_str: String = "%d:%02d" % [mins, secs]
	var tokens_str: String = background_tokens_earned.to_formatted_string()
	var upgrade_count: int = background_upgrades.size()
	var body: String = "时长: %s\n获得: %s tokens\n自动升级: %d 项" % [time_str, tokens_str, upgrade_count]
	var upgrades_text: String = ""
	if upgrade_count > 0:
		for i in range(min(upgrade_count, 5)):
			upgrades_text += "• %s\n" % background_upgrades[i]
		if upgrade_count > 5:
			upgrades_text += "…等 %d 项" % upgrade_count
	show_custom_summary("后台运行报告", body, upgrade_count, upgrades_text)


# 公开方法：显示自定义摘要浮窗（供离线收益等复用）
# upgrade_count > 0 时显示 upgrades_text 列表；upgrade_count == 0 时不显示升级列表
func show_custom_summary(title: String, body: String, upgrade_count: int = 0, upgrades_text: String = "") -> void:
	# 如果已有浮窗，先移除
	if _active_summary_panel != null and is_instance_valid(_active_summary_panel):
		_active_summary_panel.queue_free()
		_active_summary_panel = null

	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(320, 120)
	# 左下角定位：左锚贴左，下锚贴底，向上向右生长
	panel.anchor_left = 0.0
	panel.anchor_top = 1.0
	panel.anchor_right = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 16
	panel.offset_top = -140
	panel.offset_right = 336
	panel.offset_bottom = -16
	panel.grow_horizontal = Control.GROW_DIRECTION_END
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	# 半透明深色背景
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.92)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.5, 0.8, 1.0, 0.8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 12
	vbox.offset_top = 10
	vbox.offset_right = -12
	vbox.offset_bottom = -10
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	var title_label = Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	vbox.add_child(title_label)

	var info_label = Label.new()
	info_label.text = body
	info_label.add_theme_font_size_override("font_size", 13)
	info_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	vbox.add_child(info_label)

	if upgrade_count > 0 and upgrades_text != "":
		var upg_label = Label.new()
		upg_label.text = "升级:\n" + upgrades_text
		upg_label.add_theme_font_size_override("font_size", 11)
		upg_label.add_theme_color_override("font_color", Color(0.7, 0.85, 0.7))
		vbox.add_child(upg_label)

	# 鼠标悬停检测
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_entered.connect(func():
		_summary_is_hovered = true
		panel.modulate.a = 1.0
	)
	panel.mouse_exited.connect(func():
		_summary_is_hovered = false
	)

	_active_summary_panel = panel
	_summary_fade_timer = 0.0
	_summary_is_hovered = false
	# 使用 call_deferred 避免在 _notification 期间操作节点树
	get_tree().root.add_child.call_deferred(panel)


func _process_summary_fade(delta: float) -> void:
	if _active_summary_panel == null or not is_instance_valid(_active_summary_panel):
		_active_summary_panel = null
		return
	if _summary_is_hovered:
		# 悬停时恢复透明度并暂停渐隐
		_active_summary_panel.modulate.a = 1.0
		_summary_fade_timer = 0.0
		return
	_summary_fade_timer += delta
	if _summary_fade_timer >= _summary_fade_duration:
		# 渐隐完成，移除浮窗
		_active_summary_panel.queue_free()
		_active_summary_panel = null
		return
	# 最后 1.5 秒线性渐隐
	var fade_start: float = _summary_fade_duration - 1.5
	if _summary_fade_timer > fade_start:
		_active_summary_panel.modulate.a = 1.0 - (_summary_fade_timer - fade_start) / 1.5
	else:
		_active_summary_panel.modulate.a = 1.0
