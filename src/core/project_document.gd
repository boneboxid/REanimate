# Root model dokumen proyek REanimate (Version 2.0.0: Document -> Scene -> Timeline -> Layer -> Frame -> Element)
class_name ProjectDocument
extends RefCounted

var version: String = "2.0.0"
var name: String = "Untitled_Animation"
var stage_size: Vector2 = Vector2(800, 450)
var fps: int = 30
var max_frames: int = 60
var bg_color: Color = Color(0.98, 0.98, 0.98, 1.0)

# Scenes (Flash multi-scene support)
var scenes: Array[SceneModel] = []
var active_scene_index: int = 0

# Library resmi Flash (SymbolItem yang memiliki TimelineModel tersendiri)
var library: Dictionary = {} # symbol_id -> SymbolItem

# Katalog objek pada stage (id -> StageItem) untuk kompatibilitas UI / tools
var items: Dictionary = {}

# Library Simbol lama (symbol_id -> StageItem) untuk kompatibilitas
var symbols: Dictionary = {}

# Shortcut / alias layers ke timeline active scene
var layers: Array[AnimationLayer]:
	get:
		var sc = get_active_scene()
		if sc != null and sc.timeline != null:
			return sc.timeline.layers
		return _fallback_layers
	set(val):
		var sc = get_active_scene()
		if sc != null and sc.timeline != null:
			sc.timeline.layers = val
		else:
			_fallback_layers = val

var _fallback_layers: Array[AnimationLayer] = []

func _init() -> void:
	pass

func get_active_scene() -> SceneModel:
	if scenes.is_empty():
		var default_scene = SceneModel.new("Scene 1")
		default_scene.timeline.max_frames = max_frames
		scenes.append(default_scene)
		active_scene_index = 0
	active_scene_index = clampi(active_scene_index, 0, scenes.size() - 1)
	return scenes[active_scene_index]

static func create_default() -> ProjectDocument:
	var doc = ProjectDocument.new()
	doc.name = "My_Animation"
	doc.version = "2.0.0"
	
	var default_scene = SceneModel.new("Scene 1")
	default_scene.timeline.max_frames = 60
	doc.scenes.append(default_scene)
	doc.active_scene_index = 0
	
	# Buat 1 layer default
	var layer = AnimationLayer.new()
	layer.name = "Layer 1"
	default_scene.timeline.add_layer(layer)
	
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
	kf0.duration = 30
	var t0 = ItemTransform.new()
	t0.position = Vector2(-150, 0)
	t0.rotation = 0.0
	t0.scale = Vector2.ONE
	kf0.transforms[box.id] = t0
	kf0.tween_type = "linear"
	kf0.tween_to_next = "linear"
	
	# Tambahkan element ke kf0
	var el0 = ShapeElement.new()
	el0.id = box.id
	el0.name = box.name
	el0.shape_type = "rect"
	el0.size = box.size
	el0.color = box.color
	el0.stroke_color = box.stroke_color
	el0.stroke_width = box.stroke_width
	el0.transform = t0.duplicate_transform()
	kf0.add_element(el0)
	layer.set_keyframe(kf0)
	
	# Keyframe di frame 30 (Posisi kanan dari tengah)
	var kf30 = KeyframeData.new()
	kf30.frame_index = 30
	kf30.duration = 30
	var t30 = ItemTransform.new()
	t30.position = Vector2(150, 0)
	t30.rotation = deg_to_rad(180)
	t30.scale = Vector2(1.2, 1.2)
	kf30.transforms[box.id] = t30
	kf30.tween_type = "linear"
	kf30.tween_to_next = "linear"
	
	var el30 = ShapeElement.new()
	el30.id = box.id
	el30.name = box.name
	el30.shape_type = "rect"
	el30.size = box.size
	el30.color = box.color
	el30.stroke_color = box.stroke_color
	el30.stroke_width = box.stroke_width
	el30.transform = t30.duplicate_transform()
	kf30.add_element(el30)
	layer.set_keyframe(kf30)
	
	return doc

# Flash F5: Insert frame span pada seluruh layer atau active layer
func insert_frame_all_layers(at_frame: int) -> void:
	max_frames += 1
	var sc = get_active_scene()
	if sc != null and sc.timeline != null:
		sc.timeline.insert_frame_all_layers(at_frame)
		sc.timeline.max_frames = max_frames
	else:
		for l in layers:
			l.insert_frame_span(at_frame)

# Flash Shift+F5: Remove frame span pada seluruh layer atau active layer
func remove_frame_all_layers(at_frame: int) -> void:
	if max_frames > 1:
		max_frames -= 1
	var sc = get_active_scene()
	if sc != null and sc.timeline != null:
		sc.timeline.remove_frame_all_layers(at_frame)
		sc.timeline.max_frames = max_frames
	else:
		for l in layers:
			l.remove_frame_span(at_frame)

# Flash F8: Convert stage item to Library SymbolItem
func convert_to_symbol(item_id: String, sym_name: String, sym_type: String, reg_index: int = 4) -> SymbolItem:
	if not items.has(item_id):
		return null
		
	var item: StageItem = items[item_id]
	var sym = SymbolItem.new()
	sym.name = sym_name if sym_name != "" else item.name + " Symbol"
	sym.symbol_type = sym_type
	sym.registration_index = reg_index
	
	# Hitung 9-position registration point relatif terhadap ukuran item
	var half_sz = item.size * 0.5
	var reg_pt = Vector2.ZERO
	match reg_index:
		0: reg_pt = -half_sz # Top-Left
		1: reg_pt = Vector2(0, -half_sz.y) # Top-Center
		2: reg_pt = Vector2(half_sz.x, -half_sz.y) # Top-Right
		3: reg_pt = Vector2(-half_sz.x, 0) # Center-Left
		4: reg_pt = Vector2.ZERO # Center
		5: reg_pt = Vector2(half_sz.x, 0) # Center-Right
		6: reg_pt = Vector2(-half_sz.x, half_sz.y) # Bottom-Left
		7: reg_pt = Vector2(0, half_sz.y) # Bottom-Center
		8: reg_pt = half_sz # Bottom-Right
	sym.registration_point = reg_pt
	
	# Isi timeline symbol dengan element item ini di Keyframe 0
	var sym_layer = AnimationLayer.new()
	sym_layer.name = "Layer 1"
	var sym_kf = KeyframeData.new()
	sym_kf.frame_index = 0
	
	var el = ShapeElement.new()
	el.id = item.id
	el.name = item.name
	el.shape_type = item.shape_type
	el.size = item.size
	el.color = item.color
	el.stroke_color = item.stroke_color
	el.stroke_width = item.stroke_width
	el.points = item.points.duplicate()
	el.curve_controls = item.curve_controls.duplicate()
	el.polystar_sides = item.polystar_sides
	el.is_star = item.is_star
	el.star_inner_radius_ratio = item.star_inner_radius_ratio
	el.corner_radius = item.corner_radius
	el.oval_start_angle = item.oval_start_angle
	el.oval_end_angle = item.oval_end_angle
	el.oval_inner_radius_ratio = item.oval_inner_radius_ratio
	
	var t = ItemTransform.new()
	t.position = -reg_pt # Posisi di dalam symbol diimbangi oleh registration point
	el.transform = t
	sym_kf.add_element(el)
	sym_layer.set_keyframe(sym_kf)
	sym.timeline.add_layer(sym_layer)
	
	if sym_type == "button":
		sym.setup_as_button()
		sym.timeline.layers[0].get_keyframe_at(0).add_element(el)
		
	library[sym.id] = sym
	
	# Konversi StageItem menjadi representasi simbol
	item.shape_type = "symbol"
	item.symbol_type = sym_type
	item.library_ref = sym.id
	symbols[item.id] = item
	
	return sym

# Buat symbol kosong di library
func create_symbol(sym_name: String, sym_type: String = "graphic", reg_index: int = 4) -> SymbolItem:
	var sym = SymbolItem.new()
	sym.name = sym_name
	sym.symbol_type = sym_type
	sym.registration_index = reg_index
	if sym_type == "button":
		sym.setup_as_button()
	else:
		var l = AnimationLayer.new()
		l.name = "Layer 1"
		var kf = KeyframeData.new()
		kf.frame_index = 0
		l.set_keyframe(kf)
		sym.timeline.add_layer(l)
	library[sym.id] = sym
	return sym

# Duplikasi symbol di library
func duplicate_symbol(sym_id: String) -> SymbolItem:
	if not library.has(sym_id):
		return null
	var orig: SymbolItem = library[sym_id]
	var dup = SymbolItem.from_dict(orig.to_dict())
	dup.id = "symbol_" + str(Time.get_ticks_usec())
	dup.name = orig.name + " Copy"
	library[dup.id] = dup
	return dup

# Hapus symbol dari library
func delete_symbol(sym_id: String) -> bool:
	if not library.has(sym_id):
		return false
	library.erase(sym_id)
	return true

# Ganti nama symbol di library
func rename_symbol(sym_id: String, new_name: String) -> bool:
	if not library.has(sym_id):
		return false
	library[sym_id].name = new_name
	return true

# Cek apakah symbol sedang digunakan di stage/scene
func is_symbol_in_use(sym_id: String) -> bool:
	for id in items:
		var itm: StageItem = items[id]
		if itm.shape_type == "symbol" and itm.library_ref == sym_id:
			return true
	for sc in scenes:
		if sc.timeline != null:
			for l in sc.timeline.layers:
				for kf in l.keyframes:
					for el in kf.elements:
						if el is SymbolInstance and el.library_ref == sym_id:
							return true
	return false

func to_dict() -> Dictionary:
	var items_dict: Dictionary = {}
	for id in items:
		items_dict[id] = (items[id] as StageItem).to_dict()
		
	var symbols_dict: Dictionary = {}
	for sid in symbols:
		symbols_dict[sid] = (symbols[sid] as StageItem).to_dict()
		
	var lib_dict: Dictionary = {}
	for lid in library:
		lib_dict[lid] = (library[lid] as SymbolItem).to_dict()
		
	var scenes_arr: Array = []
	for sc in scenes:
		scenes_arr.append(sc.to_dict())
		
	var layers_array: Array = []
	for l in layers:
		layers_array.append(l.to_dict())
		
	return {
		"version": "2.0.0",
		"name": name,
		"stage_size": [stage_size.x, stage_size.y],
		"fps": fps,
		"max_frames": max_frames,
		"bg_color": [bg_color.r, bg_color.g, bg_color.b, bg_color.a],
		"scenes": scenes_arr,
		"active_scene_index": active_scene_index,
		"library": lib_dict,
		"items": items_dict,
		"symbols": symbols_dict,
		"layers": layers_array # Simpan juga layers untuk backward compatibility
	}

static func from_dict(d: Dictionary) -> ProjectDocument:
	var doc = ProjectDocument.new()
	doc.version = d.get("version", "1.0.0")
	doc.name = d.get("name", "Untitled")
	var sz = d.get("stage_size", [800.0, 450.0])
	if sz is Array and sz.size() >= 2:
		doc.stage_size = Vector2(sz[0], sz[1])
	doc.fps = int(d.get("fps", 30))
	doc.max_frames = int(d.get("max_frames", 60))
	var bg = d.get("bg_color", [0.98, 0.98, 0.98, 1.0])
	if bg is Array and bg.size() >= 4:
		doc.bg_color = Color(bg[0], bg[1], bg[2], bg[3])
	doc.active_scene_index = int(d.get("active_scene_index", 0))
	
	# 1. Load Items & Symbols
	var items_data = d.get("items", {})
	for id in items_data:
		doc.items[id] = StageItem.from_dict(items_data[id])
		
	var symbols_data = d.get("symbols", {})
	for sid in symbols_data:
		doc.symbols[sid] = StageItem.from_dict(symbols_data[sid])
		
	# 2. Load Library (v2.0.0)
	var lib_data = d.get("library", {})
	for lid in lib_data:
		doc.library[lid] = SymbolItem.from_dict(lib_data[lid])
		
	# 3. Load Scenes (v2.0.0) atau Layers (v1.0.0)
	var scenes_data = d.get("scenes", [])
	if not scenes_data.is_empty():
		for sc_d in scenes_data:
			doc.scenes.append(SceneModel.from_dict(sc_d))
	else:
		# Migrasi v1.0.0: buat default scene dari layers array
		var default_scene = SceneModel.new("Scene 1")
		default_scene.timeline.max_frames = doc.max_frames
		var layers_data = d.get("layers", [])
		for ld in layers_data:
			default_scene.timeline.layers.append(AnimationLayer.from_dict(ld))
		doc.scenes.append(default_scene)
		
	return doc

func save_to_file(file_path: String) -> Error:
	if file_path.get_extension().to_lower() == "fla":
		return FLAManager.export_to_fla(self, file_path)
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
	if file_path.get_extension().to_lower() == "fla":
		return FLAManager.import_from_fla(file_path)
		
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return null
		
	# Check if file is a zip/fla archive by checking PK header
	if file.get_length() >= 4:
		var magic = file.get_buffer(2)
		if magic.size() >= 2 and magic[0] == 0x50 and magic[1] == 0x4B: # 'PK'
			file.close()
			return FLAManager.import_from_fla(file_path)
		file.seek(0)
		
	var text = file.get_as_text()
	file.close()
	var json_parsed = JSON.parse_string(text)
	if json_parsed == null or not (json_parsed is Dictionary):
		return null
	return ProjectDocument.from_dict(json_parsed)
