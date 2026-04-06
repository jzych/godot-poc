extends GutTest

const KM_PER_AU := 149597870.7
const GODOT_UNITS_PER_AU := 10000.0
const ORBIT_SOLVER_TOLERANCE := 0.000001
const MAX_KEPLER_ITERATIONS := 12

func _normalize_angle(angle_rad: float) -> float:
	angle_rad = fmod(angle_rad, TAU)
	if angle_rad < -PI:
		angle_rad += TAU
	elif angle_rad > PI:
		angle_rad -= TAU
	return angle_rad

func _true_to_mean_anomaly(true_anomaly_rad: float, eccentricity: float) -> float:
	if is_zero_approx(eccentricity):
		return _normalize_angle(true_anomaly_rad)

	var eccentric_anomaly := 2.0 * atan2(
		sqrt(1.0 - eccentricity) * sin(true_anomaly_rad * 0.5),
		sqrt(1.0 + eccentricity) * cos(true_anomaly_rad * 0.5)
	)
	return eccentric_anomaly - eccentricity * sin(eccentric_anomaly)

func _mean_anomaly_at_time(orbit: Dictionary, orbital_period_seconds: float, sim_time_seconds: float) -> float:
	var mean_motion := TAU / orbital_period_seconds
	var anomaly_kind := str(orbit.get("anomaly_kind", "none"))
	var anomaly_at_epoch := float(orbit.get("anomaly_at_epoch", 0.0))

	match anomaly_kind:
		"mean_anomaly":
			return anomaly_at_epoch + (mean_motion * sim_time_seconds)
		"true_anomaly":
			return _true_to_mean_anomaly(anomaly_at_epoch, float(orbit.get("eccentricity", 0.0))) + (mean_motion * sim_time_seconds)
		"time_of_periapsis_passage":
			return mean_motion * (sim_time_seconds - anomaly_at_epoch)
		_:
			return mean_motion * sim_time_seconds

func _solve_eccentric_anomaly(mean_anomaly_rad: float, eccentricity: float) -> float:
	if is_zero_approx(eccentricity):
		return _normalize_angle(mean_anomaly_rad)

	var normalized_mean_anomaly := _normalize_angle(mean_anomaly_rad)
	var eccentric_anomaly := normalized_mean_anomaly if eccentricity < 0.8 else (PI if normalized_mean_anomaly >= 0.0 else -PI)

	for _iteration in range(MAX_KEPLER_ITERATIONS):
		var residual := eccentric_anomaly - (eccentricity * sin(eccentric_anomaly)) - normalized_mean_anomaly
		var derivative := 1.0 - (eccentricity * cos(eccentric_anomaly))
		var step := residual / derivative
		eccentric_anomaly -= step
		if abs(step) <= ORBIT_SOLVER_TOLERANCE:
			break

	return eccentric_anomaly

func _orbit_normal(orbit: Dictionary) -> Vector3:
	var ascending_node_longitude := float(orbit.get("longitude_of_ascending_node_rad", 0.0))
	var inclination := float(orbit.get("inclination_rad", 0.0))
	var ascending_node_axis := Vector3(cos(ascending_node_longitude), 0.0, sin(ascending_node_longitude)).normalized()
	if ascending_node_axis.is_zero_approx():
		ascending_node_axis = Vector3.RIGHT

	return Vector3.UP.rotated(ascending_node_axis, inclination).normalized()

func _periapsis_direction(orbit: Dictionary, orbit_normal: Vector3) -> Vector3:
	var ascending_node_longitude := float(orbit.get("longitude_of_ascending_node_rad", 0.0))
	var argument_of_periapsis := float(orbit.get("argument_of_periapsis_rad", 0.0))
	var ascending_node_direction := Vector3(cos(ascending_node_longitude), 0.0, sin(ascending_node_longitude)).normalized()
	if ascending_node_direction.is_zero_approx():
		ascending_node_direction = Vector3.RIGHT

	return ascending_node_direction.rotated(orbit_normal, argument_of_periapsis).normalized()

func _expected_relative_position(orbit: Dictionary, orbital_period_seconds: float, sim_time_seconds: float) -> Vector3:
	var eccentricity := float(orbit.get("eccentricity", 0.0))
	var semi_major_axis_units := float(orbit.get("semi_major_axis_km", 0.0)) * (GODOT_UNITS_PER_AU / KM_PER_AU)
	var mean_anomaly := _mean_anomaly_at_time(orbit, orbital_period_seconds, sim_time_seconds)
	var eccentric_anomaly := _solve_eccentric_anomaly(mean_anomaly, eccentricity)
	var denominator := 1.0 - (eccentricity * cos(eccentric_anomaly))
	var sin_true_anomaly := sqrt(max(0.0, 1.0 - (eccentricity * eccentricity))) * sin(eccentric_anomaly) / denominator
	var cos_true_anomaly := (cos(eccentric_anomaly) - eccentricity) / denominator
	var true_anomaly := atan2(sin_true_anomaly, cos_true_anomaly)
	var radius_units := semi_major_axis_units * denominator
	var orbit_normal := _orbit_normal(orbit)
	var periapsis_direction := _periapsis_direction(orbit, orbit_normal)
	var tangential_direction := orbit_normal.cross(periapsis_direction).normalized()

	return (
		periapsis_direction * (radius_units * cos(true_anomaly)) +
		tangential_direction * (radius_units * sin(true_anomaly))
	)

func _angular_momentum_y(initial_position: Vector3, next_position: Vector3) -> float:
	return initial_position.cross(next_position - initial_position).y

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
	var expected_position := _expected_relative_position(orbit, orbital_period_seconds, sim_time_seconds)

	assert_almost_eq(position.x, expected_position.x, 0.01, "Earth X position should match the exported ellipse and current sim time")
	assert_almost_eq(position.y, expected_position.y, 0.01, "Earth Y position should match the exported ellipse and current sim time")
	assert_almost_eq(position.z, expected_position.z, 0.01, "Earth Z position should match the exported ellipse and current sim time")
	bridge.queue_free()

func test_moon_position_uses_inclined_ellipse():
	var bridge = SolarSystemBridge.new()
	add_child(bridge)
	await get_tree().process_frame

	var earth_state: Dictionary = bridge.get_body_state(1)
	var moon_state: Dictionary = bridge.get_body_state(2)
	var orbit: Dictionary = moon_state["orbit"]
	var sim_time_seconds: float = bridge.get_sim_time()
	var expected_relative := _expected_relative_position(
		orbit,
		moon_state["orbital_period_seconds"],
		sim_time_seconds
	)
	var actual_relative: Vector3 = moon_state["position"] - earth_state["position"]

	assert_almost_eq(actual_relative.x, expected_relative.x, 0.01, "Moon X offset from Earth should match the exported inclined ellipse")
	assert_almost_eq(actual_relative.y, expected_relative.y, 0.01, "Moon Y offset from Earth should match the exported inclined ellipse")
	assert_almost_eq(actual_relative.z, expected_relative.z, 0.01, "Moon Z offset from Earth should match the exported inclined ellipse")
	assert_gt(abs(actual_relative.y), 0.01, "Moon orbit should no longer stay flat on the XZ plane")
	bridge.queue_free()

func test_bridge_orbits_use_real_world_prograde_direction():
	var bridge = SolarSystemBridge.new()
	add_child(bridge)
	await get_tree().process_frame

	var earth_initial: Vector3 = bridge.get_body_state(1)["position"]
	var moon_initial_relative: Vector3 = bridge.get_body_state(2)["position"] - earth_initial

	await get_tree().process_frame

	var earth_next: Vector3 = bridge.get_body_state(1)["position"]
	var moon_next_relative: Vector3 = bridge.get_body_state(2)["position"] - earth_next

	assert_gt(
		_angular_momentum_y(earth_initial, earth_next),
		0.0,
		"Earth orbit should be prograde relative to the reference-plane north"
	)
	assert_gt(
		_angular_momentum_y(moon_initial_relative, moon_next_relative),
		0.0,
		"Moon orbit should be prograde relative to the reference-plane north"
	)
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
