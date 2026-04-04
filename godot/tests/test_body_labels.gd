extends GutTest

const MAIN_SCENE := preload("res://scenes/main.tscn")
const SELECTED_HIGHLIGHT_COLOR := Color(0.8, 0.8, 0.8, 1.0)

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

func _find_distinct_hover_target(scene, excluded_body):
	var camera: Camera3D = scene.camera_rig.get_camera_node()

	for candidate in scene.body_nodes:
		if candidate == excluded_body:
			continue

		var screen_position: Vector2 = camera.unproject_position(candidate.global_position)
		scene.update_hover_from_screen_position(screen_position)
		if scene.hovered_body_view == candidate:
			return candidate

	return null

func test_hovered_body_shows_label_with_body_name():
	var scene = _spawn_main_scene()
	await _wait_frames(2)

	var earth = scene.body_nodes[1]
	var camera: Camera3D = scene.camera_rig.get_camera_node()
	scene.update_hover_from_screen_position(camera.unproject_position(earth.global_position))

	var label = scene.body_label_overlay.get_label_for_body_index(earth.body_index)

	assert_not_null(label, "Hovering a body should create a label entry for it")
	assert_true(label.visible, "Hovered body label should be visible")
	assert_eq(label.get_label_text(), earth.body_label, "Hovered label should display the body name")
	assert_eq(scene.body_label_overlay.label_appearance.font_size, 18, "Default label font size should match the requested style")

func test_selected_body_label_persists_after_hover_exit():
	var scene = _spawn_main_scene()
	await _wait_frames(2)

	var earth = scene.body_nodes[1]
	var camera: Camera3D = scene.camera_rig.get_camera_node()
	var earth_screen_position: Vector2 = camera.unproject_position(earth.global_position)
	var background_position: Vector2 = _find_background_position(scene)

	_click_at(scene, earth_screen_position)
	scene.update_hover_from_screen_position(background_position)

	var label = scene.body_label_overlay.get_label_for_body_index(earth.body_index)

	assert_not_null(label, "Selecting a body should keep its label entry")
	assert_true(label.visible, "Selected body label should remain visible after hover exits")
	assert_eq(earth.get_highlight_color(), SELECTED_HIGHLIGHT_COLOR, "Selected body should still be in the selected-only visual state")

func test_hovered_and_selected_bodies_show_two_labels():
	var scene = _spawn_main_scene()
	await _wait_frames(2)

	var earth = scene.body_nodes[1]
	var camera: Camera3D = scene.camera_rig.get_camera_node()
	var hovered_target = _find_distinct_hover_target(scene, earth)

	_click_at(scene, camera.unproject_position(earth.global_position))
	assert_not_null(hovered_target, "Test setup should find a second hover target")
	scene.update_hover_from_screen_position(camera.unproject_position(hovered_target.global_position))

	assert_eq(scene.body_label_overlay.get_visible_label_count(), 2, "Selected and hovered bodies should each show a label")

func test_label_size_stays_constant_across_zoom():
	var scene = _spawn_main_scene()
	await _wait_frames(2)

	var earth = scene.body_nodes[1]
	var camera: Camera3D = scene.camera_rig.get_camera_node()
	scene.update_hover_from_screen_position(camera.unproject_position(earth.global_position))

	var label = scene.body_label_overlay.get_label_for_body_index(earth.body_index)
	var initial_size: Vector2 = label.get_label_size()

	scene.camera_rig.current_distance = 20.0
	scene.camera_rig.target_distance = 20.0
	scene.camera_rig._apply_state()
	scene._sync_body_labels()

	assert_eq(label.get_label_size(), initial_size, "Zoom level should not change label pixel size")

func test_label_position_refreshes_when_camera_moves_without_hover_change():
	var scene = _spawn_main_scene()
	await _wait_frames(2)

	var earth = scene.body_nodes[1]
	var moving_target = _find_distinct_hover_target(scene, earth)
	var camera: Camera3D = scene.camera_rig.get_camera_node()
	assert_not_null(moving_target, "Test setup should find a visible body away from the camera focus")
	_click_at(scene, camera.unproject_position(moving_target.global_position))

	var label = scene.body_label_overlay.get_label_for_body_index(moving_target.body_index)
	var initial_position: Vector2 = label.position

	scene.camera_rig.apply_rotate_motion(Vector2(40.0, 0.0))
	scene._sync_interaction_from_camera()

	assert_ne(
		label.position,
		initial_position,
		"Label projection should refresh after camera movement even when the hovered body stays the same"
	)

func test_label_offset_tracks_projected_radius():
	var scene = _spawn_main_scene()
	await _wait_frames(2)

	var earth = scene.body_nodes[1]
	var camera: Camera3D = scene.camera_rig.get_camera_node()
	scene.update_hover_from_screen_position(camera.unproject_position(earth.global_position))

	var label = scene.body_label_overlay.get_label_for_body_index(earth.body_index)
	var projected_center: Vector2 = camera.unproject_position(earth.global_position)
	var projected_radius: float = scene.body_label_overlay.get_projected_radius_for_body(camera, earth)
	var expected_distance: float = projected_radius * 1.2
	var actual_distance: float = label.position.distance_to(projected_center)

	assert_almost_eq(
		actual_distance,
		expected_distance,
		0.75,
		"Label top-left corner should sit at 120% of the projected body radius"
	)
