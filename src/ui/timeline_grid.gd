# Timeline Grid visual yang menampilkan baris layer, nomor frame, status keyframe, dan playhead scrubber
class_name TimelineGrid
extends Control

signal frame_clicked(frame_index: int)
signal keyframe_action_requested(action: String, frame_index: int)

var cell_width: float = 16.0
var row_height: float = 24.0
var ruler_height: float = 22.0
var total_frames: int = 60
var current_frame: int = 0

var layers: Array[AnimationLayer] = []
var active_layer_index: int = 0

func _ready() -> void:
	_update_min_size()

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


func _draw() -> void:
	var total_w = total_frames * cell_width
	var total_h = ruler_height + max(1, layers.size()) * row_height
	
	# Background
	draw_rect(Rect2(Vector2.ZERO, Vector2(total_w, total_h)), Color(0.16, 0.16, 0.18, 1.0))
	
	# Header Ruler (Nomor frame)
	draw_rect(Rect2(0, 0, total_w, ruler_height), Color(0.12, 0.12, 0.14, 1.0))
	for f in range(total_frames):
		var x = f * cell_width
		draw_line(Vector2(x, 14), Vector2(x, ruler_height), Color(0.3, 0.3, 0.35, 1.0))
		if f % 5 == 0:
			draw_line(Vector2(x, 6), Vector2(x, ruler_height), Color(0.65, 0.65, 0.7, 1.0))
			draw_string(ThemeDB.fallback_font, Vector2(x + 2, 14), str(f), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.75, 0.75, 0.75, 1.0))
			
	# Gambar Baris Layer
	for i in range(layers.size()):
		var layer = layers[i]
		var y = ruler_height + (i * row_height)
		var is_active = (i == active_layer_index)
		
		# Background baris layer
		var row_col = Color(0.22, 0.22, 0.26, 1.0) if is_active else Color(0.18, 0.18, 0.21, 1.0)
		draw_rect(Rect2(0, y, total_w, row_height), row_col)
		
		# Gambar Keyframes & Tween spans
		var kfs = layer.keyframes
		for k_idx in range(kfs.size()):
			var kf = kfs[k_idx]
			var kf_x = kf.frame_index * cell_width
			
			# Jika ada keyframe berikutnya, gambar kotak tween
			if k_idx + 1 < kfs.size():
				var next_kf = kfs[k_idx + 1]
				var span_w = (next_kf.frame_index - kf.frame_index) * cell_width
				var tween_col = Color(0.2, 0.5, 0.85, 0.45) if kf.tween_to_next == "linear" else Color(0.3, 0.3, 0.3, 0.35)
				draw_rect(Rect2(kf_x, y, span_w, row_height), tween_col)
				# Garis panah tween khas Flash
				draw_line(Vector2(kf_x + 8, y + (row_height * 0.5)), Vector2(kf_x + span_w - 4, y + (row_height * 0.5)), Color(0.4, 0.7, 1.0, 0.85), 1.5)
				
			# Dot Keyframe khas Flash
			var dot_center = Vector2(kf_x + (cell_width * 0.5), y + (row_height * 0.5))
			draw_circle(dot_center, 4.5, Color(0.1, 0.1, 0.1, 1.0))
			draw_circle(dot_center, 2.8, Color(1.0, 1.0, 1.0, 1.0))
			
		# Garis horizontal pemisah antar layer
		draw_line(Vector2(0, y + row_height), Vector2(total_w, y + row_height), Color(0.12, 0.12, 0.14, 1.0))
		
	# Garis vertikal pembagi setiap frame
	for f in range(total_frames):
		var x = f * cell_width
		draw_line(Vector2(x, ruler_height), Vector2(x, total_h), Color(0.25, 0.25, 0.28, 1.0))
		
	# Playhead Khas Flash (Merah)
	var playhead_x = current_frame * cell_width + (cell_width * 0.5)
	var marker_poly = PackedVector2Array([
		Vector2(playhead_x - 5, 0),
		Vector2(playhead_x + 5, 0),
		Vector2(playhead_x + 5, 14),
		Vector2(playhead_x, ruler_height),
		Vector2(playhead_x - 5, 14)
	])
	draw_colored_polygon(marker_poly, Color(0.95, 0.22, 0.22, 1.0))
	draw_line(Vector2(playhead_x, ruler_height), Vector2(playhead_x, total_h), Color(0.95, 0.22, 0.22, 0.95), 1.5)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var clicked_frame = int(event.position.x / cell_width)
			clicked_frame = clampi(clicked_frame, 0, total_frames - 1)
			frame_clicked.emit(clicked_frame)
	elif event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			var scrubbed_frame = int(event.position.x / cell_width)
			scrubbed_frame = clampi(scrubbed_frame, 0, total_frames - 1)
			frame_clicked.emit(scrubbed_frame)
