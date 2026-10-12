# Flash Element Hierarchy: Shape, SymbolInstance, Text, Bitmap, Group
class_name Element
extends RefCounted

var id: String = ""
var name: String = "Element"
var element_type: String = "shape" # "shape", "symbol_instance", "text", "bitmap", "group"
var transform: ItemTransform = null
var transformation_point: Vector2 = Vector2.ZERO

func _init() -> void:
	id = "el_" + str(Time.get_ticks_usec())
	transform = ItemTransform.new()

func duplicate_element() -> Element:
	var el = Element.from_dict(to_dict())
	return el

func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"element_type": element_type,
		"transform": transform.to_dict() if transform != null else {},
		"transformation_point": [transformation_point.x, transformation_point.y]
	}

static func from_dict(d: Dictionary) -> Element:
	var type_str = d.get("element_type", "shape")
	var el: Element
	match type_str:
		"shape":
			el = ShapeElement.new()
			var sh = el as ShapeElement
			sh.shape_type = d.get("shape_type", "rect")
			var sz = d.get("size", [100.0, 100.0])
			sh.size = Vector2(sz[0], sz[1])
			var c = d.get("color", [0.9, 0.35, 0.35, 1.0])
			sh.color = Color(c[0], c[1], c[2], c[3])
			var sc = d.get("stroke_color", [0.2, 0.2, 0.2, 1.0])
			sh.stroke_color = Color(sc[0], sc[1], sc[2], sc[3])
			sh.stroke_width = float(d.get("stroke_width", 2.0))
			
			var pts_arr = d.get("points", [])
			var pts = PackedVector2Array()
			for p in pts_arr:
				pts.append(Vector2(p[0], p[1]))
			sh.points = pts
			
			var crv_arr = d.get("curve_controls", [])
			var crvs = PackedVector2Array()
			for cp in crv_arr:
				crvs.append(Vector2(cp[0], cp[1]))
			sh.curve_controls = crvs
			
			sh.polystar_sides = int(d.get("polystar_sides", 5))
			sh.is_star = bool(d.get("is_star", false))
			sh.star_inner_radius_ratio = float(d.get("star_inner_radius_ratio", 0.5))
			
		"symbol_instance":
			el = SymbolInstance.new()
			var si = el as SymbolInstance
			si.library_ref = d.get("library_ref", "")
			si.symbol_type = d.get("symbol_type", "graphic")
			si.color_effect = d.get("color_effect", "none")
			var tc = d.get("tint_color", [1.0, 1.0, 1.0, 1.0])
			si.tint_color = Color(tc[0], tc[1], tc[2], tc[3])
			si.tint_ratio = float(d.get("tint_ratio", 0.0))
			si.alpha = float(d.get("alpha", 1.0))
			si.loop_mode = d.get("loop_mode", "loop")
			si.first_frame = int(d.get("first_frame", 0))
			
		"text":
			el = TextElement.new()
			var te = el as TextElement
			te.text_content = d.get("text_content", "")
			te.font_size = int(d.get("font_size", 24))
			te.font_family = d.get("font_family", "")
			te.alignment = d.get("alignment", "left")
			var tc = d.get("color", [0.0, 0.0, 0.0, 1.0])
			te.color = Color(tc[0], tc[1], tc[2], tc[3])
			var sz = d.get("size", [160.0, 40.0])
			te.size = Vector2(sz[0], sz[1])
			
		"bitmap":
			el = BitmapInstance.new()
			var bi = el as BitmapInstance
			bi.texture_path = d.get("texture_path", "")
			var sz = d.get("size", [100.0, 100.0])
			bi.size = Vector2(sz[0], sz[1])
			
		"group":
			el = GroupElement.new()
			var ge = el as GroupElement
			var child_arr = d.get("elements", [])
			for c_dict in child_arr:
				ge.elements.append(Element.from_dict(c_dict))
				
		_:
			el = Element.new()
			
	el.id = d.get("id", "el_" + str(Time.get_ticks_usec()))
	el.name = d.get("name", "Element")
	el.element_type = type_str
	var tp = d.get("transformation_point", [0.0, 0.0])
	el.transformation_point = Vector2(tp[0], tp[1])
	if d.has("transform"):
		el.transform = ItemTransform.from_dict(d["transform"])
	return el
