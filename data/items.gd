class_name ItemsDB
extends RefCounted
## 所有物品的静态数据库

class ItemData:
	extends RefCounted
	## 物品数据定义
	var id: String          # e.g. "keyboard"
	var name: String        # e.g. "键盘"
	var base_price: float   # 初始售价
	var base_tps: float     # 基础TPS
	var description: String # 介绍
	var icon_path: String   # 图标路径

	func _init(p_id: String = "", p_name: String = "", p_base_price: float = 0.0, p_base_tps: float = 0.0, p_description: String = "", p_icon_path: String = "") -> void:
		id = p_id
		name = p_name
		base_price = p_base_price
		base_tps = p_base_tps
		description = p_description
		icon_path = p_icon_path


static func get_all_items() -> Dictionary:
	var items: Dictionary = {}
	items["keyboard"] = ItemData.new("keyboard", "键盘", 20.0, 1.0, "请帮我写一个 \"Hello, world\"。", "res://assets/icons/items/keyboard.jpg")
	items["microphone"] = ItemData.new("microphone", "麦克风", 100.0, 2.0, "人与人之间的谈话少了，但是人与 AI 之间的谈话却多了起来。", "res://assets/icons/items/microphone.jpg")
	items["programmer"] = ItemData.new("programmer", "程序员", 1500.0, 10.0, "一个程序员能为你工作十年，而成本仅仅是几张计算卡的价格。", "res://assets/icons/items/programmer.jpg")
	items["pipeline"] = ItemData.new("pipeline", "流水线", 15000.0, 50.0, "现在的流水线不再生产那些卖不出去的实体产品，而是 token 了。", "res://assets/icons/items/pipeline.jpg")
	items["ai_company"] = ItemData.new("ai_company", "AI 公司", 100000.0, 250.0, "为了获得更多 token，你开了一家 AI 公司。", "res://assets/icons/items/ai_company.jpg")
	items["data_center"] = ItemData.new("data_center", "计算中心", 2000000.0, 1500.0, "你用手上所有 token 置换了一家计算中心，无数都使用着你所生产的 token。", "res://assets/icons/items/data_center.jpg")
	items["nvotia"] = ItemData.new("nvotia", "Nvotia", 20000000.0, 8000.0, "为了垄断所有 token，你创立了显卡公司并击败了所有对手，成了市面上唯一一家能自主生产 token 计算卡的公司。", "res://assets/icons/items/nvotia.jpg")
	items["exchange"] = ItemData.new("exchange", "交易所", 500000000.0, 30000.0, "你为了能卖更高的价钱，使用线下交易的方式限制获取，制造稀缺性。", "res://assets/icons/items/exchange.jpg")
	items["bank"] = ItemData.new("bank", "银行", 6000000000.0, 250000.0, "token 可以创造无限的财富，因此所有的货币开始锚定 token，token 成了世界公认的货币。", "res://assets/icons/items/bank.jpg")
	items["token_nation"] = ItemData.new("token_nation", "token 之国", 80000000000.0, 1500000.0, "token 成为了货币之后，你创建了这个使用 token 驱动一切的国家。", "res://assets/icons/items/token_nation.jpg")
	items["spaceship"] = ItemData.new("spaceship", "飞船", 1500000000000.0, 10000000.0, "用地球的资源生产的 token 已经不能满足人类日常需求了，因此你建造飞船前往别的星球。", "res://assets/icons/items/spaceship.jpg")
	items["terraform"] = ItemData.new("terraform", "行星改造", 20000000000000.0, 55000000.0, "殖民外星之后，你们将整个星球都改造成了制造 token 的机器。", "res://assets/icons/items/terraform.jpg")
	items["ether_circuit"] = ItemData.new("ether_circuit", "以太电路", 200000000000000.0, 450000000.0, "人类发现了一种用以太制造电子元件的方法。人们开始将整个宇宙改造成生产 token 的工具。", "res://assets/icons/items/ether_circuit.jpg")
	items["token_ascension"] = ItemData.new("token_ascension", "token 飞升", 2500000000000000.0, 2000000000.0, "人们将大脑改造成了 token 制造机，产生 token 传递给 AI，让 AI 代替自己思考。", "res://assets/icons/items/token_ascension.jpg")
	items["time_machine"] = ItemData.new("time_machine", "时光机", 30000000000000000.0, 18000000000.0, "人们发明了时光机，能将 future 产生的 token 传送到现世。", "res://assets/icons/items/time_machine.jpg")
	items["ideal_machine"] = ItemData.new("ideal_machine", "理想机械", 350000000000000000.0, 120000000000.0, "如今，人类能将 token 和所有物质之间进行无损转化，token 成了宇宙的元素之一。", "res://assets/icons/items/ideal_machine.jpg")
	items["universe_replicator"] = ItemData.new("universe_replicator", "宇宙复制器", 8e23, 1e12, "复制了宇宙，就复制了 token。", "res://assets/icons/items/universe_replicator.jpg")
	items["truth_gate"] = ItemData.new("truth_gate", "真理之门", 1.5e24, 8e12, "给这扇门 token，它就能告诉你宇宙中的一切知识。", "res://assets/icons/items/truth_gate.jpg")
	items["wish_machine"] = ItemData.new("wish_machine", "许愿机", 2e25, 8e13, "用 token 驱动的许愿机。如果许愿更多 token 会发生什么？", "res://assets/icons/items/wish_machine.jpg")
	items["you"] = ItemData.new("you", "你", 5e26, 8e14, "一切都是因为有你。那么创造无数个你，就有了无数的 token。", "res://assets/icons/items/you.jpg")
	return items


static func get_item_ids() -> Array:
	return [
		"keyboard",
		"microphone",
		"programmer",
		"pipeline",
		"ai_company",
		"data_center",
		"nvotia",
		"exchange",
		"bank",
		"token_nation",
		"spaceship",
		"terraform",
		"ether_circuit",
		"token_ascension",
		"time_machine",
		"ideal_machine",
		"universe_replicator",
		"truth_gate",
		"wish_machine",
		"you",
	]
