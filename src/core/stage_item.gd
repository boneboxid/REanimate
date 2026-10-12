# Data model untuk elemen di atas stage
class_name StageItem
extends RefCounted

var id: String = ""
var name: String = "Item"
var shape_type: String = "rect" # "rect", "circle", "line", "path", "polystar", "text", "symbol", "sprite"
var size: Vector2 = Vector2(100, 100)
var color: Color = Color(0.9, 0.35, 0.35, 1.0)
var stroke_color: Color = Color(0.2, 0.2, 0.2, 1.0)
var stroke_width: float = 2.0
var texture: Texture2D = null
var texture_path: String = ""
var points: PackedVector2Array = PackedVector2Array() # Untuk freehand / pen brush paths / line
var curve_controls: PackedVector2Array = PackedVector2Array() # Quadratic bezier control handles untuk curve bending

# Polystar fields
var polystar_sides: int = 5
var is_star: bool = false
var star_inner_radius_ratio: float = 0.5

# Corner radius for Rect (Vector4: top-left, top-right, bottom-right, bottom-left)
var corner_radius: Vector4 = Vector4.ZERO

# Oval fields (Flash Oval Object)
var oval_start_angle: float = 0.0
var oval_end_angle: float = TAU
var oval_inner_radius_ratio: float = 0.0

# Text fields
var text_content: String = "Text"
var font_size: int = 24
var text_alignment: int = HORIZONTAL_ALIGNMENT_LEFT
var is_dynamic: bool = false

# Symbol fields
var symbol_type: String = "graphic" # "graphic", "movie_clip", "button"
var library_ref: String = "" # ID SymbolItem di Document Library
var color_effect: String = "none" # "none", "brightness", "tint", "alpha", "advanced"
var tint_color: Color = Color.WHITE
var tint_ratio: float = 0.0
var alpha: float = 1.0
var brightness: float = 0.0
var loop_mode: String = "loop" # "loop", "play_once", "single_frame"
var first_frame: int = 0
var registration_point: Vector2 = Vector2.ZERO # Pivot registration offset
var nested_item_ids: Array[String] = []
var nested_instances: Array[Dictionary] = [] # Array of { "symbol_id": String, "transform": ItemTransform, "name": String }
var sub_paths: Array[Dictionary] = [] # Array of { "points": PackedVector2Array, "curves": PackedVector2Array, "color": Color, "stroke_color": Color }

func to_dict() -> Dictionary:
	var pts: Array = []
	for p in points:
		pts.append([p.x, p.y])
	var curves: Array = []
	for cp in curve_controls:
		curves.append([cp.x, cp.y])
	var n_insts: Array = []
	for inst in nested_instances:
		var inst_dict = {
			"symbol_id": inst.get("symbol_id", ""),
			"name": inst.get("name", ""),
		}
		var t = inst.get("transform", null)
		if t is ItemTransform:
			inst_dict["transform"] = t.to_dict()
		n_insts.append(inst_dict)
	var sp_data: Array = []
	for sp in sub_paths:
		var s_pts: Array = []
		for p in sp.get("points", PackedVector2Array()):
			s_pts.append([p.x, p.y])
		var s_curves: Array = []
		for cp in sp.get("curves", PackedVector2Array()):
			s_curves.append([cp.x, cp.y])
		var col: Color = sp.get("color", color)
		var scol: Color = sp.get("stroke_color", stroke_color)
		sp_data.append({
			"points": s_pts,
			"curves": s_curves,
			"color": [col.r, col.g, col.b, col.a],
			"stroke_color": [scol.r, scol.g, scol.b, scol.a]
		})
	return {
		"id": id,
		"name": name,
		"shape_type": shape_type,
		"size": [size.x, size.y],
		"color": [color.r, color.g, color.b, color.a],
		"stroke_color": [stroke_color.r, stroke_color.g, stroke_color.b, stroke_color.a],
		"stroke_width": stroke_width,
		"texture_path": texture_path,
		"points": pts,
		"curve_controls": curves,
		"polystar_sides": polystar_sides,
		"is_star": is_star,
		"star_inner_radius_ratio": star_inner_radius_ratio,
		"corner_radius": [corner_radius.x, corner_radius.y, corner_radius.z, corner_radius.w],
		"oval_start_angle": oval_start_angle,
		"oval_end_angle": oval_end_angle,
		"oval_inner_radius_ratio": oval_inner_radius_ratio,
		"text_content": text_content,
		"font_size": font_size,
		"text_alignment": text_alignment,
		"is_dynamic": is_dynamic,
		"symbol_type": symbol_type,
		"library_ref": library_ref,
		"color_effect": color_effect,
		"tint_color": [tint_color.r, tint_color.g, tint_color.b, tint_color.a],
		"tint_ratio": tint_ratio,
		"alpha": alpha,
		"brightness": brightness,
		"loop_mode": loop_mode,
		"first_frame": first_frame,
		"registration_point": [registration_point.x, registration_point.y],
		"nested_item_ids": nested_item_ids,
		"nested_instances": n_insts,
		"sub_paths": sp_data
	}

static func from_dict(d: Dictionary) -> StageItem:
	var item = StageItem.new()
	item.id = d.get("id", str(Time.get_ticks_usec()))
	item.name = d.get("name", "Item")
	item.shape_type = d.get("shape_type", "rect")
	var sz = d.get("size", [100.0, 100.0])
	item.size = Vector2(sz[0], sz[1])
	var c = d.get("color", [0.9, 0.35, 0.35, 1.0])
	item.color = Color(c[0], c[1], c[2], c[3])
	var sc = d.get("stroke_color", [0.2, 0.2, 0.2, 1.0])
	item.stroke_color = Color(sc[0], sc[1], sc[2], sc[3])
	item.stroke_width = float(d.get("stroke_width", 2.0))
	item.texture_path = d.get("texture_path", "")
	
	if item.texture_path != "" and FileAccess.file_exists(item.texture_path):
		var img = Image.load_from_file(item.texture_path)
		if img != null:
			item.texture = ImageTexture.create_from_image(img)
			
	var pts_data = d.get("points", [])
	var pts = PackedVector2Array()
	for pt in pts_data:
		pts.append(Vector2(pt[0], pt[1]))
	item.points = pts
	
	var curves_data = d.get("curve_controls", [])
	var curves = PackedVector2Array()
	for cp in curves_data:
		curves.append(Vector2(cp[0], cp[1]))
	item.curve_controls = curves
	
	item.polystar_sides = int(d.get("polystar_sides", 5))
	item.is_star = bool(d.get("is_star", false))
	item.star_inner_radius_ratio = float(d.get("star_inner_radius_ratio", 0.5))
	var cr = d.get("corner_radius", [0.0, 0.0, 0.0, 0.0])
	item.corner_radius = Vector4(cr[0], cr[1], cr[2], cr[3])
	item.oval_start_angle = float(d.get("oval_start_angle", 0.0))
	item.oval_end_angle = float(d.get("oval_end_angle", TAU))
	item.oval_inner_radius_ratio = float(d.get("oval_inner_radius_ratio", 0.0))
	item.text_content = d.get("text_content", "Text")
	item.font_size = int(d.get("font_size", 24))
	item.text_alignment = int(d.get("text_alignment", HORIZONTAL_ALIGNMENT_LEFT))
	item.is_dynamic = bool(d.get("is_dynamic", false))
	item.symbol_type = d.get("symbol_type", "graphic")
	item.library_ref = d.get("library_ref", "")
	item.color_effect = d.get("color_effect", "none")
	var tc = d.get("tint_color", [1.0, 1.0, 1.0, 1.0])
	item.tint_color = Color(tc[0], tc[1], tc[2], tc[3])
	item.tint_ratio = float(d.get("tint_ratio", 0.0))
	item.alpha = float(d.get("alpha", 1.0))
	item.brightness = float(d.get("brightness", 0.0))
	item.loop_mode = d.get("loop_mode", "loop")
	item.first_frame = int(d.get("first_frame", 0))
	var reg = d.get("registration_point", [0.0, 0.0])
	item.registration_point = Vector2(reg[0], reg[1])
	var nested = d.get("nested_item_ids", [])
	item.nested_item_ids.assign(nested)
	
	var n_insts_data = d.get("nested_instances", [])
	for inst in n_insts_data:
		var parsed_inst = {
			"symbol_id": inst.get("symbol_id", ""),
			"name": inst.get("name", ""),
		}
		var t_data = inst.get("transform", null)
		if t_data is Dictionary:
			parsed_inst["transform"] = ItemTransform.from_dict(t_data)
		item.nested_instances.append(parsed_inst)
		
	var sp_data = d.get("sub_paths", [])
	for sp in sp_data:
		var s_pts = PackedVector2Array()
		for pt in sp.get("points", []):
			s_pts.append(Vector2(pt[0], pt[1]))
		var s_curves = PackedVector2Array()
		for cp in sp.get("curves", []):
			s_curves.append(Vector2(cp[0], cp[1]))
		var sp_col = sp.get("color", [item.color.r, item.color.g, item.color.b, item.color.a])
		var sp_scol = sp.get("stroke_color", [item.stroke_color.r, item.stroke_color.g, item.stroke_color.b, item.stroke_color.a])
		item.sub_paths.append({
			"points": s_pts,
			"curves": s_curves,
			"color": Color(sp_col[0], sp_col[1], sp_col[2], sp_col[3]),
			"stroke_color": Color(sp_scol[0], sp_scol[1], sp_scol[2], sp_scol[3])
		})
	
	return item
