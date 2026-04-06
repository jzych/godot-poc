extends CanvasLayer
class_name OrbitMarkerOverlay

const OrbitMathScript := preload("res://scripts/orbit_math.gd")
const MARKER_SCRIPT := preload("res://scripts/orbit_marker_control.gd")
const LABEL_SCRIPT := preload("res://scripts/body_highlight_label.gd")
const APPEARANCE_SCRIPT := preload("res://scripts/body_label_appearance.gd")
const PERIAPSIS_KIND := "periapsis"
const APOAPSIS_KIND := "apoapsis"
const MARKER_LABEL_OFFSET := Vector2(12.0, 12.0)
const MARKER_COLOR := Color(0.78, 0.84, 0.92, 0.95)

var label_appearance = null
var _markers_by_kind := {}
var _marker_state_by_kind := {}
var _active_marker_kind: String = ""
var _pressed_marker_kind: String = ""
var _pressed_label_hit: bool = false
var _selected_body_index: int = -1

@onready var marker_root: Control = $MarkerRoot
@onready var label_root: Control = $LabelRoot

func _ready():
	marker_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	marker_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	label_root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if label_appearance == null:
		label_appearance = _build_default_appearance()

func update_markers(
	camera: Camera3D,
	selected_body_view,
	orbit_center: Vector3,
	sim_time_seconds: float,
	bridge
):
	if camera == null or selected_body_view == null or bridge == null:
		_hide_all_markers()
		return

	var orbit: Dictionary = selected_body_view.orbit_state
	var orbital_period_seconds: float = float(selected_body_view.rotation_state.get("orbital_period_seconds", 0.0))
	if int(orbit.get("central_body_index", -1)) < 0 or orbital_period_seconds <= 0.0:
		_hide_all_markers()
		return

	if _selected_body_index != selected_body_view.body_index:
		_active_marker_kind = ""
		_pressed_marker_kind = ""

	_selected_body_index = selected_body_view.body_index
	_marker_state_by_kind.clear()

	var marker_states := {
		PERIAPSIS_KIND: {
			"title": "Periapsis",
			"distance_km": OrbitMathScript.periapsis_distance_km(orbit),
			"eta_seconds": OrbitMathScript.time_until_mean_anomaly(
				orbit,
				orbital_period_seconds,
				sim_time_seconds,
				0.0
			),
			"world_position": orbit_center + OrbitMathScript.periapsis_relative_position_units(orbit),
		},
		APOAPSIS_KIND: {
			"title": "Apoapsis",
			"distance_km": OrbitMathScript.apoapsis_distance_km(orbit),
			"eta_seconds": OrbitMathScript.time_until_mean_anomaly(
				orbit,
				orbital_period_seconds,
				sim_time_seconds,
				PI
			),
			"world_position": orbit_center + OrbitMathScript.apoapsis_relative_position_units(orbit),
		},
	}

	for marker_kind in marker_states.keys():
		var marker = _get_or_create_marker(marker_kind)
		var marker_state: Dictionary = marker_states[marker_kind]
		var layout: Dictionary = _compute_marker_layout(camera, marker_state["world_position"], marker.size)
		marker.visible = layout.get("visible", false)
		if marker.visible:
			marker.place_tip_at(layout["tip_position"])
			marker_state["screen_tip_position"] = layout["tip_position"]
			_marker_state_by_kind[marker_kind] = marker_state

	if not _marker_state_by_kind.has(_active_marker_kind):
		_active_marker_kind = ""
		_pressed_marker_kind = ""

	_sync_label(bridge)

func handle_input(event: InputEvent) -> bool:
	if not (event is InputEventMouseButton) or event.button_index != MOUSE_BUTTON_LEFT:
		return false

	if event.pressed:
		if _is_label_hit(event.position):
			_pressed_label_hit = true
			return true

		var marker_kind: String = _find_marker_kind_at_position(event.position)
		if marker_kind.is_empty():
			return false
		_pressed_marker_kind = marker_kind
		_active_marker_kind = marker_kind
		return true

	if _pressed_label_hit:
		_pressed_label_hit = false
		return true

	if _pressed_marker_kind.is_empty():
		return false

	_pressed_marker_kind = ""
	return true

func get_visible_marker_count() -> int:
	var visible_count := 0
	for marker in _markers_by_kind.values():
		if marker.visible:
			visible_count += 1
	return visible_count

func get_marker_for_kind(marker_kind: String):
	return _markers_by_kind.get(marker_kind)

func get_marker_label():
	return label_root.get_child(0) if label_root.get_child_count() > 0 else null

func get_active_marker_kind() -> String:
	return _active_marker_kind

func _get_or_create_marker(marker_kind: String):
	if _markers_by_kind.has(marker_kind):
		return _markers_by_kind[marker_kind]

	var marker = MARKER_SCRIPT.new()
	marker.configure(MARKER_COLOR)
	marker_root.add_child(marker)
	_markers_by_kind[marker_kind] = marker
	return marker

func _get_or_create_label():
	if label_root.get_child_count() > 0:
		return label_root.get_child(0)

	var label = LABEL_SCRIPT.new()
	label_root.add_child(label)
	return label

func _compute_marker_layout(camera: Camera3D, world_position: Vector3, marker_size: Vector2) -> Dictionary:
	if _is_world_position_behind_camera(camera, world_position):
		return {"visible": false}

	var tip_position: Vector2 = camera.unproject_position(world_position)
	var viewport_rect: Rect2 = get_viewport().get_visible_rect()
	var marker_rect := Rect2(
		tip_position - Vector2(marker_size.x * 0.5, marker_size.y),
		marker_size
	)
	if not viewport_rect.intersects(marker_rect):
		return {"visible": false}

	return {
		"visible": true,
		"tip_position": tip_position,
	}

func _find_marker_kind_at_position(screen_position: Vector2) -> String:
	for marker_kind in _markers_by_kind.keys():
		var marker = _markers_by_kind[marker_kind]
		if marker.visible and Rect2(marker.position, marker.size).has_point(screen_position):
			return marker_kind
	return ""

func _is_label_hit(screen_position: Vector2) -> bool:
	var label = get_marker_label()
	if label == null or not label.visible:
		return false

	return Rect2(label.position, label.size).has_point(screen_position)

func _sync_label(bridge):
	var label = _get_or_create_label()
	if _active_marker_kind.is_empty() or not _marker_state_by_kind.has(_active_marker_kind):
		label.visible = false
		return

	var marker_state: Dictionary = _marker_state_by_kind[_active_marker_kind]
	label.configure(
		label_appearance,
		marker_state["title"],
		"Distance: %s | T-%s" % [
			_format_distance_km(marker_state["distance_km"]),
			bridge.format_duration_ydhms(marker_state["eta_seconds"]),
		]
	)
	label.position = marker_state["screen_tip_position"] + MARKER_LABEL_OFFSET
	label.visible = true

func _hide_all_markers():
	_selected_body_index = -1
	_active_marker_kind = ""
	_pressed_marker_kind = ""
	_pressed_label_hit = false
	_marker_state_by_kind.clear()
	for marker in _markers_by_kind.values():
		marker.visible = false
	var label = get_marker_label()
	if label != null:
		label.visible = false

func _is_world_position_behind_camera(camera: Camera3D, world_position: Vector3) -> bool:
	return camera.to_local(world_position).z >= 0.0

func _format_distance_km(distance_km: float) -> String:
	return "%.0f km" % distance_km

func _build_default_appearance():
	var appearance = APPEARANCE_SCRIPT.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray([
		"Arial",
		"Liberation Sans",
		"Noto Sans",
		"DejaVu Sans",
	])

	appearance.font = font
	appearance.font_size = 18
	appearance.secondary_font_size = 16
	appearance.text_color = Color(0.7, 0.85, 1.0, 1.0)
	appearance.background_color = Color(0.0, 0.0, 0.0, 0.55)
	return appearance
