class_name Main
extends Control
## 主场景脚本：以编程方式构建 Cookie Clicker 风格的 UI

var _batch_size: int = 1
var _current_tab: String = "items"  # "items" 或 "techs"

# UI 引用
var _tokens_label: Label
var _tps_label: Label
var _luck_label: Label
var _reward_time_label: Label
var _scroll_container: ScrollContainer
var _list_vbox: VBoxContainer
var _shop_panel: Panel
var _obtained_view: Control
var _settings_view: Control
var _settings_panels: Dictionary = {}
var _settings_buttons: Dictionary = {}
var _obtained_item_grid: GridContainer
var _obtained_tech_grid: GridContainer
var _obtained_search_box: LineEdit

# Token 累积缓冲（用于节流更新，避免每帧触发 state_changed）
var _token_accumulator: float = 0.0
var _ui_update_timer: float = 0.0
const UI_UPDATE_INTERVAL: float = 0.1  # 10fps 状态更新


func _ready() -> void:
	_build_ui()
	GameState.state_changed.connect(_on_state_changed)
	GameState.tps_recalculated.connect(_on_tps_recalculated)
	InputMonitor.input_rewarded.connect(_on_input_rewarded)
	BackgroundManager.reward_time_started.connect(_on_reward_time_started)
	BackgroundManager.reward_time_ended.connect(_on_reward_time_ended)
	_refresh_ui()
	_refresh_list()
	# 启动时显示离线收益（若有），否则首次运行显示欢迎信息
	if not _show_offline_reward_if_any():
		if not SaveSystem.has_save():
			BackgroundManager.show_custom_summary(
				"欢迎来到 Tokens Saler",
				"通过键盘输入、鼠标移动等行为赚取 tokens\n购买物品提升 TPS，离线也会持续产出\n\n退出后再次打开将获得离线收益",
				0
			)


func _show_offline_reward_if_any() -> bool:
	if SaveSystem.last_offline_tokens == null or SaveSystem.last_offline_seconds <= 0.0:
		return false
	var secs: int = int(SaveSystem.last_offline_seconds)
	var hours: int = secs / 3600
	var mins: int = (secs % 3600) / 60
	var s: int = secs % 60
	var time_str: String
	if hours > 0:
		time_str = "%d:%02d:%02d" % [hours, mins, s]
	else:
		time_str = "%d:%02d" % [mins, s]
	# 复用 BackgroundManager 的浮窗机制显示离线收益
	BackgroundManager.show_custom_summary(
		"离线收益报告",
		"离线时长: %s\nTPS: %.1f\n获得: %s tokens" % [time_str, SaveSystem.last_offline_tps, SaveSystem.last_offline_tokens.to_formatted_string()],
		0
	)
	return true


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# 让根 Control 撑满整个窗口
	set_h_size_flags(Control.SIZE_EXPAND_FILL)
	set_v_size_flags(Control.SIZE_EXPAND_FILL)

	var main_hbox = HBoxContainer.new()
	main_hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(main_hbox)

	# === 左侧面板（背景 + 看板娘） ===
	var left_panel = Panel.new()
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_panel.size_flags_stretch_ratio = 1.6  # 左侧占更大比例
	main_hbox.add_child(left_panel)

	var bg_color = ColorRect.new()
	bg_color.color = Color(0.15, 0.15, 0.2)
	bg_color.set_anchors_preset(Control.PRESET_FULL_RECT)
	left_panel.add_child(bg_color)

	var mascot_label = Label.new()
	mascot_label.text = "看板娘\n(3D Model Placeholder)"
	mascot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mascot_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mascot_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	left_panel.add_child(mascot_label)

	# 顶部状态栏
	var top_bar = HBoxContainer.new()
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_bottom = 40
	top_bar.add_theme_constant_override("separation", 20)
	left_panel.add_child(top_bar)

	_tokens_label = Label.new()
	_tokens_label.text = "Tokens: 0"
	top_bar.add_child(_tokens_label)

	_tps_label = Label.new()
	_tps_label.text = "TPS: 0"
	top_bar.add_child(_tps_label)

	_luck_label = Label.new()
	_luck_label.text = "人品值: 0"
	top_bar.add_child(_luck_label)

	_reward_time_label = Label.new()
	_reward_time_label.text = ""
	_reward_time_label.visible = false
	top_bar.add_child(_reward_time_label)

	# === 右侧面板（商店） ===
	var right_panel = Panel.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_stretch_ratio = 1.0
	main_hbox.add_child(right_panel)
	_shop_panel = right_panel

	var right_vbox = VBoxContainer.new()
	right_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	right_vbox.offset_left = 8
	right_vbox.offset_top = 8
	right_vbox.offset_right = -8
	right_vbox.offset_bottom = -8
	right_panel.add_child(right_vbox)

	# 标签页按钮（物品 / 科技）
	var tab_hbox = HBoxContainer.new()
	right_vbox.add_child(tab_hbox)

	var items_btn = Button.new()
	items_btn.text = "物品"
	items_btn.pressed.connect(func(): _switch_tab("items"))
	tab_hbox.add_child(items_btn)

	var techs_btn = Button.new()
	techs_btn.text = "科技"
	techs_btn.pressed.connect(func(): _switch_tab("techs"))
	tab_hbox.add_child(techs_btn)

	var obtained_btn = Button.new()
	obtained_btn.text = "已获得"
	obtained_btn.pressed.connect(_show_obtained_view)
	tab_hbox.add_child(obtained_btn)

	var settings_btn = Button.new()
	settings_btn.text = "设置"
	settings_btn.pressed.connect(_show_settings_view)
	tab_hbox.add_child(settings_btn)

	# 批量购买按钮（1 / 10 / 100）
	var batch_hbox = HBoxContainer.new()
	right_vbox.add_child(batch_hbox)

	for bs in [1, 10, 100]:
		var size: int = bs
		var btn = Button.new()
		btn.text = str(size)
		btn.pressed.connect(func(): _set_batch_size(size))
		batch_hbox.add_child(btn)

	# 自动购买开关（仅物品 Tab 显示）
	var auto_row = HBoxContainer.new()
	right_vbox.add_child(auto_row)

	var auto_check = CheckBox.new()
	auto_check.text = "自动购买"
	auto_check.button_pressed = BackgroundManager.auto_upgrade_enabled
	auto_check.toggled.connect(func(pressed: bool):
		BackgroundManager.auto_upgrade_enabled = pressed
	)
	auto_row.add_child(auto_check)

	var auto_hint = Label.new()
	auto_hint.text = "（开启后每 5 秒自动购买性价比最高的物品/科技）"
	auto_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	auto_hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	auto_hint.add_theme_font_size_override("font_size", 11)
	auto_row.add_child(auto_hint)

	# 可滚动列表
	_scroll_container = ScrollContainer.new()
	_scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.add_child(_scroll_container)

	_list_vbox = VBoxContainer.new()
	_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll_container.add_child(_list_vbox)


func _switch_tab(tab: String) -> void:
	_current_tab = tab
	_refresh_list()


func _set_batch_size(bs: int) -> void:
	_batch_size = bs
	_refresh_list()


func _refresh_list() -> void:
	for child in _list_vbox.get_children():
		child.queue_free()

	if _current_tab == "items":
		for item_id in ItemsDB.get_item_ids():
			# 只显示已解锁的物品
			if not GameState.is_item_visible(item_id):
				continue
			_list_vbox.add_child(_build_item_entry(item_id))
	else:
		for tech in TechDB.get_all_techs():
			# 跳过已购买的科技
			if GameState.is_tech_purchased(tech.id):
				continue
			# 只显示已解锁的科技（链式规则已包含前置检查）
			if not GameState.is_tech_visible(tech.id):
				continue
			_list_vbox.add_child(_build_tech_entry(tech))


func _build_item_entry(item_id: String) -> Control:
	var item = ItemsDB.get_all_items()[item_id]
	var count: int = GameState.get_item_count(item_id)
	var price: BigNumber = GameState.get_item_price(item_id, _batch_size)
	var affordable: bool = GameState.can_afford_item(item_id, _batch_size)
	# 单个物品 TPS、总 TPS 贡献（数量 × 单个 TPS）
	var per_item_tps: float = 0.0
	var total_tps_contribution: float = 0.0
	if GameState.tps_calculator.item_tps.has(item_id):
		per_item_tps = float(GameState.tps_calculator.item_tps[item_id])
		total_tps_contribution = per_item_tps * count

	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(0, 90)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 8
	vbox.offset_top = 4
	vbox.offset_right = -8
	vbox.offset_bottom = -4
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)

	# 名称 + 拥有数量
	var name_row = HBoxContainer.new()
	vbox.add_child(name_row)

	# 图标
	if item.icon_path != "":
		var icon_tex = load(item.icon_path)
		if icon_tex != null:
			var icon_rect = TextureRect.new()
			icon_rect.custom_minimum_size = Vector2(48, 48)
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_rect.texture = icon_tex
			name_row.add_child(icon_rect)

	var name_label = Label.new()
	name_label.text = item.name
	name_label.add_theme_font_size_override("font_size", 16)
	name_row.add_child(name_label)

	var count_label = Label.new()
	count_label.text = "数量: %d" % count
	count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	name_row.add_child(count_label)

	# 价格
	var info_row = HBoxContainer.new()
	vbox.add_child(info_row)

	var price_label = Label.new()
	price_label.text = "价格: %s (×%d)" % [price.to_formatted_string(), _batch_size]
	if not affordable:
		price_label.add_theme_color_override("font_color", Color(0.8, 0.4, 0.4))
	info_row.add_child(price_label)

	# TPS 信息：单个 TPS、数量、乘积
	var tps_label = Label.new()
	tps_label.text = "单个TPS: %.2f  |  数量: %d  |  总贡献: %.2f" % [per_item_tps, count, total_tps_contribution]
	tps_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tps_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	info_row.add_child(tps_label)

	# 描述
	var desc_label = Label.new()
	desc_label.text = item.description
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(desc_label)

	panel.tooltip_text = item.description

	if affordable:
		var captured_id = item_id
		var captured_batch = _batch_size
		panel.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				GameState.buy_item(captured_id, captured_batch)
		)

	# 未购买（不可购买）的物品降低亮度
	if not GameState.is_item_purchasable(item_id, _batch_size):
		panel.modulate = Color(0.5, 0.5, 0.5)

	return panel


func _build_tech_entry(tech) -> Control:
	var affordable: bool = GameState.can_afford_tech(tech.id)
	var price_bn: BigNumber = BigNumber.from_number(tech.price)

	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(0, 80)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 8
	vbox.offset_top = 4
	vbox.offset_right = -8
	vbox.offset_bottom = -4
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)

	# 名称 + 分类
	var name_row = HBoxContainer.new()
	vbox.add_child(name_row)

	# 图标
	if tech.icon_path != "":
		var icon_tex = load(tech.icon_path)
		if icon_tex != null:
			var icon_rect = TextureRect.new()
			icon_rect.custom_minimum_size = Vector2(48, 48)
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_rect.texture = icon_tex
			name_row.add_child(icon_rect)

	var name_label = Label.new()
	name_label.text = tech.name
	name_label.add_theme_font_size_override("font_size", 16)
	name_row.add_child(name_label)

	var category_label = Label.new()
	category_label.text = "[%s]" % _category_display(tech.category)
	category_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	category_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	category_label.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6))
	name_row.add_child(category_label)

	# 价格
	var info_row = HBoxContainer.new()
	vbox.add_child(info_row)

	var price_label = Label.new()
	price_label.text = "价格: %s" % price_bn.to_formatted_string()
	if not affordable:
		price_label.add_theme_color_override("font_color", Color(0.8, 0.4, 0.4))
	info_row.add_child(price_label)

	# 效果
	var effect_label = Label.new()
	effect_label.text = _format_tech_effect(tech)
	effect_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	effect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	effect_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5))
	info_row.add_child(effect_label)

	# 描述
	var desc_label = Label.new()
	desc_label.text = tech.description
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(desc_label)

	panel.tooltip_text = tech.description

	if affordable:
		var captured_id = tech.id
		panel.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				GameState.buy_tech(captured_id)
		)

	# 未购买（不可购买）的科技降低亮度
	if not GameState.is_tech_purchasable(tech.id):
		panel.modulate = Color(0.5, 0.5, 0.5)

	return panel


func _category_display(category: String) -> String:
	match category:
		"input":
			return "输入"
		"universal":
			return "通用"
		"item":
			return "物品"
		_:
			return category


func _format_tech_effect(tech) -> String:
	match tech.effect_type:
		"input_gain":
			var src_name = ""
			if tech.secondary_effect.has("source_item_id"):
				var src_item = ItemsDB.get_all_items().get(tech.secondary_effect["source_item_id"])
				src_name = src_item.name if src_item != null else tech.secondary_effect["source_item_id"]
			return "输入+1%%TPS / 每%s+1%%基础" % src_name
		"item_other_linear":
			var item = ItemsDB.get_all_items().get(tech.target_item_id)
			var item_name = item.name if item != null else tech.target_item_id
			return "每持有其他物品 %s TPS+1%%" % item_name
		"item_self_to_others_linear":
			var item = ItemsDB.get_all_items().get(tech.target_item_id)
			var item_name = item.name if item != null else tech.target_item_id
			return "每持有%s 其他物品TPS+1%%" % item_name
		"item_double":
			var item = ItemsDB.get_all_items().get(tech.target_item_id)
			var item_name = item.name if item != null else tech.target_item_id
			return "%s TPS翻倍" % item_name
		"universal_double":
			return "所有物品TPS翻倍"
		_:
			return tech.effect_type


func _refresh_ui() -> void:
	_tokens_label.text = "Tokens: " + GameState.tokens.to_formatted_string()
	_tps_label.text = "TPS: %.1f" % GameState.tps_calculator.total_tps
	_luck_label.text = "人品值: " + str(GameState.luck_value)


func _process(delta: float) -> void:
	# 前台时按 TPS 累积 tokens（后台由 BackgroundManager 处理，避免重复计算）
	if not BackgroundManager.is_in_background:
		var tps: float = GameState.tps_calculator.total_tps
		if tps > 0.0:
			_token_accumulator += tps * delta

	# 节流状态更新（10fps），避免每帧触发 state_changed
	_ui_update_timer += delta
	if _ui_update_timer >= UI_UPDATE_INTERVAL:
		_ui_update_timer = 0.0
		if _token_accumulator > 0.0:
			GameState.add_tokens(BigNumber.from_number(_token_accumulator))
			_token_accumulator = 0.0
		_refresh_ui()

	# 每帧平滑显示 tokens（包含未提交的累积量）
	if _token_accumulator > 0.0:
		var display: BigNumber = GameState.tokens.add(BigNumber.from_number(_token_accumulator))
		_tokens_label.text = "Tokens: " + display.to_formatted_string()

	# 奖励时间倒计时
	if BackgroundManager.reward_time_active:
		_reward_time_label.text = "奖励时间: %.0fs (×%.0f%%)" % [BackgroundManager.reward_time_remaining, BackgroundManager.reward_multiplier * 100.0]


func _on_state_changed() -> void:
	_refresh_ui()


func _on_tps_recalculated() -> void:
	_refresh_ui()
	_refresh_list()


func _on_input_rewarded(base_tokens: float, total_tokens: BigNumber, is_crit: bool) -> void:
	_refresh_ui()
	if is_crit:
		_tokens_label.text += "  [暴击!]"


func _on_reward_time_started(duration: float, mult: float) -> void:
	_reward_time_label.visible = true
	_reward_time_label.text = "奖励时间! (×%.0f%%)" % (mult * 100.0)


func _on_reward_time_ended() -> void:
	_reward_time_label.visible = false


func _show_obtained_view() -> void:
	_shop_panel.visible = false
	if _obtained_view == null:
		_build_obtained_view()
	_obtained_view.visible = true
	_refresh_obtained_view()


func _build_obtained_view() -> void:
	var panel = Panel.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	_obtained_view = panel

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 8
	vbox.offset_top = 8
	vbox.offset_right = -8
	vbox.offset_bottom = -8
	panel.add_child(vbox)

	# 顶部栏：标题 + 搜索框 + 返回按钮
	var top_bar = HBoxContainer.new()
	top_bar.custom_minimum_size = Vector2(0, 60)
	top_bar.add_theme_constant_override("separation", 12)
	vbox.add_child(top_bar)

	var title_label = Label.new()
	title_label.text = "已获得"
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top_bar.add_child(title_label)

	_obtained_search_box = LineEdit.new()
	_obtained_search_box.placeholder_text = "搜索物品或科技..."
	_obtained_search_box.custom_minimum_size = Vector2(300, 0)
	_obtained_search_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_obtained_search_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_obtained_search_box.text_changed.connect(_on_obtained_search_changed)
	top_bar.add_child(_obtained_search_box)

	var back_btn = Button.new()
	back_btn.text = "返回"
	back_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back_btn.pressed.connect(_return_to_main)
	top_bar.add_child(back_btn)

	# 下层：物品栏 + 科技栏（可拖拽分隔）
	var split = VSplitContainer.new()
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(split)

	# 物品栏
	var item_section = VBoxContainer.new()
	split.add_child(item_section)

	var item_title = Label.new()
	item_title.text = "物品"
	item_title.add_theme_font_size_override("font_size", 18)
	item_section.add_child(item_title)

	var item_scroll = ScrollContainer.new()
	item_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	item_section.add_child(item_scroll)

	_obtained_item_grid = GridContainer.new()
	_obtained_item_grid.columns = 10
	_obtained_item_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_scroll.add_child(_obtained_item_grid)

	# 科技栏
	var tech_section = VBoxContainer.new()
	split.add_child(tech_section)

	var tech_title = Label.new()
	tech_title.text = "科技"
	tech_title.add_theme_font_size_override("font_size", 18)
	tech_section.add_child(tech_title)

	var tech_scroll = ScrollContainer.new()
	tech_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tech_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tech_section.add_child(tech_scroll)

	_obtained_tech_grid = GridContainer.new()
	_obtained_tech_grid.columns = 10
	_obtained_tech_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tech_scroll.add_child(_obtained_tech_grid)


func _on_obtained_search_changed(_new_text: String) -> void:
	_refresh_obtained_view()


func _refresh_obtained_view() -> void:
	for child in _obtained_item_grid.get_children():
		child.queue_free()
	for child in _obtained_tech_grid.get_children():
		child.queue_free()

	var search_text: String = _obtained_search_box.text.to_lower()

	# 物品栏：只显示已购买且符合搜索条件的物品
	for item_id in ItemsDB.get_item_ids():
		if GameState.get_item_count(item_id) <= 0:
			continue
		var item = ItemsDB.get_all_items()[item_id]
		if search_text != "" and item.name.to_lower().find(search_text) < 0:
			continue
		if item.icon_path == "":
			continue
		var icon_tex = load(item.icon_path)
		if icon_tex == null:
			continue
		var icon_rect = TextureRect.new()
		icon_rect.custom_minimum_size = Vector2(64, 64)
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.texture = icon_tex
		var count: int = GameState.get_item_count(item_id)
		var per_tps: float = float(GameState.tps_calculator.item_tps.get(item_id, 0.0))
		var total_tps: float = per_tps * count
		var earned: String = GameState.get_item_tokens_earned(item_id).to_formatted_string()
		icon_rect.tooltip_text = "名称: %s\n介绍: %s\n数量: %d\n单个TPS: %.2f\n总TPS: %.2f\n已获得tokens: %s" % [item.name, item.description, count, per_tps, total_tps, earned]
		_obtained_item_grid.add_child(icon_rect)

	# 科技栏：只显示已购买且符合搜索条件的科技
	for tech in TechDB.get_all_techs():
		if not GameState.is_tech_purchased(tech.id):
			continue
		if search_text != "" and tech.name.to_lower().find(search_text) < 0:
			continue
		if tech.icon_path == "":
			continue
		var icon_tex = load(tech.icon_path)
		if icon_tex == null:
			continue
		var icon_rect = TextureRect.new()
		icon_rect.custom_minimum_size = Vector2(64, 64)
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.texture = icon_tex
		var effect: String = _format_tech_effect(tech)
		icon_rect.tooltip_text = "名称: %s\n介绍: %s\n效果: %s" % [tech.name, tech.description, effect]
		_obtained_tech_grid.add_child(icon_rect)


func _show_settings_view() -> void:
	if _settings_view == null:
		_build_settings_view()
	_shop_panel.visible = false
	_settings_view.visible = true


func _build_settings_view() -> void:
	var panel = Panel.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	_settings_view = panel

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 8
	vbox.offset_top = 8
	vbox.offset_right = -8
	vbox.offset_bottom = -8
	panel.add_child(vbox)

	# === 顶部栏（高度约 60px） ===
	var top_bar = HBoxContainer.new()
	top_bar.custom_minimum_size = Vector2(0, 60)
	top_bar.add_theme_constant_override("separation", 12)
	vbox.add_child(top_bar)

	var title_label = Label.new()
	title_label.text = "设置"
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top_bar.add_child(title_label)

	# 子分类按钮
	var tab_hbox = HBoxContainer.new()
	tab_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_hbox.add_theme_constant_override("separation", 8)
	tab_hbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top_bar.add_child(tab_hbox)

	for tab_name in ["声音", "图像", "控制", "语言", "其他"]:
		var captured_name: String = tab_name
		var btn = Button.new()
		btn.text = tab_name
		btn.pressed.connect(func(): _switch_settings_tab(captured_name))
		tab_hbox.add_child(btn)
		_settings_buttons[tab_name] = btn

	var exit_btn = Button.new()
	exit_btn.text = "退出"
	exit_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	exit_btn.pressed.connect(_return_to_main)
	top_bar.add_child(exit_btn)

	# === 下层（剩余空间）：5 个面板 ===
	# 声音面板
	var sound_panel = Panel.new()
	sound_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sound_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(sound_panel)
	_settings_panels["声音"] = sound_panel

	var sound_vbox = VBoxContainer.new()
	sound_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	sound_vbox.offset_left = 8
	sound_vbox.offset_top = 8
	sound_vbox.offset_right = -8
	sound_vbox.offset_bottom = -8
	sound_vbox.add_theme_constant_override("separation", 12)
	sound_panel.add_child(sound_vbox)

	# 主音量
	var master_row = HBoxContainer.new()
	sound_vbox.add_child(master_row)
	var master_label = Label.new()
	master_label.text = "主音量"
	master_label.custom_minimum_size = Vector2(120, 0)
	master_row.add_child(master_label)
	var master_slider = HSlider.new()
	master_slider.min_value = 0
	master_slider.max_value = 100
	master_slider.value = 100
	master_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	master_row.add_child(master_slider)

	# 音效
	var sfx_row = HBoxContainer.new()
	sound_vbox.add_child(sfx_row)
	var sfx_label = Label.new()
	sfx_label.text = "音效"
	sfx_label.custom_minimum_size = Vector2(120, 0)
	sfx_row.add_child(sfx_label)
	var sfx_slider = HSlider.new()
	sfx_slider.min_value = 0
	sfx_slider.max_value = 100
	sfx_slider.value = 100
	sfx_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sfx_row.add_child(sfx_slider)

	# 背景音乐
	var bgm_row = HBoxContainer.new()
	sound_vbox.add_child(bgm_row)
	var bgm_label = Label.new()
	bgm_label.text = "背景音乐"
	bgm_label.custom_minimum_size = Vector2(120, 0)
	bgm_row.add_child(bgm_label)
	var bgm_slider = HSlider.new()
	bgm_slider.min_value = 0
	bgm_slider.max_value = 100
	bgm_slider.value = 100
	bgm_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bgm_row.add_child(bgm_slider)

	# 图像面板
	var graphics_panel = Panel.new()
	graphics_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graphics_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	graphics_panel.visible = false
	vbox.add_child(graphics_panel)
	_settings_panels["图像"] = graphics_panel

	var graphics_vbox = VBoxContainer.new()
	graphics_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	graphics_vbox.offset_left = 8
	graphics_vbox.offset_top = 8
	graphics_vbox.offset_right = -8
	graphics_vbox.offset_bottom = -8
	graphics_vbox.add_theme_constant_override("separation", 12)
	graphics_panel.add_child(graphics_vbox)

	# 全屏模式
	var fullscreen_row = HBoxContainer.new()
	graphics_vbox.add_child(fullscreen_row)
	var fullscreen_label = Label.new()
	fullscreen_label.text = "全屏模式"
	fullscreen_label.custom_minimum_size = Vector2(120, 0)
	fullscreen_row.add_child(fullscreen_label)
	var fullscreen_check = CheckBox.new()
	fullscreen_check.button_pressed = true
	fullscreen_row.add_child(fullscreen_check)

	# 分辨率
	var resolution_row = HBoxContainer.new()
	graphics_vbox.add_child(resolution_row)
	var resolution_label = Label.new()
	resolution_label.text = "分辨率"
	resolution_label.custom_minimum_size = Vector2(120, 0)
	resolution_row.add_child(resolution_label)
	var resolution_opt = OptionButton.new()
	resolution_opt.add_item("1280×720")
	resolution_opt.add_item("1920×1080")
	resolution_opt.add_item("2560×1440")
	resolution_row.add_child(resolution_opt)

	# 垂直同步
	var vsync_row = HBoxContainer.new()
	graphics_vbox.add_child(vsync_row)
	var vsync_label = Label.new()
	vsync_label.text = "垂直同步"
	vsync_label.custom_minimum_size = Vector2(120, 0)
	vsync_row.add_child(vsync_label)
	var vsync_check = CheckBox.new()
	vsync_check.button_pressed = true
	vsync_row.add_child(vsync_check)

	# 控制面板
	var control_panel = Panel.new()
	control_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	control_panel.visible = false
	vbox.add_child(control_panel)
	_settings_panels["控制"] = control_panel

	var control_vbox = VBoxContainer.new()
	control_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	control_vbox.offset_left = 8
	control_vbox.offset_top = 8
	control_vbox.offset_right = -8
	control_vbox.offset_bottom = -8
	control_vbox.add_theme_constant_override("separation", 12)
	control_panel.add_child(control_vbox)

	# 自动购买
	var auto_row = HBoxContainer.new()
	control_vbox.add_child(auto_row)
	var auto_label = Label.new()
	auto_label.text = "自动购买"
	auto_label.custom_minimum_size = Vector2(120, 0)
	auto_row.add_child(auto_label)
	var auto_check = CheckBox.new()
	auto_check.button_pressed = BackgroundManager.auto_upgrade_enabled
	auto_check.toggled.connect(func(pressed: bool):
		BackgroundManager.auto_upgrade_enabled = pressed
	)
	auto_row.add_child(auto_check)

	# 后台运行
	var bg_row = HBoxContainer.new()
	control_vbox.add_child(bg_row)
	var bg_label = Label.new()
	bg_label.text = "后台运行"
	bg_label.custom_minimum_size = Vector2(120, 0)
	bg_row.add_child(bg_label)
	var bg_status = Label.new()
	bg_status.text = "已启用"
	bg_row.add_child(bg_status)

	# 语言面板
	var language_panel = Panel.new()
	language_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	language_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	language_panel.visible = false
	vbox.add_child(language_panel)
	_settings_panels["语言"] = language_panel

	var language_vbox = VBoxContainer.new()
	language_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	language_vbox.offset_left = 8
	language_vbox.offset_top = 8
	language_vbox.offset_right = -8
	language_vbox.offset_bottom = -8
	language_vbox.add_theme_constant_override("separation", 12)
	language_panel.add_child(language_vbox)

	# 语言选择
	var lang_row = HBoxContainer.new()
	language_vbox.add_child(lang_row)
	var lang_label = Label.new()
	lang_label.text = "语言"
	lang_label.custom_minimum_size = Vector2(120, 0)
	lang_row.add_child(lang_label)
	var lang_opt = OptionButton.new()
	lang_opt.add_item("简体中文")
	lang_opt.add_item("English")
	lang_opt.add_item("日本語")
	lang_row.add_child(lang_opt)

	# 说明
	var lang_hint = Label.new()
	lang_hint.text = "语言切换功能开发中"
	lang_hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	language_vbox.add_child(lang_hint)

	# 其他面板
	var other_panel = Panel.new()
	other_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	other_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	other_panel.visible = false
	vbox.add_child(other_panel)
	_settings_panels["其他"] = other_panel

	var other_vbox = VBoxContainer.new()
	other_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	other_vbox.offset_left = 8
	other_vbox.offset_top = 8
	other_vbox.offset_right = -8
	other_vbox.offset_bottom = -8
	other_vbox.add_theme_constant_override("separation", 12)
	other_panel.add_child(other_vbox)

	# 删除存档
	var delete_btn = Button.new()
	delete_btn.text = "删除存档"
	delete_btn.pressed.connect(_on_delete_save_requested)
	other_vbox.add_child(delete_btn)

	# 关于
	var about_label = Label.new()
	about_label.text = "Tokens Saler v1.0\n一款类似 Cookie Clicker 的挂机游戏"
	other_vbox.add_child(about_label)

	# 初始显示"声音"面板
	_switch_settings_tab("声音")


func _switch_settings_tab(tab_name: String) -> void:
	for name in _settings_panels:
		_settings_panels[name].visible = (name == tab_name)
	for name in _settings_buttons:
		if name == tab_name:
			_settings_buttons[name].add_theme_color_override("font_color", Color(1, 0.8, 0.2))
		else:
			_settings_buttons[name].remove_theme_color_override("font_color")


func _on_delete_save_requested() -> void:
	var dialog = ConfirmationDialog.new()
	dialog.title = "确认删除存档"
	dialog.dialog_text = "确定要删除存档吗？此操作不可撤销。"
	dialog.confirmed.connect(func():
		SaveSystem.delete_save()
		BackgroundManager.show_custom_summary("提示", "存档已删除", 0)
		dialog.queue_free()
	)
	dialog.canceled.connect(func():
		dialog.queue_free()
	)
	add_child(dialog)
	dialog.popup_centered()


func _return_to_main() -> void:
	if _obtained_view != null:
		_obtained_view.visible = false
	if _settings_view != null:
		_settings_view.visible = false
	_shop_panel.visible = true
