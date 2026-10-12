# Stage Canvas yang menangani render objek, selection, transform box, drag-and-drop, curve bending, serta all tools
class_name StageCanvas
extends Node2D

signal item_selected(item_id: String)
signal item_multi_selected(item_ids: Array[String])
signal item_transformed(item_id: String, new_transform: ItemTransform)
signal item_deleted(item_id: String)
signal drawing_finished(new_item: StageItem, initial_pos: Vector2)
signal color_sampled(sampled_color: Color, is_stroke: bool)
signal camera_pan_requested(relative: Vector2)
signal camera_zoom_requested(zoom_in: bool, center_pos: Vector2)
signal symbol_edit_requested(symbol_id: String)

var stage_size: Vector2 = Vector2(800, 450)
var bg_color: Color = Color(0.98, 0.98, 0.98, 1.0)
var items: Dictionary = {} # id -> StageItem
var current_transforms: Dictionary = {} # id -> ItemTransform

var layer_item_order: Array[String] = []
var locked_layer_items: Dictionary = {}
var visible_layer_items: Dictionary = {}

var active_tool: String = "Select"
var current_fill_color: Color = Color(0.9, 0.35, 0.35, 1.0)
var current_stroke_color: Color = Color(0.15, 0.15, 0.15, 1.0)
var current_stroke_width: float = 2.0
var current_draw_color: Color = Color(0.9, 0.35, 0.35, 1.0) # alias for fill
var is_shift_pressed: bool = false
var is_alt_pressed: bool = false
var is_space_pressed: bool = false

var selected_item_id: String = ""
var is_dragging: bool = false
var is_rotating: bool = false
var is_scaling: bool = false
var scale_handle_index: int = -1
var drag_offset: Vector2 = Vector2.ZERO
var pivot_point: Vector2 = Vector2.ZERO
var is_dragging_pivot: bool = false

# Panning via middle mouse / space
var is_middle_panning: bool = false
var middle_pan_prev: Vector2 = Vector2.ZERO

# State untuk Menggambar (Brush/Pencil/Pen/Lasso/Shape/Line)
var is_drawing_stroke: bool = false
var current_stroke_points: PackedVector2Array = PackedVector2Array()
var current_stroke_pressures: PackedFloat32Array = PackedFloat32Array()
var shape_draw_start: Vector2 = Vector2.ZERO
var shape_draw_current: Vector2 = Vector2.ZERO

# Flash Curve Bending State
var hovered_curve_item_id: String = ""
var hovered_curve_segment_idx: int = -1
var hovered_curve_bend_point: Vector2 = Vector2.ZERO
var is_bending_curve: bool = false
var curve_bend_start_mouse: Vector2 = Vector2.ZERO
var original_curve_controls: PackedVector2Array = PackedVector2Array()

# Multi-selection & Marquee
var selected_item_ids: Array[String] = []
var is_marquee_selecting: bool = false
var marquee_start: Vector2 = Vector2.ZERO
var marquee_current: Vector2 = Vector2.ZERO

# Subselection Node & Tangent Handles
var selected_subnode_idx: int = -1
var selected_tangent_idx: int = -1 # -1: node, 0: in handle, 1: out handle
var is_dragging_subnode: bool = false

# Tool Configuration Attributes (Flash Tool Options)
var rect_corner_radius: Vector4 = Vector4.ZERO
var oval_start_angle: float = 0.0
var oval_end_angle: float = TAU
var oval_inner_radius_ratio: float = 0.0
var polystar_sides: int = 5
var polystar_is_star: bool = false
var polystar_inner_ratio: float = 0.5
var pencil_mode: String = "Smooth" # "Straighten", "Smooth", "Ink"
var eraser_mode: String = "Normal" # "Normal", "Faucet"
var text_font_size: int = 24
var text_alignment: int = HORIZONTAL_ALIGNMENT_LEFT
var text_is_dynamic: bool = false

# Onion Skinning: Array of Dictionary { "transforms": Dictionary, "alpha": float }
var onion_skin_frames: Array[Dictionary] = []
var symbols: Dictionary = {}
var current_layer_transforms: Array[Dictionary] = []

func _ready() -> void:
	queue_redraw()

func set_stage_data(p_items: Dictionary, p_transforms: Dictionary, p_onion_skins: Array[Dictionary] = [], p_symbols: Dictionary = {}, p_layer_transforms: Array[Dictionary] = [], p_layer_order: Array[String] = [], p_locked_items: Dictionary = {}, p_visible_items: Dictionary = {}) -> void:
	items = p_items
	current_transforms = p_transforms
	onion_skin_frames = p_onion_skins
	symbols = p_symbols
	current_layer_transforms = p_layer_transforms
	layer_item_order = p_layer_order
	locked_layer_items = p_locked_items
	visible_layer_items = p_visible_items
	queue_redraw()

func set_stage_settings(p_size: Vector2, p_bg_color: Color) -> void:
	stage_size = p_size
	bg_color = p_bg_color
	queue_redraw()

func _draw() -> void:
	var half_size = stage_size * 0.5
	var stage_rect = Rect2(-half_size, stage_size)
	
	# 1. Gambar Drop Shadow di belakang kertas kanvas
	var shadow_rect = Rect2(-half_size + Vector2(6, 8), stage_size)
	draw_rect(shadow_rect, Color(0.0, 0.0, 0.0, 0.35))
	
	# 2. Gambar Stage Paper Canvas
	draw_rect(stage_rect, bg_color)
	draw_rect(stage_rect, Color(0.35, 0.35, 0.4, 1.0), false, 2.0)
	
	# 3. Gambar Onion Skin (frame sebelum & sesudah dengan alpha transparan)
	for os in onion_skin_frames:
		var os_transforms: Dictionary = os.get("transforms", {})
		var os_alpha: float = os.get("alpha", 0.25)
		_draw_items_pass(os_transforms, os_alpha, true)
	
	# 4. Gambar Objek Utama (layer order: background bottom to foreground top)
	if not current_layer_transforms.is_empty():
		for lt in current_layer_transforms:
			_draw_items_pass(lt, 1.0, false)
	else:
		_draw_items_pass(current_transforms, 1.0, false)
	
	# 5. Preview saat menggambar Brush / Pencil
	if is_drawing_stroke and (active_tool == "Brush" or active_tool == "Pencil" or active_tool == "Lasso"):
		if current_stroke_points.size() > 1:
			var draw_col = current_stroke_color if active_tool == "Pencil" else current_fill_color
			if active_tool == "Lasso":
				draw_col = Color(0.2, 0.6, 1.0, 0.8)
			for i in range(current_stroke_points.size() - 1):
				var p_width = current_stroke_width
				if active_tool == "Brush" and i < current_stroke_pressures.size():
					p_width = max(1.0, current_stroke_width * current_stroke_pressures[i])
				draw_line(current_stroke_points[i], current_stroke_points[i+1], draw_col, p_width, true)
				
	# 6. Preview saat menggambar Shape (Rect / Circle / Polystar / Line)
	if is_drawing_stroke and (active_tool in ["Rect", "Circle", "Polystar", "Line"]):
		var p1 = shape_draw_start
		var p2 = shape_draw_current
		if is_shift_pressed and active_tool in ["Rect", "Circle"]:
			var max_side = max(abs(p2.x - p1.x), abs(p2.y - p1.y))
			p2.x = p1.x + (max_side if p2.x >= p1.x else -max_side)
			p2.y = p1.y + (max_side if p2.y >= p1.y else -max_side)
			
		if active_tool == "Line":
			draw_line(p1, p2, current_stroke_color, current_stroke_width, true)
		elif active_tool == "Rect":
			var sz = Vector2(abs(p2.x - p1.x), abs(p2.y - p1.y))
			var center = (p1 + p2) * 0.5
			_draw_rounded_rect_shape(center, sz, rect_corner_radius, current_fill_color, current_stroke_color, current_stroke_width)
		elif active_tool == "Circle":
			var rx = maxf(1.0, abs(p2.x - p1.x) * 0.5)
			var ry = maxf(1.0, abs(p2.y - p1.y) * 0.5)
			var center = (p1 + p2) * 0.5
			_draw_oval_sector_shape(center, rx, ry, oval_start_angle, oval_end_angle, oval_inner_radius_ratio, current_fill_color, current_stroke_color, current_stroke_width)
		elif active_tool == "Polystar":
			var center = (p1 + p2) * 0.5
			var radius = p1.distance_to(p2) * 0.5
			_draw_polystar_shape(center, radius, polystar_sides, polystar_is_star, polystar_inner_ratio, current_fill_color, current_stroke_color, current_stroke_width)
			
	# 7. Flash Curve Bending Hover Indicator
	if active_tool == "Select" and hovered_curve_item_id != "" and not is_dragging:
		# Gambarkan lengkungan busur kecil penanda Flash Curve Bending di posisi mouse
		draw_arc(hovered_curve_bend_point, 8.0, -PI * 0.75, -PI * 0.25, 12, Color(0.1, 0.5, 1.0, 0.9), 2.5)
		draw_circle(hovered_curve_bend_point, 3.0, Color(0.1, 0.5, 1.0, 0.9))

	# 8. Marquee Selection Box
	if is_marquee_selecting:
		var mq_rect = Rect2(min(marquee_start.x, marquee_current.x), min(marquee_start.y, marquee_current.y), abs(marquee_current.x - marquee_start.x), abs(marquee_current.y - marquee_start.y))
		draw_rect(mq_rect, Color(0.2, 0.6, 1.0, 0.15))
		draw_rect(mq_rect, Color(0.2, 0.6, 1.0, 0.8), false, 1.0)
		
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

func _draw_items_pass(transforms_map: Dictionary, master_alpha: float, is_ghost: bool) -> void:
	for id in items:
		var item: StageItem = items[id]
		var t: ItemTransform = transforms_map.get(id, null)
		if t == null:
			continue
			
		draw_set_transform(t.position, t.rotation, t.scale)
		var half_size = item.size * 0.5
		var item_rect = Rect2(-half_size, item.size)
		
		var draw_color = item.color
		draw_color.a *= (t.opacity * master_alpha)
		var stroke_col = item.stroke_color
		stroke_col.a *= (t.opacity * master_alpha)
		
		match item.shape_type:
			"rect":
				if item.corner_radius != Vector4.ZERO:
					_draw_rounded_rect_shape(Vector2.ZERO, item.size, item.corner_radius, draw_color, stroke_col, item.stroke_width)
				else:
					draw_rect(item_rect, draw_color)
					if item.stroke_width > 0:
						draw_rect(item_rect, stroke_col, false, item.stroke_width)
			"circle":
				var rx = maxf(1.0, half_size.x)
				var ry = maxf(1.0, half_size.y)
				_draw_oval_sector_shape(Vector2.ZERO, rx, ry, item.oval_start_angle, item.oval_end_angle, item.oval_inner_radius_ratio, draw_color, stroke_col, item.stroke_width)
			"line":
				if item.points.size() >= 2:
					draw_line(item.points[0], item.points[1], stroke_col, item.stroke_width, true)
			"path":
				if not item.sub_paths.is_empty():
					for sp in item.sub_paths:
						var sp_pts = sp.get("points", PackedVector2Array())
						var sp_curves = sp.get("curves", PackedVector2Array())
						var sp_col: Color = sp.get("color", item.color)
						sp_col.a *= (t.opacity * master_alpha)
						var sp_scol: Color = sp.get("stroke_color", item.stroke_color)
						sp_scol.a *= (t.opacity * master_alpha)
						_draw_smooth_path(sp_pts, sp_curves, sp_scol, item.stroke_width, sp_col)
				else:
					_draw_smooth_path(item.points, item.curve_controls, stroke_col, item.stroke_width, draw_color)
			"polystar":
				_draw_polystar_shape(Vector2.ZERO, half_size.x, item.polystar_sides, item.is_star, item.star_inner_radius_ratio, draw_color, stroke_col, item.stroke_width)
			"text":
				var font = ThemeDB.fallback_font
				var align = item.text_alignment
				draw_string(font, -half_size + Vector2(0, item.font_size), item.text_content, align, item.size.x, item.font_size, draw_color)
			"sprite":
				if item.texture != null:
					draw_texture_rect(item.texture, item_rect, false, draw_color)
				else:
					draw_rect(item_rect, draw_color)
					if item.stroke_width > 0:
						draw_rect(item_rect, stroke_col, false, item.stroke_width)
			"symbol":
				_draw_symbol_recursive(item, t.to_transform_2d(), master_alpha * t.opacity, 0)
				draw_set_transform(t.position, t.rotation, t.scale)
						
		# Gambar Bounding Box, Pivot, & Handles khas Flash
		var is_selected_elem = (id == selected_item_id or selected_item_ids.has(id))
		if not is_ghost and is_selected_elem:
			if active_tool == "Subselect" and (item.shape_type == "path" or item.shape_type == "line"):
				# Gambarkan anchor nodes bezier dan handle pengarah
				for p_i in range(item.points.size()):
					var pt = item.points[p_i]
					var is_sel = (p_i == selected_subnode_idx)
					var node_col = Color(0.9, 0.2, 0.2, 1.0) if is_sel else Color(0.2, 0.6, 1.0, 1.0)
					draw_rect(Rect2(pt - Vector2(4, 4), Vector2(8, 8)), Color.WHITE)
					draw_rect(Rect2(pt - Vector2(4, 4), Vector2(8, 8)), node_col, false, 1.5)
					
					# Jika node terpilih, gambarkan tangent handles ke control point sebelum & sesudah
					if is_sel:
						if p_i < item.curve_controls.size():
							var ctrl_out = item.curve_controls[p_i]
							draw_line(pt, ctrl_out, Color(0.3, 0.7, 1.0, 0.8), 1.0)
							draw_circle(ctrl_out, 3.5, Color(0.2, 0.6, 1.0, 1.0))
						if p_i > 0 and (p_i - 1) < item.curve_controls.size():
							var ctrl_in = item.curve_controls[p_i - 1]
							draw_line(pt, ctrl_in, Color(0.3, 0.7, 1.0, 0.8), 1.0)
							draw_circle(ctrl_in, 3.5, Color(0.2, 0.6, 1.0, 1.0))
			elif active_tool == "Transform" and id == selected_item_id:
				# Free Transform khas Flash: 8 handles, pivot draggable, rotation arm
				draw_rect(item_rect, Color(0.2, 0.6, 1.0, 0.9), false, 1.5)
				var cur_pivot = pivot_point
				draw_circle(cur_pivot, 4.5, Color(1.0, 1.0, 1.0, 1.0))
				draw_circle(cur_pivot, 4.5, Color(0.1, 0.1, 0.1, 1.0), false, 1.2)
				
				# Rotation Handle di atas
				var rot_pos = Vector2(0, -half_size.y - 18)
				draw_line(Vector2(0, -half_size.y), rot_pos, Color(0.2, 0.8, 0.3, 1.0), 1.5)
				draw_circle(rot_pos, 5.0, Color(0.2, 0.8, 0.3, 1.0))
				
				# 8 Transform Handles khas Flash (4 sudut + 4 tepi)
				var handles = [
					-half_size, Vector2(0, -half_size.y), Vector2(half_size.x, -half_size.y),
					Vector2(half_size.x, 0), half_size, Vector2(0, half_size.y),
					Vector2(-half_size.x, half_size.y), Vector2(-half_size.x, 0)
				]
				for h in handles:
					draw_rect(Rect2(h - Vector2(3.5, 3.5), Vector2(7, 7)), Color.WHITE)
					draw_rect(Rect2(h - Vector2(3.5, 3.5), Vector2(7, 7)), Color(0.2, 0.5, 0.9, 1.0), false, 1.2)
			else:
				# Normal Selection Tool bounding box (tanpa handles transform)
				draw_rect(item_rect, Color(0.2, 0.6, 1.0, 0.9), false, 1.5)
					
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

func _draw_symbol_recursive(sym_item: StageItem, current_xform: Transform2D, current_alpha: float, depth: int) -> void:
	if depth > 10 or sym_item == null:
		return
		
	var draw_col = sym_item.color
	if sym_item.color_effect == "tint":
		draw_col = draw_col.lerp(sym_item.tint_color, sym_item.tint_ratio)
	elif sym_item.color_effect == "brightness":
		draw_col = draw_col.lightened(sym_item.brightness) if sym_item.brightness > 0 else draw_col.darkened(-sym_item.brightness)
	draw_col.a *= current_alpha * sym_item.alpha
	
	var stroke_col = sym_item.stroke_color
	if sym_item.color_effect == "tint":
		stroke_col = stroke_col.lerp(sym_item.tint_color, sym_item.tint_ratio)
	stroke_col.a *= current_alpha * sym_item.alpha
	
	draw_set_transform_matrix(current_xform)
	
	# 1. Path / Sub-paths
	if not sym_item.sub_paths.is_empty():
		for sp in sym_item.sub_paths:
			var sp_pts = sp.get("points", PackedVector2Array())
			var sp_curves = sp.get("curves", PackedVector2Array())
			var sp_col: Color = sp.get("color", sym_item.color)
			sp_col.a *= current_alpha
			var sp_scol: Color = sp.get("stroke_color", sym_item.stroke_color)
			sp_scol.a *= current_alpha
			_draw_smooth_path(sp_pts, sp_curves, sp_scol, sym_item.stroke_width, sp_col)
	elif sym_item.points.size() > 1:
		_draw_smooth_path(sym_item.points, sym_item.curve_controls, stroke_col, sym_item.stroke_width, draw_col)
		
	# 2. Nested child instances
	if not sym_item.nested_instances.is_empty():
		for child_inst in sym_item.nested_instances:
			var child_id: String = child_inst.get("symbol_id", "")
			var child_t: ItemTransform = child_inst.get("transform", null)
			var child_item: StageItem = symbols.get(child_id, items.get(child_id, null))
			if child_item != null:
				var child_local = child_t.to_transform_2d() if child_t != null else Transform2D.IDENTITY
				var next_xform = current_xform * child_local
				var next_alpha = current_alpha * (child_t.opacity if child_t != null else 1.0)
				_draw_symbol_recursive(child_item, next_xform, next_alpha, depth + 1)
				draw_set_transform_matrix(current_xform)
	elif sym_item.points.is_empty() and sym_item.texture != null:
		var half_size = sym_item.size * 0.5
		draw_texture_rect(sym_item.texture, Rect2(-half_size, sym_item.size), false, draw_col)
	elif sym_item.points.is_empty() and sym_item.sub_paths.is_empty() and sym_item.nested_instances.is_empty():
		var half_size = sym_item.size * 0.5
		var item_rect = Rect2(-half_size, sym_item.size)
		draw_rect(item_rect, draw_col)
		if sym_item.stroke_width > 0:
			draw_rect(item_rect, stroke_col, false, sym_item.stroke_width)

func _draw_smooth_path(points_arr: PackedVector2Array, curves_arr: PackedVector2Array, col: Color, w: float, fill_col: Color = Color.TRANSPARENT) -> void:
	if points_arr.size() < 2: return
	var curve_pts = PackedVector2Array()
	if curves_arr.size() >= points_arr.size():
		for i in range(points_arr.size() - 1):
			var p0 = points_arr[i]
			var p2 = points_arr[i + 1]
			var p1 = curves_arr[i]
			for step in range(6):
				var tt = float(step) / 5.0
				var q = (1.0 - tt) * (1.0 - tt) * p0 + 2.0 * (1.0 - tt) * tt * p1 + tt * tt * p2
				curve_pts.append(q)
	else:
		curve_pts = points_arr
		
	if fill_col.a > 0.01 and curve_pts.size() >= 3:
		var clean_pts = PackedVector2Array()
		for p in curve_pts:
			if clean_pts.is_empty() or clean_pts[-1].distance_to(p) > 0.1:
				clean_pts.append(p)
		if clean_pts.size() >= 3:
			var tris = Geometry2D.triangulate_polygon(clean_pts)
			if tris.size() > 0:
				draw_colored_polygon(clean_pts, fill_col)
					
	if w > 0.1 and col.a > 0.01:
		for j in range(curve_pts.size() - 1):
			draw_line(curve_pts[j], curve_pts[j + 1], col, maxf(1.0, w), true)

func _draw_polystar_shape(center: Vector2, radius: float, sides: int, star: bool, inner_ratio: float, fill_col: Color, stroke_col: Color, stroke_w: float) -> void:
	var total_points = sides * 2 if star else sides
	var poly = PackedVector2Array()
	var step_angle = TAU / float(total_points)
	var start_angle = -PI * 0.5
	
	for i in range(total_points):
		var angle = start_angle + i * step_angle
		var r = radius
		if star and (i % 2 == 1):
			r = radius * inner_ratio
		poly.append(center + Vector2(cos(angle), sin(angle)) * r)
		
	if poly.size() >= 3:
		draw_colored_polygon(poly, fill_col)
		if stroke_w > 0:
			poly.append(poly[0])
			for i in range(poly.size() - 1):
				draw_line(poly[i], poly[i+1], stroke_col, stroke_w, true)

func _draw_rounded_rect_shape(center: Vector2, sz: Vector2, radii: Vector4, fill_col: Color, stroke_col: Color, stroke_w: float) -> void:
	var half = sz * 0.5
	var r_tl = clampf(radii.x, 0.0, minf(half.x, half.y))
	var r_tr = clampf(radii.y, 0.0, minf(half.x, half.y))
	var r_br = clampf(radii.z, 0.0, minf(half.x, half.y))
	var r_bl = clampf(radii.w, 0.0, minf(half.x, half.y))
	
	if r_tl <= 0.01 and r_tr <= 0.01 and r_br <= 0.01 and r_bl <= 0.01:
		var rect = Rect2(center - half, sz)
		draw_rect(rect, fill_col)
		if stroke_w > 0:
			draw_rect(rect, stroke_col, false, stroke_w)
		return
		
	var pts = PackedVector2Array()
	var steps = 8
	# Top edge & Top-Right corner
	pts.append(center + Vector2(half.x - r_tr, -half.y))
	for i in range(steps + 1):
		var a = -PI * 0.5 + (float(i) / float(steps)) * (PI * 0.5)
		pts.append(center + Vector2(half.x - r_tr, -half.y + r_tr) + Vector2(cos(a) * r_tr, sin(a) * r_tr))
	# Right edge & Bottom-Right corner
	pts.append(center + Vector2(half.x, half.y - r_br))
	for i in range(steps + 1):
		var a = 0.0 + (float(i) / float(steps)) * (PI * 0.5)
		pts.append(center + Vector2(half.x - r_br, half.y - r_br) + Vector2(cos(a) * r_br, sin(a) * r_br))
	# Bottom edge & Bottom-Left corner
	pts.append(center + Vector2(-half.x + r_bl, half.y))
	for i in range(steps + 1):
		var a = PI * 0.5 + (float(i) / float(steps)) * (PI * 0.5)
		pts.append(center + Vector2(-half.x + r_bl, half.y - r_bl) + Vector2(cos(a) * r_bl, sin(a) * r_bl))
	# Left edge & Top-Left corner
	pts.append(center + Vector2(-half.x, -half.y + r_tl))
	for i in range(steps + 1):
		var a = PI + (float(i) / float(steps)) * (PI * 0.5)
		pts.append(center + Vector2(-half.x + r_tl, -half.y + r_tl) + Vector2(cos(a) * r_tl, sin(a) * r_tl))
		
	if pts.size() >= 3:
		draw_colored_polygon(pts, fill_col)
		if stroke_w > 0:
			pts.append(pts[0])
			for i in range(pts.size() - 1):
				draw_line(pts[i], pts[i+1], stroke_col, stroke_w, true)

func _draw_oval_sector_shape(center: Vector2, rx: float, ry: float, start_a: float, end_a: float, inner_ratio: float, fill_col: Color, stroke_col: Color, stroke_w: float) -> void:
	var total_span = end_a - start_a
	while total_span < 0.0: total_span += TAU
	if total_span <= 0.001: total_span = TAU
	
	var is_full_ellipse = (abs(total_span - TAU) < 0.01) and inner_ratio <= 0.01
	if is_full_ellipse:
		var ellipse_pts = PackedVector2Array()
		for i in range(48):
			var th = (float(i) / 48.0) * TAU
			ellipse_pts.append(center + Vector2(cos(th) * rx, sin(th) * ry))
		draw_colored_polygon(ellipse_pts, fill_col)
		if stroke_w > 0:
			ellipse_pts.append(ellipse_pts[0])
			draw_polyline(ellipse_pts, stroke_col, stroke_w, true)
		return
		
	var pts = PackedVector2Array()
	var steps = int(clampf(round(total_span / TAU * 48.0), 8.0, 48.0))
	# Outer arc
	for i in range(steps + 1):
		var th = start_a + (float(i) / float(steps)) * total_span
		pts.append(center + Vector2(cos(th) * rx, sin(th) * ry))
		
	if inner_ratio > 0.01:
		# Inner arc reversed
		var in_rx = rx * inner_ratio
		var in_ry = ry * inner_ratio
		for i in range(steps, -1, -1):
			var th = start_a + (float(i) / float(steps)) * total_span
			pts.append(center + Vector2(cos(th) * in_rx, sin(th) * in_ry))
	else:
		# Pie center
		pts.append(center)
		
	if pts.size() >= 3:
		draw_colored_polygon(pts, fill_col)
		if stroke_w > 0:
			pts.append(pts[0])
			for i in range(pts.size() - 1):
				draw_line(pts[i], pts[i+1], stroke_col, stroke_w, true)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		is_shift_pressed = event.shift_pressed
		is_alt_pressed = event.alt_pressed
		if event.keycode == KEY_SPACE:
			is_space_pressed = event.pressed
			
		# Arrow keys nudge for selected items (Flash standard: 1px, Shift: 10px)
		if event.pressed and not event.is_echo() and selected_item_id != "" and current_transforms.has(selected_item_id):
			var nudge_dist = 10.0 if event.shift_pressed else 1.0
			var delta = Vector2.ZERO
			if event.keycode == KEY_LEFT: delta = Vector2(-nudge_dist, 0)
			elif event.keycode == KEY_RIGHT: delta = Vector2(nudge_dist, 0)
			elif event.keycode == KEY_UP: delta = Vector2(0, -nudge_dist)
			elif event.keycode == KEY_DOWN: delta = Vector2(0, nudge_dist)
			
			if delta != Vector2.ZERO:
				var t: ItemTransform = current_transforms[selected_item_id]
				t.position += delta
				item_transformed.emit(selected_item_id, t)
				queue_redraw()
				if get_viewport() != null:
					get_viewport().set_input_as_handled()
				return
		
	if event is InputEventMouseButton:
		var local_mouse = to_local(get_global_mouse_position())
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.double_click and selected_item_id != "" and items.has(selected_item_id):
				var itm: StageItem = items[selected_item_id]
				if (itm.shape_type == "symbol" or itm.symbol_type != "") and itm.library_ref != "":
					symbol_edit_requested.emit(itm.library_ref)
					return
			if event.pressed:
				_handle_press(local_mouse, 1.0)
			else:
				_handle_release(local_mouse)
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				is_middle_panning = true
				middle_pan_prev = event.position
			else:
				is_middle_panning = false
	elif event is InputEventMouseMotion:
		if is_middle_panning or (is_space_pressed and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)):
			var delta = event.position - middle_pan_prev
			middle_pan_prev = event.position
			camera_pan_requested.emit(delta)
			return
		middle_pan_prev = event.position
		var local_mouse = to_local(get_global_mouse_position())
		var pressure = 1.0
		if event.pressure > 0.0:
			pressure = event.pressure
		_handle_motion(local_mouse, pressure)

func _handle_press(mouse_pos: Vector2, pressure: float) -> void:
	match active_tool:
		"Select":
			if hovered_curve_item_id != "" and hovered_curve_segment_idx >= 0:
				# Mulai Flash Curve Bending!
				is_bending_curve = true
				curve_bend_start_mouse = mouse_pos
				queue_redraw()
				return
			_handle_select_press(mouse_pos)
		"Subselect":
			_handle_subselect_press(mouse_pos)
		"Transform":
			_handle_transform_press(mouse_pos)
		"Brush", "Pencil", "Lasso":
			is_drawing_stroke = true
			current_stroke_points = PackedVector2Array([mouse_pos])
			current_stroke_pressures = PackedFloat32Array([pressure])
			queue_redraw()
		"Rect", "Circle", "Polystar", "Line":
			is_drawing_stroke = true
			shape_draw_start = mouse_pos
			shape_draw_current = mouse_pos
			queue_redraw()
		"Pen":
			_handle_pen_click(mouse_pos)
		"Text":
			_create_text_item(mouse_pos)
		"InkBottle":
			_apply_ink_bottle(mouse_pos)
		"PaintBucket":
			_apply_paint_bucket(mouse_pos)
		"Eyedropper":
			_apply_eyedropper(mouse_pos)
		"Eraser":
			_apply_eraser(mouse_pos)
		"Hand":
			is_dragging = true
			drag_offset = mouse_pos
		"Zoom":
			camera_zoom_requested.emit(!is_alt_pressed, mouse_pos)

func _handle_motion(mouse_pos: Vector2, pressure: float) -> void:
	# Flash Curve Bending drag (khusus Selection Tool)
	if is_bending_curve and hovered_curve_item_id != "" and items.has(hovered_curve_item_id):
		var item: StageItem = items[hovered_curve_item_id]
		var t = current_transforms.get(hovered_curve_item_id, null)
		if t != null:
			var local_mouse = (mouse_pos - t.position).rotated(-t.rotation) / t.scale
			if hovered_curve_segment_idx < item.curve_controls.size():
				item.curve_controls[hovered_curve_segment_idx] = local_mouse
				queue_redraw()
		return
		
	if active_tool == "Transform":
		if selected_item_id != "" and current_transforms.has(selected_item_id):
			var t: ItemTransform = current_transforms[selected_item_id]
			var item: StageItem = items[selected_item_id]
			var half_size = item.size * 0.5
			if is_dragging_pivot:
				pivot_point = (mouse_pos - t.position).rotated(-t.rotation) / t.scale
				queue_redraw()
				return
			elif is_rotating:
				var dir = mouse_pos - (t.position + pivot_point.rotated(t.rotation) * t.scale)
				t.rotation = dir.angle() + (PI / 2.0)
				item_transformed.emit(selected_item_id, t)
				queue_redraw()
				return
			elif is_scaling and scale_handle_index >= 0:
				var local_mouse = (mouse_pos - t.position).rotated(-t.rotation)
				match scale_handle_index:
					0: # Top-Left
						var rx = -local_mouse.x / maxf(1.0, half_size.x)
						var ry = -local_mouse.y / maxf(1.0, half_size.y)
						t.scale = Vector2(maxf(0.05, rx), maxf(0.05, ry))
					1: # Top-Center
						var ry = -local_mouse.y / maxf(1.0, half_size.y)
						t.scale.y = maxf(0.05, ry)
					2: # Top-Right
						var rx = local_mouse.x / maxf(1.0, half_size.x)
						var ry = -local_mouse.y / maxf(1.0, half_size.y)
						t.scale = Vector2(maxf(0.05, rx), maxf(0.05, ry))
					3: # Right-Center
						var rx = local_mouse.x / maxf(1.0, half_size.x)
						t.scale.x = maxf(0.05, rx)
					4: # Bottom-Right
						var rx = local_mouse.x / maxf(1.0, half_size.x)
						var ry = local_mouse.y / maxf(1.0, half_size.y)
						t.scale = Vector2(maxf(0.05, rx), maxf(0.05, ry))
					5: # Bottom-Center
						var ry = local_mouse.y / maxf(1.0, half_size.y)
						t.scale.y = maxf(0.05, ry)
					6: # Bottom-Left
						var rx = -local_mouse.x / maxf(1.0, half_size.x)
						var ry = local_mouse.y / maxf(1.0, half_size.y)
						t.scale = Vector2(maxf(0.05, rx), maxf(0.05, ry))
					7: # Left-Center
						var rx = -local_mouse.x / maxf(1.0, half_size.x)
						t.scale.x = maxf(0.05, rx)
						
				if is_shift_pressed and scale_handle_index in [0, 2, 4, 6]:
					var uniform_s = maxf(t.scale.x, t.scale.y)
					t.scale = Vector2(uniform_s, uniform_s)
					
				item_transformed.emit(selected_item_id, t)
				queue_redraw()
				return
			elif is_dragging:
				t.position = mouse_pos - drag_offset
				item_transformed.emit(selected_item_id, t)
				queue_redraw()
				return

	elif active_tool == "Select":
		if is_marquee_selecting:
			marquee_current = mouse_pos
			queue_redraw()
			return
		elif selected_item_id != "" and current_transforms.has(selected_item_id):
			var t: ItemTransform = current_transforms[selected_item_id]
			if is_dragging:
				t.position = mouse_pos - drag_offset
				item_transformed.emit(selected_item_id, t)
				queue_redraw()
				return
				
		# Update check curve proximity when hovering on Selection Tool
		if not is_dragging:
			_check_curve_proximity(mouse_pos)
			
	elif active_tool == "Subselect" and is_dragging_subnode:
		if selected_item_id != "" and items.has(selected_item_id):
			var item: StageItem = items[selected_item_id]
			var t = current_transforms.get(selected_item_id, null)
			if t != null:
				var local_pos = (mouse_pos - t.position).rotated(-t.rotation) / t.scale
				if selected_tangent_idx == -1 and selected_subnode_idx >= 0 and selected_subnode_idx < item.points.size():
					item.points[selected_subnode_idx] = local_pos
					queue_redraw()
				elif selected_tangent_idx >= 0 and selected_tangent_idx < item.curve_controls.size():
					item.curve_controls[selected_tangent_idx] = local_pos
					queue_redraw()
				
	elif (active_tool in ["Brush", "Pencil", "Lasso"]) and is_drawing_stroke:
		if current_stroke_points.is_empty() or current_stroke_points[-1].distance_to(mouse_pos) > 3.0:
			current_stroke_points.append(mouse_pos)
			current_stroke_pressures.append(pressure)
			queue_redraw()
			
	elif (active_tool in ["Rect", "Circle", "Polystar", "Line"]) and is_drawing_stroke:
		shape_draw_current = mouse_pos
		queue_redraw()
		
	elif active_tool == "Hand" and is_dragging:
		var delta = mouse_pos - drag_offset
		var cam = get_viewport().get_camera_2d()
		camera_pan_requested.emit(delta * (cam.zoom if cam != null else Vector2.ONE))


func _handle_release(mouse_pos: Vector2) -> void:
	if is_bending_curve:
		is_bending_curve = false
		queue_redraw()
		return
		
	if is_drawing_stroke:
		is_drawing_stroke = false
		if active_tool == "Lasso":
			if current_stroke_points.size() >= 3:
				var hit_ids: Array[String] = []
				for id in items:
					if locked_layer_items.get(id, false): continue
					if not visible_layer_items.get(id, true): continue
					var t: ItemTransform = current_transforms.get(id, null)
					if t == null: continue
					if Geometry2D.is_point_in_polygon(t.position, current_stroke_points):
						hit_ids.append(id)
				if not hit_ids.is_empty():
					selected_item_id = hit_ids[-1]
					selected_item_ids = hit_ids
					item_selected.emit(selected_item_id)
					item_multi_selected.emit(hit_ids)
				else:
					selected_item_id = ""
					selected_item_ids.clear()
					item_selected.emit("")
			current_stroke_points.clear()
			current_stroke_pressures.clear()
			queue_redraw()
			return
		elif (active_tool == "Brush" or active_tool == "Pencil") and current_stroke_points.size() > 1:
			var new_item = StageItem.new()
			new_item.id = ("brush_" if active_tool == "Brush" else "pencil_") + str(Time.get_ticks_usec())
			new_item.name = "Brush Stroke" if active_tool == "Brush" else "Pencil Line"
			new_item.shape_type = "path"
			new_item.stroke_color = current_stroke_color if active_tool == "Pencil" else current_fill_color
			new_item.stroke_width = current_stroke_width
			
			var pts_to_use = current_stroke_points
			# Pencil Mode Ramer-Douglas-Peucker & Straighten / Smooth / Ink
			if active_tool == "Pencil":
				if pencil_mode == "Straighten":
					pts_to_use = _simplify_rdp(current_stroke_points, 12.0)
				elif pencil_mode == "Smooth":
					pts_to_use = _simplify_rdp(current_stroke_points, 4.0)
					
			var center = Vector2.ZERO
			for p in pts_to_use: center += p
			center /= float(pts_to_use.size())
			
			var rel_pts = PackedVector2Array()
			var ctrl_pts = PackedVector2Array()
			for i in range(pts_to_use.size()):
				var rel = pts_to_use[i] - center
				rel_pts.append(rel)
				if i < pts_to_use.size() - 1:
					var next_rel = pts_to_use[i + 1] - center
					ctrl_pts.append((rel + next_rel) * 0.5) # Initial midpoint control
			new_item.points = rel_pts
			new_item.curve_controls = ctrl_pts
			
			current_stroke_points.clear()
			current_stroke_pressures.clear()
			drawing_finished.emit(new_item, center)
			queue_redraw()
			return
			
		elif active_tool in ["Rect", "Circle", "Polystar", "Line"]:
			shape_draw_current = mouse_pos
			var p1 = shape_draw_start
			var p2 = shape_draw_current
			if is_shift_pressed and active_tool in ["Rect", "Circle"]:
				var max_side = max(abs(p2.x - p1.x), abs(p2.y - p1.y))
				p2.x = p1.x + (max_side if p2.x >= p1.x else -max_side)
				p2.y = p1.y + (max_side if p2.y >= p1.y else -max_side)
				
			var sz = Vector2(abs(p2.x - p1.x), abs(p2.y - p1.y))
			if sz.x > 3 or sz.y > 3:
				var center = (p1 + p2) * 0.5
				var new_item = StageItem.new()
				new_item.id = active_tool.to_lower() + "_" + str(Time.get_ticks_usec())
				new_item.name = active_tool + " Shape"
				new_item.shape_type = active_tool.to_lower()
				new_item.size = sz
				new_item.color = current_fill_color
				new_item.stroke_color = current_stroke_color
				new_item.stroke_width = current_stroke_width
				
				if active_tool == "Rect":
					new_item.corner_radius = rect_corner_radius
				elif active_tool == "Circle":
					new_item.oval_start_angle = oval_start_angle
					new_item.oval_end_angle = oval_end_angle
					new_item.oval_inner_radius_ratio = oval_inner_radius_ratio
				elif active_tool == "Line":
					new_item.points = PackedVector2Array([p1 - center, p2 - center])
					new_item.curve_controls = PackedVector2Array([(p1 + p2) * 0.5 - center])
				elif active_tool == "Polystar":
					new_item.is_star = polystar_is_star
					new_item.polystar_sides = polystar_sides
					new_item.star_inner_radius_ratio = polystar_inner_ratio
					
				drawing_finished.emit(new_item, center)
			queue_redraw()
			return

	if is_dragging or is_rotating or is_scaling or is_dragging_pivot or is_dragging_subnode:
		is_dragging = false
		is_rotating = false
		is_scaling = false
		scale_handle_index = -1
		is_dragging_pivot = false
		is_dragging_subnode = false
		return
		
	if is_marquee_selecting:
		is_marquee_selecting = false
		var mq_rect = Rect2(min(marquee_start.x, marquee_current.x), min(marquee_start.y, marquee_current.y), abs(marquee_current.x - marquee_start.x), abs(marquee_current.y - marquee_start.y))
		if mq_rect.size.x > 3 and mq_rect.size.y > 3:
			var hit_ids: Array[String] = []
			for id in items:
				if locked_layer_items.get(id, false): continue
				if not visible_layer_items.get(id, true): continue
				var t: ItemTransform = current_transforms.get(id, null)
				if t == null: continue
				var itm: StageItem = items[id]
				var itm_rect = Rect2(t.position - itm.size * 0.5 * t.scale, itm.size * t.scale)
				if mq_rect.intersects(itm_rect) or mq_rect.has_point(t.position):
					hit_ids.append(id)
			if not hit_ids.is_empty():
				selected_item_ids = hit_ids
				selected_item_id = hit_ids[-1]
				item_selected.emit(selected_item_id)
				item_multi_selected.emit(selected_item_ids)
		queue_redraw()
		return

func _simplify_rdp(pts: PackedVector2Array, epsilon: float) -> PackedVector2Array:
	if pts.size() <= 2:
		return pts
		
	var dmax = 0.0
	var index = 0
	var end_idx = pts.size() - 1
	var line_vec = pts[end_idx] - pts[0]
	var len_sq = line_vec.length_squared()
	
	for i in range(1, end_idx):
		var d = 0.0
		if len_sq > 0.0001:
			var u = clampf((pts[i] - pts[0]).dot(line_vec) / len_sq, 0.0, 1.0)
			var proj = pts[0] + u * line_vec
			d = pts[i].distance_to(proj)
		else:
			d = pts[i].distance_to(pts[0])
			
		if d > dmax:
			index = i
			dmax = d
			
	if dmax > epsilon:
		var left = _simplify_rdp(pts.slice(0, index + 1), epsilon)
		var right = _simplify_rdp(pts.slice(index), epsilon)
		var res = left.slice(0, left.size() - 1)
		res.append_array(right)
		return res
	else:
		return PackedVector2Array([pts[0], pts[end_idx]])

func _check_curve_proximity(mouse_pos: Vector2) -> void:
	# Cek apakah mouse dekat dengan kurva/garis objek yang ada untuk Flash Curve Bending
	hovered_curve_item_id = ""
	hovered_curve_segment_idx = -1
	
	for id in items:
		var item: StageItem = items[id]
		if item.shape_type != "path" and item.shape_type != "line": continue
		var t = current_transforms.get(id, null)
		if t == null: continue
		
		var local_mouse = (mouse_pos - t.position).rotated(-t.rotation) / t.scale
		for i in range(item.points.size() - 1):
			var p0 = item.points[i]
			var p1 = item.points[i + 1]
			var seg_vec = p1 - p0
			var len_sq = seg_vec.length_squared()
			if len_sq == 0: continue
			var tt = clampf((local_mouse - p0).dot(seg_vec) / len_sq, 0.0, 1.0)
			var proj = p0 + tt * seg_vec
			if local_mouse.distance_to(proj) <= 8.0: # Dekat garis
				hovered_curve_item_id = id
				hovered_curve_segment_idx = i
				hovered_curve_bend_point = mouse_pos
				# Pastikan curve_controls terisi
				while item.curve_controls.size() < item.points.size() - 1:
					item.curve_controls.append((p0 + p1) * 0.5)
				queue_redraw()
				return
				
	if hovered_curve_item_id != "":
		hovered_curve_item_id = ""
		hovered_curve_segment_idx = -1
		queue_redraw()

func _handle_transform_press(mouse_pos: Vector2) -> void:
	if selected_item_id != "" and current_transforms.has(selected_item_id):
		var cur_t: ItemTransform = current_transforms[selected_item_id]
		var cur_item: StageItem = items[selected_item_id]
		var half_size = cur_item.size * 0.5
		
		# 1. Rotation handle hit-test
		var rot_handle_pos = cur_t.position + Vector2(0, -(half_size.y * cur_t.scale.y) - 18).rotated(cur_t.rotation)
		if mouse_pos.distance_to(rot_handle_pos) <= 12.0:
			is_rotating = true
			return
			
		# 2. Pivot point hit-test
		var stage_pivot = cur_t.position + pivot_point.rotated(cur_t.rotation) * cur_t.scale
		if mouse_pos.distance_to(stage_pivot) <= 8.0:
			is_dragging_pivot = true
			return
			
		# 3. 8 Scale handles hit-test
		var handles = [
			-half_size, Vector2(0, -half_size.y), Vector2(half_size.x, -half_size.y),
			Vector2(half_size.x, 0), half_size, Vector2(0, half_size.y),
			Vector2(-half_size.x, half_size.y), Vector2(-half_size.x, 0)
		]
		for i in range(handles.size()):
			var h_pos = cur_t.position + (handles[i] * cur_t.scale).rotated(cur_t.rotation)
			if mouse_pos.distance_to(h_pos) <= 9.0:
				is_scaling = true
				scale_handle_index = i
				return
				
	# Jika tidak klik handle, lakukan hit-test objek
	_handle_select_press(mouse_pos)

func _handle_select_press(mouse_pos: Vector2) -> void:
	var hit_id = _hit_test_item(mouse_pos)
	if hit_id != "":
		# Shift or Ctrl additive selection
		if is_shift_pressed or Input.is_key_pressed(KEY_CTRL):
			if not selected_item_ids.has(hit_id):
				selected_item_ids.append(hit_id)
			else:
				selected_item_ids.erase(hit_id)
			selected_item_id = selected_item_ids[-1] if not selected_item_ids.is_empty() else ""
			item_selected.emit(selected_item_id)
			item_multi_selected.emit(selected_item_ids)
			queue_redraw()
			return
			
		# Alt-drag = duplikasi item khas Flash
		if is_alt_pressed:
			var src_item: StageItem = items[hit_id]
			var src_t: ItemTransform = current_transforms.get(hit_id, null)
			var dup_item = StageItem.from_dict(src_item.to_dict())
			dup_item.id = src_item.shape_type + "_" + str(Time.get_ticks_usec())
			dup_item.name = src_item.name + " Copy"
			var dup_pos = src_t.position + Vector2(15, 15) if src_t != null else mouse_pos
			drawing_finished.emit(dup_item, dup_pos)
			selected_item_id = dup_item.id
			selected_item_ids = [dup_item.id]
			item_selected.emit(selected_item_id)
			item_multi_selected.emit(selected_item_ids)
			is_dragging = true
			drag_offset = mouse_pos - dup_pos
			queue_redraw()
			return
			
		selected_item_id = hit_id
		selected_item_ids = [hit_id]
		is_dragging = true
		var t = current_transforms[hit_id]
		drag_offset = mouse_pos - t.position
		pivot_point = Vector2.ZERO
		item_selected.emit(hit_id)
		item_multi_selected.emit(selected_item_ids)
		queue_redraw()
		return
		
	# Clicking empty canvas: start Marquee selection
	if not (is_shift_pressed or Input.is_key_pressed(KEY_CTRL)):
		selected_item_id = ""
		selected_item_ids.clear()
		item_selected.emit("")
		item_multi_selected.emit(selected_item_ids)
		
	is_marquee_selecting = true
	marquee_start = mouse_pos
	marquee_current = mouse_pos
	queue_redraw()

func _hit_test_item(mouse_pos: Vector2) -> String:
	var check_ids: Array = []
	if not layer_item_order.is_empty():
		check_ids = layer_item_order
	else:
		check_ids = items.keys()
		check_ids.reverse()
		
	for id in check_ids:
		if not items.has(id): continue
		if locked_layer_items.get(id, false): continue # Layer terkunci diabaikan
		if not visible_layer_items.get(id, true): continue # Layer tersembunyi diabaikan
		var t: ItemTransform = current_transforms.get(id, null)
		var item: StageItem = items[id]
		if t == null: continue
		
		var local_to_item = (mouse_pos - t.position).rotated(-t.rotation) / t.scale
		var half_size = item.size * 0.5
		var is_hit: bool = false
		
		match item.shape_type:
			"rect", "sprite", "symbol", "text":
				is_hit = Rect2(-half_size, item.size).has_point(local_to_item)
			"circle":
				var rx = maxf(1.0, half_size.x)
				var ry = maxf(1.0, half_size.y)
				var nx = local_to_item.x / rx
				var ny = local_to_item.y / ry
				var dist_sq = nx * nx + ny * ny
				if dist_sq <= 1.0:
					if item.oval_inner_radius_ratio > 0.01:
						var in_r = item.oval_inner_radius_ratio
						if dist_sq >= (in_r * in_r):
							is_hit = true
					else:
						is_hit = true
					if is_hit and abs((item.oval_end_angle - item.oval_start_angle) - TAU) > 0.01:
						var a = atan2(local_to_item.y, local_to_item.x)
						while a < 0.0: a += TAU
						var s = item.oval_start_angle
						var e = item.oval_end_angle
						while s < 0.0: s += TAU
						while e < 0.0: e += TAU
						if s < e:
							if a < s or a > e: is_hit = false
						else:
							if a < s and a > e: is_hit = false
			"polystar":
				is_hit = local_to_item.length() <= half_size.x
			"path", "line":
				var thresh = maxf(8.0, item.stroke_width * 0.5 + 4.0)
				for pt in item.points:
					if pt.distance_to(local_to_item) <= thresh:
						is_hit = true
						break
				if not is_hit and item.points.size() >= 2:
					for i in range(item.points.size() - 1):
						var p0 = item.points[i]
						var p1 = item.points[i + 1]
						var seg = p1 - p0
						var len_sq = seg.length_squared()
						if len_sq > 0.0001:
							var u = clampf((local_to_item - p0).dot(seg) / len_sq, 0.0, 1.0)
							var proj = p0 + u * seg
							if local_to_item.distance_to(proj) <= thresh:
								is_hit = true
								break
				if not is_hit and not item.sub_paths.is_empty():
					for sp in item.sub_paths:
						var s_pts = sp.get("points", PackedVector2Array())
						for i in range(s_pts.size() - 1):
							var p0 = s_pts[i]
							var p1 = s_pts[i + 1]
							var seg = p1 - p0
							var len_sq = seg.length_squared()
							if len_sq > 0.0001:
								var u = clampf((local_to_item - p0).dot(seg) / len_sq, 0.0, 1.0)
								var proj = p0 + u * seg
								if local_to_item.distance_to(proj) <= thresh:
									is_hit = true
									break
						if is_hit: break
		if is_hit:
			return id
	return ""

func _handle_subselect_press(mouse_pos: Vector2) -> void:
	if selected_item_id != "" and items.has(selected_item_id):
		var item: StageItem = items[selected_item_id]
		var t = current_transforms.get(selected_item_id, null)
		if t != null and (item.shape_type == "path" or item.shape_type == "line"):
			var local_pos = (mouse_pos - t.position).rotated(-t.rotation) / t.scale
			
			# 1. Cek klik pada tangent control handles terlebih dahulu jika ada node terpilih
			if selected_subnode_idx >= 0:
				if selected_subnode_idx < item.curve_controls.size():
					if item.curve_controls[selected_subnode_idx].distance_to(local_pos) <= 8.0:
						selected_tangent_idx = selected_subnode_idx
						is_dragging_subnode = true
						queue_redraw()
						return
				if selected_subnode_idx > 0 and (selected_subnode_idx - 1) < item.curve_controls.size():
					if item.curve_controls[selected_subnode_idx - 1].distance_to(local_pos) <= 8.0:
						selected_tangent_idx = selected_subnode_idx - 1
						is_dragging_subnode = true
						queue_redraw()
						return
						
			# 2. Cek klik pada anchor node
			for p_i in range(item.points.size()):
				if item.points[p_i].distance_to(local_pos) <= 8.0:
					# Alt-click: convert corner <-> smooth
					if is_alt_pressed and item.curve_controls.size() > 0:
						var c_idx = min(p_i, item.curve_controls.size() - 1)
						var p_prev = item.points[max(0, p_i - 1)]
						var p_cur = item.points[p_i]
						# Toggle: if at node, pull out smooth handle, else collapse
						if item.curve_controls[c_idx].distance_to(p_cur) < 2.0:
							item.curve_controls[c_idx] = (p_prev + p_cur) * 0.5 + Vector2(10, -10)
						else:
							item.curve_controls[c_idx] = p_cur
						queue_redraw()
						return
						
					selected_subnode_idx = p_i
					selected_tangent_idx = -1
					is_dragging_subnode = true
					queue_redraw()
					return
					
	_handle_select_press(mouse_pos)
	selected_subnode_idx = -1
	selected_tangent_idx = -1

func _handle_pen_click(mouse_pos: Vector2) -> void:
	if selected_item_id != "" and items.has(selected_item_id) and items[selected_item_id].shape_type == "path":
		var cur_item: StageItem = items[selected_item_id]
		var t = current_transforms.get(selected_item_id, null)
		var local_pos = (mouse_pos - t.position).rotated(-t.rotation) / t.scale if t != null else mouse_pos
		
		# Jika klik mendekati titik awal (points[0]), tutup path dan isi fill!
		if cur_item.points.size() >= 3 and cur_item.points[0].distance_to(local_pos) <= 10.0:
			cur_item.points.append(cur_item.points[0])
			cur_item.color = current_fill_color
			selected_item_id = ""
			item_selected.emit("")
			queue_redraw()
			return
			
		cur_item.points.append(local_pos)
		if cur_item.points.size() > 1:
			var prev_pt = cur_item.points[-2]
			cur_item.curve_controls.append((prev_pt + local_pos) * 0.5)
		queue_redraw()
	else:
		var new_item = StageItem.new()
		new_item.id = "pen_" + str(Time.get_ticks_usec())
		new_item.name = "Pen Path"
		new_item.shape_type = "path"
		new_item.color = Color.TRANSPARENT
		new_item.stroke_color = current_stroke_color
		new_item.stroke_width = current_stroke_width
		new_item.points = PackedVector2Array([Vector2.ZERO])
		drawing_finished.emit(new_item, mouse_pos)
		selected_item_id = new_item.id
		item_selected.emit(new_item.id)

func _create_text_item(mouse_pos: Vector2) -> void:
	var new_item = StageItem.new()
	new_item.id = "text_" + str(Time.get_ticks_usec())
	new_item.name = "Text Label"
	new_item.shape_type = "text"
	new_item.text_content = "REanimate Text"
	new_item.size = Vector2(160, 40)
	new_item.color = current_fill_color
	new_item.font_size = text_font_size
	new_item.text_alignment = text_alignment
	new_item.is_dynamic = text_is_dynamic
	drawing_finished.emit(new_item, mouse_pos)

func _apply_ink_bottle(mouse_pos: Vector2) -> void:
	var hit_id = _hit_test_item(mouse_pos)
	if hit_id != "":
		var item: StageItem = items[hit_id]
		item.stroke_color = current_stroke_color
		item.stroke_width = current_stroke_width
		queue_redraw()

func _apply_paint_bucket(mouse_pos: Vector2) -> void:
	var hit_id = _hit_test_item(mouse_pos)
	if hit_id != "":
		var item: StageItem = items[hit_id]
		item.color = current_fill_color
		queue_redraw()

func _apply_eyedropper(mouse_pos: Vector2) -> void:
	var hit_id = _hit_test_item(mouse_pos)
	if hit_id != "":
		var item: StageItem = items[hit_id]
		color_sampled.emit(item.color, false)
		color_sampled.emit(item.stroke_color, true)

func _apply_eraser(mouse_pos: Vector2) -> void:
	var hit_id = _hit_test_item(mouse_pos)
	if hit_id != "":
		# Flash Eraser Faucet mode or Normal mode
		items.erase(hit_id)
		current_transforms.erase(hit_id)
		if selected_item_id == hit_id:
			selected_item_id = ""
			selected_item_ids.erase(hit_id)
			item_selected.emit("")
		item_deleted.emit(hit_id)
		queue_redraw()
