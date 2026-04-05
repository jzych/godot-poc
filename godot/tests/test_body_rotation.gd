extends GutTest

const MAIN_SCENE := preload("res://scenes/main.tscn")

func _spawn_main_scene() -> Node3D:
	var scene: Node3D = MAIN_SCENE.instantiate()
	add_child(scene)
	autofree(scene)
	return scene

func _wait_frames(count: int):
	for _i in range(count):
		await get_tree().process_frame

func test_rotating_body_visual_basis_changes_over_time():
	var scene = _spawn_main_scene()
	await _wait_frames(2)

	var earth = scene.body_nodes[1]
	var initial_basis: Basis = earth.get_visual_basis()

	await _wait_frames(4)

	assert_ne(
		earth.get_visual_basis(),
		initial_basis,
		"Earth visual basis should change over time as the body rotates"
	)

func test_axial_tilt_is_applied_relative_to_orbit_plane():
	var scene = _spawn_main_scene()
	await _wait_frames(2)

	var earth = scene.body_nodes[1]
	var orbit_normal: Vector3 = earth.get_orbit_normal().normalized()
	var rotation_axis: Vector3 = earth.get_rotation_axis().normalized()
	var expected_tilt: float = float(earth.rotation_state.get("axial_tilt_to_orbit_rad", 0.0))
	var actual_tilt: float = acos(clamp(orbit_normal.dot(rotation_axis), -1.0, 1.0))

	assert_almost_eq(
		actual_tilt,
		expected_tilt,
		0.0001,
		"Body rotation axis should be tilted away from the orbit normal by the configured axial tilt"
	)

func test_prime_meridian_visual_is_configured_and_rotates_with_body():
	var scene = _spawn_main_scene()
	await _wait_frames(2)

	var moon = scene.body_nodes[2]
	var base_color: Color = moon.get_base_color()
	var meridian_color: Color = moon.get_prime_meridian_color()
	var initial_direction: Vector3 = moon.get_prime_meridian_world_direction()

	await _wait_frames(4)

	assert_true(moon.has_prime_meridian_visual(), "Orbiting bodies should use the surface shader with a prime meridian line")
	assert_lt(meridian_color.get_luminance(), base_color.get_luminance(), "Prime meridian color should be darker than the base body color")
	assert_ne(
		moon.get_prime_meridian_world_direction(),
		initial_direction,
		"Prime meridian direction should rotate with the body over time"
	)
