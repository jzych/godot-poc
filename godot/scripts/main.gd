extends Node3D

const KM_PER_AU := 149597870.7
const AU_TO_UNITS := 10000.0
const KM_TO_UNITS := AU_TO_UNITS / KM_PER_AU
const BODY_VIEW_SCENE := preload("res://scenes/celestial_body_view.tscn")
const ORBIT_LANE_SCRIPT := preload("res://scripts/orbit_lane_view.gd")
const FOCUS_CONTROLLER_SCRIPT := preload("res://scripts/focus_controller.gd")
const BODY_COLLISION_MASK := 1
const PICK_DISTANCE := 50000.0
const CLICK_DRAG_THRESHOLD := 6.0
const HOVER_HIGHLIGHT_COLOR := Color.WHITE
const SELECTED_HIGHLIGHT_COLOR := Color(0.8, 0.8, 0.8, 1.0)
const CAMERA_DEBUG_PANEL_SIZE := Vector2(390.0, 430.0)
const CAMERA_DEBUG_PANEL_MARGIN := 12.0
const CAMERA_DEBUG_SLIDER_FOV := "fov"
const CAMERA_DEBUG_SLIDER_DISTANCE := "distance"
const CAMERA_DEBUG_SLIDER_NEAR_RATIO := "near_ratio"
const CAMERA_DEBUG_SLIDER_FAR_MULTIPLIER := "far_multiplier"

var bridge: SolarSystemBridge
var focus_controller: FocusController
var body_nodes: Array = []
var spacecraft_nodes: Array = []
var focus_target_nodes: Array = []
var orbit_lane_nodes := {}
var hovered_body_view = null
var selected_body_view = null
var locked_body_view = null
var spaceship_button_layer: CanvasLayer = null
var spaceship_button: Button = null
var camera_debug_layer: CanvasLayer = null
var camera_debug_panel: PanelContainer = null
var camera_debug_label: Label = null
var camera_debug_sliders: Dictionary = {}
var camera_debug_value_labels: Dictionary = {}
var _syncing_camera_debug_controls: bool = false
var _left_click_pressed: bool = false
var _left_click_dragging: bool = false
var _left_click_press_position: Vector2 = Vector2.ZERO
var _interaction_sync_queued: bool = false
var render_origin_position: Vector3 = Vector3.ZERO

@onready var camera_rig: CosmosCameraRig = $CosmosCameraRig
@onready var orbit_lanes_container: Node3D = $OrbitLanesContainer
@onready var bodies_container: Node3D = $BodiesContainer
@onready var body_label_overlay = $BodyLabelOverlay
@onready var orbit_marker_overlay = $OrbitMarkerOverlay

func _ready():
	bridge = SolarSystemBridge.new()
	add_child(bridge)
	focus_controller = FOCUS_CONTROLLER_SCRIPT.new()
	await get_tree().process_frame
	_spawn_bodies()
	_spawn_spacecraft()
	_spawn_orbit_lanes()
	_setup_light()
	_setup_camera()
	_setup_spaceship_button()
	_setup_camera_debug_panel()
	_sync_camera_debug_panel()

func _spawn_bodies():
	for i in range(bridge.get_body_count()):
		var state = bridge.get_body_state(i)
		var body_view = _spawn_focus_target_view(i, state, bodies_container)
		body_nodes.append(body_view)

func _spawn_spacecraft():
	var body_count: int = bridge.get_body_count()
	for i in range(bridge.get_spacecraft_count()):
		var state = bridge.get_spacecraft_state(i)
		var spacecraft_view = _spawn_focus_target_view(body_count + i, state, bodies_container)
		spacecraft_nodes.append(spacecraft_view)

func _spawn_focus_target_view(focus_index: int, state: Dictionary, parent: Node):
	state["km_to_units"] = KM_TO_UNITS
	var radius_units: float = float(state.get("radius_km", 1.0)) * KM_TO_UNITS
	var target_view = BODY_VIEW_SCENE.instantiate()
	parent.add_child(target_view)
	target_view.configure(focus_index, state, radius_units)
	target_view.update_render_position(state, render_origin_position)
	target_view.update_simulation_state(state, bridge.get_sim_time())
	focus_target_nodes.append(target_view)
	focus_controller.register_target(state, target_view)
	return target_view

func _spawn_orbit_lanes():
	for body_view in body_nodes:
		var state = bridge.get_body_state(body_view.body_index)
		var orbit: Dictionary = state.get("orbit", {})
		var central_body_index := int(orbit.get("central_body_index", -1))
		if central_body_index < 0:
			continue
		if float(state.get("orbital_period_seconds", 0.0)) <= 0.0:
			continue
		if float(orbit.get("semi_major_axis_km", 0.0)) <= 0.0:
			continue

		var orbit_lane = ORBIT_LANE_SCRIPT.new()
		orbit_lanes_container.add_child(orbit_lane)
		orbit_lane.configure(body_view.body_index, state, bridge.get_sim_time())
		orbit_lane.update_center_position(_get_orbit_center_position(central_body_index))
		orbit_lane_nodes[body_view.body_index] = orbit_lane

	_refresh_orbit_lanes()

func _process(_delta):
	if bridge == null or body_nodes.is_empty():
		return

	var sim_time_seconds: float = bridge.get_sim_time()
	for i in range(body_nodes.size()):
		var state = bridge.get_body_state(i)
		body_nodes[i].update_render_position(state, render_origin_position)
		body_nodes[i].update_simulation_state(state, sim_time_seconds)
		focus_controller.update_target_state(state)

	for i in range(spacecraft_nodes.size()):
		var state = bridge.get_spacecraft_state(i)
		spacecraft_nodes[i].update_render_position(state, render_origin_position)
		spacecraft_nodes[i].update_simulation_state(state, sim_time_seconds)
		focus_controller.update_target_state(state)

	if locked_body_view != null and camera_rig != null and camera_rig.is_focus_lock_active():
		_set_render_origin(locked_body_view.simulation_position)

	_sync_orbit_lanes(sim_time_seconds)
	_sync_focus_lock_target()
	_sync_camera_debug_panel()
	_queue_interaction_sync()

func _input(event):
	if orbit_marker_overlay != null and orbit_marker_overlay.handle_input(event):
		_sync_orbit_markers()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			update_hover_from_screen_position(event.position)
			if event.double_click and hovered_body_view != null:
				_set_selected_body(hovered_body_view)
				_start_focus_lock(hovered_body_view)
				_left_click_pressed = false
				_left_click_dragging = false
				get_viewport().set_input_as_handled()
				return

			_left_click_pressed = true
			_left_click_dragging = false
			_left_click_press_position = event.position
		elif _left_click_pressed:
			_left_click_pressed = false
			if not _left_click_dragging:
				update_hover_from_screen_position(event.position)
				_set_selected_body(hovered_body_view)
	elif event is InputEventMouseMotion and _left_click_pressed:
		if event.position.distance_to(_left_click_press_position) >= CLICK_DRAG_THRESHOLD:
			_left_click_dragging = true

func _setup_light():
	var light = DirectionalLight3D.new()
	light.light_energy = 3.0
	light.light_color = Color(1.0, 0.95, 0.8)
	light.rotation_degrees = Vector3(-30, -30, 0)
	add_child(light)

func _setup_camera():
	if bridge == null or camera_rig == null:
		return

	var earth_view = focus_controller.get_target_view("earth") if focus_controller != null else null
	var earth_pos: Vector3 = earth_view.global_position if earth_view != null else bridge.get_body_state(1)["position"]
	var outward = earth_pos.normalized()
	var camera_offset = outward * 3.0 + Vector3(0, 2.0, 0)
	camera_rig.configure_from_focus_target(
		earth_pos,
		camera_offset,
		_build_camera_focus_state(earth_view)
	)

func _setup_spaceship_button():
	if spaceship_button_layer != null:
		return

	spaceship_button_layer = CanvasLayer.new()
	spaceship_button_layer.name = "SpaceshipButtonLayer"
	add_child(spaceship_button_layer)

	spaceship_button = Button.new()
	spaceship_button.name = "SpaceshipButton"
	spaceship_button.text = "SPACESHIP"
	spaceship_button.focus_mode = Control.FOCUS_NONE
	spaceship_button.custom_minimum_size = Vector2(136.0, 36.0)
	spaceship_button.anchor_left = 1.0
	spaceship_button.anchor_right = 1.0
	spaceship_button.anchor_top = 0.0
	spaceship_button.anchor_bottom = 0.0
	spaceship_button.offset_left = -148.0
	spaceship_button.offset_right = -12.0
	spaceship_button.offset_top = 12.0
	spaceship_button.offset_bottom = 48.0
	spaceship_button.gui_input.connect(_on_spaceship_button_gui_input)
	spaceship_button.pressed.connect(_on_spaceship_button_pressed)
	spaceship_button_layer.add_child(spaceship_button)

func _setup_camera_debug_panel():
	if camera_debug_layer != null:
		return

	camera_debug_layer = CanvasLayer.new()
	camera_debug_layer.name = "CameraDebugLayer"
	camera_debug_layer.layer = 20
	add_child(camera_debug_layer)

	camera_debug_panel = PanelContainer.new()
	camera_debug_panel.name = "CameraDebugPanel"
	camera_debug_panel.anchor_left = 1.0
	camera_debug_panel.anchor_right = 1.0
	camera_debug_panel.anchor_top = 1.0
	camera_debug_panel.anchor_bottom = 1.0
	camera_debug_panel.offset_left = -CAMERA_DEBUG_PANEL_SIZE.x - CAMERA_DEBUG_PANEL_MARGIN
	camera_debug_panel.offset_right = -CAMERA_DEBUG_PANEL_MARGIN
	camera_debug_panel.offset_top = -CAMERA_DEBUG_PANEL_SIZE.y - CAMERA_DEBUG_PANEL_MARGIN
	camera_debug_panel.offset_bottom = -CAMERA_DEBUG_PANEL_MARGIN
	camera_debug_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.02, 0.025, 0.035, 0.78)
	panel_style.border_color = Color(0.45, 0.58, 0.68, 0.85)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(6)
	camera_debug_panel.add_theme_stylebox_override("panel", panel_style)
	camera_debug_layer.add_child(camera_debug_panel)

	var margin_container := MarginContainer.new()
	margin_container.add_theme_constant_override("margin_left", 10)
	margin_container.add_theme_constant_override("margin_top", 8)
	margin_container.add_theme_constant_override("margin_right", 10)
	margin_container.add_theme_constant_override("margin_bottom", 8)
	camera_debug_panel.add_child(margin_container)

	var debug_layout := VBoxContainer.new()
	debug_layout.name = "CameraDebugLayout"
	debug_layout.add_theme_constant_override("separation", 6)
	margin_container.add_child(debug_layout)

	camera_debug_label = Label.new()
	camera_debug_label.name = "CameraDebugLabel"
	camera_debug_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camera_debug_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	camera_debug_label.add_theme_font_size_override("font_size", 13)
	camera_debug_label.add_theme_color_override("font_color", Color(0.82, 0.92, 1.0, 1.0))
	debug_layout.add_child(camera_debug_label)

	_add_camera_debug_slider(
		debug_layout,
		CAMERA_DEBUG_SLIDER_FOV,
		"FOV",
		5.0,
		120.0,
		0.5
	)
	_add_camera_debug_slider(
		debug_layout,
		CAMERA_DEBUG_SLIDER_DISTANCE,
		"Distance",
		0.0,
		1.0,
		0.001
	)
	_add_camera_debug_slider(
		debug_layout,
		CAMERA_DEBUG_SLIDER_NEAR_RATIO,
		"Near ratio",
		0.000001,
		0.1,
		0.0001
	)
	_add_camera_debug_slider(
		debug_layout,
		CAMERA_DEBUG_SLIDER_FAR_MULTIPLIER,
		"Far multiplier",
		1.01,
		20.0,
		0.01
	)

func _add_camera_debug_slider(
	parent: Container,
	control_id: String,
	title: String,
	min_value: float,
	max_value: float,
	step_value: float
):
	var control_layout := VBoxContainer.new()
	control_layout.name = "%sControl" % control_id.capitalize().replace(" ", "")
	control_layout.add_theme_constant_override("separation", 1)
	parent.add_child(control_layout)

	var label_row := HBoxContainer.new()
	control_layout.add_child(label_row)

	var title_label := Label.new()
	title_label.text = title
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_font_size_override("font_size", 12)
	title_label.add_theme_color_override("font_color", Color(0.72, 0.84, 0.92, 1.0))
	label_row.add_child(title_label)

	var value_label := Label.new()
	value_label.name = "%sValue" % control_id.capitalize().replace(" ", "")
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.custom_minimum_size = Vector2(104.0, 0.0)
	value_label.add_theme_font_size_override("font_size", 12)
	value_label.add_theme_color_override("font_color", Color(0.88, 0.95, 1.0, 1.0))
	label_row.add_child(value_label)

	var slider := HSlider.new()
	slider.name = "%sSlider" % control_id.capitalize().replace(" ", "")
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step_value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.focus_mode = Control.FOCUS_NONE
	slider.value_changed.connect(_on_camera_debug_slider_changed.bind(control_id))
	control_layout.add_child(slider)

	camera_debug_sliders[control_id] = slider
	camera_debug_value_labels[control_id] = value_label

func _on_spaceship_button_pressed():
	_activate_spaceship_button(false)

func _on_spaceship_button_gui_input(event: InputEvent):
	if not (event is InputEventMouseButton):
		return
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed or not event.double_click:
		return

	_activate_spaceship_button(true)
	spaceship_button.accept_event()

func _activate_spaceship_button(lock_view: bool):
	if spacecraft_nodes.is_empty():
		return

	var spacecraft_view = spacecraft_nodes[0]
	_select_focus_target_from_ui(spacecraft_view)
	if lock_view:
		_start_focus_lock(spacecraft_view)

func _select_focus_target_from_ui(target_view):
	if target_view == null:
		return

	_set_hovered_body(target_view)
	_set_selected_body(target_view)

func update_hover_from_screen_position(mouse_position: Vector2):
	if camera_rig == null:
		_set_hovered_body(null)
		return

	var camera: Camera3D = camera_rig.get_camera_node()
	var visible_rect: Rect2 = get_viewport().get_visible_rect()
	if camera == null or not visible_rect.has_point(mouse_position):
		_set_hovered_body(null)
		return

	var ray_origin: Vector3 = camera.project_ray_origin(mouse_position)
	var ray_normal: Vector3 = camera.project_ray_normal(mouse_position)
	var query := PhysicsRayQueryParameters3D.create(
		ray_origin,
		ray_origin + (ray_normal * PICK_DISTANCE)
	)
	# Camera-inside-body positions are currently treated as invalid and will be
	# handled later, so hover picking intentionally keeps the default
	# hit_from_inside = false behavior for now.
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.collision_mask = BODY_COLLISION_MASK

	var result: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	_set_hovered_body(_resolve_body_view_from_hit(result))

func _set_hovered_body(body_view):
	if hovered_body_view == body_view:
		return

	hovered_body_view = body_view
	_refresh_highlights()

func _set_selected_body(body_view):
	if selected_body_view == body_view:
		return

	selected_body_view = body_view
	_refresh_highlights()

func _resolve_body_view_from_hit(result: Dictionary):
	if result.is_empty():
		return null

	var collider: Variant = result.get("collider")
	if collider is CollisionObject3D and collider.has_meta("body_view"):
		return collider.get_meta("body_view")

	return null

func _refresh_highlights():
	for body_view in focus_target_nodes:
		if body_view == hovered_body_view:
			body_view.set_highlight(true, HOVER_HIGHLIGHT_COLOR)
		elif body_view == selected_body_view:
			body_view.set_highlight(true, SELECTED_HIGHLIGHT_COLOR)
		else:
			body_view.set_highlight(false, HOVER_HIGHLIGHT_COLOR)

	_refresh_orbit_lanes()
	_sync_orbit_markers()
	_sync_body_labels()
	_queue_interaction_sync()

func _refresh_orbit_lanes():
	var selected_body_index: int = selected_body_view.body_index if selected_body_view != null else -1
	for body_index in orbit_lane_nodes.keys():
		orbit_lane_nodes[body_index].set_selected(body_index == selected_body_index)

func _sync_orbit_lanes(sim_time_seconds: float):
	for orbit_lane in orbit_lane_nodes.values():
		orbit_lane.update_center_position(_get_orbit_center_position(orbit_lane.central_body_index))
		orbit_lane.update_simulation_phase(sim_time_seconds)

func _get_orbit_center_position(central_body_index: int) -> Vector3:
	if central_body_index < 0 or central_body_index >= body_nodes.size():
		return Vector3.ZERO
	return body_nodes[central_body_index].position

func get_orbit_lane_for_body_index(body_index: int):
	return orbit_lane_nodes.get(body_index)

func _sync_body_labels():
	if body_label_overlay == null or camera_rig == null:
		return

	body_label_overlay.update_labels(
		camera_rig.get_camera_node(),
		hovered_body_view,
		selected_body_view
	)

func _sync_orbit_markers():
	if orbit_marker_overlay == null or camera_rig == null or bridge == null:
		return

	var orbit_center := Vector3.ZERO
	if selected_body_view != null:
		orbit_center = _get_orbit_center_position(
			int(selected_body_view.orbit_state.get("central_body_index", -1))
		)

	orbit_marker_overlay.update_markers(
		camera_rig.get_camera_node(),
		selected_body_view,
		orbit_center,
		bridge.get_sim_time(),
		bridge
	)

func _start_focus_lock(body_view):
	if body_view == null or camera_rig == null:
		return

	locked_body_view = body_view
	_set_render_origin(body_view.simulation_position)
	camera_rig.start_focus_lock_for_target(
		body_view.global_position,
		_build_camera_focus_state(body_view)
	)

func _build_camera_focus_state(body_view) -> Dictionary:
	if body_view == null:
		return {}

	return {
		"id": body_view.focus_id,
		"focus_type": body_view.focus_type,
		"framing_radius": body_view.get_camera_framing_radius(),
		"preferred_min_distance": body_view.preferred_min_distance_units,
		"preferred_max_distance": body_view.preferred_max_distance_units,
	}

func _queue_interaction_sync():
	if _interaction_sync_queued:
		return

	_interaction_sync_queued = true
	call_deferred("_sync_interaction_from_camera")

func _sync_interaction_from_camera():
	_interaction_sync_queued = false

	if bridge == null or body_nodes.is_empty():
		return

	update_hover_from_screen_position(get_viewport().get_mouse_position())
	_sync_orbit_markers()
	_sync_body_labels()

func _sync_focus_lock_target():
	if locked_body_view == null or camera_rig == null:
		return

	if not camera_rig.is_focus_lock_active():
		locked_body_view = null
		return

	camera_rig.update_focus_lock_target(locked_body_view.global_position)

func _set_render_origin(new_render_origin: Vector3):
	if render_origin_position.is_equal_approx(new_render_origin):
		return

	var origin_delta: Vector3 = new_render_origin - render_origin_position
	render_origin_position = new_render_origin
	for target_view in focus_target_nodes:
		target_view.position = target_view.simulation_position - render_origin_position

	for orbit_lane in orbit_lane_nodes.values():
		orbit_lane.update_center_position(_get_orbit_center_position(orbit_lane.central_body_index))

	if camera_rig != null:
		camera_rig.apply_render_origin_shift(origin_delta)

func _sync_camera_debug_panel():
	if camera_debug_label == null or camera_rig == null:
		return

	var camera_state: Dictionary = camera_rig.get_camera_state()
	camera_debug_label.text = _build_camera_debug_text(camera_state)
	_sync_camera_debug_control_values(camera_state)

func _build_camera_debug_text(camera_state: Dictionary = {}) -> String:
	if camera_state.is_empty() and camera_rig != null:
		camera_state = camera_rig.get_camera_state()
	var camera: Camera3D = camera_rig.get_camera_node()
	var focus_name := "none"
	if locked_body_view != null:
		focus_name = locked_body_view.body_label
	elif selected_body_view != null:
		focus_name = selected_body_view.body_label
	elif hovered_body_view != null:
		focus_name = hovered_body_view.body_label

	var spacecraft_rendered := false
	for spacecraft_view in spacecraft_nodes:
		if spacecraft_view.body_mesh.mesh != null:
			spacecraft_rendered = true
			break

	return "\n".join([
		"Camera View",
		"projection: %s  fov: %.2f deg" % [
			str(camera_state.get("projection", "unknown")),
			float(camera_state.get("effective_fov", 0.0)),
		],
		"focus: %s (%s/%s)" % [
			focus_name,
			str(camera_state.get("current_focus_id", "")),
			str(camera_state.get("current_focus_type", "")),
		],
		"locked: %s  zoom: %.4f" % [
			str(camera_rig.is_focus_lock_active()),
			float(camera_state.get("zoom_scalar", 0.0)),
		],
		"distance: %s -> %s" % [
			_format_debug_float(float(camera_state.get("focus_distance", 0.0))),
			_format_debug_float(float(camera_state.get("target_focus_distance", 0.0))),
		],
		"bounds: %s .. %s" % [
			_format_debug_float(float(camera_state.get("min_focus_distance", 0.0))),
			_format_debug_float(float(camera_state.get("max_focus_distance", 0.0))),
		],
		"clip: near %s  far %s" % [
			_format_debug_float(float(camera_state.get("near_clip", 0.0))),
			_format_debug_float(float(camera_state.get("far_clip", 0.0))),
		],
		"yaw/pitch: %.2f / %.2f" % [
			float(camera_state.get("yaw", 0.0)),
			float(camera_state.get("pitch", 0.0)),
		],
		"camera local: %s" % _format_debug_vector(camera.position if camera != null else Vector3.ZERO),
		"render origin: %s" % _format_debug_vector(render_origin_position),
		"small objects: %s (%d spacecraft)" % [
			"rendered" if spacecraft_rendered else "not rendered",
			spacecraft_nodes.size(),
		],
	])

func _format_debug_float(value: float) -> String:
	var abs_value := absf(value)
	if is_zero_approx(value):
		return "0"
	if abs_value >= 1000000000.0:
		return "%.3fG" % (value / 1000000000.0)
	if abs_value >= 1000000.0:
		return "%.3fM" % (value / 1000000.0)
	if abs_value >= 10000.0:
		return "%.3fk" % (value / 1000.0)
	if abs_value < 0.001:
		return "%.9f" % value
	return "%.6f" % value

func _format_debug_vector(value: Vector3) -> String:
	return "(%s, %s, %s)" % [
		_format_debug_float(value.x),
		_format_debug_float(value.y),
		_format_debug_float(value.z),
	]

func _sync_camera_debug_control_values(camera_state: Dictionary):
	if camera_debug_sliders.is_empty() or camera_rig == null:
		return

	_syncing_camera_debug_controls = true
	_set_camera_debug_slider_value(
		CAMERA_DEBUG_SLIDER_FOV,
		float(camera_state.get("effective_fov", camera_rig.fixed_fov_degrees)),
		"%.1f deg" % camera_rig.fixed_fov_degrees
	)
	_set_camera_debug_slider_value(
		CAMERA_DEBUG_SLIDER_DISTANCE,
		float(camera_state.get("zoom_scalar", camera_rig.get_zoom_scalar())),
		_format_debug_float(float(camera_state.get("target_focus_distance", camera_rig.target_distance)))
	)
	_set_camera_debug_slider_value(
		CAMERA_DEBUG_SLIDER_NEAR_RATIO,
		camera_rig.near_clip_distance_ratio,
		"%.6f" % camera_rig.near_clip_distance_ratio
	)
	_set_camera_debug_slider_value(
		CAMERA_DEBUG_SLIDER_FAR_MULTIPLIER,
		camera_rig.far_clip_distance_multiplier,
		"%.2fx" % camera_rig.far_clip_distance_multiplier
	)
	_syncing_camera_debug_controls = false

func _set_camera_debug_slider_value(control_id: String, value: float, display_text: String):
	var slider: HSlider = camera_debug_sliders.get(control_id)
	if slider != null and not is_equal_approx(slider.value, value):
		slider.value = value

	var value_label: Label = camera_debug_value_labels.get(control_id)
	if value_label != null:
		value_label.text = display_text

func _on_camera_debug_slider_changed(value: float, control_id: String):
	if _syncing_camera_debug_controls or camera_rig == null:
		return

	match control_id:
		CAMERA_DEBUG_SLIDER_FOV:
			camera_rig.set_fixed_fov_degrees(value)
		CAMERA_DEBUG_SLIDER_DISTANCE:
			camera_rig.set_zoom_scalar(value)
		CAMERA_DEBUG_SLIDER_NEAR_RATIO:
			camera_rig.set_near_clip_distance_ratio(value)
		CAMERA_DEBUG_SLIDER_FAR_MULTIPLIER:
			camera_rig.set_far_clip_distance_multiplier(value)

	_sync_orbit_markers()
	_sync_body_labels()
	_sync_camera_debug_panel()
