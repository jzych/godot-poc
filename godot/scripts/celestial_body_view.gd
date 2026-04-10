extends Node3D
class_name CelestialBodyView

const BODY_OUTLINE_SHADER := preload("res://shaders/body_outline.gdshader")
const BODY_SURFACE_SHADER := preload("res://shaders/body_surface.gdshader")

const BODY_COLLISION_LAYER := 1
const MIN_OUTLINE_WIDTH := 0.01
const OUTLINE_WIDTH_RATIO := 0.05
const DEFAULT_HIGHLIGHT_COLOR := Color.WHITE
const DEFAULT_ORBIT_NORMAL := Vector3.UP
const DEFAULT_PRIME_MERIDIAN_DIRECTION := Vector3.FORWARD
const PRIME_MERIDIAN_WIDTH := 0.035
const PRIME_MERIDIAN_SOFTNESS := 0.015
const PRIME_MERIDIAN_DARKEN_FACTOR := 0.35
const EMISSION_STRENGTH := 0.45
const AXIS_EPSILON := 0.000001

var body_index: int = -1
var focus_id: String = ""
var focus_type: String = ""
var body_label: String = ""
var body_secondary_label: String = ""
var body_radius: float = 1.0
var body_radius_km: float = 1.0
var visual_shape: String = "sphere"
var visual_size_km: float = 2.0
var visual_size_units: float = 2.0
var preferred_min_distance_km: float = 1.0
var preferred_max_distance_km: float = 1.0
var preferred_min_distance_units: float = 1.0
var preferred_max_distance_units: float = 1.0
var orbit_state: Dictionary = {}
var rotation_state: Dictionary = {}

var _body_mesh_resource: Mesh = null
var _base_color: Color = Color.WHITE
var _outline_material: ShaderMaterial = null
var _surface_material: ShaderMaterial = null
var _highlight_visible: bool = false
var _highlight_color: Color = DEFAULT_HIGHLIGHT_COLOR
var _orbit_normal: Vector3 = DEFAULT_ORBIT_NORMAL
var _rotation_axis: Vector3 = DEFAULT_ORBIT_NORMAL
var _prime_meridian_direction: Vector3 = DEFAULT_PRIME_MERIDIAN_DIRECTION
var _base_visual_basis: Basis = Basis.IDENTITY

@onready var body_visual_root: Node3D = $BodyVisualRoot
@onready var body_mesh: MeshInstance3D = $BodyVisualRoot/BodyMesh
@onready var outline_mesh: MeshInstance3D = $BodyVisualRoot/OutlineMesh
@onready var hit_body: StaticBody3D = $HitBody
@onready var collision_shape: CollisionShape3D = $HitBody/CollisionShape3D

func _ready():
	_refresh_visuals()

func configure(index: int, state: Dictionary, radius_units: float):
	body_index = index
	focus_id = str(state.get("id", str(index)))
	focus_type = str(state.get("focus_type", "planet"))
	body_label = str(state.get("name", "Body"))
	body_secondary_label = _build_secondary_label(state)
	body_radius = radius_units
	body_radius_km = float(state.get("radius_km", 1.0))
	visual_shape = str(state.get("visual_shape", "sphere"))
	visual_size_km = float(state.get("visual_size_km", body_radius_km * 2.0))
	visual_size_units = visual_size_km * float(state.get("km_to_units", 0.0))
	if visual_size_units <= 0.0:
		visual_size_units = radius_units * 2.0
	preferred_min_distance_km = float(state.get("preferred_min_distance_km", 1.0))
	preferred_max_distance_km = float(state.get("preferred_max_distance_km", 1.0))
	preferred_min_distance_units = preferred_min_distance_km * float(state.get("km_to_units", 1.0))
	preferred_max_distance_units = preferred_max_distance_km * float(state.get("km_to_units", 1.0))
	orbit_state = state.get("orbit", {})
	rotation_state = state.get("rotation", {})
	_body_mesh_resource = _build_body_mesh(radius_units)
	_base_color = state.get("color", Color.WHITE)
	name = body_label
	_refresh_rotation_model()
	_refresh_visuals()

func is_highlight_visible() -> bool:
	return _highlight_visible

func get_highlight_color() -> Color:
	return _highlight_color

func set_highlight(visible: bool, color: Color = DEFAULT_HIGHLIGHT_COLOR):
	_highlight_visible = visible
	_highlight_color = color
	_apply_highlight_state()

func update_simulation_state(state: Dictionary, sim_time_seconds: float):
	orbit_state = state.get("orbit", orbit_state)
	rotation_state = state.get("rotation", rotation_state)
	_refresh_rotation_model()
	_apply_visual_rotation(sim_time_seconds)

func get_visual_basis() -> Basis:
	return body_visual_root.basis

func get_camera_framing_radius() -> float:
	if visual_shape == "cube" and visual_size_units > 0.0:
		return visual_size_units * 0.5
	return body_radius

func get_orbit_normal() -> Vector3:
	return _orbit_normal

func get_rotation_axis() -> Vector3:
	return _rotation_axis

func get_prime_meridian_world_direction() -> Vector3:
	return (body_visual_root.global_transform.basis * Vector3.FORWARD).normalized()

func has_prime_meridian_visual() -> bool:
	return _surface_material != null and body_mesh.material_override == _surface_material

func get_base_color() -> Color:
	return _base_color

func get_prime_meridian_color() -> Color:
	if _surface_material == null:
		return Color.BLACK
	return _surface_material.get_shader_parameter("meridian_color")

func _refresh_visuals():
	if not is_node_ready() or _body_mesh_resource == null:
		return

	body_mesh.mesh = _body_mesh_resource
	outline_mesh.mesh = _body_mesh_resource
	outline_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	if _surface_material == null:
		_surface_material = ShaderMaterial.new()
		_surface_material.shader = BODY_SURFACE_SHADER

	_surface_material.set_shader_parameter("base_color", _base_color)
	_surface_material.set_shader_parameter("meridian_color", _base_color.darkened(1.0 - PRIME_MERIDIAN_DARKEN_FACTOR))
	_surface_material.set_shader_parameter("meridian_width", PRIME_MERIDIAN_WIDTH)
	_surface_material.set_shader_parameter("meridian_softness", PRIME_MERIDIAN_SOFTNESS)
	_surface_material.set_shader_parameter("emission_strength", EMISSION_STRENGTH)
	body_mesh.material_override = _surface_material

	if _outline_material == null:
		_outline_material = ShaderMaterial.new()
		_outline_material.shader = BODY_OUTLINE_SHADER

	_outline_material.set_shader_parameter(
		"outline_width",
		max(body_radius * OUTLINE_WIDTH_RATIO, MIN_OUTLINE_WIDTH)
	)
	outline_mesh.material_override = _outline_material
	_apply_highlight_state()

	collision_shape.shape = _build_collision_shape()

	hit_body.collision_layer = BODY_COLLISION_LAYER
	hit_body.collision_mask = 0
	hit_body.input_ray_pickable = true
	hit_body.set_meta("body_view", self)
	_apply_visual_rotation(0.0)

func _build_sphere_mesh(radius_units: float) -> SphereMesh:
	var sphere := SphereMesh.new()
	sphere.radius = radius_units
	sphere.height = radius_units * 2.0
	return sphere

func _build_body_mesh(radius_units: float) -> Mesh:
	if visual_shape == "cube":
		var cube := BoxMesh.new()
		cube.size = Vector3.ONE * visual_size_units
		return cube

	return _build_sphere_mesh(radius_units)

func _build_collision_shape() -> Shape3D:
	if visual_shape == "cube":
		var box_shape := BoxShape3D.new()
		box_shape.size = Vector3.ONE * visual_size_units
		return box_shape

	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = body_radius
	return sphere_shape

func _build_secondary_label(state: Dictionary) -> String:
	var parts: Array[String] = []
	var central_body_name := str(state.get("central_body_name", ""))
	var orbital_period_text := str(state.get("orbital_period_ydhms", ""))

	if not central_body_name.is_empty():
		parts.append("Central: %s" % central_body_name)
	if not orbital_period_text.is_empty():
		parts.append("Period: %s" % orbital_period_text)

	return " | ".join(parts)

func _apply_highlight_state():
	if not is_node_ready() or _outline_material == null:
		return

	outline_mesh.visible = _highlight_visible
	_outline_material.set_shader_parameter("outline_color", _highlight_color)

func _refresh_rotation_model():
	_orbit_normal = _compute_orbit_normal()
	_rotation_axis = _compute_rotation_axis(_orbit_normal)
	_prime_meridian_direction = _compute_prime_meridian_direction(_rotation_axis, _orbit_normal)

	var local_x: Vector3 = _rotation_axis.cross(_prime_meridian_direction).normalized()
	if local_x.length_squared() <= AXIS_EPSILON:
		local_x = Vector3.RIGHT

	_base_visual_basis = Basis(local_x, _rotation_axis, _prime_meridian_direction).orthonormalized()

func _apply_visual_rotation(sim_time_seconds: float):
	if not is_node_ready():
		return

	var rotation_speed: float = float(rotation_state.get("rotation_speed_rad_per_s", 0.0))
	var spin_basis := Basis(Vector3.UP, rotation_speed * sim_time_seconds)
	body_visual_root.basis = (_base_visual_basis * spin_basis).orthonormalized()

func _compute_orbit_normal() -> Vector3:
	var inclination: float = float(orbit_state.get("inclination_rad", 0.0))
	var ascending_node_longitude: float = float(orbit_state.get("longitude_of_ascending_node_rad", 0.0))
	var ascending_node_axis := Vector3(cos(ascending_node_longitude), 0.0, sin(ascending_node_longitude))
	if ascending_node_axis.length_squared() <= AXIS_EPSILON:
		ascending_node_axis = Vector3.RIGHT

	return (Basis(ascending_node_axis.normalized(), inclination) * DEFAULT_ORBIT_NORMAL).normalized()

func _compute_rotation_axis(orbit_normal: Vector3) -> Vector3:
	var tilt: float = float(rotation_state.get("axial_tilt_to_orbit_rad", 0.0))
	if is_zero_approx(tilt):
		return orbit_normal

	var periapsis_direction := _compute_periapsis_direction(orbit_normal)
	var tilt_axis := orbit_normal.cross(periapsis_direction).normalized()
	if tilt_axis.length_squared() <= AXIS_EPSILON:
		tilt_axis = orbit_normal.cross(DEFAULT_PRIME_MERIDIAN_DIRECTION).normalized()
	if tilt_axis.length_squared() <= AXIS_EPSILON:
		return orbit_normal

	return (Basis(tilt_axis, tilt) * orbit_normal).normalized()

func _compute_prime_meridian_direction(rotation_axis: Vector3, orbit_normal: Vector3) -> Vector3:
	var periapsis_direction := _compute_periapsis_direction(orbit_normal)
	var projected_direction := periapsis_direction - (rotation_axis * periapsis_direction.dot(rotation_axis))
	if projected_direction.length_squared() <= AXIS_EPSILON:
		projected_direction = DEFAULT_PRIME_MERIDIAN_DIRECTION - (rotation_axis * DEFAULT_PRIME_MERIDIAN_DIRECTION.dot(rotation_axis))
	if projected_direction.length_squared() <= AXIS_EPSILON:
		projected_direction = Vector3.RIGHT - (rotation_axis * Vector3.RIGHT.dot(rotation_axis))

	return projected_direction.normalized()

func _compute_periapsis_direction(orbit_normal: Vector3) -> Vector3:
	var ascending_node_longitude: float = float(orbit_state.get("longitude_of_ascending_node_rad", 0.0))
	var argument_of_periapsis: float = float(orbit_state.get("argument_of_periapsis_rad", 0.0))
	var ascending_node_direction := Vector3(cos(ascending_node_longitude), 0.0, sin(ascending_node_longitude))
	if ascending_node_direction.length_squared() <= AXIS_EPSILON:
		ascending_node_direction = Vector3.RIGHT

	var periapsis_direction := Basis(orbit_normal, argument_of_periapsis) * ascending_node_direction.normalized()
	if periapsis_direction.length_squared() <= AXIS_EPSILON:
		return DEFAULT_PRIME_MERIDIAN_DIRECTION
	return periapsis_direction.normalized()
