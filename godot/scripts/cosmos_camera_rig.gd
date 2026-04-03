extends Node3D
class_name CosmosCameraRig

@export var rotation_sensitivity := 0.2
@export var pitch_min_deg := -80.0
@export var pitch_max_deg := 80.0

var focus_position: Vector3 = Vector3.ZERO
var pan_plane_height: float = 0.0
var yaw_degrees_value: float = 0.0
var pitch_degrees_value: float = -35.0
var current_distance: float = 3.6055513

var _rotate_active: bool = false

@onready var yaw_pivot: Node3D = $YawPivot
@onready var pitch_pivot: Node3D = $YawPivot/PitchPivot
@onready var camera: Camera3D = $YawPivot/PitchPivot/Camera3D

func _ready():
	_ensure_input_actions()
	_apply_state()

func _unhandled_input(event):
	var handled: bool = false

	if event is InputEventMouseButton:
		if event.is_action_pressed(&"camera_rotate_hold"):
			_rotate_active = true
			handled = true
		elif event.is_action_released(&"camera_rotate_hold"):
			_rotate_active = false
			handled = true
	elif event is InputEventMouseMotion and _rotate_active:
		apply_rotate_motion(event.relative)
		handled = true

	if handled:
		get_viewport().set_input_as_handled()

func configure_from_offset(new_focus_position: Vector3, offset: Vector3):
	var safe_offset: Vector3 = offset
	if safe_offset.length_squared() <= 0.0001:
		safe_offset = Vector3(0.0, 0.0, 1.0)

	focus_position = new_focus_position
	pan_plane_height = new_focus_position.y
	current_distance = max(safe_offset.length(), 0.01)

	var horizontal_length: float = Vector2(safe_offset.x, safe_offset.z).length()
	yaw_degrees_value = rad_to_deg(atan2(safe_offset.x, safe_offset.z))
	pitch_degrees_value = clamp(
		rad_to_deg(atan2(-safe_offset.y, horizontal_length)),
		pitch_min_deg,
		pitch_max_deg
	)

	_apply_state()

func get_camera_node() -> Camera3D:
	return camera

func apply_rotate_motion(relative: Vector2):
	yaw_degrees_value += relative.x * rotation_sensitivity
	pitch_degrees_value = clamp(
		pitch_degrees_value + relative.y * rotation_sensitivity,
		pitch_min_deg,
		pitch_max_deg
	)
	_apply_state()

func _apply_state():
	if not is_node_ready():
		return

	position = focus_position
	yaw_pivot.rotation_degrees = Vector3(0.0, yaw_degrees_value, 0.0)
	pitch_pivot.rotation_degrees = Vector3(pitch_degrees_value, 0.0, 0.0)
	camera.position = Vector3(0.0, 0.0, current_distance)

func _ensure_input_actions():
	_ensure_action(&"camera_rotate_hold", [_make_mouse_button_event(2)])

func _ensure_action(action_name: StringName, events: Array):
	if InputMap.has_action(action_name):
		return

	InputMap.add_action(action_name, 0.5)
	for event in events:
		InputMap.action_add_event(action_name, event)

func _make_mouse_button_event(button_index: int) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button_index
	return event
