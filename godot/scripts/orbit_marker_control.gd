extends Control
class_name OrbitMarkerControl

const DEFAULT_SIZE := Vector2(18.0, 18.0)
const OUTLINE_COLOR := Color(0.02, 0.02, 0.02, 0.9)

var marker_color: Color = Color(0.82, 0.86, 0.92, 1.0)

func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = DEFAULT_SIZE
	queue_redraw()

func configure(color: Color):
	marker_color = color
	size = DEFAULT_SIZE
	queue_redraw()

func place_tip_at(screen_position: Vector2):
	position = screen_position - Vector2(size.x * 0.5, size.y)

func get_tip_position() -> Vector2:
	return position + Vector2(size.x * 0.5, size.y)

func _draw():
	var points := PackedVector2Array([
		Vector2(size.x * 0.5, size.y),
		Vector2(0.0, 0.0),
		Vector2(size.x, 0.0),
	])
	var outline_points := PackedVector2Array([
		points[0],
		points[1],
		points[2],
		points[0],
	])
	draw_colored_polygon(points, marker_color)
	draw_polyline(outline_points, OUTLINE_COLOR, 1.5, true)
