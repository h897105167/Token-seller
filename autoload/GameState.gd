extends Node
## 游戏状态管理器（autoload 单例）
## 持有 tokens、物品数量、已购科技、人品值等核心状态，并提供购买与存档接口

signal state_changed
signal tps_recalculated
signal item_purchased(item_id: String, count: int)
signal tech_purchased(tech_id: String)

var tokens: BigNumber
var total_tokens: BigNumber
var item_counts: Dictionary
var purchased_techs: Dictionary
var luck_value: int
var total_input_tokens: float
var login_days: int
var background_time: float
var last_login_date: String
# 每个物品已获得的 tokens 累计（用于"已获得"界面展示）
var item_tokens_earned: Dictionary

var tps_calculator: TPSCalculator


func _init() -> void:
	tokens = BigNumber.from_number(500.0)
	total_tokens = BigNumber.from_number(500.0)
	item_counts = {}
	for item_id in ItemsDB.get_item_ids():
		item_counts[item_id] = 0
	item_counts["keyboard"] = 1
	purchased_techs = {}
	luck_value = 0
	total_input_tokens = 0.0
	login_days = 1
	background_time = 0.0
	last_login_date = ""
	item_tokens_earned = {}


func _ready() -> void:
	tps_calculator = TPSCalculator.new()
	tps_calculator.set_game_state(self)
	tps_calculator.recalculate()
	# 注意：state_changed 信号不再触发 tps_recalculate
	# TPS 重算只在购买物品/科技时通过 _recalculate_tps() 触发
	# 这样 add_tokens 每 0.1 秒触发 state_changed 时不会重算 TPS


func _recalculate_tps() -> void:
	tps_calculator.recalculate()
	emit_signal("tps_recalculated")


# ===== 物品购买 =====

func get_item_price(item_id: String, batch_size: int) -> BigNumber:
	var item = ItemsDB.get_all_items().get(item_id)
	if item == null:
		return BigNumber.zero()
	var n: int = get_item_count(item_id)
	var base_price: float = item.base_price
	var growth: float = pow(1.15, n)
	if batch_size == 1:
		return BigNumber.from_number(base_price * growth)
	# 批量公式: base_price × 1.15^n × (1.15^batch_size - 1) / (1.15 - 1)
	var batch_factor: float = (pow(1.15, batch_size) - 1.0) / 0.15
	return BigNumber.from_number(base_price * growth * batch_factor)


func is_item_visible(item_id: String) -> bool:
	var item_ids: Array = ItemsDB.get_item_ids()
	var index: int = item_ids.find(item_id)
	if index == -1:
		return false
	# 键盘（index 0）始终 visible
	if index == 0:
		return true
	# 检查前两个物品是否已购买（item_counts > 0）
	if index - 1 >= 0 and get_item_count(item_ids[index - 1]) > 0:
		return true
	if index - 2 >= 0 and get_item_count(item_ids[index - 2]) > 0:
		return true
	return false


func is_item_purchasable(item_id: String, batch_size: int) -> bool:
	return is_item_visible(item_id) and tokens.is_greater_equal(get_item_price(item_id, batch_size))


func can_afford_item(item_id: String, batch_size: int) -> bool:
	if not is_item_visible(item_id):
		return false
	return tokens.is_greater_equal(get_item_price(item_id, batch_size))


func buy_item(item_id: String, batch_size: int) -> bool:
	if not can_afford_item(item_id, batch_size):
		return false
	var price: BigNumber = get_item_price(item_id, batch_size)
	tokens = tokens.subtract(price)
	item_counts[item_id] = get_item_count(item_id) + batch_size
	emit_signal("item_purchased", item_id, batch_size)
	emit_signal("state_changed")
	_recalculate_tps()
	return true


# ===== 科技购买 =====

func is_tech_visible(tech_id: String) -> bool:
	if is_tech_purchased(tech_id):
		return false
	var tech = TechDB.get_tech_by_id(tech_id)
	if tech == null:
		return false
	var line: Array = get_tech_line(tech_id)
	# 直接在线性数组中找到序号（避免重复调用 get_tech_line）
	var seq: int = -1
	for i in range(line.size()):
		if line[i].id == tech_id:
			seq = i
			break
	if seq == -1:
		return false
	# 同线第一个科技按原 unlock_condition 判断
	if seq == 0:
		# 前置科技必须已购买
		if tech.prereq_tech_id != "" and not is_tech_purchased(tech.prereq_tech_id):
			return false
		# 解锁条件
		var unlock: Dictionary = tech.unlock_condition
		var type: String = unlock.get("type", "")
		if type == "input_tokens":
			if total_input_tokens < float(unlock.get("value", 0.0)):
				return false
		elif type == "item_count":
			var req_item_id: String = unlock.get("item_id", "")
			if get_item_count(req_item_id) < int(unlock.get("value", 0)):
				return false
		elif type == "login_days":
			if login_days < int(unlock.get("value", 0)):
				return false
		return true
	# 非第一个科技：检查同线前两个科技是否已购买
	if seq - 1 >= 0 and is_tech_purchased(line[seq - 1].id):
		return true
	if seq - 2 >= 0 and is_tech_purchased(line[seq - 2].id):
		return true
	return false


func is_tech_purchasable(tech_id: String) -> bool:
	var tech = TechDB.get_tech_by_id(tech_id)
	if tech == null:
		return false
	return is_tech_visible(tech_id) and tokens.is_greater_equal(BigNumber.from_number(tech.price))


func can_afford_tech(tech_id: String) -> bool:
	if not is_tech_visible(tech_id):
		return false
	var tech = TechDB.get_tech_by_id(tech_id)
	if tech == null:
		return false
	return tokens.is_greater_equal(BigNumber.from_number(tech.price))


func buy_tech(tech_id: String) -> bool:
	if not can_afford_tech(tech_id):
		return false
	var tech = TechDB.get_tech_by_id(tech_id)
	if tech == null:
		return false
	tokens = tokens.subtract(BigNumber.from_number(tech.price))
	purchased_techs[tech_id] = true
	emit_signal("tech_purchased", tech_id)
	emit_signal("state_changed")
	_recalculate_tps()
	return true


# ===== Token 管理 =====

func add_tokens(amount: BigNumber) -> void:
	tokens = tokens.add(amount)
	total_tokens = total_tokens.add(amount)
	# 按各物品 TPS 贡献比例分配累计到 item_tokens_earned
	if tps_calculator != null and tps_calculator.total_tps > 0.0:
		var total_tps: float = tps_calculator.total_tps
		for item_id in item_counts:
			var count: int = int(item_counts[item_id])
			if count <= 0:
				continue
			var per_tps: float = float(tps_calculator.item_tps.get(item_id, 0.0))
			if per_tps <= 0.0:
				continue
			var share: float = per_tps * count / total_tps
			var earned: BigNumber = BigNumber.from_number(amount.to_float() * share)
			item_tokens_earned[item_id] = get_item_tokens_earned(item_id).add(earned)
	emit_signal("state_changed")


func add_input_tokens(amount: BigNumber, base_amount: float) -> void:
	tokens = tokens.add(amount)
	total_tokens = total_tokens.add(amount)
	total_input_tokens += base_amount
	emit_signal("state_changed")


func spend_tokens(amount: BigNumber) -> void:
	tokens = tokens.subtract(amount)
	emit_signal("state_changed")


# ===== 存档 =====

func to_dict() -> Dictionary:
	var item_tokens_earned_dict: Dictionary = {}
	for item_id in item_tokens_earned:
		var val = item_tokens_earned[item_id]
		if val is BigNumber:
			item_tokens_earned_dict[item_id] = val.to_dict()
	return {
		"tokens": tokens.to_dict(),
		"total_tokens": total_tokens.to_dict(),
		"item_counts": item_counts.duplicate(),
		"purchased_techs": purchased_techs.duplicate(),
		"luck_value": luck_value,
		"total_input_tokens": total_input_tokens,
		"login_days": login_days,
		"background_time": background_time,
		"last_login_date": last_login_date,
		"item_tokens_earned": item_tokens_earned_dict,
	}


func from_dict(d: Dictionary) -> void:
	tokens = BigNumber.from_dict(d.get("tokens", {"mantissa": 0.0, "exponent": 0}))
	total_tokens = BigNumber.from_dict(d.get("total_tokens", {"mantissa": 0.0, "exponent": 0}))
	item_counts = d.get("item_counts", {}).duplicate()
	purchased_techs = d.get("purchased_techs", {}).duplicate()
	luck_value = int(d.get("luck_value", 0))
	total_input_tokens = float(d.get("total_input_tokens", 0.0))
	login_days = int(d.get("login_days", 1))
	background_time = float(d.get("background_time", 0.0))
	last_login_date = d.get("last_login_date", "")
	item_tokens_earned = {}
	var ite_dict: Dictionary = d.get("item_tokens_earned", {})
	for item_id in ite_dict:
		item_tokens_earned[item_id] = BigNumber.from_dict(ite_dict[item_id])
	emit_signal("state_changed")
	# 加载存档后重算 TPS（物品数量和已购科技可能变化）
	_recalculate_tps()


# ===== 辅助 =====

func get_item_count(item_id: String) -> int:
	return int(item_counts.get(item_id, 0))


func get_item_tokens_earned(item_id: String) -> BigNumber:
	var val = item_tokens_earned.get(item_id, null)
	if val == null:
		return BigNumber.zero()
	if val is BigNumber:
		return val
	return BigNumber.zero()


func is_tech_purchased(tech_id: String) -> bool:
	return purchased_techs.has(tech_id)


func get_tech_line(tech_id: String) -> Array:
	var tech = TechDB.get_tech_by_id(tech_id)
	if tech == null:
		return []
	if tech.category == "input":
		return TechDB.get_input_techs()
	elif tech.category == "universal":
		return TechDB.get_universal_techs()
	elif tech.category == "item":
		return TechDB.get_item_techs(tech.target_item_id)
	return []


func get_tech_seq_in_line(tech_id: String) -> int:
	var line: Array = get_tech_line(tech_id)
	for i in range(line.size()):
		if line[i].id == tech_id:
			return i
	return -1
