# Satu layer di dalam timeline yang berisi urutan keyframe (normal, guide, mask, masked, folder, audio)
class_name AnimationLayer
extends RefCounted

var id: String = ""
var name: String = "Layer"
var is_visible: bool = true
var is_locked: bool = false
var layer_type: String = "normal" # "normal", "guide", "mask", "masked", "folder", "audio"
var parent_folder: String = ""
var outline_color: Color = Color.TRANSPARENT
var is_outline_mode: bool = false

var audio_stream_path: String = ""
var audio_stream: AudioStream = null
var audio_volume_db: float = 0.0
var keyframes: Array[KeyframeData] = [] # Selalu diurutkan berdasarkan frame_index

func _init() -> void:
	id = "layer_" + str(Time.get_ticks_usec())

# Cari keyframe persis di frame_index
func get_keyframe_at(frame: int) -> KeyframeData:
	for k in keyframes:
		if k.frame_index == frame:
			return k
	return null

# Hapus keyframe di frame_index
func remove_keyframe_at(frame: int) -> bool:
	for i in range(keyframes.size()):
		if keyframes[i].frame_index == frame:
			keyframes.remove_at(i)
			return true
	return false

# Tambah atau update keyframe
func set_keyframe(kf: KeyframeData) -> void:
	for i in range(keyframes.size()):
		if keyframes[i].frame_index == kf.frame_index:
			keyframes[i] = kf
			_update_durations()
			return
	keyframes.append(kf)
	keyframes.sort_custom(func(a, b): return a.frame_index < b.frame_index)
	_update_durations()

func _update_durations() -> void:
	for i in range(keyframes.size()):
		if i < keyframes.size() - 1:
			keyframes[i].duration = keyframes[i + 1].frame_index - keyframes[i].frame_index

# Flash F5: Insert Frame Span (menggeser keyframe sesudahnya 1 langkah ke kanan)
func insert_frame_span(at_frame: int) -> void:
	for k in keyframes:
		if k.frame_index > at_frame:
			k.frame_index += 1
	keyframes.sort_custom(func(a, b): return a.frame_index < b.frame_index)
	_update_durations()

# Flash Shift+F5: Remove Frame Span (menggeser keyframe sesudahnya 1 langkah ke kiri)
func remove_frame_span(at_frame: int) -> void:
	var to_remove = -1
	for i in range(keyframes.size()):
		var k = keyframes[i]
		if k.frame_index == at_frame and i > 0:
			to_remove = i
		elif k.frame_index > at_frame:
			k.frame_index = maxi(0, k.frame_index - 1)
	if to_remove != -1:
		keyframes.remove_at(to_remove)
	keyframes.sort_custom(func(a, b): return a.frame_index < b.frame_index)
	_update_durations()

# Flash F7: Insert Blank Keyframe
func insert_blank_keyframe(at_frame: int) -> KeyframeData:
	var kf = KeyframeData.new()
	kf.frame_index = at_frame
	kf.elements.clear()
	kf.transforms.clear() # Kosong = Blank Keyframe
	kf.tween_type = "none"
	set_keyframe(kf)
	return kf

# Flash Shift+F6: Clear Keyframe (hapus keyframe tanpa menggeser frame)
func clear_keyframe(at_frame: int) -> bool:
	var res = remove_keyframe_at(at_frame)
	if res:
		_update_durations()
	return res

# Dapatkan transform terinterpolasi (tweening) pada frame apa pun
func get_interpolated_transform(item_id: String, frame: int) -> ItemTransform:
	if not is_visible or keyframes.is_empty():
		return null
	
	# Jika sebelum keyframe pertama
	if frame < keyframes[0].frame_index:
		return null
	
	# Jika setelah keyframe terakhir
	if frame >= keyframes[-1].frame_index:
		var last_kf = keyframes[-1]
		# Jika ada batas span duration eksplisit dan frame sudah melampaui span
		if last_kf.duration > 1 and frame >= last_kf.frame_index + last_kf.duration:
			return null
		return last_kf.transforms.get(item_id, null)
	
	# Cari antara dua keyframe (prev & next)
	var prev_kf: KeyframeData = null
	var next_kf: KeyframeData = null
	for k in keyframes:
		if k.frame_index <= frame:
			prev_kf = k
		elif k.frame_index > frame:
			next_kf = k
			break
			
	if prev_kf == null:
		return null
	if next_kf == null:
		return prev_kf.transforms.get(item_id, null)
		
	var t_prev = prev_kf.transforms.get(item_id, null)
	var t_next = next_kf.transforms.get(item_id, null)
	
	if t_prev == null:
		return null
	if t_next == null or (prev_kf.tween_type == "none" and prev_kf.tween_to_next == "none"):
		return t_prev
		
	# Interpolasi (Tweening) dengan Ease
	var span = next_kf.frame_index - prev_kf.frame_index
	if span <= 0:
		return t_prev
	var factor: float = float(frame - prev_kf.frame_index) / float(span)
	
	# Penerapan Flash Ease curve
	if prev_kf.ease != 0.0:
		var ease_ratio = clampf(prev_kf.ease / 100.0, -1.0, 1.0)
		if ease_ratio > 0.0:
			factor = factor * (1.0 - ease_ratio) + (1.0 - pow(1.0 - factor, 2.0)) * ease_ratio
		else:
			factor = factor * (1.0 + ease_ratio) + pow(factor, 2.0) * (-ease_ratio)
			
	var result = ItemTransform.interpolate(t_prev, t_next, factor)
	
	# Rotasi CW / CCW jika rotate_dir diset
	if prev_kf.rotate_dir == "cw":
		var total_rot = t_next.rotation - t_prev.rotation + TAU * prev_kf.rotate_times
		if total_rot < 0: total_rot += TAU
		result.rotation = t_prev.rotation + total_rot * factor
	elif prev_kf.rotate_dir == "ccw":
		var total_rot = t_next.rotation - t_prev.rotation - TAU * prev_kf.rotate_times
		if total_rot > 0: total_rot -= TAU
		result.rotation = t_prev.rotation + total_rot * factor
		
	return result

# Salin keyframe dalam rentang [start_f, end_f]
func copy_frames(start_f: int, end_f: int) -> Array[KeyframeData]:
	var result: Array[KeyframeData] = []
	for k in keyframes:
		if k.frame_index >= start_f and k.frame_index <= end_f:
			var dup = k.duplicate_keyframe()
			dup.frame_index = k.frame_index - start_f # Simpan relative offset
			result.append(dup)
	return result

# Tempel keyframe yang disalin ke posisi target_f
func paste_frames(target_f: int, copied_kfs: Array[KeyframeData]) -> void:
	for ck in copied_kfs:
		var new_kf = ck.duplicate_keyframe()
		new_kf.frame_index = target_f + ck.frame_index
		set_keyframe(new_kf)

# Balik urutan keyframes di antara [start_f, end_f] (Flash Reverse Frames)
func reverse_frames(start_f: int, end_f: int) -> void:
	var span_kfs: Array[KeyframeData] = []
	for k in keyframes:
		if k.frame_index >= start_f and k.frame_index <= end_f:
			span_kfs.append(k)
	if span_kfs.size() <= 1:
		return
		
	var orig_indices: Array[int] = []
	for k in span_kfs:
		orig_indices.append(k.frame_index)
	orig_indices.reverse()
	
	for i in range(span_kfs.size()):
		span_kfs[i].frame_index = orig_indices[i]
		
	keyframes.sort_custom(func(a, b): return a.frame_index < b.frame_index)
	_update_durations()

# Hapus keyframe di rentang (start_f, end_f] tanpa menggeser timeline
func clear_frames(start_f: int, end_f: int) -> void:
	var to_remove: Array[int] = []
	for i in range(keyframes.size()):
		var k = keyframes[i]
		if k.frame_index > start_f and k.frame_index <= end_f:
			to_remove.append(k.frame_index)
	for f in to_remove:
		remove_keyframe_at(f)
	_update_durations()

# Konversi seluruh frame di dalam rentang menjadi Keyframe penuh (F6 di setiap frame)
func convert_to_keyframes(start_f: int, end_f: int) -> void:
	for f in range(start_f, end_f + 1):
		if get_keyframe_at(f) == null:
			var active_kf: KeyframeData = null
			for k in keyframes:
				if k.frame_index <= f:
					active_kf = k
				else:
					break
			if active_kf != null:
				var new_kf = active_kf.duplicate_keyframe()
				new_kf.frame_index = f
				set_keyframe(new_kf)

# Pindahkan posisi keyframe (Drag Keyframe di timeline)
func drag_keyframe(from_f: int, to_f: int) -> void:
	var kf = get_keyframe_at(from_f)
	if kf == null or from_f == to_f:
		return
	remove_keyframe_at(from_f)
	kf.frame_index = to_f
	set_keyframe(kf)

# Ubah durasi span keyframe dengan menggeser keyframe sesudahnya
func resize_span(kf_frame: int, new_duration: int) -> void:
	var kf_idx = -1
	for i in range(keyframes.size()):
		if keyframes[i].frame_index == kf_frame:
			kf_idx = i
			break
	if kf_idx == -1:
		return
		
	var cur_dur = keyframes[kf_idx].duration
	var delta = new_duration - cur_dur
	if delta == 0:
		return
		
	for i in range(kf_idx + 1, keyframes.size()):
		keyframes[i].frame_index = maxi(keyframes[i - 1].frame_index + 1, keyframes[i].frame_index + delta)
		
	keyframes.sort_custom(func(a, b): return a.frame_index < b.frame_index)
	_update_durations()

# Dapatkan frame index berdasarkan label
func get_frame_by_label(lbl: String) -> int:
	for k in keyframes:
		if k.label == lbl:
			return k.frame_index
	return -1

# Dapatkan element terinterpolasi (Shape Tween / Classic Tween) pada frame tertentu
func get_interpolated_element(element_id: String, frame: int) -> Element:
	if not is_visible or keyframes.is_empty():
		return null
		
	if frame < keyframes[0].frame_index:
		return null
	if frame >= keyframes[-1].frame_index:
		var last_kf = keyframes[-1]
		if last_kf.duration > 1 and frame >= last_kf.frame_index + last_kf.duration:
			return null
		return last_kf.get_element(element_id)
		
	var prev_kf: KeyframeData = null
	var next_kf: KeyframeData = null
	for k in keyframes:
		if k.frame_index <= frame:
			prev_kf = k
		elif k.frame_index > frame:
			next_kf = k
			break
			
	if prev_kf == null:
		return null
	var el_prev = prev_kf.get_element(element_id)
	if el_prev == null:
		return null
	if next_kf == null or (prev_kf.tween_type == "none" and prev_kf.tween_to_next == "none"):
		return el_prev
		
	var el_next = next_kf.get_element(element_id)
	if el_next == null:
		return el_prev
		
	var span = next_kf.frame_index - prev_kf.frame_index
	if span <= 0:
		return el_prev
	var factor: float = float(frame - prev_kf.frame_index) / float(span)
	
	if prev_kf.ease != 0.0:
		var ease_ratio = clampf(prev_kf.ease / 100.0, -1.0, 1.0)
		if ease_ratio > 0.0:
			factor = factor * (1.0 - ease_ratio) + (1.0 - pow(1.0 - factor, 2.0)) * ease_ratio
		else:
			factor = factor * (1.0 + ease_ratio) + pow(factor, 2.0) * (-ease_ratio)
			
	# Jika Shape Tween antar dua ShapeElement:
	if (prev_kf.tween_type == "shape" or prev_kf.tween_to_next == "shape") and el_prev is ShapeElement and el_next is ShapeElement:
		var ste = preload("res://src/core/shape_tween_engine.gd")
		return ste.interpolate_shape(el_prev as ShapeElement, el_next as ShapeElement, factor)
		
	# Classic Tween / default: duplikasi el_prev dan update transform terinterpolasi
	var result_el = el_prev.duplicate_element()
	var t_interp = get_interpolated_transform(element_id, frame)
	if t_interp != null:
		result_el.transform = t_interp
		
	if el_prev is SymbolInstance and el_next is SymbolInstance:
		var si_prev = el_prev as SymbolInstance
		var si_next = el_next as SymbolInstance
		var si_res = result_el as SymbolInstance
		si_res.alpha = lerpf(si_prev.alpha, si_next.alpha, factor)
		si_res.tint_ratio = lerpf(si_prev.tint_ratio, si_next.tint_ratio, factor)
		si_res.tint_color = si_prev.tint_color.lerp(si_next.tint_color, factor)
		
	return result_el

func to_dict() -> Dictionary:
	var kfs: Array = []
	for k in keyframes:
		kfs.append(k.to_dict())
	return {
		"id": id,
		"name": name,
		"is_visible": is_visible,
		"is_locked": is_locked,
		"layer_type": layer_type,
		"parent_folder": parent_folder,
		"outline_color": [outline_color.r, outline_color.g, outline_color.b, outline_color.a],
		"is_outline_mode": is_outline_mode,
		"audio_stream_path": audio_stream_path,
		"audio_volume_db": audio_volume_db,
		"keyframes": kfs
	}

static func from_dict(d: Dictionary) -> AnimationLayer:
	var l = AnimationLayer.new()
	l.id = d.get("id", "layer_" + str(Time.get_ticks_usec()))
	l.name = d.get("name", "Layer")
	l.is_visible = bool(d.get("is_visible", true))
	l.is_locked = bool(d.get("is_locked", false))
	var lt = d.get("layer_type", "normal")
	l.layer_type = "normal" if lt == "graphic" else lt
	l.parent_folder = d.get("parent_folder", "")
	var oc = d.get("outline_color", [0.0, 0.0, 0.0, 0.0])
	l.outline_color = Color(oc[0], oc[1], oc[2], oc[3])
	l.is_outline_mode = bool(d.get("is_outline_mode", false))
	l.audio_stream_path = d.get("audio_stream_path", "")
	l.audio_volume_db = float(d.get("audio_volume_db", 0.0))
	var kfs_data = d.get("keyframes", [])
	for kd in kfs_data:
		l.keyframes.append(KeyframeData.from_dict(kd))
	l.keyframes.sort_custom(func(a, b): return a.frame_index < b.frame_index)
	l._update_durations()
	return l
