# Modul untuk mengekspor animasi ke berbagai format (PNG Sequence, Animated GIF / Frames, JSON Data)
class_name ExportManager
extends RefCounted

# Ekspor project ke format Adobe Animate Texture Atlas compatible JSON
static func export_to_texture_atlas_json(doc: RefCounted, file_path: String) -> Error:
	var root_dict: Dictionary = {
		"AN": {
			"N": doc.name,
			"SN": "MainTimeline",
			"TL": {
				"L": []
			}
		},
		"SD": {
			"S": []
		},
		"MD": {
			"FRT": doc.fps,
			"STAGE_W": doc.stage_size.x,
			"STAGE_H": doc.stage_size.y
		}
	}
	
	var layers_json: Array = []
	for layer in doc.layers:
		var layer_data: Dictionary = {
			"LN": layer.name,
			"FR": []
		}
		
		# Tulis setiap keyframe span
		for i in range(layer.keyframes.size()):
			var kf = layer.keyframes[i]
			var duration = 1
			if i + 1 < layer.keyframes.size():
				duration = layer.keyframes[i + 1].frame_index - kf.frame_index
			else:
				duration = doc.max_frames - kf.frame_index
			duration = max(1, duration)
			
			var elements: Array = []
			for item_id in kf.transforms:
				var t: ItemTransform = kf.transforms[item_id]
				var item: StageItem = doc.items.get(item_id, null)
				if item == null: continue
				
				# Convert Transform2D ke format Matrix 3D (16 float)
				var cos_r = cos(t.rotation)
				var sin_r = sin(t.rotation)
				var a = cos_r * t.scale.x
				var b = sin_r * t.scale.x
				var c = -sin_r * t.scale.y
				var d = cos_r * t.scale.y
				
				var m3d = [
					a, b, 0.0, 0.0,
					c, d, 0.0, 0.0,
					0.0, 0.0, 1.0, 0.0,
					t.position.x, t.position.y, 0.0, 1.0
				]
				
				elements.append({
					"SI": {
						"SN": item.name,
						"IN": item.id,
						"ST": "G",
						"M3D": m3d,
						"ALPHA": t.opacity
					}
				})
				
			layer_data["FR"].append({
				"I": kf.frame_index,
				"DU": duration,
				"E": elements
			})
			
		layers_json.append(layer_data)
		
	root_dict["AN"]["TL"]["L"] = layers_json
	
	# Simpan ke file
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(root_dict, "\t"))
	file.close()
	return OK

# Ekspor frame sequence ke kumpulan gambar PNG dalam satu folder
static func export_png_sequence(viewport: SubViewport, doc: ProjectDocument, out_dir: String, callback_update_frame: Callable) -> int:
	var dir = DirAccess.open(out_dir)
	if dir == null:
		DirAccess.make_dir_absolute(out_dir)
		dir = DirAccess.open(out_dir)
		
	var exported_count = 0
	for frame in range(doc.max_frames):
		# Render frame tertentu
		callback_update_frame.call(frame)
		# Force redraw viewport
		RenderingServer.frame_post_draw
		
		var img: Image = viewport.get_texture().get_image()
		if img != null:
			var filename = "%s/frame_%04d.png" % [out_dir, frame]
			img.save_png(filename)
			exported_count += 1
			
	return exported_count
