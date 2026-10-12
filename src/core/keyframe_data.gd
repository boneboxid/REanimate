# Satu keyframe pada frame tertentu (memiliki elements per-frame, duration, tweening, ease)
class_name KeyframeData
extends RefCounted

var frame_index: int = 0
var duration: int = 1 # Span frame length
var tween_type: String = "none" # "none", "classic", "shape"
var tween_to_next: String = "none": # Alias backward compatibility
	get:
		return tween_type
	set(val):
		tween_type = val

var ease: float = 0.0 # -100.0 (in) sampai 100.0 (out)
var rotate_dir: String = "none" # "none", "cw", "ccw"
var rotate_times: int = 0
var label: String = ""

# Elements per-frame (Flash element model)
var elements: Array[Element] = []

# Map item_id -> ItemTransform (disinkronkan untuk kompatibilitas UI / renderer)
var transforms: Dictionary = {}

func add_element(el: Element) -> void:
	elements.append(el)
	if el.transform != null:
		transforms[el.id] = el.transform

func get_element(id: String) -> Element:
	for el in elements:
		if el.id == id:
			return el
	return null

func remove_element(id: String) -> bool:
	transforms.erase(id)
	for i in range(elements.size()):
		if elements[i].id == id:
			elements.remove_at(i)
			return true
	return false

func sync_transforms_from_elements() -> void:
	transforms.clear()
	for el in elements:
		if el.transform != null:
			transforms[el.id] = el.transform

func duplicate_keyframe() -> KeyframeData:
	var k = KeyframeData.new()
	k.frame_index = frame_index
	k.duration = duration
	k.tween_type = tween_type
	k.ease = ease
	k.rotate_dir = rotate_dir
	k.rotate_times = rotate_times
	k.label = label
	
	# Deep copy of elements
	for el in elements:
		k.add_element(el.duplicate_element())
		
	# Duplicate any extra transforms
	for id in transforms:
		if not k.transforms.has(id):
			k.transforms[id] = (transforms[id] as ItemTransform).duplicate_transform()
			
	return k

func to_dict() -> Dictionary:
	var el_arr: Array = []
	for el in elements:
		el_arr.append(el.to_dict())
		
	var t_dict: Dictionary = {}
	for id in transforms:
		t_dict[id] = (transforms[id] as ItemTransform).to_dict()
		
	return {
		"frame_index": frame_index,
		"duration": duration,
		"tween_type": tween_type,
		"tween_to_next": tween_type,
		"ease": ease,
		"rotate_dir": rotate_dir,
		"rotate_times": rotate_times,
		"label": label,
		"elements": el_arr,
		"transforms": t_dict
	}

static func from_dict(d: Dictionary) -> KeyframeData:
	var k = KeyframeData.new()
	k.frame_index = int(d.get("frame_index", 0))
	k.duration = int(d.get("duration", 1))
	k.tween_type = d.get("tween_type", d.get("tween_to_next", "none"))
	k.ease = float(d.get("ease", 0.0))
	k.rotate_dir = d.get("rotate_dir", "none")
	k.rotate_times = int(d.get("rotate_times", 0))
	k.label = d.get("label", "")
	
	var el_data = d.get("elements", [])
	for ed in el_data:
		var el = Element.from_dict(ed)
		k.add_element(el)
		
	var t_dict = d.get("transforms", {})
	for id in t_dict:
		if not k.transforms.has(id):
			k.transforms[id] = ItemTransform.from_dict(t_dict[id])
			
	return k
