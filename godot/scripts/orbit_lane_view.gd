extends MeshInstance3D
class_name OrbitLaneView

const OrbitMathScript := preload("res://scripts/orbit_math.gd")

const DEFAULT_SAMPLE_COUNT := 128
const UNSELECTED_FADE_START := Color(0.22, 0.22, 0.24, 0.52)
const UNSELECTED_FADE_END := Color(0.16, 0.16, 0.16, 0.30)
const SELECTED_FADE_START := Color(0.58, 0.58, 0.62, 1.0)
const SELECTED_FADE_END := Color(0.24, 0.24, 0.27, 1.0)

var body_index: int = -1
var central_body_index: int = -1
var orbital_period_seconds: float = 0.0
var orbit_state: Dictionary = {}
var sample_count: int = DEFAULT_SAMPLE_COUNT

var _material: StandardMaterial3D = null
var _sample_positions := PackedVector3Array()
var _sample_colors := PackedColorArray()
var _selected: bool = false

func _ready():
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_material.vertex_color_use_as_albedo = true
		_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_material.albedo_color = Color.WHITE
	material_override = _material

func configure(index: int, state: Dictionary, sim_time_seconds: float):
	body_index = index
	orbit_state = state.get("orbit", {})
	orbital_period_seconds = float(state.get("orbital_period_seconds", 0.0))
	central_body_index = int(orbit_state.get("central_body_index", -1))
	sample_count = OrbitMathScript.recommended_sample_count(orbit_state)
	_refresh_sample_positions(sim_time_seconds)
	_rebuild_mesh()

func set_selected(selected: bool):
	if _selected == selected and mesh != null:
		return

	_selected = selected
	_rebuild_mesh()

func update_center_position(center_position: Vector3):
	position = center_position

func update_simulation_phase(sim_time_seconds: float):
	_refresh_sample_positions(sim_time_seconds)
	_rebuild_mesh()

func get_sample_positions() -> PackedVector3Array:
	return _sample_positions

func get_sample_colors() -> PackedColorArray:
	return _sample_colors

func is_selected_lane() -> bool:
	return _selected

func _rebuild_mesh():
	if _sample_positions.is_empty():
		mesh = null
		return

	_sample_colors = _build_sample_colors()

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _sample_positions
	arrays[Mesh.ARRAY_COLOR] = _sample_colors

	var orbit_mesh: ArrayMesh = ArrayMesh.new()
	orbit_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINE_STRIP, arrays)
	mesh = orbit_mesh

func _build_sample_colors() -> PackedColorArray:
	var colors: PackedColorArray = PackedColorArray()
	colors.resize(_sample_positions.size())

	var fade_start: Color = SELECTED_FADE_START if _selected else UNSELECTED_FADE_START
	var fade_end: Color = SELECTED_FADE_END if _selected else UNSELECTED_FADE_END
	var last_index: int = max(_sample_positions.size() - 1, 1)

	for sample_index in range(_sample_positions.size()):
		var t: float = float(sample_index) / float(last_index)
		colors[sample_index] = fade_start.lerp(fade_end, t)

	return colors

func _refresh_sample_positions(sim_time_seconds: float):
	_sample_positions = OrbitMathScript.sample_relative_positions_units(
		orbit_state,
		orbital_period_seconds,
		sample_count,
		sim_time_seconds
	)
