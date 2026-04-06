extends Node3D

const KM_PER_AU := 149597870.7
const AU_TO_UNITS := 10000.0
const KM_TO_UNITS := AU_TO_UNITS / KM_PER_AU
const BODY_VIEW_SCENE := preload("res://scenes/celestial_body_view.tscn")
const ORBIT_LANE_SCRIPT := preload("res://scripts/orbit_lane_view.gd")
const BODY_COLLISION_MASK := 1
const PICK_DISTANCE := 50000.0
const CLICK_DRAG_THRESHOLD := 6.0
const HOVER_HIGHLIGHT_COLOR := Color.WHITE
const SELECTED_HIGHLIGHT_COLOR := Color(0.8, 0.8, 0.8, 1.0)
const CAMERA_BODY_CLEARANCE_RATIO := 0.05
const CAMERA_BODY_CLEARANCE_MIN := 0.1

# Real radii in km
const BODY_RADII := {
	"Sun": 696000.0,
	"Earth": 6371.0,
	"Moon": 1737.0,
}

var bridge: SolarSystemBridge
var body_nodes: Array = []
var orbit_lane_nodes := {}
var hovered_body_view = null
var selected_body_view = null
var locked_body_view = null
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
	await get_tree().process_frame
	_spawn_bodies()
	_spawn_orbit_lanes()
	_setup_light()
	_setup_camera()

func _spawn_bodies():
	for i in range(bridge.get_body_count()):
		var state = bridge.get_body_state(i)
		var radius_units: float = BODY_RADII.get(state["name"], 1000.0) * KM_TO_UNITS
		var body_view = BODY_VIEW_SCENE.instantiate()
		bodies_container.add_child(body_view)
		body_view.configure(i, state, radius_units)
		body_view.update_simulation_state(state, bridge.get_sim_time())
		body_nodes.append(body_view)

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

	_sync_orbit_lanes(sim_time_seconds)
	_sync_focus_lock_target()
	_sync_camera_clearance()
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

	var earth_pos: Vector3 = bridge.get_body_state(1)["position"]
	var outward = earth_pos.normalized()
	var camera_offset = outward * 3.0 + Vector3(0, 2.0, 0)
	camera_rig.configure_from_offset(earth_pos, camera_offset)
	_sync_camera_clearance()

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
	# The camera rig maintains a body-clearance floor on orbit distance, so
	# hover picking intentionally keeps the default hit_from_inside = false
	# behavior here.
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
	for body_view in body_nodes:
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
	camera_rig.start_focus_lock(body_view.global_position, body_view.body_radius)

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

func _sync_camera_clearance():
	if camera_rig == null or body_nodes.is_empty():
		return

	var camera: Camera3D = camera_rig.get_camera_node()
	if camera == null:
		return

	var offset: Vector3 = camera.global_position - camera_rig.focus_position
	if offset.length_squared() <= 0.000001:
		camera_rig.set_minimum_safe_distance(camera_rig.min_distance)
		return

	var desired_distance: float = max(camera_rig.current_distance, camera_rig.target_distance)
	var ray_direction: Vector3 = offset.normalized()
	var required_distance: float = camera_rig.min_distance

	for body_view in body_nodes:
		var clearance_radius: float = body_view.body_radius + max(
			body_view.body_radius * CAMERA_BODY_CLEARANCE_RATIO,
			CAMERA_BODY_CLEARANCE_MIN
		)
		required_distance = max(
			required_distance,
			_get_required_camera_distance_for_body(
				camera_rig.focus_position,
				ray_direction,
				desired_distance,
				body_view.global_position,
				clearance_radius
			)
		)

	camera_rig.set_minimum_safe_distance(required_distance)

func _get_required_camera_distance_for_body(
	ray_origin: Vector3,
	ray_direction: Vector3,
	desired_distance: float,
	sphere_center: Vector3,
	sphere_radius: float
) -> float:
	var origin_to_center: Vector3 = ray_origin - sphere_center
	var projection: float = ray_direction.dot(origin_to_center)
	var discriminant: float = (projection * projection) - (
		origin_to_center.length_squared() - (sphere_radius * sphere_radius)
	)
	if discriminant < 0.0:
		return 0.0

	var sqrt_discriminant: float = sqrt(discriminant)
	var near_distance: float = -projection - sqrt_discriminant
	var far_distance: float = -projection + sqrt_discriminant
	if far_distance <= 0.0:
		return 0.0
	if desired_distance < near_distance or desired_distance > far_distance:
		return 0.0
	return far_distance
