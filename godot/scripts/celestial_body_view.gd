extends Node3D
class_name CelestialBodyView

const BODY_OUTLINE_SHADER := preload("res://shaders/body_outline.gdshader")

const BODY_COLLISION_LAYER := 1
const MIN_OUTLINE_WIDTH := 0.01
const OUTLINE_WIDTH_RATIO := 0.05
const DEFAULT_HIGHLIGHT_COLOR := Color.WHITE

var body_index: int = -1
var body_label: String = ""
var body_secondary_label: String = ""
var body_radius: float = 1.0
var orbit_state: Dictionary = {}
var rotation_state: Dictionary = {}

var _body_mesh_resource: Mesh = null
var _base_color: Color = Color.WHITE
var _outline_material: ShaderMaterial = null
var _base_material: StandardMaterial3D = null
var _highlight_visible: bool = false
var _highlight_color: Color = DEFAULT_HIGHLIGHT_COLOR

@onready var body_mesh: MeshInstance3D = $BodyMesh
@onready var outline_mesh: MeshInstance3D = $OutlineMesh
@onready var hit_body: StaticBody3D = $HitBody
@onready var collision_shape: CollisionShape3D = $HitBody/CollisionShape3D

func _ready():
	_refresh_visuals()

func configure(index: int, state: Dictionary, radius_units: float):
	body_index = index
	body_label = str(state.get("name", "Body"))
	body_secondary_label = _build_secondary_label(state)
	body_radius = radius_units
	orbit_state = state.get("orbit", {})
	rotation_state = state.get("rotation", {})
	_body_mesh_resource = _build_sphere_mesh(radius_units)
	_base_color = state.get("color", Color.WHITE)
	name = body_label
	_refresh_visuals()

func is_highlight_visible() -> bool:
	return _highlight_visible

func get_highlight_color() -> Color:
	return _highlight_color

func set_highlight(visible: bool, color: Color = DEFAULT_HIGHLIGHT_COLOR):
	_highlight_visible = visible
	_highlight_color = color
	_apply_highlight_state()

func _refresh_visuals():
	if not is_node_ready() or _body_mesh_resource == null:
		return

	body_mesh.mesh = _body_mesh_resource
	outline_mesh.mesh = _body_mesh_resource
	outline_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	if _base_material == null:
		_base_material = StandardMaterial3D.new()
		_base_material.emission_enabled = true
		_base_material.emission_energy_multiplier = 0.5

	_base_material.albedo_color = _base_color
	_base_material.emission = _base_color
	body_mesh.material_override = _base_material

	if _outline_material == null:
		_outline_material = ShaderMaterial.new()
		_outline_material.shader = BODY_OUTLINE_SHADER

	_outline_material.set_shader_parameter(
		"outline_width",
		max(body_radius * OUTLINE_WIDTH_RATIO, MIN_OUTLINE_WIDTH)
	)
	outline_mesh.material_override = _outline_material
	_apply_highlight_state()

	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = body_radius
	collision_shape.shape = sphere_shape

	hit_body.collision_layer = BODY_COLLISION_LAYER
	hit_body.collision_mask = 0
	hit_body.input_ray_pickable = true
	hit_body.set_meta("body_view", self)

func _build_sphere_mesh(radius_units: float) -> SphereMesh:
	var sphere := SphereMesh.new()
	sphere.radius = radius_units
	sphere.height = radius_units * 2.0
	return sphere

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
