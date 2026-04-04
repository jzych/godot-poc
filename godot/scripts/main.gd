extends Node3D

const KM_PER_AU := 149597870.7
const AU_TO_UNITS := 10000.0
const KM_TO_UNITS := AU_TO_UNITS / KM_PER_AU
const BODY_VIEW_SCENE := preload("res://scenes/celestial_body_view.tscn")
const BODY_COLLISION_MASK := 1
const PICK_DISTANCE := 50000.0
const CLICK_DRAG_THRESHOLD := 6.0
const HOVER_HIGHLIGHT_COLOR := Color.WHITE
const SELECTED_HIGHLIGHT_COLOR := Color(0.8, 0.8, 0.8, 1.0)

# Real radii in km
const BODY_RADII := {
	"Sun": 696000.0,
	"Earth": 6371.0,
	"Moon": 1737.0,
}

var bridge: SolarSystemBridge
var body_nodes: Array = []
var hovered_body_view = null
var selected_body_view = null
var _left_click_pressed: bool = false
var _left_click_dragging: bool = false
var _left_click_press_position: Vector2 = Vector2.ZERO

@onready var camera_rig: CosmosCameraRig = $CosmosCameraRig
@onready var bodies_container: Node3D = $BodiesContainer

func _ready():
	bridge = SolarSystemBridge.new()
	add_child(bridge)
	await get_tree().process_frame
	_spawn_bodies()
	_setup_light()
	_setup_camera()

func _spawn_bodies():
	for i in range(bridge.get_body_count()):
		var state = bridge.get_body_state(i)
		var radius_units: float = BODY_RADII.get(state["name"], 1000.0) * KM_TO_UNITS
		var body_view = BODY_VIEW_SCENE.instantiate()
		bodies_container.add_child(body_view)
		body_view.configure(i, state, radius_units)
		body_nodes.append(body_view)

func _process(_delta):
	if bridge == null or body_nodes.is_empty():
		return

	for i in range(body_nodes.size()):
		var state = bridge.get_body_state(i)
		body_nodes[i].position = state["position"]

	update_hover_from_screen_position(get_viewport().get_mouse_position())

func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
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
	for body_view in body_nodes:
		if body_view == hovered_body_view:
			body_view.set_highlight(true, HOVER_HIGHLIGHT_COLOR)
		elif body_view == selected_body_view:
			body_view.set_highlight(true, SELECTED_HIGHLIGHT_COLOR)
		else:
			body_view.set_highlight(false, HOVER_HIGHLIGHT_COLOR)
