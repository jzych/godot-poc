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

func _mouse_button_event(button_index: int, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button_index
	event.pressed = pressed
	return event

func _mouse_motion_event(relative: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.relative = relative
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

func test_main_scene_wires_camera_rig():
	var scene := _spawn_main_scene()
	await _wait_frames(1)

	var rig: CosmosCameraRig = scene.get_node_or_null("CosmosCameraRig")
	var configured_focus: Vector3 = rig.focus_position
	var earth_pos_at_setup: Vector3 = scene.bridge.get_body_state(1)["position"]

	assert_not_null(rig, "Main scene should instance the camera rig")
	assert_not_null(scene.bridge, "Main scene should create the native bridge")
	assert_eq(configured_focus, earth_pos_at_setup, "Camera rig should be configured from Earth's position at startup")

	await _wait_frames(2)

	assert_eq(scene.body_nodes.size(), scene.bridge.get_body_count(), "Scene should spawn views for all bridge bodies")
	assert_eq(rig.focus_position, configured_focus, "Camera focus should remain stable after startup")
	assert_gt(rig.current_distance, 0.0, "Camera rig should have a valid startup distance")
