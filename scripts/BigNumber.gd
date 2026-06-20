class_name BigNumber
extends RefCounted
## 大数工具类，使用科学计数法存储：value = mantissa × 10^exponent
## mantissa 规范化到 [1, 10) 区间，零值时 mantissa=0, exponent=0

var mantissa: float = 0.0
var exponent: int = 0


func _init(m: float = 0.0, e: int = 0) -> void:
	mantissa = m
	exponent = e
	_normalize()


func _normalize() -> void:
	if mantissa == 0.0:
		exponent = 0
		return
	if mantissa < 0.0:
		mantissa = -mantissa
	# 使用 log10 计算位移，将 mantissa 规范化到 [1, 10)
	var exp_shift = int(floor(log(mantissa) / log(10)))
	if exp_shift != 0:
		mantissa /= pow(10.0, exp_shift)
		exponent += exp_shift
	# 修正浮点误差
	while mantissa >= 10.0:
		mantissa /= 10.0
		exponent += 1
	while mantissa < 1.0 and mantissa > 0.0:
		mantissa *= 10.0
		exponent -= 1


func clone() -> BigNumber:
	return BigNumber.new(mantissa, exponent)


## 返回近似的 float 值（大数会溢出为 inf，仅用于小数值场景）
func to_float() -> float:
	return mantissa * pow(10.0, exponent)


func add(other: BigNumber) -> BigNumber:
	if mantissa == 0.0:
		return other.clone()
	if other.mantissa == 0.0:
		return clone()
	if exponent >= other.exponent:
		var exp_diff = exponent - other.exponent
		var other_m = other.mantissa
		if exp_diff < 300:
			other_m /= pow(10.0, exp_diff)
		else:
			other_m = 0.0
		return BigNumber.new(mantissa + other_m, exponent)
	else:
		var exp_diff = other.exponent - exponent
		var this_m = mantissa
		if exp_diff < 300:
			this_m /= pow(10.0, exp_diff)
		else:
			this_m = 0.0
		return BigNumber.new(this_m + other.mantissa, other.exponent)


func subtract(other: BigNumber) -> BigNumber:
	if other.mantissa == 0.0:
		return clone()
	if mantissa == 0.0:
		return BigNumber.zero()
	if compare(other) < 0:
		return BigNumber.zero()
	var exp_diff = exponent - other.exponent
	var other_m = other.mantissa
	if exp_diff > 0:
		if exp_diff < 300:
			other_m /= pow(10.0, exp_diff)
		else:
			other_m = 0.0
	var result_m = mantissa - other_m
	if result_m < 0.0:
		result_m = 0.0
	return BigNumber.new(result_m, exponent)


func multiply(scalar: float) -> BigNumber:
	return BigNumber.new(mantissa * scalar, exponent)


func multiply_bn(other: BigNumber) -> BigNumber:
	return BigNumber.new(mantissa * other.mantissa, exponent + other.exponent)


func divide(scalar: float) -> BigNumber:
	if scalar == 0.0:
		push_error("BigNumber: division by zero")
		return BigNumber.zero()
	return BigNumber.new(mantissa / scalar, exponent)


func compare(other: BigNumber) -> int:
	if mantissa == 0.0 and other.mantissa == 0.0:
		return 0
	if mantissa == 0.0:
		return -1
	if other.mantissa == 0.0:
		return 1
	if exponent > other.exponent:
		return 1
	if exponent < other.exponent:
		return -1
	if mantissa > other.mantissa:
		return 1
	if mantissa < other.mantissa:
		return -1
	return 0


func is_greater_equal(other: BigNumber) -> bool:
	return compare(other) >= 0


func is_less(other: BigNumber) -> bool:
	return compare(other) < 0


static func from_number(n: float) -> BigNumber:
	return BigNumber.new(n, 0)


static func from_power(exp: int) -> BigNumber:
	return BigNumber.new(1.0, exp)


static func from_mantissa_exp(m: float, e: int) -> BigNumber:
	return BigNumber.new(m, e)


static func zero() -> BigNumber:
	return BigNumber.new(0.0, 0)


func to_str() -> String:
	if mantissa == 0.0:
		return "0"
	var m = mantissa
	var e = exponent
	# 四舍五入到 1 位小数后再次规范化，避免 9.999... 显示为 "10E..."
	var rounded = round(m * 10.0) / 10.0
	if rounded >= 10.0:
		rounded /= 10.0
		e += 1
	var m_str: String
	if abs(rounded - round(rounded)) < 0.01:
		m_str = str(int(round(rounded)))
	else:
		m_str = "%.1f" % rounded
	return m_str + "E" + str(e)


func to_formatted_string() -> String:
	if mantissa == 0.0:
		return "0"
	# 小于 10000 的数显示为普通数字
	if exponent < 4:
		var value = mantissa * pow(10.0, exponent)
		if value < 10000.0:
			if abs(value - round(value)) < 0.01:
				return str(int(round(value)))
			else:
				return "%.2f" % value
	return to_str()


func to_dict() -> Dictionary:
	return {
		"mantissa": mantissa,
		"exponent": exponent
	}


static func from_dict(d: Dictionary) -> BigNumber:
	return BigNumber.new(float(d.get("mantissa", 0.0)), int(d.get("exponent", 0)))
