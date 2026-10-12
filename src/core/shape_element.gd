class_name ShapeElement
extends Element

var shape_type: String = "rect" # "rect", "circle", "line", "path", "polystar"
var size: Vector2 = Vector2(100, 100)
var color: Color = Color(0.9, 0.35, 0.35, 1.0)
var stroke_color: Color = Color(0.2, 0.2, 0.2, 1.0)
var stroke_width: float = 2.0
var points: PackedVector2Array = PackedVector2Array()
var curve_controls: PackedVector2Array = PackedVector2Array()
var polystar_sides: int = 5
var is_star: bool = false
var star_inner_radius_ratio: float = 0.5

var corner_radius: Vector4 = Vector4.ZERO
var oval_start_angle: float = 0.0
var oval_end_angle: float = TAU
var oval_inner_radius_ratio: float = 0.0

func _init() -> void:
	super._init()
	element_type = "shape"
	
func to_dict() -> Dictionary:
	var d = super.to_dict()
	d["shape_type"] = shape_type
	d["size"] = [size.x, size.y]
	d["color"] = [color.r, color.g, color.b, color.a]
	d["stroke_color"] = [stroke_color.r, stroke_color.g, stroke_color.b, stroke_color.a]
	d["stroke_width"] = stroke_width
	var pts = []
	for p in points: pts.append([p.x, p.y])
	d["points"] = pts
	var crvs = []
	for cp in curve_controls: crvs.append([cp.x, cp.y])
	d["curve_controls"] = crvs
	d["polystar_sides"] = polystar_sides
	d["is_star"] = is_star
	d["star_inner_radius_ratio"] = star_inner_radius_ratio
	d["corner_radius"] = [corner_radius.x, corner_radius.y, corner_radius.z, corner_radius.w]
	d["oval_start_angle"] = oval_start_angle
	d["oval_end_angle"] = oval_end_angle
	d["oval_inner_radius_ratio"] = oval_inner_radius_ratio
	return d
