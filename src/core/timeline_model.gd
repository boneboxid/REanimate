# Reusable Timeline Model (untuk Scene dan Symbol/MovieClip)
class_name TimelineModel
extends RefCounted

var layers: Array[AnimationLayer] = []
var max_frames: int = 60

func _init() -> void:
	pass

func add_layer(layer: AnimationLayer) -> void:
	layers.append(layer)

func remove_layer(index: int) -> void:
	if index >= 0 and index < layers.size():
		layers.remove_at(index)

func insert_frame_all_layers(at_frame: int) -> void:
	max_frames += 1
	for l in layers:
		l.insert_frame_span(at_frame)

func remove_frame_all_layers(at_frame: int) -> void:
	if max_frames > 1:
		max_frames -= 1
	for l in layers:
		l.remove_frame_span(at_frame)

func reorder_layer(from_idx: int, to_idx: int) -> void:
	if from_idx < 0 or from_idx >= layers.size() or to_idx < 0 or to_idx >= layers.size() or from_idx == to_idx:
		return
	var l = layers[from_idx]
	layers.remove_at(from_idx)
	layers.insert(to_idx, l)

# Cek apakah layer pada index tertentu merupakan masked layer dan dapatkan layer mask-nya
func get_mask_for_layer(masked_layer_idx: int) -> AnimationLayer:
	if masked_layer_idx <= 0 or masked_layer_idx >= layers.size():
		return null
	var target = layers[masked_layer_idx]
	if target.layer_type != "masked":
		return null
	# Telusuri ke atas untuk mencari layer mask terdekat
	for i in range(masked_layer_idx - 1, -1, -1):
		if layers[i].layer_type == "mask":
			return layers[i]
		elif layers[i].layer_type != "masked":
			break
	return null

# Dapatkan seluruh layer di dalam folder tertentu
func get_layers_in_folder(folder_id: String) -> Array[AnimationLayer]:
	var result: Array[AnimationLayer] = []
	for l in layers:
		if l.parent_folder == folder_id:
			result.append(l)
	return result

# Cari frame index di seluruh layer berdasarkan label
func get_frame_by_label(lbl: String) -> int:
	for l in layers:
		var f = l.get_frame_by_label(lbl)
		if f != -1:
			return f
	return -1

func to_dict() -> Dictionary:
	var l_arr: Array = []
	for l in layers:
		l_arr.append(l.to_dict())
	return {
		"max_frames": max_frames,
		"layers": l_arr
	}

static func from_dict(d: Dictionary) -> TimelineModel:
	var tm = TimelineModel.new()
	tm.max_frames = int(d.get("max_frames", 60))
	var l_data = d.get("layers", [])
	for ld in l_data:
		tm.layers.append(AnimationLayer.from_dict(ld))
	return tm
