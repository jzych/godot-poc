extends GutTest

const MAIN_SCENE := preload("res://scenes/main.tscn")
const OrbitMathScript := preload("res://scripts/orbit_math.gd")

func _spawn_main_scene() -> Node3D:
	var scene: Node3D = MAIN_SCENE.instantiate()
	add_child(scene)
	autofree(scene)
	return scene

func _wait_frames(count: int):
	for _i in range(count):
		await get_tree().process_frame

func _mouse_button_event(button_index: int, pressed: bool, position: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button_index
	event.pressed = pressed
	event.position = position
	event.global_position = position
	return event

func _click_at(scene, position: Vector2):
	scene._input(_mouse_button_event(MOUSE_BUTTON_LEFT, true, position))
	scene._input(_mouse_button_event(MOUSE_BUTTON_LEFT, false, position))

func test_orbit_lanes_exist_only_for_orbiting_bodies():
	var scene = _spawn_main_scene()
	await _wait_frames(2)

	assert_null(scene.get_orbit_lane_for_body_index(0), "Sun should not have an orbit lane")
	assert_not_null(scene.get_orbit_lane_for_body_index(1), "Earth should have an orbit lane")
	assert_not_null(scene.get_orbit_lane_for_body_index(2), "Moon should have an orbit lane")

func test_selected_orbit_lane_becomes_brighter_and_opaque_but_stays_faded():
	var scene = _spawn_main_scene()
	await _wait_frames(2)

	var earth = scene.body_nodes[1]
	var earth_lane = scene.get_orbit_lane_for_body_index(earth.body_index)
	var camera: Camera3D = scene.camera_rig.get_camera_node()
	var unselected_colors: PackedColorArray = earth_lane.get_sample_colors()
	var last_color_index := unselected_colors.size() - 1

	_click_at(scene, camera.unproject_position(earth.global_position))

	var selected_colors: PackedColorArray = earth_lane.get_sample_colors()
	assert_true(earth_lane.is_selected_lane(), "Selecting a body should switch its orbit lane to the selected style")
	assert_lt(unselected_colors[0].a, 1.0, "Unselected orbit lane should remain translucent")
	assert_lt(unselected_colors[last_color_index].a, 1.0, "Unselected orbit lane should remain translucent along the whole path")
	assert_gt(unselected_colors[0].a, unselected_colors[last_color_index].a, "Unselected orbit lane should be strongest at the body and fade away along the path")
	assert_eq(selected_colors[0].a, 1.0, "Selected orbit lane should become fully opaque")
	assert_eq(selected_colors[last_color_index].a, 1.0, "Selected orbit lane should stay fully opaque along the whole path")
	assert_gt(selected_colors[last_color_index].get_luminance(), unselected_colors[last_color_index].get_luminance(), "Selected orbit lane should be brighter than the default lane")
	assert_gt(selected_colors[0].get_luminance(), selected_colors[last_color_index].get_luminance(), "Selected orbit lane should be strongest at the body and fade away along the path")

func test_orbit_lane_samples_align_with_current_orbital_phase():
	var scene = _spawn_main_scene()
	await _wait_frames(2)

	var earth = scene.body_nodes[1]
	var earth_lane = scene.get_orbit_lane_for_body_index(earth.body_index)
	var sim_time_seconds: float = scene.bridge.get_sim_time()
	scene._sync_orbit_lanes(sim_time_seconds)
	var expected_positions := OrbitMathScript.sample_relative_positions_units(
		earth.orbit_state,
		float(earth.rotation_state.get("orbital_period_seconds", 0.0)),
		earth_lane.sample_count,
		sim_time_seconds
	)
	var actual_positions: PackedVector3Array = earth_lane.get_sample_positions()
	var sample_indexes := [0, int(earth_lane.sample_count / 4), int(earth_lane.sample_count / 2)]

	for sample_index in sample_indexes:
		assert_almost_eq(actual_positions[sample_index].x, expected_positions[sample_index].x, 0.001, "Orbit lane X sample should match orbital metadata")
		assert_almost_eq(actual_positions[sample_index].y, expected_positions[sample_index].y, 0.001, "Orbit lane Y sample should match orbital metadata")
		assert_almost_eq(actual_positions[sample_index].z, expected_positions[sample_index].z, 0.001, "Orbit lane Z sample should match orbital metadata")

func test_orbit_lane_seam_tracks_current_body_position():
	var scene = _spawn_main_scene()
	await _wait_frames(2)

	var earth = scene.body_nodes[1]
	var earth_lane = scene.get_orbit_lane_for_body_index(1)
	var moon = scene.body_nodes[2]
	var moon_lane = scene.get_orbit_lane_for_body_index(2)

	var earth_relative: Vector3 = earth.position - Vector3.ZERO
	var moon_relative: Vector3 = moon.position - earth.position
	var earth_samples: PackedVector3Array = earth_lane.get_sample_positions()
	var moon_samples: PackedVector3Array = moon_lane.get_sample_positions()
	var earth_last_index := earth_samples.size() - 1
	var moon_last_index := moon_samples.size() - 1

	assert_almost_eq(earth_samples[0].x, earth_relative.x, 0.001, "Earth lane seam should start at the current Earth position")
	assert_almost_eq(earth_samples[0].y, earth_relative.y, 0.001, "Earth lane seam should start at the current Earth position")
	assert_almost_eq(earth_samples[0].z, earth_relative.z, 0.001, "Earth lane seam should start at the current Earth position")
	assert_almost_eq(earth_samples[earth_last_index].x, earth_relative.x, 0.001, "Earth lane seam should end at the current Earth position")
	assert_almost_eq(earth_samples[earth_last_index].y, earth_relative.y, 0.001, "Earth lane seam should end at the current Earth position")
	assert_almost_eq(earth_samples[earth_last_index].z, earth_relative.z, 0.001, "Earth lane seam should end at the current Earth position")
	assert_almost_eq(moon_samples[0].x, moon_relative.x, 0.001, "Moon lane seam should start at the current Moon position relative to Earth")
	assert_almost_eq(moon_samples[0].y, moon_relative.y, 0.001, "Moon lane seam should start at the current Moon position relative to Earth")
	assert_almost_eq(moon_samples[0].z, moon_relative.z, 0.001, "Moon lane seam should start at the current Moon position relative to Earth")
	assert_almost_eq(moon_samples[moon_last_index].x, moon_relative.x, 0.001, "Moon lane seam should end at the current Moon position relative to Earth")
	assert_almost_eq(moon_samples[moon_last_index].y, moon_relative.y, 0.001, "Moon lane seam should end at the current Moon position relative to Earth")
	assert_almost_eq(moon_samples[moon_last_index].z, moon_relative.z, 0.001, "Moon lane seam should end at the current Moon position relative to Earth")

func test_large_orbit_lane_uses_high_resolution_sampling():
	var scene = _spawn_main_scene()
	await _wait_frames(2)

	var earth_lane = scene.get_orbit_lane_for_body_index(1)
	var moon_lane = scene.get_orbit_lane_for_body_index(2)

	assert_gt(earth_lane.sample_count, moon_lane.sample_count, "Larger orbits should use more samples than smaller ones")
	assert_gte(earth_lane.sample_count, 512, "Earth lane should use enough samples to avoid visible polygonal edges at large scale")

func test_moon_orbit_lane_follows_earth_position():
	var scene = _spawn_main_scene()
	await _wait_frames(2)

	var earth = scene.body_nodes[1]
	var moon_lane = scene.get_orbit_lane_for_body_index(2)
	var initial_center: Vector3 = moon_lane.position

	await _wait_frames(4)

	assert_eq(moon_lane.position, earth.position, "Moon orbit lane should stay centered on the moving Earth")
	assert_ne(moon_lane.position, initial_center, "Moon orbit lane center should update as Earth moves")
