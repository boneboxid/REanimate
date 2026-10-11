# Root model dokumen proyek REanimate
class_name ProjectDocument
extends RefCounted

var name: String = "Untitled_Animation"
var stage_size: Vector2 = Vector2(800, 450)
var fps: int = 30
var max_frames: int = 60
var bg_color: Color = Color(0.98, 0.98, 0.98, 1.0)

# Katalog objek pada stage (id -> StageItem)
var items: Dictionary = {}

# Daftar layer (urutan render dari indeks 0 ke atas)
var layers: Array[AnimationLayer] = []

func _init() -> void:
	pass

static func create_default() -> ProjectDocument:
	var doc = ProjectDocument.new()
	doc.name = "My_Animation"
	
	# Buat 1 layer default
	var layer = AnimationLayer.new()
	layer.name = "Layer 1"
	doc.layers.append(layer)
	
	# Buat 1 shape kotak default
	var box = StageItem.new()
	box.id = "item_" + str(Time.get_ticks_usec())
	box.name = "Hero Box"
	box.shape_type = "rect"
	box.size = Vector2(100, 100)
	box.color = Color(0.9, 0.3, 0.3, 1.0)
	box.stroke_color = Color(0.15, 0.15, 0.15, 1.0)
	box.stroke_width = 2.0
	doc.items[box.id] = box
	
	# Keyframe awal di frame 0 (Posisi kiri dari tengah)
	var kf0 = KeyframeData.new()
	kf0.frame_index = 0
	var t0 = ItemTransform.new()
	t0.position = Vector2(-150, 0)
	t0.rotation = 0.0
	t0.scale = Vector2.ONE
	kf0.transforms[box.id] = t0
	kf0.tween_to_next = "linear"
	layer.set_keyframe(kf0)
	
	# Keyframe di frame 30 (Posisi kanan dari tengah)
	var kf30 = KeyframeData.new()
	kf30.frame_index = 30
	var t30 = ItemTransform.new()
	t30.position = Vector2(150, 0)
	t30.rotation = deg_to_rad(180)
	t30.scale = Vector2(1.2, 1.2)
	kf30.transforms[box.id] = t30
	kf30.tween_to_next = "linear"
	layer.set_keyframe(kf30)
	
	return doc

func to_dict() -> Dictionary:
	var items_dict: Dictionary = {}
	for id in items:
		items_dict[id] = (items[id] as StageItem).to_dict()
		
	var layers_array: Array = []
	for l in layers:
		layers_array.append(l.to_dict())
		
	return {
		"version": "1.0.0",
		"name": name,
		"stage_size": [stage_size.x, stage_size.y],
		"fps": fps,
		"max_frames": max_frames,
		"bg_color": [bg_color.r, bg_color.g, bg_color.b, bg_color.a],
		"items": items_dict,
		"layers": layers_array
	}

static func from_dict(d: Dictionary) -> ProjectDocument:
	var doc = ProjectDocument.new()
	doc.name = d.get("name", "Untitled")
	var sz = d.get("stage_size", [800.0, 450.0])
	doc.stage_size = Vector2(sz[0], sz[1])
	doc.fps = int(d.get("fps", 30))
	doc.max_frames = int(d.get("max_frames", 60))
	var bg = d.get("bg_color", [0.98, 0.98, 0.98, 1.0])
	doc.bg_color = Color(bg[0], bg[1], bg[2], bg[3])
	
	var items_data = d.get("items", {})
	for id in items_data:
		doc.items[id] = StageItem.from_dict(items_data[id])
		
	var layers_data = d.get("layers", [])
	for ld in layers_data:
		doc.layers.append(AnimationLayer.from_dict(ld))
		
	return doc

func save_to_file(file_path: String) -> Error:
	var json_str = JSON.stringify(to_dict(), "\t")
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(json_str)
	file.close()
	return OK

static func load_from_file(file_path: String) -> ProjectDocument:
	if not FileAccess.file_exists(file_path):
		return null
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return null
	var text = file.get_as_text()
	file.close()
	var json_parsed = JSON.parse_string(text)
	if json_parsed == null or not (json_parsed is Dictionary):
		return null
	return ProjectDocument.from_dict(json_parsed)
