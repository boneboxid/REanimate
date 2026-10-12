# Touch & Stylus Gesture Handler untuk Android Tablet dan Desktop Touchscreens
class_name TouchInputHandler
extends RefCounted

signal pinch_zoom_requested(scale_factor: float, center_pos: Vector2)
signal touch_pan_requested(relative_delta: Vector2)
signal touch_rotate_requested(angle_delta: float)
signal stylus_stroke_point(pos: Vector2, pressure: float)

# State Multi-touch
var active_touches: Dictionary = {} # index -> Vector2 pos
var prev_pinch_distance: float = 0.0
var prev_pinch_angle: float = 0.0
var prev_midpoint: Vector2 = Vector2.ZERO

# State Stylus & Palm Rejection
var is_stylus_active: bool = false
var stylus_last_time_msec: int = 0
var palm_rejection_window_msec: int = 400 # Abaikan sentuhan jari 400ms setelah stylus diangkat

func handle_input_event(event: InputEvent) -> bool:
	var cur_time = Time.get_ticks_msec()
	
	# 1. Stylus Detection & Pressure
	if event is InputEventMouseMotion:
		if event.pressure > 0.0:
			is_stylus_active = true
			stylus_last_time_msec = cur_time
			stylus_stroke_point.emit(event.position, event.pressure)
		elif is_stylus_active and (cur_time - stylus_last_time_msec > palm_rejection_window_msec):
			is_stylus_active = false
			
	# 2. Multi-Touch Screen Events (Finger / Stylus Touch)
	if event is InputEventScreenTouch:
		if event.pressed:
			# Palm Rejection: Jika stylus sedang aktif atau baru saja aktif, abaikan touch jari non-stylus
			if is_stylus_active and (cur_time - stylus_last_time_msec < palm_rejection_window_msec):
				return true
				
			active_touches[event.index] = event.position
			if active_touches.size() == 2:
				_init_two_finger_gesture()
		else:
			active_touches.erase(event.index)
			if active_touches.size() < 2:
				prev_pinch_distance = 0.0
				prev_pinch_angle = 0.0
		return active_touches.size() >= 2
		
	# 3. Touch Drag / Drag Motion
	elif event is InputEventScreenDrag:
		active_touches[event.index] = event.position
		
		# Dua jari: Pinch-to-zoom, Pan, & Rotate canvas
		if active_touches.size() == 2:
			var touch_keys = active_touches.keys()
			var p1: Vector2 = active_touches[touch_keys[0]]
			var p2: Vector2 = active_touches[touch_keys[1]]
			
			var cur_dist = p1.distance_to(p2)
			var cur_midpoint = (p1 + p2) * 0.5
			var cur_angle = (p2 - p1).angle()
			
			if prev_pinch_distance > 0.0:
				# Pinch Zoom
				var scale_delta = cur_dist / prev_pinch_distance
				if abs(scale_delta - 1.0) > 0.005:
					pinch_zoom_requested.emit(scale_delta, cur_midpoint)
					
				# Two-finger Pan
				var pan_delta = cur_midpoint - prev_midpoint
				if pan_delta.length() > 0.5:
					touch_pan_requested.emit(pan_delta)
					
				# Two-finger Rotate
				var angle_delta = cur_angle - prev_pinch_angle
				if abs(angle_delta) > 0.02:
					touch_rotate_requested.emit(angle_delta)
					
			prev_pinch_distance = cur_dist
			prev_midpoint = cur_midpoint
			prev_pinch_angle = cur_angle
			return true
			
		elif active_touches.size() == 1:
			# Palm rejection check
			if is_stylus_active and (cur_time - stylus_last_time_msec < palm_rejection_window_msec):
				return true
				
	return false

func _init_two_finger_gesture() -> void:
	if active_touches.size() == 2:
		var touch_keys = active_touches.keys()
		var p1: Vector2 = active_touches[touch_keys[0]]
		var p2: Vector2 = active_touches[touch_keys[1]]
		prev_pinch_distance = p1.distance_to(p2)
		prev_midpoint = (p1 + p2) * 0.5
		prev_pinch_angle = (p2 - p1).angle()
