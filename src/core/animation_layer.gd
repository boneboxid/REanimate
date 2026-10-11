# Satu layer di dalam timeline yang berisi urutan keyframe
class_name AnimationLayer
extends RefCounted

var id: String = ""
var name: String = "Layer"
var is_visible: bool = true
var is_locked: bool = false
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
			return
	keyframes.append(kf)
	keyframes.sort_custom(func(a, b): return a.frame_index < b.frame_index)

# Dapatkan transform terinterpolasi (tweening) pada frame apa pun
func get_interpolated_transform(item_id: String, frame: int) -> ItemTransform:
	if not is_visible or keyframes.is_empty():
		return null
	
	# Jika sebelum keyframe pertama
	if frame <= keyframes[0].frame_index:
		return keyframes[0].transforms.get(item_id, null)
	
	# Jika setelah keyframe terakhir
	if frame >= keyframes[-1].frame_index:
		return keyframes[-1].transforms.get(item_id, null)
	
	# Cari antara dua keyframe (prev & next)
	var prev_kf: KeyframeData = null
	var next_kf: KeyframeData = null
	for k in keyframes:
		if k.frame_index <= frame:
			prev_kf = k
		elif k.frame_index > frame:
			next_kf = k
			break
			
	if prev_kf == null or next_kf == null:
		return null
		
	var t_prev = prev_kf.transforms.get(item_id, null)
	var t_next = next_kf.transforms.get(item_id, null)
	
	if t_prev == null:
		return t_next
	if t_next == null or prev_kf.tween_to_next == "none":
		return t_prev
		
	# Interpolasi (Tweening)
	var span = next_kf.frame_index - prev_kf.frame_index
	if span <= 0:
		return t_prev
	var factor: float = float(frame - prev_kf.frame_index) / float(span)
	return ItemTransform.interpolate(t_prev, t_next, factor)

func to_dict() -> Dictionary:
	var kfs: Array = []
	for k in keyframes:
		kfs.append(k.to_dict())
	return {
		"id": id,
		"name": name,
		"is_visible": is_visible,
		"is_locked": is_locked,
		"keyframes": kfs
	}

static func from_dict(d: Dictionary) -> AnimationLayer:
	var l = AnimationLayer.new()
	l.id = d.get("id", "layer_" + str(Time.get_ticks_usec()))
	l.name = d.get("name", "Layer")
	l.is_visible = bool(d.get("is_visible", true))
	l.is_locked = bool(d.get("is_locked", false))
	var kfs_data = d.get("keyframes", [])
	for kd in kfs_data:
		l.keyframes.append(KeyframeData.from_dict(kd))
	l.keyframes.sort_custom(func(a, b): return a.frame_index < b.frame_index)
	return l
