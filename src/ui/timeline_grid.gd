# Timeline Grid visual yang menampilkan baris layer, nomor frame, status keyframe, dan playhead scrubber khas Flash
class_name TimelineGrid
extends Control

signal frame_clicked(frame_index: int)
signal frame_range_selected(layer_idx: int, start_f: int, end_f: int)
signal keyframe_action_requested(action: String, layer_idx: int, frame_index: int)
signal keyframe_dragged(layer_idx: int, from_f: int, to_f: int)

var cell_width: float = 16.0
var row_height: float = 24.0
var ruler_height: float = 22.0
var total_frames: int = 60
var current_frame: int = 0

var layers: Array[AnimationLayer] = []
var active_layer_index: int = 0

# Span selection
var sel_start_frame: int = -1
var sel_end_frame: int = -1
var sel_layer_idx: int = -1
var is_selecting_range: bool = false

# Dragging keyframe
var is_dragging_kf: bool = false
var drag_source_frame: int = -1
var drag_source_layer: int = -1

# Onion Skin range
var is_onion_skin_enabled: bool = false
var onion_prev_frames: int = 2
var onion_next_frames: int = 2

var context_menu: PopupMenu

func _ready() -> void:
	_setup_context_menu()
	_update_min_size()

func _setup_context_menu() -> void:
	context_menu = PopupMenu.new()
	context_menu.name = "TimelineContextMenu"
	context_menu.add_item("Create Classic Tween", 1)
	context_menu.add_item("Create Shape Tween", 2)
	context_menu.add_separator()
	context_menu.add_item("Insert Frame (F5)", 3)
	context_menu.add_item("Remove Frames (Shift+F5)", 4)
	context_menu.add_item("Insert Keyframe (F6)", 5)
	context_menu.add_item("Clear Keyframe (Shift+F6)", 6)
	context_menu.add_item("Insert Blank Keyframe (F7)", 7)
	context_menu.add_separator()
	context_menu.add_item("Convert to Keyframes", 8)
	context_menu.add_item("Reverse Frames", 9)
	context_menu.add_item("Clear Frames", 10)
	context_menu.add_separator()
	context_menu.add_item("Copy Frames", 11)
	context_menu.add_item("Paste Frames", 12)
	
	context_menu.id_pressed.connect(_on_context_menu_item_selected)
	add_child(context_menu)

func _on_context_menu_item_selected(id: int) -> void:
	var action_map = {
		1: "create_classic_tween",
		2: "create_shape_tween",
		3: "insert_frame",
		4: "remove_frame",
		5: "insert_keyframe",
		6: "clear_keyframe",
		7: "insert_blank_keyframe",
		8: "convert_to_keyframes",
		9: "reverse_frames",
		10: "clear_frames",
		11: "copy_frames",
		12: "paste_frames"
	}
	if action_map.has(id):
		var act = action_map[id]
		var target_f = current_frame if sel_start_frame == -1 else sel_start_frame
		var target_layer = active_layer_index if sel_layer_idx == -1 else sel_layer_idx
		keyframe_action_requested.emit(act, target_layer, target_f)

func _update_min_size() -> void:
	var total_h = ruler_height + max(1, layers.size()) * row_height
	custom_minimum_size = Vector2(total_frames * cell_width, total_h)
	queue_redraw()

func set_timeline_state(p_layers: Array[AnimationLayer], p_active_layer: int, p_frame: int, p_max_frames: int) -> void:
	layers = p_layers
	active_layer_index = p_active_layer
	current_frame = p_frame
	total_frames = p_max_frames
	_update_min_size()

func set_cell_width(new_w: float) -> void:
	cell_width = clampf(new_w, 8.0, 48.0)
	_update_min_size()

func select_frame_range(layer_idx: int, start_f: int, end_f: int) -> void:
	sel_layer_idx = layer_idx
	sel_start_frame = mini(start_f, end_f)
	sel_end_frame = maxi(start_f, end_f)
	frame_range_selected.emit(sel_layer_idx, sel_start_frame, sel_end_frame)
	queue_redraw()

func clear_selection() -> void:
	sel_start_frame = -1
	sel_end_frame = -1
	sel_layer_idx = -1
	queue_redraw()

func _draw() -> void:
	var total_w = total_frames * cell_width
	var total_h = ruler_height + max(1, layers.size()) * row_height
	
	# 1. Background Timeline Charcoal resmi Adobe
	draw_rect(Rect2(Vector2.ZERO, Vector2(total_w, total_h)), Color(0.18, 0.18, 0.20, 1.0))
	
	# 2. Header Ruler (Nomor frame khas Flash)
	draw_rect(Rect2(0, 0, total_w, ruler_height), Color(0.13, 0.13, 0.15, 1.0))
	for f in range(total_frames):
		var x = f * cell_width
		draw_line(Vector2(x, 14), Vector2(x, ruler_height), Color(0.32, 0.32, 0.36, 1.0))
		if f % 5 == 0:
			draw_line(Vector2(x, 6), Vector2(x, ruler_height), Color(0.7, 0.7, 0.75, 1.0))
			draw_string(ThemeDB.fallback_font, Vector2(x + 2, 13), str(f + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.8, 0.8, 0.85, 1.0))
			
	# Onion Skin Marker Range di Header Ruler
	if is_onion_skin_enabled:
		var o_start_f = maxi(0, current_frame - onion_prev_frames)
		var o_end_f = mini(total_frames - 1, current_frame + onion_next_frames)
		var o_rect = Rect2(o_start_f * cell_width, 1, (o_end_f - o_start_f + 1) * cell_width, ruler_height - 2)
		draw_rect(o_rect, Color(0.2, 0.6, 0.9, 0.25))
		draw_rect(o_rect, Color(0.3, 0.7, 1.0, 0.8), false, 1.5)
		
	# 3. Gambar Baris-Baris Layer
	for i in range(layers.size()):
		var layer = layers[i]
		var y = ruler_height + (i * row_height)
		var is_active = (i == active_layer_index)
		
		# Background baris layer
		var row_col = Color(0.24, 0.24, 0.28, 1.0) if is_active else Color(0.19, 0.19, 0.22, 1.0)
		draw_rect(Rect2(0, y, total_w, row_height), row_col)
		
		# Jika Audio Layer: Gambarkan Gelombang Audio Waveform
		if layer.layer_type == "audio":
			draw_rect(Rect2(0, y, total_w, row_height), Color(0.18, 0.25, 0.22, 1.0))
			var wave_center_y = y + (row_height * 0.5)
			for wf in range(total_frames):
				var wx = wf * cell_width
				var amp = (sin(float(wf) * 0.8) * 0.4 + cos(float(wf) * 1.5) * 0.3) * (row_height * 0.4)
				draw_line(Vector2(wx + (cell_width * 0.5), wave_center_y - abs(amp)), Vector2(wx + (cell_width * 0.5), wave_center_y + abs(amp)), Color(0.3, 0.85, 0.5, 0.8), 1.5)
				
		# Gambar Keyframes & Tween spans khas Flash
		var kfs = layer.keyframes
		for k_idx in range(kfs.size()):
			var kf = kfs[k_idx]
			var kf_x = kf.frame_index * cell_width
			var is_blank = kf.transforms.is_empty() and kf.elements.is_empty()
			
			# Jika ada keyframe berikutnya, gambar span tween / hold
			var span_w = cell_width
			if k_idx + 1 < kfs.size():
				span_w = (kfs[k_idx + 1].frame_index - kf.frame_index) * cell_width
			else:
				span_w = (total_frames - kf.frame_index) * cell_width
				
			if span_w > cell_width:
				if kf.tween_type == "classic" or kf.tween_to_next == "linear":
					# Classic Motion Tween span: Biru muda lembut (#99CCFF)
					var tween_col = Color(0.60, 0.80, 1.0, 0.85)
					draw_rect(Rect2(kf_x + 1, y + 1, span_w - 1, row_height - 2), tween_col)
					# Garis panah hitam kontinu khas Flash
					var arrow_y = y + (row_height * 0.5)
					var arrow_end_x = kf_x + span_w - 6
					draw_line(Vector2(kf_x + 10, arrow_y), Vector2(arrow_end_x, arrow_y), Color(0.1, 0.1, 0.15, 0.9), 1.5)
					var arrow_head = PackedVector2Array([
						Vector2(arrow_end_x, arrow_y),
						Vector2(arrow_end_x - 5, arrow_y - 3),
						Vector2(arrow_end_x - 5, arrow_y + 3)
					])
					draw_colored_polygon(arrow_head, Color(0.1, 0.1, 0.15, 0.9))
				elif kf.tween_type == "shape" or kf.tween_to_next == "shape":
					# Shape Tween: Hijau muda lembut (#99FF99)
					var shape_tween_col = Color(0.60, 1.0, 0.60, 0.85)
					draw_rect(Rect2(kf_x + 1, y + 1, span_w - 1, row_height - 2), shape_tween_col)
					var arrow_y = y + (row_height * 0.5)
					var arrow_end_x = kf_x + span_w - 6
					draw_line(Vector2(kf_x + 10, arrow_y), Vector2(arrow_end_x, arrow_y), Color(0.1, 0.1, 0.15, 0.9), 1.5)
				else:
					# Hold Frame Span: Kotak abu-abu terang / putih lembut di akhir span
					draw_rect(Rect2(kf_x + cell_width, y + 1, span_w - cell_width, row_height - 2), Color(0.78, 0.78, 0.80, 0.6))
					var end_rect = Rect2(kf_x + span_w - cell_width + 2, y + 3, cell_width - 4, row_height - 6)
					draw_rect(end_rect, Color(0.9, 0.9, 0.9, 0.95))
					draw_rect(end_rect, Color(0.2, 0.2, 0.2, 1.0), false, 1.0)
					
			# Frame Label flag khas Flash
			if kf.label != "":
				draw_string(ThemeDB.fallback_font, Vector2(kf_x + 2, y + 10), kf.label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.9, 0.3, 0.3, 1.0))
				
			# Bulat Keyframe Khas Flash:
			var dot_center = Vector2(kf_x + (cell_width * 0.5), y + (row_height * 0.5))
			if is_blank:
				# Blank Keyframe (F7): Bulat berongga (lingkaran putih dengan garis hitam)
				draw_circle(dot_center, 4.0, Color.WHITE)
				draw_arc(dot_center, 4.0, 0, TAU, 16, Color(0.1, 0.1, 0.1, 1.0), 1.5)
			else:
				# Keyframe berobjek (F6): Bulat hitam pekat
				draw_circle(dot_center, 4.5, Color(0.1, 0.1, 0.1, 1.0))
				draw_circle(dot_center, 2.5, Color(0.2, 0.2, 0.2, 1.0))
				
		# Highlight span selection jika berada di layer ini
		if (sel_layer_idx == -1 or sel_layer_idx == i) and sel_start_frame >= 0 and sel_end_frame >= sel_start_frame:
			var sel_x = sel_start_frame * cell_width
			var sel_w = (sel_end_frame - sel_start_frame + 1) * cell_width
			var sel_rect = Rect2(sel_x, y, sel_w, row_height)
			draw_rect(sel_rect, Color(0.95, 0.75, 0.2, 0.35))
			draw_rect(sel_rect, Color(0.95, 0.85, 0.3, 0.9), false, 1.5)
			
		# Garis horizontal pemisah antar layer
		draw_line(Vector2(0, y + row_height), Vector2(total_w, y + row_height), Color(0.12, 0.12, 0.14, 1.0))
		
	# 4. Garis vertikal pembagi setiap frame
	for f in range(total_frames):
		var x = f * cell_width
		draw_line(Vector2(x, ruler_height), Vector2(x, total_h), Color(0.25, 0.25, 0.28, 0.7))
		
	# 5. Playhead Khas Flash (Kepala Merah + Garis Vertikal Penembus Seluruh Layer)
	var playhead_x = current_frame * cell_width + (cell_width * 0.5)
	var marker_poly = PackedVector2Array([
		Vector2(playhead_x - 5, 0),
		Vector2(playhead_x + 5, 0),
		Vector2(playhead_x + 5, 14),
		Vector2(playhead_x, ruler_height),
		Vector2(playhead_x - 5, 14)
	])
	draw_colored_polygon(marker_poly, Color(0.95, 0.24, 0.24, 1.0))
	draw_line(Vector2(playhead_x, ruler_height), Vector2(playhead_x, total_h), Color(0.95, 0.24, 0.24, 0.95), 1.5)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var clicked_frame = int(event.position.x / cell_width)
		clicked_frame = clampi(clicked_frame, 0, total_frames - 1)
		var clicked_layer = -1
		if event.position.y > ruler_height:
			clicked_layer = int((event.position.y - ruler_height) / row_height)
			clicked_layer = clampi(clicked_layer, 0, layers.size() - 1)
			
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if Input.is_key_pressed(KEY_SHIFT) and sel_start_frame != -1:
					# Shift-click span range selection
					select_frame_range(clicked_layer if clicked_layer != -1 else active_layer_index, sel_start_frame, clicked_frame)
				else:
					# Check if clicking on an existing keyframe to start dragging
					if clicked_layer >= 0 and clicked_layer < layers.size():
						var kf = layers[clicked_layer].get_keyframe_at(clicked_frame)
						if kf != null:
							is_dragging_kf = true
							drag_source_frame = clicked_frame
							drag_source_layer = clicked_layer
							
					select_frame_range(clicked_layer if clicked_layer != -1 else active_layer_index, clicked_frame, clicked_frame)
					is_selecting_range = true
					frame_clicked.emit(clicked_frame)
			else:
				if is_dragging_kf and drag_source_frame != -1 and drag_source_layer != -1:
					if drag_source_frame != clicked_frame:
						keyframe_dragged.emit(drag_source_layer, drag_source_frame, clicked_frame)
					is_dragging_kf = false
					drag_source_frame = -1
					drag_source_layer = -1
				is_selecting_range = false
				
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			# Context menu on right click
			if clicked_layer != -1:
				active_layer_index = clicked_layer
			current_frame = clicked_frame
			if sel_start_frame == -1:
				select_frame_range(active_layer_index, clicked_frame, clicked_frame)
			context_menu.position = Vector2i(get_global_mouse_position())
			context_menu.popup()
			
	elif event is InputEventMouseMotion:
		var hovered_frame = int(event.position.x / cell_width)
		hovered_frame = clampi(hovered_frame, 0, total_frames - 1)
		if is_selecting_range:
			select_frame_range(sel_layer_idx, sel_start_frame, hovered_frame)
			frame_clicked.emit(hovered_frame)
		elif event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			frame_clicked.emit(hovered_frame)
