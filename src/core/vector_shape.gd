# Engine Vektor Flash sejati: FillStyle, StrokeStyle, Edge, and Shape Merging
class_name VectorShape
extends RefCounted

class FillStyle extends RefCounted:
	var fill_type: String = "solid" # "solid", "linear_gradient", "radial_gradient", "bitmap"
	var color: Color = Color.RED
	var gradient_colors: PackedColorArray = PackedColorArray()
	var gradient_offsets: PackedFloat32Array = PackedFloat32Array()
	var matrix: Transform2D = Transform2D.IDENTITY

	func _init(p_col: Color = Color.RED, p_type: String = "solid") -> void:
		color = p_col
		fill_type = p_type

	func to_dict() -> Dictionary:
		var cols: Array = []
		for c in gradient_colors: cols.append([c.r, c.g, c.b, c.a])
		var offs: Array = []
		for o in gradient_offsets: offs.append(o)
		return {
			"fill_type": fill_type,
			"color": [color.r, color.g, color.b, color.a],
			"gradient_colors": cols,
			"gradient_offsets": offs
		}

	static func from_dict(d: Dictionary) -> FillStyle:
		var fs = FillStyle.new()
		fs.fill_type = d.get("fill_type", "solid")
		var c = d.get("color", [1.0, 0.0, 0.0, 1.0])
		fs.color = Color(c[0], c[1], c[2], c[3])
		var cols = d.get("gradient_colors", [])
		for cd in cols: fs.gradient_colors.append(Color(cd[0], cd[1], cd[2], cd[3]))
		var offs = d.get("gradient_offsets", [])
		for od in offs: fs.gradient_offsets.append(float(od))
		return fs

class StrokeStyle extends RefCounted:
	var color: Color = Color.BLACK
	var width: float = 2.0
	var cap_style: int = 0
	var join_style: int = 0

	func _init(p_col: Color = Color.BLACK, p_width: float = 2.0) -> void:
		color = p_col
		width = p_width

	func to_dict() -> Dictionary:
		return {
			"color": [color.r, color.g, color.b, color.a],
			"width": width,
			"cap_style": cap_style,
			"join_style": join_style
		}

	static func from_dict(d: Dictionary) -> StrokeStyle:
		var ss = StrokeStyle.new()
		var c = d.get("color", [0.0, 0.0, 0.0, 1.0])
		ss.color = Color(c[0], c[1], c[2], c[3])
		ss.width = float(d.get("width", 2.0))
		ss.cap_style = int(d.get("cap_style", 0))
		ss.join_style = int(d.get("join_style", 0))
		return ss

class Edge extends RefCounted:
	var p0: Vector2 = Vector2.ZERO
	var c: Vector2 = Vector2.ZERO # Control point
	var p1: Vector2 = Vector2.ZERO
	var fill_left: int = -1 # Index fill_styles
	var fill_right: int = -1 # Index fill_styles
	var stroke_idx: int = -1 # Index stroke_styles

	func _init(start: Vector2 = Vector2.ZERO, ctrl: Vector2 = Vector2.ZERO, end_pt: Vector2 = Vector2.ZERO) -> void:
		p0 = start
		c = ctrl
		p1 = end_pt

	func to_dict() -> Dictionary:
		return {
			"p0": [p0.x, p0.y],
			"c": [c.x, c.y],
			"p1": [p1.x, p1.y],
			"fill_left": fill_left,
			"fill_right": fill_right,
			"stroke_idx": stroke_idx
		}

	static func from_dict(d: Dictionary) -> Edge:
		var p0_d = d.get("p0", [0.0, 0.0])
		var c_d = d.get("c", [0.0, 0.0])
		var p1_d = d.get("p1", [0.0, 0.0])
		var e = Edge.new(Vector2(p0_d[0], p0_d[1]), Vector2(c_d[0], c_d[1]), Vector2(p1_d[0], p1_d[1]))
		e.fill_left = int(d.get("fill_left", -1))
		e.fill_right = int(d.get("fill_right", -1))
		e.stroke_idx = int(d.get("stroke_idx", -1))
		return e

var fill_styles: Array[FillStyle] = []
var stroke_styles: Array[StrokeStyle] = []
var edges: Array[Edge] = []

# Region polygons (Geometry2D polygons) per fill style
var fill_regions: Array[Dictionary] = [] # Array of { "polygon": PackedVector2Array, "fill_index": int }
# Stroke paths
var stroke_paths: Array[Dictionary] = [] # Array of { "points": PackedVector2Array, "stroke_index": int }

# Object Drawing mode flag (jika true, tidak memotong/bergabung otomatis)
var is_drawing_object: bool = false

func add_fill_style(fs: FillStyle) -> int:
	fill_styles.append(fs)
	return fill_styles.size() - 1

func add_stroke_style(ss: StrokeStyle) -> int:
	stroke_styles.append(ss)
	return stroke_styles.size() - 1

# Flash Merge Drawing: gabung atau potong poligon baru ke shape yang ada
func merge_polygon(new_poly: PackedVector2Array, fill_col: Color, stroke_col: Color = Color.TRANSPARENT, stroke_w: float = 0.0) -> void:
	if new_poly.size() < 3: return
	
	var fs_idx = -1
	# Cari apakah fill_style dengan warna sama sudah ada
	for i in range(fill_styles.size()):
		if fill_styles[i].fill_type == "solid" and fill_styles[i].color == fill_col:
			fs_idx = i
			break
	if fs_idx == -1:
		fs_idx = add_fill_style(FillStyle.new(fill_col, "solid"))
		
	# Stroke style
	var ss_idx = -1
	if stroke_w > 0.0 and stroke_col.a > 0.0:
		ss_idx = add_stroke_style(StrokeStyle.new(stroke_col, stroke_w))
		var sp = new_poly.duplicate()
		sp.append(sp[0])
		stroke_paths.append({ "points": sp, "stroke_index": ss_idx })

	# Jika is_drawing_object (Object Drawing mode 'J'), jangan potong region lain
	if is_drawing_object:
		fill_regions.append({ "polygon": new_poly, "fill_index": fs_idx })
		return

	# Flash Merge Drawing Rule:
	# 1. Potong (clip) semua region lama yang tertimpa oleh new_poly
	var updated_regions: Array[Dictionary] = []
	for reg in fill_regions:
		var old_poly: PackedVector2Array = reg["polygon"]
		var old_fs: int = reg["fill_index"]
		
		# Jika warna sama, merge poligon!
		if old_fs == fs_idx:
			var merged = Geometry2D.merge_polygons(old_poly, new_poly)
			if not merged.is_empty():
				new_poly = merged[0] # New poly becomes the union
				for m_i in range(1, merged.size()):
					updated_regions.append({ "polygon": merged[m_i], "fill_index": fs_idx })
			else:
				updated_regions.append(reg)
		else:
			# Warna beda: potong region lama (clip) dengan new_poly
			var clipped = Geometry2D.clip_polygons(old_poly, new_poly)
			for piece in clipped:
				if piece.size() >= 3:
					updated_regions.append({ "polygon": piece, "fill_index": old_fs })
					
	# Tambahkan new_poly
	updated_regions.append({ "polygon": new_poly, "fill_index": fs_idx })
	fill_regions = updated_regions

# Flash Erase / Cut Region: memotong area poligon
func cut_polygon(cut_poly: PackedVector2Array) -> void:
	if cut_poly.size() < 3: return
	var updated_regions: Array[Dictionary] = []
	for reg in fill_regions:
		var clipped = Geometry2D.clip_polygons(reg["polygon"], cut_poly)
		for piece in clipped:
			if piece.size() >= 3:
				updated_regions.append({ "polygon": piece, "fill_index": reg["fill_index"] })
	fill_regions = updated_regions

# Paint Bucket: isi region pada titik tertentu
func paint_bucket_at(pos: Vector2, new_col: Color) -> bool:
	var target_idx = -1
	for i in range(fill_regions.size() - 1, -1, -1):
		if Geometry2D.is_point_in_polygon(pos, fill_regions[i]["polygon"]):
			target_idx = i
			break
	if target_idx != -1:
		var fs_idx = add_fill_style(FillStyle.new(new_col, "solid"))
		fill_regions[target_idx]["fill_index"] = fs_idx
		return true
	return false

# Hit testing: membedakan klik pada Fill vs Stroke
func hit_test_subparts(pos: Vector2) -> Dictionary:
	# Cek stroke dulu
	for sp in stroke_paths:
		var pts: PackedVector2Array = sp["points"]
		var ss: StrokeStyle = stroke_styles[sp["stroke_index"]]
		var thresh = maxf(6.0, ss.width * 0.5 + 3.0)
		for i in range(pts.size() - 1):
			var seg = pts[i+1] - pts[i]
			var l_sq = seg.length_squared()
			if l_sq > 0.0001:
				var u = clampf((pos - pts[i]).dot(seg) / l_sq, 0.0, 1.0)
				var proj = pts[i] + u * seg
				if pos.distance_to(proj) <= thresh:
					return { "part": "stroke", "index": sp["stroke_index"], "path": pts }
					
	# Cek fill
	for i in range(fill_regions.size() - 1, -1, -1):
		if Geometry2D.is_point_in_polygon(pos, fill_regions[i]["polygon"]):
			return { "part": "fill", "index": fill_regions[i]["fill_index"], "polygon": fill_regions[i]["polygon"], "region_index": i }
			
	return { "part": "none" }

func to_dict() -> Dictionary:
	var fs_arr: Array = []
	for fs in fill_styles: fs_arr.append(fs.to_dict())
	var ss_arr: Array = []
	for ss in stroke_styles: ss_arr.append(ss.to_dict())
	var regs: Array = []
	for r in fill_regions:
		var pts: Array = []
		for p in r["polygon"]: pts.append([p.x, p.y])
		regs.append({ "polygon": pts, "fill_index": r["fill_index"] })
	var sp_arr: Array = []
	for sp in stroke_paths:
		var pts: Array = []
		for p in sp.get("points", PackedVector2Array()): pts.append([p.x, p.y])
		sp_arr.append({ "points": pts, "stroke_index": sp.get("stroke_index", 0) })
	var edges_arr: Array = []
	for e in edges: edges_arr.append(e.to_dict())
	return {
		"is_drawing_object": is_drawing_object,
		"fill_styles": fs_arr,
		"stroke_styles": ss_arr,
		"fill_regions": regs,
		"stroke_paths": sp_arr,
		"edges": edges_arr
	}

static func from_dict(d: Dictionary) -> VectorShape:
	var vs = VectorShape.new()
	vs.is_drawing_object = bool(d.get("is_drawing_object", false))
	for fsd in d.get("fill_styles", []):
		vs.fill_styles.append(FillStyle.from_dict(fsd))
	for ssd in d.get("stroke_styles", []):
		vs.stroke_styles.append(StrokeStyle.from_dict(ssd))
	for rd in d.get("fill_regions", []):
		var pts = PackedVector2Array()
		for p in rd.get("polygon", []): pts.append(Vector2(p[0], p[1]))
		vs.fill_regions.append({ "polygon": pts, "fill_index": int(rd.get("fill_index", 0)) })
	for spd in d.get("stroke_paths", []):
		var pts = PackedVector2Array()
		for p in spd.get("points", []): pts.append(Vector2(p[0], p[1]))
		vs.stroke_paths.append({ "points": pts, "stroke_index": int(spd.get("stroke_index", 0)) })
	for ed in d.get("edges", []):
		vs.edges.append(Edge.from_dict(ed))
	return vs
