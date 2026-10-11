# Satu keyframe pada frame tertentu
class_name KeyframeData
extends RefCounted

var frame_index: int = 0
# Map item_id -> ItemTransform
var transforms: Dictionary = {}
# Jenis tweening ke keyframe berikutnya: "linear", "none"
var tween_to_next: String = "linear"

func duplicate_keyframe() -> KeyframeData:
	var k = KeyframeData.new()
	k.frame_index = frame_index
	k.tween_to_next = tween_to_next
	for id in transforms:
		k.transforms[id] = (transforms[id] as ItemTransform).duplicate_transform()
	return k

func to_dict() -> Dictionary:
	var t_dict: Dictionary = {}
	for id in transforms:
		t_dict[id] = (transforms[id] as ItemTransform).to_dict()
	return {
		"frame_index": frame_index,
		"tween_to_next": tween_to_next,
		"transforms": t_dict
	}

static func from_dict(d: Dictionary) -> KeyframeData:
	var k = KeyframeData.new()
	k.frame_index = int(d.get("frame_index", 0))
	k.tween_to_next = d.get("tween_to_next", "linear")
	var t_dict = d.get("transforms", {})
	for id in t_dict:
		k.transforms[id] = ItemTransform.from_dict(t_dict[id])
	return k
