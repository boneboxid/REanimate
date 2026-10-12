# Kumpulan concrete Command untuk mutasi dokumen REanimate
class_name DocCommands
extends RefCounted

# 1. Add Item Command
class AddItemCommand extends Command:
	var doc: ProjectDocument
	var layer: AnimationLayer
	var frame: int
	var item: StageItem
	var element: Element
	var transform: ItemTransform

	func _init(p_doc: ProjectDocument, p_layer: AnimationLayer, p_frame: int, p_item: StageItem, p_transform: ItemTransform, p_element: Element = null) -> void:
		name = "Add Item"
		doc = p_doc
		layer = p_layer
		frame = p_frame
		item = p_item
		transform = p_transform
		element = p_element

	var created_kf: bool = false

	func execute() -> void:
		doc.items[item.id] = item
		var kf = layer.get_keyframe_at(frame)
		created_kf = false
		if kf == null:
			kf = KeyframeData.new()
			kf.frame_index = frame
			layer.set_keyframe(kf)
			created_kf = true
		kf.transforms[item.id] = transform.duplicate_transform()
		if element != null:
			kf.add_element(element)

	func undo() -> void:
		doc.items.erase(item.id)
		var kf = layer.get_keyframe_at(frame)
		if kf != null:
			kf.transforms.erase(item.id)
			if element != null:
				kf.remove_element(element.id)
			if created_kf and kf.transforms.is_empty() and kf.elements.is_empty():
				layer.remove_keyframe_at(frame)
				layer._update_durations()

# 2. Delete Item Command
class DeleteItemCommand extends Command:
	var doc: ProjectDocument
	var item_id: String
	var saved_item: StageItem
	var saved_transforms: Dictionary = {} # layer_index -> { frame_index -> ItemTransform }
	var saved_elements: Dictionary = {} # layer_index -> { frame_index -> Element }

	func _init(p_doc: ProjectDocument, p_id: String) -> void:
		name = "Delete Item"
		doc = p_doc
		item_id = p_id

	func execute() -> void:
		if doc.items.has(item_id):
			saved_item = doc.items[item_id]
			doc.items.erase(item_id)
		for l_i in range(doc.layers.size()):
			var l = doc.layers[l_i]
			for kf in l.keyframes:
				if kf.transforms.has(item_id):
					if not saved_transforms.has(l_i): saved_transforms[l_i] = {}
					saved_transforms[l_i][kf.frame_index] = kf.transforms[item_id]
					kf.transforms.erase(item_id)
				var el = kf.get_element(item_id)
				if el != null:
					if not saved_elements.has(l_i): saved_elements[l_i] = {}
					saved_elements[l_i][kf.frame_index] = el
					kf.remove_element(item_id)

	func undo() -> void:
		if saved_item != null:
			doc.items[item_id] = saved_item
		for l_i in saved_transforms:
			if l_i < doc.layers.size():
				var l = doc.layers[l_i]
				for f_idx in saved_transforms[l_i]:
					var kf = l.get_keyframe_at(f_idx)
					if kf != null:
						kf.transforms[item_id] = saved_transforms[l_i][f_idx]
		for l_i in saved_elements:
			if l_i < doc.layers.size():
				var l = doc.layers[l_i]
				for f_idx in saved_elements[l_i]:
					var kf = l.get_keyframe_at(f_idx)
					if kf != null:
						kf.add_element(saved_elements[l_i][f_idx])

# 3. Transform Item Command
class TransformItemCommand extends Command:
	var layer: AnimationLayer
	var frame: int
	var item_id: String
	var old_transform: ItemTransform
	var new_transform: ItemTransform

	func _init(p_layer: AnimationLayer, p_frame: int, p_id: String, p_old_t: ItemTransform, p_new_t: ItemTransform) -> void:
		name = "Transform Item"
		layer = p_layer
		frame = p_frame
		item_id = p_id
		old_transform = p_old_t.duplicate_transform() if p_old_t != null else null
		new_transform = p_new_t.duplicate_transform()

	func execute() -> void:
		var kf = layer.get_keyframe_at(frame)
		if kf == null:
			kf = KeyframeData.new()
			kf.frame_index = frame
			layer.set_keyframe(kf)
		kf.transforms[item_id] = new_transform.duplicate_transform()

	func undo() -> void:
		var kf = layer.get_keyframe_at(frame)
		if kf != null:
			if old_transform != null:
				kf.transforms[item_id] = old_transform.duplicate_transform()
			else:
				kf.transforms.erase(item_id)

# 4. Change Color Command
class ChangeColorCommand extends Command:
	var item: StageItem
	var is_stroke: bool
	var old_color: Color
	var new_color: Color

	func _init(p_item: StageItem, p_is_stroke: bool, p_new_color: Color) -> void:
		name = "Change Color"
		item = p_item
		is_stroke = p_is_stroke
		old_color = item.stroke_color if is_stroke else item.color
		new_color = p_new_color

	func execute() -> void:
		if is_stroke:
			item.stroke_color = new_color
		else:
			item.color = new_color

	func undo() -> void:
		if is_stroke:
			item.stroke_color = old_color
		else:
			item.color = old_color

# Snapshot helper untuk command yang menggeser frame pada seluruh layer
class FrameSnapshot extends RefCounted:
	var max_frames: int = 0
	var timeline_max_frames: int = 0
	var layers_state: Array = [] # [{layer, kfs, indices, durations}]

	static func capture(p_doc: ProjectDocument) -> FrameSnapshot:
		var s = FrameSnapshot.new()
		s.max_frames = p_doc.max_frames
		var sc = p_doc.get_active_scene()
		if sc != null and sc.timeline != null:
			s.timeline_max_frames = sc.timeline.max_frames
		for l in p_doc.layers:
			var idxs: Array = []
			var durs: Array = []
			for k in l.keyframes:
				idxs.append(k.frame_index)
				durs.append(k.duration)
			s.layers_state.append({"layer": l, "kfs": l.keyframes.duplicate(), "indices": idxs, "durations": durs})
		return s

	func restore(p_doc: ProjectDocument) -> void:
		p_doc.max_frames = max_frames
		var sc = p_doc.get_active_scene()
		if sc != null and sc.timeline != null:
			sc.timeline.max_frames = timeline_max_frames
		for st in layers_state:
			var l: AnimationLayer = st["layer"]
			l.keyframes.assign(st["kfs"])
			for i in range(l.keyframes.size()):
				l.keyframes[i].frame_index = st["indices"][i]
				l.keyframes[i].duration = st["durations"][i]

# 5. Insert Frame Span (F5) Command
class InsertFrameSpanCommand extends Command:
	var doc: ProjectDocument
	var frame: int
	var snapshot: FrameSnapshot

	func _init(p_doc: ProjectDocument, p_frame: int) -> void:
		name = "Insert Frame Span"
		doc = p_doc
		frame = p_frame

	func execute() -> void:
		snapshot = FrameSnapshot.capture(doc)
		doc.insert_frame_all_layers(frame)

	func undo() -> void:
		if snapshot != null:
			snapshot.restore(doc)

# 6. Remove Frame Span (Shift+F5) Command
class RemoveFrameSpanCommand extends Command:
	var doc: ProjectDocument
	var frame: int
	var snapshot: FrameSnapshot

	func _init(p_doc: ProjectDocument, p_frame: int) -> void:
		name = "Remove Frame Span"
		doc = p_doc
		frame = p_frame

	func execute() -> void:
		snapshot = FrameSnapshot.capture(doc)
		doc.remove_frame_all_layers(frame)

	func undo() -> void:
		if snapshot != null:
			snapshot.restore(doc)

# 7. Add Layer Command
class AddLayerCommand extends Command:
	var doc: ProjectDocument
	var timeline: TimelineModel
	var layer: AnimationLayer

	func _init(p_doc: ProjectDocument, p_layer: AnimationLayer) -> void:
		name = "Add Layer"
		doc = p_doc
		layer = p_layer
		var sc = p_doc.get_active_scene()
		timeline = sc.timeline if sc != null else null

	func execute() -> void:
		if timeline != null:
			timeline.add_layer(layer)
		else:
			doc.layers.append(layer)

	func undo() -> void:
		var arr = timeline.layers if timeline != null else doc.layers
		var idx = arr.find(layer)
		if idx != -1:
			arr.remove_at(idx)
