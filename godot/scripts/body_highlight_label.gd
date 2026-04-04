extends Control
class_name BodyHighlightLabel

const HORIZONTAL_PADDING := 10.0
const VERTICAL_PADDING := 6.0
const APPEARANCE_SCRIPT := preload("res://scripts/body_label_appearance.gd")

var _label: Label = null
var _label_settings: LabelSettings = null
var _appearance = null
var _background_color := Color(0.0, 0.0, 0.0, 0.55)
var _label_text := ""

func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _label == null:
		_label = Label.new()
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_label)

	if _label_settings == null:
		_label_settings = LabelSettings.new()

	_label.label_settings = _label_settings
	_refresh()

func configure(appearance, label_text: String):
	_appearance = appearance
	_label_text = label_text
	_refresh()

func get_label_size() -> Vector2:
	return size

func get_label_text() -> String:
	return _label_text

func _refresh():
	if not is_node_ready() or _appearance == null:
		return

	_label.text = _label_text
	_label_settings.font = _appearance.font
	_label_settings.font_size = _appearance.font_size
	_label_settings.font_color = _appearance.text_color
	_background_color = _appearance.background_color

	var text_size: Vector2 = _appearance.font.get_string_size(
		_label_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		_appearance.font_size
	)
	size = Vector2(
		ceil(text_size.x + (HORIZONTAL_PADDING * 2.0)),
		ceil(text_size.y + (VERTICAL_PADDING * 2.0))
	)
	_label.position = Vector2(HORIZONTAL_PADDING, VERTICAL_PADDING)
	_label.size = size - Vector2(HORIZONTAL_PADDING * 2.0, VERTICAL_PADDING * 2.0)
	queue_redraw()

func _draw():
	draw_rect(Rect2(Vector2.ZERO, size), _background_color, true)
