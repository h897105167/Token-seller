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

	# 预计算已购科技集合
	var purchased: Dictionary = {}
	for tech in all_techs:
		if _game_state.is_tech_purchased(tech.id):
			purchased[tech.id] = true

	# 1. 通用科技数量 → universal_multiplier = 2^k
	var universal_count: int = 0
	for tech in all_techs:
		if tech.category == "universal" and purchased.has(tech.id):
			universal_count += 1
	universal_multiplier = pow(2.0, universal_count)

	# 2. 每个物品的 item_double 科技数量 → exponential_multiplier = 2^n
	exponential_multiplier.clear()
	linear_multiplier.clear()
	for item_id in item_ids:
		var double_count: int = 0
		for tech in all_techs:
			if tech.target_item_id == item_id and tech.effect_type == "item_double" and purchased.has(tech.id):
				double_count += 1
		exponential_multiplier[item_id] = pow(2.0, double_count)
		linear_multiplier[item_id] = 0.0

	# 总物品数
	var total_item_count: int = 0
	for item_id in item_ids:
		total_item_count += _game_state.get_item_count(item_id)

	# 3. 线性倍率
	for item_id in item_ids:
		var linear: float = 0.0
		# item_other_linear: 每持有其他物品，本物品 TPS +1%
		for tech in all_techs:
			if tech.target_item_id == item_id and tech.effect_type == "item_other_linear" and purchased.has(tech.id):
				linear += (total_item_count - _game_state.get_item_count(item_id)) * 0.01
		# item_self_to_others_linear: 其他物品的 t2 科技，每持有该其他物品，本物品 TPS +1%
		for other_id in item_ids:
			if other_id == item_id:
				continue
			for tech in all_techs:
				if tech.target_item_id == other_id and tech.effect_type == "item_self_to_others_linear" and purchased.has(tech.id):
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
	var input_gain_count: int = 0
	for tech in all_techs:
		if tech.effect_type == "input_gain" and purchased.has(tech.id):
			input_gain_count += 1
	input_gain_multiplier = float(input_gain_count)

	# 8. input_base_linear: 每个输入科技的 secondary_effect source_item_id
	input_base_linear_multiplier = 0.0
	for tech in all_techs:
		if tech.effect_type == "input_gain" and purchased.has(tech.id):
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
