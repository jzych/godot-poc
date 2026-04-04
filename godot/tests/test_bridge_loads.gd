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

func test_body_state_exposes_orbit_metadata():
	var bridge = SolarSystemBridge.new()
	add_child(bridge)
	await get_tree().process_frame

	var sun_state: Dictionary = bridge.get_body_state(0)
	var earth_state: Dictionary = bridge.get_body_state(1)
	var orbit: Dictionary = earth_state["orbit"]
	var rotation: Dictionary = earth_state["rotation"]

	assert_eq(sun_state["central_body_name"], "", "Root bodies should not expose placeholder central-body text")
	assert_eq(earth_state["central_body_name"], "Sun", "Earth should expose Sun as its central body")
	assert_gt(earth_state["orbital_period_seconds"], 0.0, "Earth should expose orbital period in seconds")
	assert_ne(earth_state["orbital_period_ydhms"], "", "Earth should expose formatted orbital period text")
	assert_eq(orbit["central_body_index"], 0, "Earth orbit metadata should reference the Sun index")
	assert_gt(orbit["semi_major_axis_km"], 0.0, "Earth orbit metadata should expose the semi-major axis")
	assert_eq(orbit["anomaly_kind"], "mean_anomaly", "Earth should expose its anomaly representation")
	assert_gt(rotation["rotation_speed_rad_per_s"], 0.0, "Earth should expose axial rotation speed")
	assert_gt(rotation["orbital_period_seconds"], 0.0, "Earth should expose orbital period in rotation metadata")
	bridge.queue_free()

func test_initial_body_position_matches_exported_anomaly():
	var bridge = SolarSystemBridge.new()
	add_child(bridge)
	await get_tree().process_frame

	var earth_state: Dictionary = bridge.get_body_state(1)
	var orbit: Dictionary = earth_state["orbit"]
	var position: Vector3 = earth_state["position"]
	var sim_time_seconds: float = bridge.get_sim_time()
	var orbital_period_seconds: float = earth_state["orbital_period_seconds"]
	var semi_major_axis_units: float = float(orbit["semi_major_axis_km"]) * (10000.0 / 149597870.7)
	var anomaly: float = float(orbit["anomaly_at_epoch"])
	var omega: float = TAU / orbital_period_seconds
	var expected_angle: float = anomaly + (omega * sim_time_seconds)
	var expected_position := Vector3(
		cos(expected_angle) * semi_major_axis_units,
		0.0,
		sin(expected_angle) * semi_major_axis_units
	)

	assert_almost_eq(position.x, expected_position.x, 0.001, "Earth X position should match the exported anomaly and current sim time")
	assert_almost_eq(position.z, expected_position.z, 0.001, "Earth Z position should match the exported anomaly and current sim time")
	bridge.queue_free()

func test_bridge_formats_duration_ydhms():
	var bridge = SolarSystemBridge.new()
	assert_eq(bridge.format_duration_ydhms(0.0), "0s", "Formatter should show zero seconds for zero duration")
	assert_eq(
		bridge.format_duration_ydhms((6.0 * 3600.0) + (15.0 * 60.0) + 12.0),
		"6h 15min 12s",
		"Formatter should return compact ydhms text"
	)
	bridge.free()
