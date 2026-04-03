extends SceneTree

var _failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	await _test_bridge_class_exists()
	await _test_bridge_has_bodies()
	await _test_body_positions_change()
	await _test_sun_stays_at_origin()

	if _failures > 0:
		push_error("Bridge test runner failed %d test(s)." % _failures)
		quit(1)
		return

	print("Bridge test runner passed.")
	quit(0)

func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		_failures += 1

func _assert_equal(actual, expected, message: String) -> void:
	if actual != expected:
		push_error("%s Expected: %s Actual: %s" % [message, expected, actual])
		_failures += 1

func _assert_not_equal(actual, expected, message: String) -> void:
	if actual == expected:
		push_error("%s Value: %s" % [message, actual])
		_failures += 1

func _add_bridge() -> SolarSystemBridge:
	var bridge = SolarSystemBridge.new()
	get_root().add_child(bridge)
	await process_frame
	return bridge

func _remove_bridge(bridge: SolarSystemBridge) -> void:
	if bridge != null and is_instance_valid(bridge):
		bridge.queue_free()
		await process_frame

func _test_bridge_class_exists() -> void:
	var bridge = SolarSystemBridge.new()
	_assert_true(bridge != null, "SolarSystemBridge should instantiate")
	_assert_true(bridge is Node, "SolarSystemBridge should be a Node")
	bridge.free()

func _test_bridge_has_bodies() -> void:
	var bridge = await _add_bridge()
	_assert_equal(bridge.get_body_count(), 3, "Bridge should create three bodies.")
	await _remove_bridge(bridge)

func _test_body_positions_change() -> void:
	var bridge = await _add_bridge()
	var pos_before = bridge.get_body_state(1).get("position", Vector3.ZERO)

	for _i in range(10):
		await process_frame

	var pos_after = bridge.get_body_state(1).get("position", Vector3.ZERO)
	_assert_not_equal(pos_before, pos_after, "Earth position should change over time.")
	await _remove_bridge(bridge)

func _test_sun_stays_at_origin() -> void:
	var bridge = await _add_bridge()

	for _i in range(10):
		await process_frame

	var sun_pos = bridge.get_body_state(0).get("position", Vector3.ZERO)
	_assert_equal(sun_pos, Vector3.ZERO, "Sun should remain at the origin.")
	await _remove_bridge(bridge)
