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
var _left_click_pressed: bool = false
var _left_click_dragging: bool = false
var _left_click_press_position: Vector2 = Vector2.ZERO
var _interaction_sync_queued: bool = false

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
	target_view.position = state.get("position", Vector3.ZERO)
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
		body_nodes[i].position = state["position"]
		body_nodes[i].update_simulation_state(state, sim_time_seconds)
		focus_controller.update_target_state(state)

	for i in range(spacecraft_nodes.size()):
		var state = bridge.get_spacecraft_state(i)
		spacecraft_nodes[i].position = state["position"]
		spacecraft_nodes[i].update_simulation_state(state, sim_time_seconds)
		focus_controller.update_target_state(state)

	_sync_orbit_lanes(sim_time_seconds)
	_sync_focus_lock_target()
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
		"framing_radius": body_view.body_radius,
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
