extends GutTest

const MAIN_SCENE := preload("res://scenes/main.tscn")
const HOVER_HIGHLIGHT_COLOR := Color.WHITE
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

func _mouse_motion_event(position: Vector2, relative: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	event.relative = relative
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

func test_hover_highlights_body_under_cursor():
	var scene = _spawn_main_scene()
	await _wait_frames(2)

	var earth = scene.body_nodes[1]
	var camera: Camera3D = scene.camera_rig.get_camera_node()
	var hover_position: Vector2 = camera.unproject_position(earth.global_position)

	scene.update_hover_from_screen_position(hover_position)

	assert_eq(scene.hovered_body_view, earth, "Hovering Earth should resolve the Earth body view")
	assert_true(earth.is_highlight_visible(), "Hovered body should display the outline highlight")
	assert_false(scene.body_nodes[0].is_highlight_visible(), "Other bodies should remain unhighlighted")

func test_hover_clears_when_cursor_is_off_body():
	var scene = _spawn_main_scene()
	await _wait_frames(2)

	var earth = scene.body_nodes[1]
	var camera: Camera3D = scene.camera_rig.get_camera_node()
	scene.update_hover_from_screen_position(camera.unproject_position(earth.global_position))

	scene.update_hover_from_screen_position(Vector2(-10.0, -10.0))

	assert_null(scene.hovered_body_view, "Moving the cursor off bodies should clear hover state")
	assert_false(earth.is_highlight_visible(), "Hover outline should clear when no body is under the cursor")

func test_click_selects_hovered_body_and_selection_persists_after_hover_exit():
	var scene = _spawn_main_scene()
	await _wait_frames(2)

	var earth = scene.body_nodes[1]
	var camera: Camera3D = scene.camera_rig.get_camera_node()
	var earth_screen_position: Vector2 = camera.unproject_position(earth.global_position)
	var background_position: Vector2 = _find_background_position(scene)

	_click_at(scene, earth_screen_position)
	scene.update_hover_from_screen_position(background_position)

	assert_eq(scene.selected_body_view, earth, "Clicking a hovered body should select it")
	assert_null(scene.hovered_body_view, "Moving away after selection should clear the hover target")
	assert_true(earth.is_highlight_visible(), "Selected body should remain highlighted when hover exits")
	assert_eq(
		earth.get_highlight_color(),
		SELECTED_HIGHLIGHT_COLOR,
		"Selected-only highlight should switch to light gray"
	)

func test_hovering_another_body_keeps_selected_body_highlighted():
	var scene = _spawn_main_scene()
	await _wait_frames(2)

	var earth = scene.body_nodes[1]
	var camera: Camera3D = scene.camera_rig.get_camera_node()
	var hovered_target = _find_distinct_hover_target(scene, earth)

	_click_at(scene, camera.unproject_position(earth.global_position))

	assert_not_null(hovered_target, "Test setup should find a second body that resolves under the cursor")
	scene.update_hover_from_screen_position(camera.unproject_position(hovered_target.global_position))

	assert_eq(scene.selected_body_view, earth, "Selection should stay on the clicked body")
	assert_eq(scene.hovered_body_view, hovered_target, "Hover should move independently to another body")
	assert_true(earth.is_highlight_visible(), "Selected body should stay highlighted while another body is hovered")
	assert_true(hovered_target.is_highlight_visible(), "Hovered body should be highlighted")
	assert_eq(
		earth.get_highlight_color(),
		SELECTED_HIGHLIGHT_COLOR,
		"Selected body should use the light gray outline when not hovered"
	)
	assert_eq(
		hovered_target.get_highlight_color(),
		HOVER_HIGHLIGHT_COLOR,
		"Hovered body should keep the white outline"
	)

func test_clicking_background_clears_selection():
	var scene = _spawn_main_scene()
	await _wait_frames(2)

	var earth = scene.body_nodes[1]
	var camera: Camera3D = scene.camera_rig.get_camera_node()
	var background_position: Vector2 = _find_background_position(scene)

	_click_at(scene, camera.unproject_position(earth.global_position))
	_click_at(scene, background_position)

	assert_null(scene.selected_body_view, "Clicking empty background should clear the current selection")
	assert_null(scene.hovered_body_view, "Background click should leave no hovered body")
	assert_false(earth.is_highlight_visible(), "Clearing selection should remove the outline from the previously selected body")

func test_drag_pan_gesture_does_not_clear_selection():
	var scene = _spawn_main_scene()
	await _wait_frames(2)

	var earth = scene.body_nodes[1]
	var camera: Camera3D = scene.camera_rig.get_camera_node()
	var earth_screen_position: Vector2 = camera.unproject_position(earth.global_position)
	var background_position: Vector2 = _find_background_position(scene)
	var drag_position := background_position + Vector2(20.0, 0.0)

	_click_at(scene, earth_screen_position)
	scene._input(_mouse_button_event(MOUSE_BUTTON_LEFT, true, background_position))
	scene._input(_mouse_motion_event(drag_position, drag_position - background_position))
	scene._input(_mouse_button_event(MOUSE_BUTTON_LEFT, false, drag_position))
	scene.update_hover_from_screen_position(drag_position)

	assert_eq(scene.selected_body_view, earth, "LMB drag pan should not clear the existing selection")
	assert_true(earth.is_highlight_visible(), "Selected body should remain highlighted after an LMB drag pan")
	assert_eq(
		earth.get_highlight_color(),
		SELECTED_HIGHLIGHT_COLOR,
		"Selection highlight should remain in the selected-only state after an LMB drag pan"
	)
