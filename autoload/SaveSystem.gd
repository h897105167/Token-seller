extends Node
## 存档系统（autoload 单例）
## 负责将 GameState 序列化为 JSON 存档、启动时加载、定时自动保存以及退出时保存
## 同时实现离线 TPS 收益：退出时记录时间戳，启动时计算离线时长 × TPS 发放奖励

const SAVE_PATH = "user://save.json"
const AUTOSAVE_INTERVAL: float = 30.0  # 每 30 秒自动保存一次
const OFFLINE_REWARD_CAP_SECONDS: float = 86400.0 * 7.0  # 离线收益最多计算 7 天

var _autosave_timer: float = 0.0
# 离线奖励信息（加载后填充，供 UI 显示）
var last_offline_seconds: float = 0.0
var last_offline_tokens: BigNumber = null
var last_offline_tps: float = 0.0


func _ready() -> void:
	# 启动时尝试加载存档
	load_game()


func _process(delta: float) -> void:
	_autosave_timer += delta
	if _autosave_timer >= AUTOSAVE_INTERVAL:
		_autosave_timer = 0.0
		save_game()


func _notification(what: int) -> void:
	# 应用退出时保存
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()


func save_game() -> bool:
	# 将 GameState 序列化为 JSON 文件，并记录退出时间戳
	var data: Dictionary = {
		"version": 1,
		"save_time": Time.get_datetime_string_from_system(false, true),
		"save_timestamp": Time.get_unix_time_from_system(),
		"game_state": GameState.to_dict(),
	}
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		printerr("[SaveSystem] 无法打开存档文件进行写入: ", SAVE_PATH, " 错误: ", FileAccess.get_open_error())
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true


func load_game() -> bool:
	# 从 SAVE_PATH 读取 JSON 并恢复 GameState，并计算离线收益
	if not FileAccess.file_exists(SAVE_PATH):
		# 首次运行，无存档
		return false
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		printerr("[SaveSystem] 无法打开存档文件进行读取: ", SAVE_PATH, " 错误: ", FileAccess.get_open_error())
		return false
	var text: String = file.get_as_text()
	file.close()

	var json = JSON.new()
	var err = json.parse(text)
	if err != OK:
		printerr("[SaveSystem] JSON 解析失败: ", json.get_error_message(), " 行: ", json.get_error_line())
		return false
	var data = json.data
	if typeof(data) != TYPE_DICTIONARY:
		printerr("[SaveSystem] 存档根节点不是 Dictionary")
		return false
	if not data.has("game_state"):
		printerr("[SaveSystem] 存档缺少 game_state 字段")
		return false

	GameState.from_dict(data["game_state"])

	# 登录天数追踪
	_track_login_day()

	# 计算离线收益
	_calculate_offline_reward(data)

	return true


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


# ===== 内部辅助 =====

func _track_login_day() -> void:
	var today: String = Time.get_date_string_from_system(false)
	var last: String = GameState.last_login_date
	if last == "":
		# 首次登录：仅记录今日日期，login_days 保持初始值
		GameState.last_login_date = today
	elif last != today:
		# 新的一天：增加登录天数并更新日期
		GameState.login_days += 1
		GameState.last_login_date = today
	# 同一天：不做处理


func _calculate_offline_reward(data: Dictionary) -> void:
	# 基于存档时间戳计算离线时长，按当前 TPS 发放收益
	last_offline_seconds = 0.0
	last_offline_tokens = null
	last_offline_tps = 0.0

	if not data.has("save_timestamp"):
		return
	var save_ts: float = float(data["save_timestamp"])
	var now_ts: float = Time.get_unix_time_from_system()
	var elapsed: float = now_ts - save_ts
	if elapsed <= 0.0:
		return
	# 限制最大离线收益时长
	elapsed = min(elapsed, OFFLINE_REWARD_CAP_SECONDS)

	# 使用存档加载后的当前 TPS 计算
	var tps: float = 0.0
	if GameState.tps_calculator != null:
		tps = GameState.tps_calculator.total_tps
	if tps <= 0.0:
		return

	var earned: BigNumber = BigNumber.from_number(tps * elapsed)
	GameState.add_tokens(earned)

	last_offline_seconds = elapsed
	last_offline_tokens = earned
	last_offline_tps = tps
