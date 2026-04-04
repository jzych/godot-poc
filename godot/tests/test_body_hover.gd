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
