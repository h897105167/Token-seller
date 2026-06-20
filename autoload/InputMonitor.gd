extends Node
## 输入监控器（autoload 单例）
## 监听键盘、鼠标行为，按规则发放 token，并处理暴击与奖励时间

signal input_rewarded(base_tokens: float, total_tokens: BigNumber, is_crit: bool)

var reward_time_active: bool = false
var reward_multiplier: float = 0.0

var _mouse_distance_accumulator: float = 0.0

const CRIT_CHANCE: float = 0.01  # 1% 暴击概率
const MOUSE_PIXEL_THRESHOLD: float = 100.0  # 每 100 像素


func _input(event: InputEvent) -> void:
	# 键盘按键
	if event is InputEventKey and event.pressed and not event.echo:
		_handle_key_press(event)
	# 鼠标移动
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)
	# 鼠标滚轮
	elif event is InputEventMouseButton and event.pressed:
		_handle_mouse_wheel(event)


func _handle_key_press(event: InputEventKey) -> void:
	# 单独的修饰键按下不计入
	var keycode: int = event.keycode
	if keycode == KEY_CTRL or keycode == KEY_SHIFT or keycode == KEY_ALT or keycode == KEY_META:
		return

	# Ctrl/Alt/Shift/Meta + 普通键 → 组合键
	var is_combination: bool = event.ctrl_pressed or event.alt_pressed or event.shift_pressed or event.meta_pressed

	var base_tokens: float = 0.0
	if is_combination:
		# 组合键 → 5 基础 token
		base_tokens = 5.0
	elif event.unicode > 0:
		# 单字符按键 → 1 基础 token
		base_tokens = 1.0
	else:
		# 非可打印字符且无修饰键（如 F1、方向键等），不计入
		return

	_award_input_tokens(base_tokens)


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	_mouse_distance_accumulator += event.relative.length()
	if _mouse_distance_accumulator >= MOUSE_PIXEL_THRESHOLD:
		var units: int = int(_mouse_distance_accumulator / MOUSE_PIXEL_THRESHOLD)
		var base_tokens: float = units * 0.2
		_mouse_distance_accumulator -= units * MOUSE_PIXEL_THRESHOLD
		_award_input_tokens(base_tokens)


func _handle_mouse_wheel(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		var base_tokens: float = 2.0
		_award_input_tokens(base_tokens)


func _award_input_tokens(base_tokens: float) -> void:
	var crit_mult: float = 0.0
	var reward_mult: float = 0.0
	if reward_time_active:
		# 奖励时间内无暴击，仅应用奖励倍率
		reward_mult = reward_multiplier
	else:
		# 正常状态下判定暴击
		if randf() < CRIT_CHANCE:
			crit_mult = randf_range(2.0, 5.0) + GameState.luck_value / 1000.0
			GameState.luck_value += 1

	var tokens: BigNumber = GameState.tps_calculator.get_behavior_tokens_with_crit(base_tokens, crit_mult, reward_mult)
	GameState.add_input_tokens(tokens, base_tokens)
	emit_signal("input_rewarded", base_tokens, tokens, crit_mult > 0.0)
