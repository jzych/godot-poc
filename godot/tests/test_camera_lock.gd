extends GutTest

const CAMERA_RIG_SCENE := preload("res://scenes/cosmos_camera_rig.tscn")
const MAIN_SCENE := preload("res://scenes/main.tscn")

func _spawn_camera_rig() -> CosmosCameraRig:
	var rig: CosmosCameraRig = CAMERA_RIG_SCENE.instantiate()
	add_child(rig)
	autofree(rig)
	return rig

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

func _mouse_motion_event(position: Vector2, relative: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	event.relative = relative
	return event

func _dispatch_input_event(event: InputEvent, frames: int = 1):
	Input.parse_input_event(event)
	await _wait_frames(frames)

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

func test_start_focus_lock_sets_radius_based_distance_without_changing_angles():
	var rig: CosmosCameraRig = _spawn_camera_rig()
	await _wait_frames(1)

	rig.configure_from_offset(Vector3(10.0, 5.0, 10.0), Vector3(0.0, 2.0, 4.0))
	var initial_yaw: float = rig.yaw_degrees_value
	var initial_pitch: float = rig.pitch_degrees_value

	rig.start_focus_lock(Vector3(20.0, 5.0, 20.0), 2.0)
	var expected_distance: float = rig.get_focus_lock_distance_for_radius(2.0)

	assert_true(rig.is_focus_lock_active(), "Starting a focus lock should enable lock mode")
	assert_almost_eq(
		rig.target_distance,
		expected_distance,
		0.000001,
		"Lock distance should frame the body from its radius and fixed FOV"
	)
	assert_eq(rig.yaw_degrees_value, initial_yaw, "Focus lock should preserve yaw")
	assert_eq(rig.pitch_degrees_value, initial_pitch, "Focus lock should preserve pitch")

func test_focus_lock_smoothly_moves_focus_toward_target():
	var rig: CosmosCameraRig = _spawn_camera_rig()
	await _wait_frames(1)

	rig.configure_from_offset(Vector3(10.0, 5.0, 10.0), Vector3(0.0, 2.0, 4.0))
	rig.focus_lock_smoothing_speed = 4.0
	var starting_focus: Vector3 = rig.focus_position
	var target_focus := Vector3(40.0, 5.0, 10.0)

	rig.start_focus_lock(target_focus, 1.0)
	rig._process(0.05)

	assert_gt(rig.focus_position.x, starting_focus.x, "Focus lock should move toward the target body")
	assert_lt(rig.focus_position.x, target_focus.x, "Focus lock movement should remain smooth")
	assert_eq(rig.focus_position.y, target_focus.y, "Focus lock should keep the locked target height")

func test_focus_lock_transition_snaps_to_exact_locked_center_when_close():
	var rig: CosmosCameraRig = _spawn_camera_rig()
	await _wait_frames(1)

	var target_focus := Vector3(40.0, 5.0, 10.0)
	rig.configure_from_offset(Vector3(10.0, 5.0, 10.0), Vector3(0.0, 2.0, 4.0))
	rig.focus_lock_smoothing_speed = 8.0
	rig.zoom_smoothing_speed = 8.0
	rig.focus_lock_snap_distance = 0.5
	rig.distance_snap_threshold = 0.5
	rig.start_focus_lock(target_focus, 1.0)

	for _i in range(10):
		rig._process(0.05)

	assert_eq(rig.focus_position, target_focus, "Lock transition should settle on the exact locked center")
	assert_eq(rig.current_distance, rig.target_distance, "Lock transition should settle on the exact locked distance")
	assert_false(rig._focus_lock_transition_active, "Lock transition should end once it reaches the snap threshold")

func test_moving_focus_lock_transition_finishes_without_first_rotate_snap():
	var rig: CosmosCameraRig = _spawn_camera_rig()
	await _wait_frames(1)

	var live_target := Vector3(20.0, 5.0, 20.0)
	rig.configure_from_offset(Vector3(10.0, 5.0, 10.0), Vector3(0.0, 2.0, 4.0))
	rig.focus_lock_smoothing_speed = 20.0
	rig.zoom_smoothing_speed = 20.0
	rig.focus_lock_snap_distance = 0.05
	rig.distance_snap_threshold = 0.05
	rig.start_focus_lock(live_target, 0.05)

	for _i in range(12):
		live_target += Vector3(0.2, 0.0, 0.1)
		rig.update_focus_lock_target(live_target)
		rig._process(0.1)

	assert_false(rig._focus_lock_transition_active, "Moving-target lock transition should complete cleanly")
	assert_eq(rig.focus_position, live_target, "Completed lock transition should end at the live target center")
	assert_eq(rig.current_distance, rig.target_distance, "Completed lock transition should end at the steady lock distance")

	var camera_before: Vector3 = rig.get_camera_node().global_position
	var pitch_input: float = 0.0001 / rig.rotation_sensitivity
	rig.apply_rotate_motion(Vector2(0.0, pitch_input))
	var camera_after: Vector3 = rig.get_camera_node().global_position

	assert_eq(rig.focus_position, live_target, "First locked rotate should not snap the orbit center")
	assert_lt(
		camera_before.distance_to(camera_after),
		0.001,
		"First tiny locked rotate should only produce a tiny orbit movement"
	)

func test_pan_inputs_cancel_focus_lock():
	var rig: CosmosCameraRig = _spawn_camera_rig()
	await _wait_frames(1)

	rig.configure_from_offset(Vector3(10.0, 5.0, 10.0), Vector3(0.0, 2.0, 4.0))
	rig.start_focus_lock(Vector3(20.0, 5.0, 20.0), 1.0)
	rig.apply_keyboard_pan(Vector2(1.0, 0.0), 0.5)

	assert_false(rig.is_focus_lock_active(), "Keyboard pan should cancel focus lock")

	rig.start_focus_lock(Vector3(20.0, 5.0, 20.0), 1.0)
	rig._unhandled_input(_mouse_button_event(MOUSE_BUTTON_LEFT, true, Vector2(20.0, 20.0)))

	assert_true(rig.is_focus_lock_active(), "LMB press alone should not cancel focus lock")
	rig._unhandled_input(_mouse_motion_event(Vector2(30.0, 20.0), Vector2(10.0, 0.0)))

	assert_false(rig.is_focus_lock_active(), "LMB drag pan should cancel focus lock")

func test_mouse_jitter_below_pan_threshold_does_not_cancel_focus_lock():
	var rig: CosmosCameraRig = _spawn_camera_rig()
	await _wait_frames(1)

	rig.configure_from_offset(Vector3(10.0, 5.0, 10.0), Vector3(0.0, 2.0, 4.0))
	rig.start_focus_lock(Vector3(20.0, 5.0, 20.0), 1.0)
	rig._unhandled_input(_mouse_button_event(MOUSE_BUTTON_LEFT, true, Vector2(20.0, 20.0)))
	rig._unhandled_input(_mouse_motion_event(Vector2(23.0, 20.0), Vector2(3.0, 0.0)))
	rig._unhandled_input(_mouse_motion_event(Vector2(20.0, 20.0), Vector2(-3.0, 0.0)))

	assert_true(rig.is_focus_lock_active(), "Back-and-forth jitter below the displacement threshold should not cancel focus lock")
	assert_false(rig._pan_active, "Back-and-forth jitter below the displacement threshold should not start pan mode")

func test_rotation_and_zoom_preserve_focus_lock_target():
	var rig: CosmosCameraRig = _spawn_camera_rig()
	await _wait_frames(1)

	var target_focus := Vector3(20.0, 5.0, 20.0)
	rig.configure_from_offset(Vector3(10.0, 5.0, 10.0), Vector3(0.0, 2.0, 4.0))
	rig.start_focus_lock(target_focus, 1.0)
	var initial_target_distance: float = rig.target_distance

	rig.apply_rotate_motion(Vector2(25.0, -10.0))
	rig.apply_zoom_step(1.0)

	assert_true(rig.is_focus_lock_active(), "Rotation and zoom should not cancel focus lock")
	assert_eq(rig.focus_lock_target_position, target_focus, "Rotation and zoom should not change the locked focus target")
	assert_gt(rig.target_distance, initial_target_distance, "Zoom should still update the lock distance")

func test_locked_rotation_orbits_around_current_locked_body_position():
	var rig: CosmosCameraRig = _spawn_camera_rig()
	await _wait_frames(1)

	var initial_target := Vector3(20.0, 5.0, 20.0)
	var updated_target := Vector3(28.0, 5.0, 18.0)
	rig.configure_from_offset(Vector3(10.0, 5.0, 10.0), Vector3(0.0, 2.0, 4.0))
	rig.start_focus_lock(initial_target, 1.0)
	rig._process(1.0)
	rig.update_focus_lock_target(updated_target)
	rig.apply_rotate_motion(Vector2(25.0, -10.0))

	assert_eq(rig.focus_position, updated_target, "Locked rotation should orbit around the current locked body position")
	assert_eq(rig.current_distance, rig.target_distance, "Locked rotation should use the settled lock distance")
	assert_eq(rig.pan_plane_height, updated_target.y, "Locked rotation should keep the pan plane aligned to the locked body")

func test_double_click_starts_focus_lock_on_selected_body():
	var scene = _spawn_main_scene()
	await _wait_frames(2)

	var earth = scene.body_nodes[1]
	var focus_target = _find_distinct_hover_target(scene, earth)
	var camera: Camera3D = scene.camera_rig.get_camera_node()
	var click_position: Vector2 = camera.unproject_position(focus_target.global_position)

	assert_not_null(focus_target, "Test setup should find a body that can be double-clicked")
	await _dispatch_input_event(
		_mouse_button_event(
			MOUSE_BUTTON_LEFT,
			true,
			click_position,
			true
		)
	)

	assert_eq(scene.selected_body_view, focus_target, "Double-click should select the clicked body")
	assert_eq(scene.locked_body_view, focus_target, "Double-click should lock onto the clicked body")
	assert_true(scene.camera_rig.is_focus_lock_active(), "Double-click should start focus lock mode")
	assert_eq(scene.camera_rig.current_focus_id, focus_target.focus_id, "Double-click should switch the camera focus id")
	assert_eq(scene.camera_rig.current_focus_type, focus_target.focus_type, "Double-click should switch the camera focus type")
	assert_gte(scene.camera_rig.target_distance, focus_target.preferred_min_distance_units, "Double-click should respect the target min zoom bound")
	assert_lte(scene.camera_rig.target_distance, focus_target.preferred_max_distance_units, "Double-click should respect the target max zoom bound")
	assert_false(scene.camera_rig._pan_active, "Double-click should not start pan-hold in the camera rig")

func test_main_scene_pan_cancels_focus_lock():
	var scene = _spawn_main_scene()
	await _wait_frames(2)

	var earth = scene.body_nodes[1]
	var focus_target = _find_distinct_hover_target(scene, earth)
	var camera: Camera3D = scene.camera_rig.get_camera_node()

	assert_not_null(focus_target, "Test setup should find a body that can be locked")
	scene._input(
		_mouse_button_event(
			MOUSE_BUTTON_LEFT,
			true,
			camera.unproject_position(focus_target.global_position),
			true
		)
	)
	scene.camera_rig.apply_keyboard_pan(Vector2(1.0, 0.0), 0.5)
	scene._sync_focus_lock_target()

	assert_false(scene.camera_rig.is_focus_lock_active(), "Pan should cancel focus lock in the main scene")
	assert_null(scene.locked_body_view, "Main scene should clear the locked body after pan cancels focus lock")

func test_main_scene_updates_focus_lock_target_from_locked_body_motion():
	var scene = _spawn_main_scene()
	await _wait_frames(2)

	var earth = scene.body_nodes[1]
	var focus_target = _find_distinct_hover_target(scene, earth)
	var camera: Camera3D = scene.camera_rig.get_camera_node()

	assert_not_null(focus_target, "Test setup should find a body that can be locked")
	scene._input(
		_mouse_button_event(
			MOUSE_BUTTON_LEFT,
			true,
			camera.unproject_position(focus_target.global_position),
			true
		)
	)

	var updated_position: Vector3 = focus_target.global_position + Vector3(5.0, 0.0, 0.0)
	focus_target.global_position = updated_position
	scene._sync_focus_lock_target()

	assert_eq(
		scene.camera_rig.focus_lock_target_position,
		updated_position,
		"Main scene should keep updating the lock target from the locked body's live position"
	)

func test_single_click_selection_does_not_cancel_existing_focus_lock():
	var scene = _spawn_main_scene()
	await _wait_frames(2)

	var earth = scene.body_nodes[1]
	var locked_target = _find_distinct_hover_target(scene, earth)
	var selected_target = _find_distinct_hover_target(scene, locked_target)
	var camera: Camera3D = scene.camera_rig.get_camera_node()

	assert_not_null(locked_target, "Test setup should find a body that can be locked")
	assert_not_null(selected_target, "Test setup should find a second body that can be selected")
	await _dispatch_input_event(
		_mouse_button_event(
			MOUSE_BUTTON_LEFT,
			true,
			camera.unproject_position(locked_target.global_position),
			true
		)
	)
	scene._set_selected_body(selected_target)

	assert_eq(scene.selected_body_view, selected_target, "Single click should still update selection")
	assert_eq(scene.locked_body_view, locked_target, "Single click should not replace the existing lock target")
	assert_true(scene.camera_rig.is_focus_lock_active(), "Single click selection should not cancel focus lock")
