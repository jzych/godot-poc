extends Node3D

const KM_PER_AU := 149597870.7
const AU_TO_UNITS := 10000.0
const KM_TO_UNITS := AU_TO_UNITS / KM_PER_AU

# Real radii in km
const BODY_RADII := {
	"Sun": 696000.0,
	"Earth": 6371.0,
	"Moon": 1737.0,
}

var bridge: SolarSystemBridge
var body_nodes: Array[MeshInstance3D] = []
var camera: Camera3D
var camera_offset: Vector3

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
		var mesh_instance = MeshInstance3D.new()
		var sphere = SphereMesh.new()

		var radius_units: float = BODY_RADII.get(state["name"], 1000.0) * KM_TO_UNITS
		sphere.radius = radius_units
		sphere.height = radius_units * 2.0

		mesh_instance.mesh = sphere

		var mat = StandardMaterial3D.new()
		mat.albedo_color = state["color"]
		mat.emission_enabled = true
		mat.emission = state["color"]
		mat.emission_energy_multiplier = 0.5
		mesh_instance.material_override = mat

		mesh_instance.name = state["name"]
		add_child(mesh_instance)
		body_nodes.append(mesh_instance)

func _process(_delta):
	for i in range(body_nodes.size()):
		var state = bridge.get_body_state(i)
		body_nodes[i].position = state["position"]
	var earth_pos: Vector3 = bridge.get_body_state(1)["position"]
	camera.position = earth_pos + camera_offset
	camera.look_at(earth_pos)

func _setup_light():
	var light = DirectionalLight3D.new()
	light.light_energy = 3.0
	light.light_color = Color(1.0, 0.95, 0.8)
	light.rotation_degrees = Vector3(-30, -30, 0)
	add_child(light)

func _setup_camera():
	var earth_pos: Vector3 = bridge.get_body_state(1)["position"]
	var outward = earth_pos.normalized()
	camera_offset = outward * 3.0 + Vector3(0, 2.0, 0)

	camera = Camera3D.new()
	camera.far = 25000.0
	camera.position = earth_pos + camera_offset
	add_child(camera)
	camera.look_at(earth_pos)
