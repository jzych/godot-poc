extends GutTest

func test_bridge_class_exists():
	var bridge = SolarSystemBridge.new()
	assert_not_null(bridge, "SolarSystemBridge should instantiate")
	assert_true(bridge is Node, "SolarSystemBridge should be a Node")
	bridge.free()

func test_bridge_has_bodies():
	var bridge = SolarSystemBridge.new()
	add_child(bridge)
	await get_tree().process_frame
	assert_eq(bridge.get_body_count(), 3, "Should have 3 bodies after init")
	bridge.queue_free()

func test_body_positions_change():
	var bridge = SolarSystemBridge.new()
	add_child(bridge)
	await get_tree().process_frame
	var pos_before = bridge.get_body_state(1)["position"]
	for i in range(10):
		await get_tree().process_frame
	var pos_after = bridge.get_body_state(1)["position"]
	assert_ne(pos_before, pos_after, "Earth position should change over time")
	bridge.queue_free()

func test_sun_stays_at_origin():
	var bridge = SolarSystemBridge.new()
	add_child(bridge)
	await get_tree().process_frame
	for i in range(10):
		await get_tree().process_frame
	var sun_pos = bridge.get_body_state(0)["position"]
	assert_eq(sun_pos, Vector3.ZERO, "Sun should remain at origin")
	bridge.queue_free()
