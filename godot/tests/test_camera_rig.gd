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

func _mouse_button_event(button_index: int, pressed: bool, position: Vector2 = Vector2.ZERO) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button_index
	event.pressed = pressed
	event.position = position
	event.global_position = position
	return event

func _mouse_motion_event(relative: Vector2, position: Vector2 = Vector2.ZERO) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.relative = relative
	event.position = position
	event.global_position = position
	return event

func _wait_frames(count: int):
	for _i in range(count):
		await get_tree().process_frame

func test_rotation_requires_rotate_hold():
	var rig: CosmosCameraRig = _spawn_camera_rig()
	await _wait_frames(1)

	var initial_yaw: float = rig.yaw_degrees_value
	rig._unhandled_input(_mouse_motion_event(Vector2(40.0, 0.0)))

	assert_eq(rig.yaw_degrees_value, initial_yaw, "Mouse motion should not rotate without RMB held")

func test_rotation_changes_yaw_and_clamps_pitch():
	var rig: CosmosCameraRig = _spawn_camera_rig()
	await _wait_frames(1)

	rig._unhandled_input(_mouse_button_event(2, true))
	rig._unhandled_input(_mouse_motion_event(Vector2(50.0, 1000.0)))
	rig._unhandled_input(_mouse_button_event(2, false))

	assert_gt(rig.yaw_degrees_value, 0.0, "RMB drag should update yaw")
	assert_true(
		is_equal_approx(rig.pitch_degrees_value, rig.pitch_max_deg),
		"Pitch should clamp at the configured maximum"
	)

func test_configure_from_offset_sets_focus_height_and_distance():
	var rig: CosmosCameraRig = _spawn_camera_rig()
	await _wait_frames(1)

	rig.configure_from_offset(Vector3(10.0, 5.0, 10.0), Vector3(0.0, 2.0, 4.0))

	assert_true(
		is_equal_approx(rig.focus_position.y, rig.pan_plane_height),
		"Configured focus height should set the fixed pan-plane height for later phases"
	)
	assert_true(
		is_equal_approx(rig.current_distance, Vector3(0.0, 2.0, 4.0).length()),
		"Initial camera distance should come from the configured offset"
	)

func test_camera_scene_exposes_active_camera():
	var rig: CosmosCameraRig = _spawn_camera_rig()
	await _wait_frames(1)

	var camera: Camera3D = rig.get_camera_node()

	assert_true(camera.current, "Camera rig should expose the active camera")
	assert_eq(camera.projection, Camera3D.PROJECTION_ORTHOGONAL, "Camera rig should use orthographic projection")

func test_zoom_input_changes_target_size_without_moving_focus():
	var rig: CosmosCameraRig = _spawn_camera_rig()
	await _wait_frames(1)

	rig.configure_from_offset(Vector3(10.0, 5.0, 10.0), Vector3(0.0, 2.0, 4.0))
	var initial_target_size: float = rig.target_orthographic_size
	var initial_focus: Vector3 = rig.focus_position
	var initial_yaw: float = rig.yaw_degrees_value
	var initial_pitch: float = rig.pitch_degrees_value

	rig._unhandled_input(_mouse_button_event(4, true))

	assert_lt(rig.target_orthographic_size, initial_target_size, "Zoom in should reduce the orthographic size")
	assert_eq(rig.focus_position, initial_focus, "Zoom input should not move the focus point")
	assert_eq(rig.yaw_degrees_value, initial_yaw, "Zoom input should not change yaw")
	assert_eq(rig.pitch_degrees_value, initial_pitch, "Zoom input should not change pitch")
	assert_eq(rig.current_distance, Vector3(0.0, 2.0, 4.0).length(), "Zoom input should not change orbit distance")

func test_zoom_interpolates_toward_target_size():
	var rig: CosmosCameraRig = _spawn_camera_rig()
	await _wait_frames(1)

	rig.configure_from_offset(Vector3(10.0, 5.0, 10.0), Vector3(0.0, 2.0, 4.0))
	var starting_size: float = rig.current_orthographic_size

	rig._unhandled_input(_mouse_button_event(5, true))
	var zoom_target_size: float = rig.target_orthographic_size
	rig._process(0.1)

	assert_gt(rig.current_orthographic_size, starting_size, "Zoom out should increase the orthographic size")
	assert_lte(rig.current_orthographic_size, zoom_target_size, "Smoothing should move toward the target without overshooting")
	assert_almost_eq(rig.get_camera_node().size, rig.current_orthographic_size, 0.001, "Camera size should track the orthographic zoom state")

func test_changing_distance_does_not_change_orthographic_projection_scale():
	var rig: CosmosCameraRig = _spawn_camera_rig()
	await _wait_frames(1)

	rig.configure_from_offset(Vector3(0.0, 0.0, 0.0), Vector3(0.0, 2.0, 4.0))
	rig.current_orthographic_size = 8.0
	rig.target_orthographic_size = 8.0
	rig.current_distance = 4.0
	rig.target_distance = 4.0
	rig._apply_state()

	var camera: Camera3D = rig.get_camera_node()
	var near_center: Vector2 = camera.unproject_position(Vector3.ZERO)
	var near_edge: Vector2 = camera.unproject_position(Vector3.RIGHT)
	var near_radius: float = near_center.distance_to(near_edge)

	rig.current_distance = 40.0
	rig.target_distance = 40.0
	rig._apply_state()

	var far_center: Vector2 = camera.unproject_position(Vector3.ZERO)
	var far_edge: Vector2 = camera.unproject_position(Vector3.RIGHT)
	var far_radius: float = far_center.distance_to(far_edge)

	assert_almost_eq(far_radius, near_radius, 0.001, "Orthographic projection should keep the same projected size when only distance changes")

func test_minimum_safe_distance_snaps_camera_outward_without_overwriting_requested_distance():
	var rig: CosmosCameraRig = _spawn_camera_rig()
	await _wait_frames(1)

	rig.configure_from_offset(Vector3.ZERO, Vector3(0.0, 2.0, 4.0))
	rig.current_orthographic_size = 8.0
	rig.target_orthographic_size = 8.0
	rig.current_distance = 4.0
	rig.target_distance = 4.0
	rig._apply_state()

	var camera: Camera3D = rig.get_camera_node()
	var before_radius: float = camera.unproject_position(Vector3.ZERO).distance_to(
		camera.unproject_position(Vector3.RIGHT)
	)

	rig.set_minimum_safe_distance(12.0)

	var after_radius: float = camera.unproject_position(Vector3.ZERO).distance_to(
		camera.unproject_position(Vector3.RIGHT)
	)

	assert_eq(rig.current_distance, 12.0, "Safety floor should push the camera out immediately when the current orbit distance is unsafe")
	assert_eq(rig.target_distance, 4.0, "Safety floor should not overwrite the requested orbit distance")
	assert_almost_eq(after_radius, before_radius, 0.001, "Orthographic projection should keep the same projected size after a safety-distance snap")

func test_zoom_respects_orthographic_size_bounds():
	var rig: CosmosCameraRig = _spawn_camera_rig()
	await _wait_frames(1)

	rig.min_orthographic_size = 0.5
	rig.max_orthographic_size = 6.0
	rig.configure_from_offset(Vector3(10.0, 5.0, 10.0), Vector3(0.0, 2.0, 4.0))

	for _i in range(20):
		rig.apply_zoom_step(-1.0)
	assert_eq(rig.target_orthographic_size, rig.min_orthographic_size, "Zoom in should clamp to min orthographic size")

	for _j in range(30):
		rig.apply_zoom_step(1.0)
	assert_eq(rig.target_orthographic_size, rig.max_orthographic_size, "Zoom out should clamp to max orthographic size")

func test_keyboard_pan_moves_focus_on_fixed_plane():
	var rig: CosmosCameraRig = _spawn_camera_rig()
	await _wait_frames(1)

	rig.configure_from_offset(Vector3(10.0, 5.0, 10.0), Vector3(0.0, 2.0, 4.0))
	var start: Vector3 = rig.focus_position
	var initial_yaw: float = rig.yaw_degrees_value
	var initial_pitch: float = rig.pitch_degrees_value

	rig.apply_keyboard_pan(Vector2(0.0, 1.0), 1.0)

	assert_eq(rig.focus_position.y, start.y, "Keyboard pan should preserve height")
	assert_eq(rig.pan_plane_height, start.y, "Keyboard pan should keep the same plane height")
	assert_eq(rig.focus_position.x, start.x, "Forward pan at zero yaw should not change X")
	assert_lt(rig.focus_position.z, start.z, "Forward pan should move along the fixed XZ plane")
	assert_eq(rig.yaw_degrees_value, initial_yaw, "Keyboard pan should not change yaw")
	assert_eq(rig.pitch_degrees_value, initial_pitch, "Keyboard pan should not change pitch")

func test_drag_pan_requires_pan_hold_and_preserves_orientation():
	var rig: CosmosCameraRig = _spawn_camera_rig()
	await _wait_frames(1)

	rig.configure_from_offset(Vector3(10.0, 7.0, 10.0), Vector3(0.0, 2.0, 4.0))
	var start: Vector3 = rig.focus_position
	var initial_yaw: float = rig.yaw_degrees_value
	var initial_pitch: float = rig.pitch_degrees_value

	rig._unhandled_input(_mouse_motion_event(Vector2(120.0, -80.0)))
	assert_eq(rig.focus_position, start, "Mouse motion should not pan without LMB held")

	rig._unhandled_input(_mouse_button_event(1, true, Vector2(20.0, 20.0)))
	rig._unhandled_input(_mouse_motion_event(Vector2(120.0, -80.0), Vector2(140.0, -60.0)))
	rig._unhandled_input(_mouse_button_event(1, false, Vector2(140.0, -60.0)))

	assert_eq(rig.focus_position.y, start.y, "Drag pan should preserve height")
	assert_eq(rig.pan_plane_height, start.y, "Drag pan should keep the configured plane height")
	assert_lt(rig.focus_position.x, start.x, "Dragging right should move focus left for grab-style pan")
	assert_gt(rig.focus_position.z, start.z, "Dragging up should move focus backward on the fixed plane")
	assert_eq(rig.yaw_degrees_value, initial_yaw, "Drag pan should not change yaw")
	assert_eq(rig.pitch_degrees_value, initial_pitch, "Drag pan should not change pitch")

func test_drag_pan_does_not_interfere_with_rotation():
	var rig: CosmosCameraRig = _spawn_camera_rig()
	await _wait_frames(1)

	rig.configure_from_offset(Vector3(10.0, 7.0, 10.0), Vector3(0.0, 2.0, 4.0))
	var start_focus: Vector3 = rig.focus_position
	var start_yaw: float = rig.yaw_degrees_value
	var start_pitch: float = rig.pitch_degrees_value

	rig._unhandled_input(_mouse_button_event(1, true, Vector2(20.0, 20.0)))
	rig._unhandled_input(_mouse_button_event(2, true))
	rig._unhandled_input(_mouse_motion_event(Vector2(120.0, -80.0), Vector2(140.0, -60.0)))
	rig._unhandled_input(_mouse_button_event(2, false))
	rig._unhandled_input(_mouse_button_event(1, false, Vector2(140.0, -60.0)))

	assert_eq(rig.focus_position, start_focus, "Drag pan should not move focus while rotation is active")
	assert_gt(rig.yaw_degrees_value, start_yaw, "Rotation input should still update yaw")
	assert_lt(rig.pitch_degrees_value, start_pitch, "Rotation should still update pitch while pan is held")

func test_pan_speed_scales_with_zoom_size():
	var rig: CosmosCameraRig = _spawn_camera_rig()
	await _wait_frames(1)

	rig.configure_from_offset(Vector3(10.0, 5.0, 10.0), Vector3(0.0, 2.0, 4.0))
	var start: Vector3 = rig.focus_position

	rig.current_orthographic_size = 2.0
	rig.target_orthographic_size = 2.0
	rig.apply_keyboard_pan(Vector2(1.0, 0.0), 1.0)
	var near_distance_delta: float = rig.focus_position.distance_to(start)

	rig.focus_position = start
	rig.current_orthographic_size = 20.0
	rig.target_orthographic_size = 20.0
	rig.apply_keyboard_pan(Vector2(1.0, 0.0), 1.0)
	var far_distance_delta: float = rig.focus_position.distance_to(start)

	assert_gt(far_distance_delta, near_distance_delta, "Pan speed should increase at wider orthographic zoom sizes")
	assert_eq(rig.focus_position.y, start.y, "Pan speed scaling should still preserve height")

func test_main_scene_wires_camera_rig():
	var scene := _spawn_main_scene()
	await _wait_frames(1)

	var rig: CosmosCameraRig = scene.get_node_or_null("CosmosCameraRig")
	var configured_focus: Vector3 = rig.focus_position
	var earth_pos_at_setup: Vector3 = scene.bridge.get_body_state(1)["position"]
	var starting_distance: float = rig.current_distance
	var starting_height: float = rig.focus_position.y

	assert_not_null(rig, "Main scene should instance the camera rig")
	assert_not_null(scene.bridge, "Main scene should create the native bridge")
	assert_eq(configured_focus, earth_pos_at_setup, "Camera rig should be configured from Earth's position at startup")

	await _wait_frames(2)

	assert_eq(scene.body_nodes.size(), scene.bridge.get_body_count(), "Scene should spawn views for all bridge bodies")
	assert_eq(rig.focus_position, configured_focus, "Camera focus should remain stable after startup")
	assert_gt(rig.current_distance, 0.0, "Camera rig should have a valid startup distance")
	var starting_orthographic_size: float = rig.current_orthographic_size

	rig._unhandled_input(_mouse_button_event(5, true))
	rig._process(0.2)

	assert_eq(rig.focus_position, configured_focus, "Zooming in the main scene should not move focus")
	assert_eq(rig.current_distance, starting_distance, "Main scene zoom input should not change orbit distance")
	assert_gt(rig.current_orthographic_size, starting_orthographic_size, "Main scene zoom input should update orthographic size")

	var pan_right: Vector3 = rig._get_pan_right()
	var pan_forward: Vector3 = rig._get_pan_forward()
	rig.apply_keyboard_pan(Vector2(1.0, 0.0), 0.5)
	var keyboard_pan_delta: Vector3 = rig.focus_position - configured_focus
	assert_eq(rig.focus_position.y, starting_height, "Main scene keyboard pan should preserve height")
	assert_gt(
		keyboard_pan_delta.dot(pan_right),
		0.0,
		"Main scene keyboard pan should move along the camera-relative XZ direction"
	)

	var focus_after_keyboard_pan: Vector3 = rig.focus_position
	rig._unhandled_input(_mouse_button_event(1, true, Vector2(20.0, 20.0)))
	rig._unhandled_input(_mouse_motion_event(Vector2(50.0, -40.0), Vector2(70.0, -20.0)))
	rig._unhandled_input(_mouse_button_event(1, false, Vector2(70.0, -20.0)))

	var drag_pan_delta: Vector3 = rig.focus_position - focus_after_keyboard_pan
	assert_eq(rig.focus_position.y, starting_height, "Main scene drag pan should preserve height")
	assert_lt(
		drag_pan_delta.dot(pan_right),
		0.0,
		"Main scene drag pan should update focus along the camera-relative XZ direction"
	)
	assert_lt(
		drag_pan_delta.dot(pan_forward),
		0.0,
		"Main scene drag pan vertical motion should move opposite the camera-forward direction"
	)
