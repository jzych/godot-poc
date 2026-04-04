extends Node3D
class_name CosmosCameraRig

const FOCUS_LOCK_DISTANCE_RADIUS_MULTIPLIER := 3.0

@export var rotation_sensitivity := 0.2
@export var pitch_min_deg := -80.0
@export var pitch_max_deg := 80.0
@export var min_distance := 0.5
@export var max_distance := 20000.0
@export var zoom_step_ratio := 0.15
@export var zoom_smoothing_speed := 8.0
@export var pan_speed_base := 6.0
@export var pan_speed_distance_factor := 2.0
@export var pan_drag_threshold := 6.0
@export var focus_lock_smoothing_speed := 8.0
@export var focus_lock_snap_distance := 0.01
@export var distance_snap_threshold := 0.01

var focus_position: Vector3 = Vector3.ZERO
@export var pan_plane_height := 0.0
var yaw_degrees_value: float = 0.0
var pitch_degrees_value: float = -35.0
var current_distance: float = 3.6055513
var target_distance: float = 3.6055513
var focus_lock_target_position: Vector3 = Vector3.ZERO
var _focus_lock_transition_offset: Vector3 = Vector3.ZERO

var _rotate_active: bool = false
var _pan_active: bool = false
var _pan_pressed: bool = false
var _focus_lock_active: bool = false
var _focus_lock_transition_active: bool = false
var _pan_press_position: Vector2 = Vector2.ZERO

@onready var yaw_pivot: Node3D = $YawPivot
@onready var pitch_pivot: Node3D = $YawPivot/PitchPivot
@onready var camera: Camera3D = $YawPivot/PitchPivot/Camera3D

func _ready():
	_ensure_input_actions()
	current_distance = clamp(current_distance, min_distance, max_distance)
	target_distance = clamp(target_distance, min_distance, max_distance)
	_apply_state()

func _process(delta):
	var needs_apply: bool = false
	var focus_snap_squared: float = pow(focus_lock_snap_distance, 2)
	var distance_offset: float = absf(current_distance - target_distance)
	var focus_transition_settled: bool = true
	var distance_transition_settled: bool = true

	if _focus_lock_active:
		if _focus_lock_transition_active:
			if _focus_lock_transition_offset.length_squared() <= focus_snap_squared:
				_focus_lock_transition_offset = Vector3.ZERO
			else:
				var focus_weight: float = clamp(delta * focus_lock_smoothing_speed, 0.0, 1.0)
				_focus_lock_transition_offset = _focus_lock_transition_offset.lerp(Vector3.ZERO, focus_weight)
				if _focus_lock_transition_offset.length_squared() <= focus_snap_squared:
					_focus_lock_transition_offset = Vector3.ZERO
				else:
					focus_transition_settled = false

			var transition_focus_position: Vector3 = focus_lock_target_position + _focus_lock_transition_offset
			if not focus_position.is_equal_approx(transition_focus_position):
				focus_position = transition_focus_position
				needs_apply = true
		elif not focus_position.is_equal_approx(focus_lock_target_position):
			focus_position = focus_lock_target_position
			needs_apply = true

		pan_plane_height = focus_position.y

	if distance_offset <= distance_snap_threshold:
		current_distance = target_distance
	else:
		var weight: float = clamp(delta * zoom_smoothing_speed, 0.0, 1.0)
		current_distance = lerpf(current_distance, target_distance, weight)
		if absf(current_distance - target_distance) <= distance_snap_threshold:
			current_distance = target_distance
		else:
			distance_transition_settled = false
		needs_apply = true

	if _focus_lock_transition_active and focus_transition_settled and distance_transition_settled:
		_focus_lock_transition_offset = Vector3.ZERO
		focus_position = focus_lock_target_position
		pan_plane_height = focus_position.y
		_focus_lock_transition_active = false
		needs_apply = true

	var keyboard_pan: Vector2 = _get_keyboard_pan_input()
	if keyboard_pan.length_squared() > 0.0:
		apply_keyboard_pan(keyboard_pan, delta)
		return

	if needs_apply:
		_apply_state()

func _unhandled_input(event):
	var handled: bool = false

	if event is InputEventMouseButton:
		if event.is_action_pressed(&"camera_zoom_in"):
			apply_zoom_step(-1.0)
			handled = true
		elif event.is_action_pressed(&"camera_zoom_out"):
			apply_zoom_step(1.0)
			handled = true
		elif event.is_action_pressed(&"camera_pan_hold"):
			_pan_pressed = true
			_pan_active = false
			_pan_press_position = event.position
		elif event.is_action_released(&"camera_pan_hold"):
			_pan_pressed = false
			_pan_active = false
			_pan_press_position = Vector2.ZERO
		elif event.is_action_pressed(&"camera_rotate_hold"):
			_rotate_active = true
			handled = true
		elif event.is_action_released(&"camera_rotate_hold"):
			_rotate_active = false
			handled = true
	elif event is InputEventMouseMotion:
		if _rotate_active:
			apply_rotate_motion(event.relative)
			handled = true
		elif _pan_pressed:
			if not _pan_active and event.position.distance_to(_pan_press_position) >= pan_drag_threshold:
				cancel_focus_lock()
				_pan_active = true
			if _pan_active:
				apply_drag_pan(event.relative)
				handled = true

	if handled:
		get_viewport().set_input_as_handled()

func configure_from_offset(new_focus_position: Vector3, offset: Vector3):
	var safe_offset: Vector3 = offset
	if safe_offset.length_squared() <= 0.0001:
		safe_offset = Vector3(0.0, 0.0, 1.0)

	focus_position = new_focus_position
	pan_plane_height = new_focus_position.y
	current_distance = clamp(safe_offset.length(), min_distance, max_distance)
	target_distance = current_distance
	_focus_lock_transition_offset = Vector3.ZERO

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

func apply_zoom_step(direction: float):
	if is_zero_approx(direction):
		return

	var zoom_factor: float = pow(1.0 + zoom_step_ratio, direction)
	target_distance = clamp(target_distance * zoom_factor, min_distance, max_distance)

func apply_keyboard_pan(input_vector: Vector2, delta: float):
	if delta <= 0.0 or input_vector.length_squared() <= 0.0:
		return

	cancel_focus_lock()

	var pan_vector: Vector2 = input_vector
	if pan_vector.length() > 1.0:
		pan_vector = pan_vector.normalized()

	var translation: Vector3 = (_get_pan_right() * pan_vector.x) + (_get_pan_forward() * pan_vector.y)
	if translation.length_squared() <= 0.0:
		return

	_translate_focus_on_pan_plane(translation.normalized() * _get_pan_speed() * delta)

func apply_drag_pan(relative: Vector2):
	if relative.length_squared() <= 0.0:
		return

	cancel_focus_lock()

	var translation: Vector3 = (-_get_pan_right() * relative.x) + (_get_pan_forward() * relative.y)
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var reference_extent: float = max(min(viewport_size.x, viewport_size.y), 1.0)
	var world_units_per_pixel: float = _get_pan_speed() / reference_extent

	_translate_focus_on_pan_plane(translation * world_units_per_pixel)
	
func _translate_focus_on_pan_plane(translation: Vector3):
	if translation.length_squared() <= 0.0:
		return

	focus_position += translation
	focus_position.y = pan_plane_height
	_apply_state()

func start_focus_lock(target_focus_position: Vector3, body_radius: float):
	_focus_lock_active = true
	focus_lock_target_position = target_focus_position
	target_distance = get_focus_lock_distance_for_radius(body_radius)
	_focus_lock_transition_offset = focus_position - target_focus_position
	_focus_lock_transition_active = (
		_focus_lock_transition_offset.length_squared() > pow(focus_lock_snap_distance, 2)
		or absf(current_distance - target_distance) > distance_snap_threshold
	)
	if not _focus_lock_transition_active:
		_focus_lock_transition_offset = Vector3.ZERO
		focus_position = focus_lock_target_position
	pan_plane_height = focus_position.y

func update_focus_lock_target(target_focus_position: Vector3):
	if not _focus_lock_active:
		return

	focus_lock_target_position = target_focus_position
	if _focus_lock_transition_active:
		focus_position = focus_lock_target_position + _focus_lock_transition_offset
	else:
		focus_position = focus_lock_target_position
	pan_plane_height = focus_position.y
	_apply_state()

func cancel_focus_lock():
	_focus_lock_active = false
	_focus_lock_transition_active = false
	_focus_lock_transition_offset = Vector3.ZERO

func is_focus_lock_active() -> bool:
	return _focus_lock_active

func get_focus_lock_distance_for_radius(body_radius: float) -> float:
	return clamp(
		max(body_radius * FOCUS_LOCK_DISTANCE_RADIUS_MULTIPLIER, min_distance),
		min_distance,
		max_distance
	)

func _apply_state():
	if not is_node_ready():
		return

	position = focus_position
	yaw_pivot.rotation_degrees = Vector3(0.0, yaw_degrees_value, 0.0)
	pitch_pivot.rotation_degrees = Vector3(pitch_degrees_value, 0.0, 0.0)
	camera.position = Vector3(0.0, 0.0, current_distance)

func _ensure_input_actions():
	_ensure_action(&"camera_rotate_hold", [_make_mouse_button_event(2)])
	_ensure_action(&"camera_pan_hold", [_make_mouse_button_event(1)])
	_ensure_action(&"camera_zoom_in", [_make_mouse_button_event(4)])
	_ensure_action(&"camera_zoom_out", [_make_mouse_button_event(5)])
	_ensure_action(&"camera_forward", [_make_key_event(KEY_W)])
	_ensure_action(&"camera_back", [_make_key_event(KEY_S)])
	_ensure_action(&"camera_left", [_make_key_event(KEY_A)])
	_ensure_action(&"camera_right", [_make_key_event(KEY_D)])

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

func _make_key_event(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	return event

func _get_keyboard_pan_input() -> Vector2:
	return Vector2(
		Input.get_action_strength(&"camera_right") - Input.get_action_strength(&"camera_left"),
		Input.get_action_strength(&"camera_forward") - Input.get_action_strength(&"camera_back")
	)

func _get_pan_forward() -> Vector3:
	var yaw_basis: Basis = Basis(Vector3.UP, deg_to_rad(yaw_degrees_value))
	var forward: Vector3 = -yaw_basis.z
	forward.y = 0.0
	return forward.normalized()

func _get_pan_right() -> Vector3:
	var yaw_basis: Basis = Basis(Vector3.UP, deg_to_rad(yaw_degrees_value))
	var right: Vector3 = yaw_basis.x
	right.y = 0.0
	return right.normalized()

func _get_pan_speed() -> float:
	return pan_speed_base + (current_distance * pan_speed_distance_factor)
