extends Node3D

var bridge: SolarSystemBridge
var body_nodes: Array[MeshInstance3D] = []

func _ready():
	bridge = SolarSystemBridge.new()
	add_child(bridge)
	await get_tree().process_frame
	_spawn_bodies()
	_setup_camera()

func _spawn_bodies():
	for i in range(bridge.get_body_count()):
		var state = bridge.get_body_state(i)
		var mesh_instance = MeshInstance3D.new()
		var sphere = SphereMesh.new()

		match state["name"]:
			"Sun":
				sphere.radius = 1.5
				sphere.height = 3.0
			"Earth":
				sphere.radius = 0.5
				sphere.height = 1.0
			"Moon":
				sphere.radius = 0.2
				sphere.height = 0.4

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

func _setup_camera():
	var camera = Camera3D.new()
	camera.position = Vector3(0, 30, 30)
	camera.look_at(Vector3.ZERO)
	add_child(camera)
