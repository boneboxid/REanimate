extends SceneTree

func _init() -> void:
	print("--- TESTING REANIMATE ENGINE ---")
	
	# 1. Test Project Document creation
	var doc = ProjectDocument.create_default()
	assert(doc.layers.size() == 1, "Layer count must be 1")
	assert(doc.items.size() == 1, "Item count must be 1")
	print("OK: ProjectDocument.create_default()")
	
	# 2. Test Multi-Layer
	var layer2 = AnimationLayer.new()
	layer2.name = "Background Layer"
	doc.layers.append(layer2)
	assert(doc.layers.size() == 2, "Layer count must be 2")
	print("OK: Multi-layer support")
	
	# 3. Test Save & Load
	var test_path = "user://test_project.rean"
	var err = doc.save_to_file(test_path)
	assert(err == OK, "Save must succeed")
	var loaded_doc = ProjectDocument.load_from_file(test_path)
	assert(loaded_doc != null, "Loaded doc must not be null")
	assert(loaded_doc.layers.size() == 2, "Loaded layers must match")
	print("OK: Project Save (.rean) and Load")
	
	# 4. Test Texture Atlas JSON Export
	var export_json_path = "user://test_atlas.json"
	var export_err = ExportManager.export_to_texture_atlas_json(doc, export_json_path)
	assert(export_err == OK, "Export Texture Atlas must succeed")
	print("OK: Texture Atlas JSON Export")
	
	# 5. Test Interpolation Tweening
	var box_id = doc.items.keys()[0]
	var t_half = doc.layers[0].get_interpolated_transform(box_id, 15)
	assert(t_half != null, "Interpolated transform at frame 15 must exist")
	print("OK: Interpolated Tweening at frame 15: pos =", t_half.position)
	
	print("--- ALL 5 ENGINE TESTS PASSED SUCCESSFULLY! ---")
	quit()
