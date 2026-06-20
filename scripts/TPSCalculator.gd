class_name TPSCalculator
extends RefCounted
## TPS 计算引擎
## 根据 GameState 中的物品数量与已购科技计算各项 TPS 值与行为获得倍率

var total_tps: float = 0.0
var item_tps: Dictionary = {}
var item_total_tps: Dictionary = {}
var exponential_multiplier: Dictionary = {}
var linear_multiplier: Dictionary = {}
var universal_multiplier: float = 1.0
var input_gain_multiplier: float = 0.0
var input_base_linear_multiplier: float = 0.0

var _game_state: Node


func _init(gs: Node = null) -> void:
	_game_state = gs


func set_game_state(gs: Node) -> void:
	_game_state = gs


func recalculate() -> void:
	if _game_state == null:
		return

	var all_items: Dictionary = ItemsDB.get_all_items()
	var item_ids: Array = ItemsDB.get_item_ids()
	var all_techs: Array = TechDB.get_all_techs()

	# 单次遍历：预计算已购科技集合 + 按类别/effect_type 分组
	var purchased: Dictionary = {}
	var purchased_universal_count: int = 0
	var purchased_input_techs: Array = []  # 已购输入科技（用于 input_base_linear）
	# 按物品分组：item_id -> {double_count, other_linear_purchased, self_to_others_linear_purchased}
	var per_item: Dictionary = {}
	for item_id in item_ids:
		per_item[item_id] = {"double_count": 0, "has_other_linear": false, "has_self_to_others_linear": false}

	for tech in all_techs:
		var is_purchased: bool = _game_state.is_tech_purchased(tech.id)
		if not is_purchased:
			continue
		purchased[tech.id] = true
		if tech.category == "universal":
			purchased_universal_count += 1
		elif tech.category == "input":
			purchased_input_techs.append(tech)
		elif tech.category == "item":
			var pi: Dictionary = per_item[tech.target_item_id]
			if tech.effect_type == "item_double":
				pi.double_count += 1
			elif tech.effect_type == "item_other_linear":
				pi.has_other_linear = true
			elif tech.effect_type == "item_self_to_others_linear":
				pi.has_self_to_others_linear = true

	# 1. 通用科技数量 → universal_multiplier = 2^k
	universal_multiplier = pow(2.0, purchased_universal_count)

	# 2. 每个物品的 item_double 科技数量 → exponential_multiplier = 2^n
	exponential_multiplier.clear()
	linear_multiplier.clear()
	for item_id in item_ids:
		var pi: Dictionary = per_item[item_id]
		exponential_multiplier[item_id] = pow(2.0, pi.double_count)
		linear_multiplier[item_id] = 0.0

	# 总物品数
	var total_item_count: int = 0
	for item_id in item_ids:
		total_item_count += _game_state.get_item_count(item_id)

	# 3. 线性倍率（只检查已购科技，避免全量遍历）
	for item_id in item_ids:
		var pi: Dictionary = per_item[item_id]
		var linear: float = 0.0
		# item_other_linear: 每持有其他物品，本物品 TPS +1%
		if pi.has_other_linear:
			linear += (total_item_count - _game_state.get_item_count(item_id)) * 0.01
		# item_self_to_others_linear: 其他物品的 t2 科技，每持有该其他物品，本物品 TPS +1%
		for other_id in item_ids:
			if other_id == item_id:
				continue
			var pi_other: Dictionary = per_item[other_id]
			if pi_other.has_self_to_others_linear:
				linear += _game_state.get_item_count(other_id) * 0.01
		linear_multiplier[item_id] = linear

	# 4-6. item_tps / item_total_tps / total_tps
	item_tps.clear()
	item_total_tps.clear()
	total_tps = 0.0
	for item_id in item_ids:
		var item = all_items[item_id]
		var tps: float = item.base_tps * exponential_multiplier[item_id] * (1.0 + linear_multiplier[item_id]) * universal_multiplier
		item_tps[item_id] = tps
		var total: float = _game_state.get_item_count(item_id) * tps
		item_total_tps[item_id] = total
		total_tps += total

	# 7. input_gain 科技数量 → input_gain_multiplier = n × 1.0 (n × 100%)
	input_gain_multiplier = float(purchased_input_techs.size())

	# 8. input_base_linear: 每个输入科技的 secondary_effect source_item_id
	input_base_linear_multiplier = 0.0
	for tech in purchased_input_techs:
		var secondary: Dictionary = tech.secondary_effect
		if secondary.get("type", "") == "input_base_linear":
			var source_item_id: String = secondary.get("source_item_id", "")
			input_base_linear_multiplier += _game_state.get_item_count(source_item_id) * 0.01


func get_behavior_tokens(base_tokens: float) -> BigNumber:
	return get_behavior_tokens_with_crit(base_tokens, 0.0, 0.0)


func get_behavior_tokens_with_crit(base_tokens: float, crit_multiplier: float, reward_multiplier: float) -> BigNumber:
	# base × (1 + 行为线性倍率) + 总TPS × 行为获得倍率 × (1 + 暴击倍数 + 奖励倍数)
	# 暴击与奖励互斥（奖励时间内禁用暴击），故二者通常不同时非零
	var base_part: float = base_tokens * (1.0 + input_base_linear_multiplier)
	var tps_part: float = total_tps * input_gain_multiplier * (1.0 + crit_multiplier + reward_multiplier)
	return BigNumber.from_number(base_part + tps_part)
