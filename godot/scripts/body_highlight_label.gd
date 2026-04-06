extends Control
class_name BodyHighlightLabel

const HORIZONTAL_PADDING := 10.0
const VERTICAL_PADDING := 6.0
const LINE_SPACING := 2
const APPEARANCE_SCRIPT := preload("res://scripts/body_label_appearance.gd")

var _content: VBoxContainer = null
var _primary_label: Label = null
var _secondary_label: Label = null
var _primary_label_settings: LabelSettings = null
var _secondary_label_settings: LabelSettings = null
var _appearance = null
var _background_color := Color(0.0, 0.0, 0.0, 0.55)
var _primary_text := ""
var _secondary_text := ""

func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _content == null:
		_content = VBoxContainer.new()
		_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_content.add_theme_constant_override("separation", LINE_SPACING)
		add_child(_content)

	if _primary_label == null:
		_primary_label = Label.new()
		_primary_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_content.add_child(_primary_label)

	if _secondary_label == null:
		_secondary_label = Label.new()
		_secondary_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_content.add_child(_secondary_label)

	if _primary_label_settings == null:
		_primary_label_settings = LabelSettings.new()
	if _secondary_label_settings == null:
		_secondary_label_settings = LabelSettings.new()

	_primary_label.label_settings = _primary_label_settings
	_secondary_label.label_settings = _secondary_label_settings
	_refresh()

func configure(appearance, primary_text: String, secondary_text: String = ""):
	_appearance = appearance
	_primary_text = primary_text
	_secondary_text = secondary_text
	_refresh()

func get_label_size() -> Vector2:
	return size

func get_label_text() -> String:
	return _primary_text

func get_secondary_text() -> String:
	return _secondary_text

func _refresh():
	if not is_node_ready() or _appearance == null:
		return

	_primary_label.text = _primary_text
	_primary_label_settings.font = _appearance.font
	_primary_label_settings.font_size = _appearance.font_size
	_primary_label_settings.font_color = _appearance.text_color

	_secondary_label.text = _secondary_text
	_secondary_label.visible = not _secondary_text.is_empty()
	_secondary_label_settings.font = _appearance.font
	_secondary_label_settings.font_size = _appearance.secondary_font_size
	_secondary_label_settings.font_color = _appearance.text_color
	_background_color = _appearance.background_color

	var content_size: Vector2 = _content.get_combined_minimum_size()
	size = Vector2(
		ceil(content_size.x + (HORIZONTAL_PADDING * 2.0)),
		ceil(content_size.y + (VERTICAL_PADDING * 2.0))
	)
	_content.position = Vector2(HORIZONTAL_PADDING, VERTICAL_PADDING)
	_content.size = size - Vector2(HORIZONTAL_PADDING * 2.0, VERTICAL_PADDING * 2.0)
	queue_redraw()

func _draw():
	draw_rect(Rect2(Vector2.ZERO, size), _background_color, true)
