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

func _mouse_button_event(button_index: int, pressed: bool, position: Vector2, double_click: bool = false) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button_index
	event.pressed = pressed
	event.position = position
	event.global_position = position
	event.double_click = double_click
	return event

func _click_at(scene, position: Vector2):
	scene._input(_mouse_button_event(MOUSE_BUTTON_LEFT, true, position))
	scene._input(_mouse_button_event(MOUSE_BUTTON_LEFT, false, position))

func _double_click_at(scene, position: Vector2):
	scene._input(_mouse_button_event(MOUSE_BUTTON_LEFT, true, position, true))

func _click_marker(scene, marker):
	_click_at(scene, marker.position + (marker.size * 0.5))

func _click_marker_label(scene, marker_label):
	_click_at(scene, marker_label.position + (marker_label.get_label_size() * 0.5))

func _find_background_position(scene) -> Vector2:
	var viewport_size: Vector2 = scene.get_viewport().get_visible_rect().size
	var candidates := [
		Vector2(10.0, 10.0),
		Vector2(viewport_size.x - 10.0, 10.0),
		Vector2(10.0, viewport_size.y - 10.0),
		Vector2(viewport_size.x - 10.0, viewport_size.y - 10.0),
	]

	for candidate in candidates:
		scene.update_hover_from_screen_position(candidate)
		if scene.hovered_body_view == null:
			return candidate

	return Vector2(-10.0, -10.0)

func _select_body(scene, body_view):
	var camera: Camera3D = scene.camera_rig.get_camera_node()
	_click_at(scene, camera.unproject_position(body_view.global_position))

func _frame_selected_orbit(scene, _view_size: float, orbit_distance: float = 120.0):
	if scene.selected_body_view != null:
		var central_body_index := int(scene.selected_body_view.orbit_state.get("central_body_index", -1))
		if central_body_index >= 0:
			scene.camera_rig.focus_position = scene._get_orbit_center_position(central_body_index)
	scene.camera_rig.current_distance = orbit_distance
	scene.camera_rig.target_distance = orbit_distance
	scene.camera_rig._apply_state()
	scene._sync_interaction_from_camera()

func test_selected_orbit_shows_periapsis_and_apoapsis_markers():
	var scene = _spawn_main_scene()
	await _wait_frames(2)

	_frame_selected_orbit(scene, 80.0)
	var moon = scene.body_nodes[2]
	_select_body(scene, moon)
	_frame_selected_orbit(scene, 80.0)
	await _wait_frames(1)

	assert_eq(scene.orbit_marker_overlay.get_visible_marker_count(), 2, "Selected orbiting body should show two orbit markers")

	var periapsis_marker = scene.orbit_marker_overlay.get_marker_for_kind("periapsis")
	var apoapsis_marker = scene.orbit_marker_overlay.get_marker_for_kind("apoapsis")
	assert_true(periapsis_marker.visible, "Periapsis marker should be visible for the selected orbit")
	assert_true(apoapsis_marker.visible, "Apoapsis marker should be visible for the selected orbit")

	var camera: Camera3D = scene.camera_rig.get_camera_node()
	var center_position: Vector3 = scene._get_orbit_center_position(int(moon.orbit_state.get("central_body_index", -1)))
	var expected_periapsis_tip: Vector2 = camera.unproject_position(
		center_position + OrbitMathScript.periapsis_relative_position_units(moon.orbit_state)
	)
	var expected_apoapsis_tip: Vector2 = camera.unproject_position(
		center_position + OrbitMathScript.apoapsis_relative_position_units(moon.orbit_state)
	)

	assert_almost_eq(periapsis_marker.get_tip_position().x, expected_periapsis_tip.x, 0.75, "Periapsis marker should point at periapsis")
	assert_almost_eq(periapsis_marker.get_tip_position().y, expected_periapsis_tip.y, 0.75, "Periapsis marker should point at periapsis")
	assert_almost_eq(apoapsis_marker.get_tip_position().x, expected_apoapsis_tip.x, 0.75, "Apoapsis marker should point at apoapsis")
	assert_almost_eq(apoapsis_marker.get_tip_position().y, expected_apoapsis_tip.y, 0.75, "Apoapsis marker should point at apoapsis")

func test_clicking_marker_shows_distance_and_eta_label():
	var scene = _spawn_main_scene()
	await _wait_frames(2)

	_frame_selected_orbit(scene, 80.0)
	var moon = scene.body_nodes[2]
	_select_body(scene, moon)
	_frame_selected_orbit(scene, 80.0)
	await _wait_frames(1)

	var periapsis_marker = scene.orbit_marker_overlay.get_marker_for_kind("periapsis")
	_click_marker(scene, periapsis_marker)

	var marker_label = scene.orbit_marker_overlay.get_marker_label()
	assert_not_null(marker_label, "Clicking a marker should create a marker label")
	assert_true(marker_label.visible, "Clicking a marker should show its label")
	assert_eq(marker_label.get_label_text(), "Periapsis", "Marker label should identify the clicked marker")
	assert_true(marker_label.get_secondary_text().contains("Distance:"), "Marker label should show the event distance")
	assert_true(marker_label.get_secondary_text().contains("T-"), "Marker label should show time-to-arrival in T-minus format")

func test_marker_visibility_and_label_follow_selection_state():
	var scene = _spawn_main_scene()
	await _wait_frames(2)

	_frame_selected_orbit(scene, 80.0)
	var moon = scene.body_nodes[2]
	var sun = scene.body_nodes[0]
	_select_body(scene, moon)
	_frame_selected_orbit(scene, 80.0)
	await _wait_frames(1)

	var periapsis_marker = scene.orbit_marker_overlay.get_marker_for_kind("periapsis")
	_click_marker(scene, periapsis_marker)
	assert_true(scene.orbit_marker_overlay.get_marker_label().visible, "Marker label should be visible after clicking a marker")

	_select_body(scene, sun)
	await _wait_frames(1)
	assert_eq(scene.orbit_marker_overlay.get_visible_marker_count(), 0, "Selecting a body without an orbit lane should hide orbit markers")
	assert_false(scene.orbit_marker_overlay.get_marker_label().visible, "Changing selection should hide the previous marker label")

	var background_position: Vector2 = _find_background_position(scene)
	_click_at(scene, background_position)
	await _wait_frames(1)
	assert_eq(scene.orbit_marker_overlay.get_visible_marker_count(), 0, "Clearing selection should hide all orbit markers")
	assert_false(scene.orbit_marker_overlay.get_marker_label().visible, "Clearing selection should hide marker labels")

func test_clicking_marker_does_not_break_selection_or_focus_lock():
	var scene = _spawn_main_scene()
	await _wait_frames(2)

	_frame_selected_orbit(scene, 80.0)
	var moon = scene.body_nodes[2]
	var camera: Camera3D = scene.camera_rig.get_camera_node()
	_double_click_at(scene, camera.unproject_position(moon.global_position))
	_frame_selected_orbit(scene, 80.0)
	await _wait_frames(1)

	var apoapsis_marker = scene.orbit_marker_overlay.get_marker_for_kind("apoapsis")
	_click_marker(scene, apoapsis_marker)

	assert_eq(scene.selected_body_view, moon, "Clicking a marker should not change body selection")
	assert_eq(scene.locked_body_view, moon, "Clicking a marker should not change the locked body")
	assert_true(scene.camera_rig.is_focus_lock_active(), "Clicking a marker should not cancel focus lock")

func test_clicking_marker_label_does_not_fall_through_to_scene_selection():
	var scene = _spawn_main_scene()
	await _wait_frames(2)

	_frame_selected_orbit(scene, 80.0)
	var moon = scene.body_nodes[2]
	_select_body(scene, moon)
	_frame_selected_orbit(scene, 80.0)
	await _wait_frames(1)

	var periapsis_marker = scene.orbit_marker_overlay.get_marker_for_kind("periapsis")
	_click_marker(scene, periapsis_marker)
	var marker_label = scene.orbit_marker_overlay.get_marker_label()

	assert_true(marker_label.visible, "Test setup should show the marker label before clicking it")
	_click_marker_label(scene, marker_label)

	assert_eq(scene.selected_body_view, moon, "Clicking the marker label should not clear or change body selection")
	assert_true(marker_label.visible, "Clicking the marker label should not hide the label")
	assert_eq(scene.orbit_marker_overlay.get_active_marker_kind(), "periapsis", "Clicking the marker label should keep the active marker")
