# Stage Canvas yang menangani render objek, selection, transform box, drag-and-drop, serta drawing (Brush/Line)
class_name StageCanvas
extends Node2D

signal item_selected(item_id: String)
signal item_transformed(item_id: String, new_transform: ItemTransform)
signal drawing_finished(new_item: StageItem, initial_pos: Vector2)

var stage_size: Vector2 = Vector2(800, 450)
var bg_color: Color = Color(0.98, 0.98, 0.98, 1.0)
var items: Dictionary = {} # id -> StageItem
var current_transforms: Dictionary = {} # id -> ItemTransform

var active_tool: String = "Select" # "Select", "Transform", "Brush", "Pen", "Rect", "Circle"
var current_draw_color: Color = Color(0.1, 0.1, 0.1, 1.0)
var current_stroke_width: float = 3.0

var selected_item_id: String = ""
var is_dragging: bool = false
var is_rotating: bool = false
var is_scaling: bool = false
var scale_handle_index: int = -1
var drag_offset: Vector2 = Vector2.ZERO

# State untuk Menggambar (Brush/Shape)
var is_drawing_stroke: bool = false
var current_stroke_points: PackedVector2Array = PackedVector2Array()
var shape_draw_start: Vector2 = Vector2.ZERO
var shape_draw_current: Vector2 = Vector2.ZERO

# Onion Skinning: Array of Dictionary { "transforms": Dictionary, "alpha": float }
var onion_skin_frames: Array[Dictionary] = []

func _ready() -> void:
	queue_redraw()

func set_stage_data(p_items: Dictionary, p_transforms: Dictionary, p_onion_skins: Array[Dictionary] = []) -> void:
	items = p_items
	current_transforms = p_transforms
	onion_skin_frames = p_onion_skins
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
	
	# 4. Gambar Objek Utama
	_draw_items_pass(current_transforms, 1.0, false)
	
	# 4. Preview saat menggambar Brush secara realtime
	if is_drawing_stroke and current_stroke_points.size() > 1:
		for i in range(current_stroke_points.size() - 1):
			draw_line(current_stroke_points[i], current_stroke_points[i+1], current_draw_color, current_stroke_width, true)
			
	# 5. Preview saat menggambar Shape (Rect / Circle) secara realtime
	if is_drawing_stroke and (active_tool == "Rect" or active_tool == "Circle"):
		var p1 = shape_draw_start
		var p2 = shape_draw_current
		var preview_rect = Rect2(min(p1.x, p2.x), min(p1.y, p2.y), abs(p2.x - p1.x), abs(p2.y - p1.y))
		if active_tool == "Rect":
			draw_rect(preview_rect, current_draw_color)
			draw_rect(preview_rect, Color(0.1, 0.1, 0.1, 1.0), false, 2.0)
		elif active_tool == "Circle":
			var center = (p1 + p2) * 0.5
			var radius = p1.distance_to(p2) * 0.5
			draw_circle(center, radius, current_draw_color)
			draw_arc(center, radius, 0, TAU, 32, Color(0.1, 0.1, 0.1, 1.0), 2.0)
			
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
		
		if item.shape_type == "rect":
			draw_rect(item_rect, draw_color)
			if item.stroke_width > 0:
				draw_rect(item_rect, stroke_col, false, item.stroke_width)
		elif item.shape_type == "circle":
			draw_circle(Vector2.ZERO, half_size.x, draw_color)
			if item.stroke_width > 0:
				draw_arc(Vector2.ZERO, half_size.x, 0, TAU, 32, stroke_col, item.stroke_width)
		elif item.shape_type == "path" and item.points.size() > 1:
			for i in range(item.points.size() - 1):
				draw_line(item.points[i], item.points[i+1], stroke_col, item.stroke_width, true)
		elif item.shape_type == "sprite" and item.texture != null:
			draw_texture_rect(item.texture, item_rect, false, draw_color)
			
		# Gambar Bounding Box & Transformation Handles (hanya untuk frame aktif, bukan ghost)
		if not is_ghost and id == selected_item_id:
			# Selection rectangle
			draw_rect(item_rect, Color(0.2, 0.6, 1.0, 1.0), false, 2.0)
			# Pivot point (tengah)
			draw_circle(Vector2.ZERO, 4.0, Color(0.2, 0.6, 1.0, 1.0))
			# Rotation Handle di atas
			var rot_pos = Vector2(0, -half_size.y - 16)
			draw_line(Vector2(0, -half_size.y), rot_pos, Color(0.2, 0.8, 0.3, 1.0), 1.5)
			draw_circle(rot_pos, 5.0, Color(0.2, 0.8, 0.3, 1.0))
			# 4 Sudut Scale Handles
			var handles = [
				-half_size, # Kiri atas
				Vector2(half_size.x, -half_size.y), # Kanan atas
				half_size, # Kanan bawah
				Vector2(-half_size.x, half_size.y) # Kiri bawah
			]
			for h in handles:
				draw_rect(Rect2(h - Vector2(4, 4), Vector2(8, 8)), Color(1.0, 1.0, 1.0, 1.0))
				draw_rect(Rect2(h - Vector2(4, 4), Vector2(8, 8)), Color(0.2, 0.6, 1.0, 1.0), false, 1.5)
				
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var local_mouse = to_local(get_global_mouse_position())
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_handle_press(local_mouse)
			else:
				_handle_release(local_mouse)
	elif event is InputEventMouseMotion:
		var local_mouse = to_local(get_global_mouse_position())
		_handle_motion(local_mouse)

func _handle_press(mouse_pos: Vector2) -> void:
	if active_tool == "Select" or active_tool == "Transform":
		_handle_select_press(mouse_pos)
	elif active_tool == "Brush":
		is_drawing_stroke = true
		current_stroke_points = PackedVector2Array([mouse_pos])
		queue_redraw()
	elif active_tool == "Rect" or active_tool == "Circle":
		is_drawing_stroke = true
		shape_draw_start = mouse_pos
		shape_draw_current = mouse_pos
		queue_redraw()

func _handle_motion(mouse_pos: Vector2) -> void:
	if active_tool == "Select" or active_tool == "Transform":
		if selected_item_id != "" and current_transforms.has(selected_item_id):
			var t: ItemTransform = current_transforms[selected_item_id]
			if is_dragging:
				t.position = mouse_pos - drag_offset
				item_transformed.emit(selected_item_id, t)
				queue_redraw()
			elif is_rotating:
				var dir = mouse_pos - t.position
				t.rotation = dir.angle() + (PI / 2.0)
				item_transformed.emit(selected_item_id, t)
				queue_redraw()
	elif active_tool == "Brush" and is_drawing_stroke:
		if current_stroke_points.is_empty() or current_stroke_points[-1].distance_to(mouse_pos) > 4.0:
			current_stroke_points.append(mouse_pos)
			queue_redraw()
	elif (active_tool == "Rect" or active_tool == "Circle") and is_drawing_stroke:
		shape_draw_current = mouse_pos
		queue_redraw()

func _handle_release(mouse_pos: Vector2) -> void:
	if is_dragging or is_rotating or is_scaling:
		is_dragging = false
		is_rotating = false
		is_scaling = false
		return
		
	if is_drawing_stroke:
		is_drawing_stroke = false
		if active_tool == "Brush" and current_stroke_points.size() > 1:
			var new_item = StageItem.new()
			new_item.id = "stroke_" + str(Time.get_ticks_usec())
			new_item.name = "Brush Stroke"
			new_item.shape_type = "path"
			new_item.stroke_color = current_draw_color
			new_item.stroke_width = current_stroke_width
			
			# Normalize points relatif terhadap center
			var center = Vector2.ZERO
			for p in current_stroke_points:
				center += p
			center /= float(current_stroke_points.size())
			
			var rel_pts = PackedVector2Array()
			for p in current_stroke_points:
				rel_pts.append(p - center)
			new_item.points = rel_pts
			
			current_stroke_points.clear()
			drawing_finished.emit(new_item, center)
			queue_redraw()
			
		elif (active_tool == "Rect" or active_tool == "Circle"):
			var p1 = shape_draw_start
			var p2 = shape_draw_current
			var sz = Vector2(abs(p2.x - p1.x), abs(p2.y - p1.y))
			if sz.x > 5 and sz.y > 5:
				var center = (p1 + p2) * 0.5
				var new_item = StageItem.new()
				new_item.id = ("rect_" if active_tool == "Rect" else "circle_") + str(Time.get_ticks_usec())
				new_item.name = "Shape " + active_tool
				new_item.shape_type = "rect" if active_tool == "Rect" else "circle"
				new_item.size = sz
				new_item.color = current_draw_color
				new_item.stroke_color = Color(0.15, 0.15, 0.15, 1.0)
				new_item.stroke_width = 2.0
				
				drawing_finished.emit(new_item, center)
			queue_redraw()

func _handle_select_press(mouse_pos: Vector2) -> void:
	# Cek apakah klik objek terpilih untuk rotasi
	if selected_item_id != "" and current_transforms.has(selected_item_id):
		var cur_t: ItemTransform = current_transforms[selected_item_id]
		var cur_item: StageItem = items[selected_item_id]
		var rot_handle_pos = cur_t.position + Vector2(0, -(cur_item.size.y * 0.5 * cur_t.scale.y) - 16).rotated(cur_t.rotation)
		if mouse_pos.distance_to(rot_handle_pos) <= 12.0:
			is_rotating = true
			return
			
	# Hit-testing objek
	for id in items:
		var t: ItemTransform = current_transforms.get(id, null)
		var item: StageItem = items[id]
		if t == null: continue
		
		var local_to_item = (mouse_pos - t.position).rotated(-t.rotation) / t.scale
		var half_size = item.size * 0.5
		var is_hit: bool = false
		
		if item.shape_type == "rect" or item.shape_type == "sprite":
			is_hit = Rect2(-half_size, item.size).has_point(local_to_item)
		elif item.shape_type == "circle":
			is_hit = local_to_item.length() <= half_size.x
		elif item.shape_type == "path":
			# Hit-test jika dekat dengan salah satu titik path
			for pt in item.points:
				if pt.distance_to(local_to_item) <= max(10.0, item.stroke_width):
					is_hit = true
					break
					
		if is_hit:
			selected_item_id = id
			is_dragging = true
			drag_offset = mouse_pos - t.position
			item_selected.emit(id)
			queue_redraw()
			return
			
	# Deselect jika klik area kosong
	if selected_item_id != "":
		selected_item_id = ""
		item_selected.emit("")
		queue_redraw()
