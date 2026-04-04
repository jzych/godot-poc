extends CanvasLayer
class_name BodyLabelOverlay

const LABEL_SCRIPT := preload("res://scripts/body_highlight_label.gd")
const APPEARANCE_SCRIPT := preload("res://scripts/body_label_appearance.gd")
const LABEL_OFFSET_MULTIPLIER := 1.2
const LABEL_OFFSET_DIRECTION := Vector2(0.70710678, 0.70710678)

var label_appearance = null
var _labels_by_body_index := {}

@onready var label_root: Control = $LabelRoot

func _ready():
	label_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	label_root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if label_appearance == null:
		label_appearance = _build_default_appearance()

func update_labels(camera: Camera3D, hovered_body_view, selected_body_view):
	if camera == null:
		_hide_all_labels()
		return

	var target_body_views: Array = []
	if hovered_body_view != null:
		target_body_views.append(hovered_body_view)
	if selected_body_view != null and selected_body_view != hovered_body_view:
		target_body_views.append(selected_body_view)

	var active_body_indexes := {}
	for body_view in target_body_views:
		active_body_indexes[body_view.body_index] = true
		var label = _get_or_create_label(body_view)
		label.configure(
			label_appearance,
			body_view.body_label,
			body_view.body_secondary_label
		)
		var layout: Dictionary = _compute_label_layout(camera, body_view)
		label.visible = layout.get("visible", false)
		if label.visible:
			label.position = layout["position"]

	for body_index in _labels_by_body_index.keys():
		if not active_body_indexes.has(body_index):
			_labels_by_body_index[body_index].visible = false

func get_visible_label_count() -> int:
	var visible_count := 0
	for label in _labels_by_body_index.values():
		if label.visible:
			visible_count += 1
	return visible_count

func get_label_for_body_index(body_index: int):
	return _labels_by_body_index.get(body_index)

func get_projected_radius_for_body(camera: Camera3D, body_view) -> float:
	var body_position: Vector3 = body_view.global_position
	if _is_body_behind_camera(camera, body_position):
		return 0.0

	var center: Vector2 = camera.unproject_position(body_position)
	var edge_right: Vector2 = camera.unproject_position(
		body_position + (camera.global_basis.x * body_view.body_radius)
	)
	var edge_up: Vector2 = camera.unproject_position(
		body_position + (camera.global_basis.y * body_view.body_radius)
	)

	return max(center.distance_to(edge_right), center.distance_to(edge_up))

func _get_or_create_label(body_view):
	if _labels_by_body_index.has(body_view.body_index):
		return _labels_by_body_index[body_view.body_index]

	var label = LABEL_SCRIPT.new()
	label_root.add_child(label)
	_labels_by_body_index[body_view.body_index] = label
	return label

func _compute_label_layout(camera: Camera3D, body_view) -> Dictionary:
	var body_position: Vector3 = body_view.global_position
	var viewport_rect: Rect2 = get_viewport().get_visible_rect()
	if _is_body_behind_camera(camera, body_position):
		return {"visible": false}

	var projected_center: Vector2 = camera.unproject_position(body_position)
	# For now labels hide once the projected center leaves the viewport. Bodies
	# that are only partially on-screen near the edge will be handled later.
	if not viewport_rect.has_point(projected_center):
		return {"visible": false}

	var projected_radius: float = get_projected_radius_for_body(camera, body_view)
	return {
		"visible": true,
		"position": projected_center + (LABEL_OFFSET_DIRECTION * projected_radius * LABEL_OFFSET_MULTIPLIER),
	}

func _hide_all_labels():
	for label in _labels_by_body_index.values():
		label.visible = false

func _is_body_behind_camera(camera: Camera3D, body_position: Vector3) -> bool:
	return camera.to_local(body_position).z >= 0.0

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
