class_name BigNumberTest
extends RefCounted
## BigNumber 单元测试脚本
## 调用 BigNumberTest.run_tests() 运行所有测试，返回 true 表示全部通过


static func run_tests() -> bool:
	var all_passed = true
	print("=== BigNumber Tests ===")

	# Test 1: 1E30 - 2E29 = 8E29
	var a = BigNumber.from_power(30)
	var b = BigNumber.from_power(29).multiply(2.0)
	var c = a.subtract(b)
	var passed = (c.to_str() == "8E29")
	print("Test 1: 1E30 - 2E29 = 8E29: ", "PASS" if passed else "FAIL (got " + c.to_str() + ")")
	all_passed = all_passed and passed

	# Test 2: 1.5E3 (1500) formatting
	var d = BigNumber.from_number(1500.0)
	var formatted = d.to_formatted_string()
	passed = (formatted == "1500")
	print("Test 2: 1.5E3 formatted = 1500: ", "PASS" if passed else "FAIL (got " + formatted + ")")
	all_passed = all_passed and passed

	# Test 3: 20 × 1.15^3 (price calculation)
	var scalar = pow(1.15, 3)
	var price_bn = BigNumber.from_number(20.0).multiply(scalar)
	var expected_float = 20.0 * scalar
	var expected_str = "%.2f" % expected_float
	passed = (price_bn.to_formatted_string() == expected_str)
	print("Test 3: 20 × 1.15^3 = ", expected_str, ": ", "PASS" if passed else "FAIL (got " + price_bn.to_formatted_string() + ")")
	all_passed = all_passed and passed

	# Test 4: 500 + 100 = 600
	var e = BigNumber.from_number(500.0).add(BigNumber.from_number(100.0))
	passed = (e.to_formatted_string() == "600")
	print("Test 4: 500 + 100 = 600: ", "PASS" if passed else "FAIL (got " + e.to_formatted_string() + ")")
	all_passed = all_passed and passed

	# Test 5: from_number(1500).to_str() == "1.5E3"
	var f = BigNumber.from_number(1500.0)
	passed = (f.to_str() == "1.5E3")
	print("Test 5: from_number(1500).to_str() == '1.5E3': ", "PASS" if passed else "FAIL (got " + f.to_str() + ")")
	all_passed = all_passed and passed

	# Test 6: Comparison: 1E30 > 2E29
	var g1 = BigNumber.from_power(30)
	var g2 = BigNumber.from_power(29).multiply(2.0)
	passed = (g1.compare(g2) > 0)
	print("Test 6: 1E30 > 2E29: ", "PASS" if passed else "FAIL (compare returned " + str(g1.compare(g2)) + ")")
	all_passed = all_passed and passed

	# Test 7: Serialization round-trip
	var h = BigNumber.from_mantissa_exp(3.14, 25)
	var dict = h.to_dict()
	var h2 = BigNumber.from_dict(dict)
	passed = (h.mantissa == h2.mantissa and h.exponent == h2.exponent)
	print("Test 7: Serialization round-trip (3.14E25): ", "PASS" if passed else "FAIL")
	all_passed = all_passed and passed

	# Additional Test 8: multiply_bn
	var m1 = BigNumber.from_number(2.0)
	var m2 = BigNumber.from_power(10)
	var m3 = m1.multiply_bn(m2)
	passed = (m3.to_str() == "2E10")
	print("Test 8: 2 × 1E10 = 2E10 (multiply_bn): ", "PASS" if passed else "FAIL (got " + m3.to_str() + ")")
	all_passed = all_passed and passed

	# Additional Test 9: divide
	var div = BigNumber.from_number(100.0).divide(4.0)
	passed = (div.to_formatted_string() == "25")
	print("Test 9: 100 / 4 = 25 (divide): ", "PASS" if passed else "FAIL (got " + div.to_formatted_string() + ")")
	all_passed = all_passed and passed

	# Additional Test 10: is_greater_equal / is_less
	passed = (g1.is_greater_equal(g2) and g2.is_less(g1))
	print("Test 10: is_greater_equal / is_less: ", "PASS" if passed else "FAIL")
	all_passed = all_passed and passed

	# Additional Test 11: zero handling
	var z = BigNumber.zero()
	passed = (z.to_str() == "0" and z.to_formatted_string() == "0")
	print("Test 11: zero handling: ", "PASS" if passed else "FAIL (got " + z.to_str() + ")")
	all_passed = all_passed and passed

	# Additional Test 12: large number formatting (1E40)
	var big = BigNumber.from_power(40)
	passed = (big.to_str() == "1E40")
	print("Test 12: 1E40 to_str: ", "PASS" if passed else "FAIL (got " + big.to_str() + ")")
	all_passed = all_passed and passed

	print("=== All tests passed: ", all_passed, " ===")
	return all_passed
