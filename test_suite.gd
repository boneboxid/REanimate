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
	# 6. Quick Wins Tests
	const TestQuickWinsScript = preload("res://tests/test_quick_wins.gd")
	TestQuickWinsScript.run_all_tests()
	
	# 7. Phase 1 Data Model Tests
	const TestDataModelsScript = preload("res://tests/test_data_models.gd")
	TestDataModelsScript.run_all_tests()
	
	# 8. Phase 2 Undo/Redo Tests
	const TestUndoRedoScript = preload("res://tests/test_undo_redo.gd")
	TestUndoRedoScript.run_all_tests()
	
	# 9. Phase 3 Flash Vector Engine Tests
	const TestVectorEngineScript = preload("res://tests/test_vector_engine.gd")
	TestVectorEngineScript.run_all_tests()
	
	# 10. Phase 4 Drawing Tools Tests
	const TestDrawingToolsScript = preload("res://tests/test_drawing_tools.gd")
	TestDrawingToolsScript.run_all_tests()
	
	# 11. Phase 5 Timeline & Tweening Tests
	const TestTimelineTweenScript = preload("res://tests/test_timeline_tween.gd")
	TestTimelineTweenScript.run_all_tests()
	
	# 12. Phase 6 Symbol & Library Tests
	const TestSymbolLibraryScript = preload("res://tests/test_symbol_library.gd")
	TestSymbolLibraryScript.run_all_tests()
	
	# 13. Phase 7 Real FLA Compatibility Tests
	const TestFLACompatibilityScript = preload("res://tests/test_fla_compatibility.gd")
	TestFLACompatibilityScript.run_all_tests()
	
	# 14. Phase 8 & 9 UI Shortcuts, Export & Mobile Tests
	const TestUIShortcutsAndExportScript = preload("res://tests/test_ui_shortcuts_and_export.gd")
	TestUIShortcutsAndExportScript.run_all_tests()
	
	# 15. Editor Runtime Smoke Tests
	const TestEditorRuntimeScript = preload("res://tests/test_editor_runtime.gd")
	await TestEditorRuntimeScript.run_all_tests(self)
	
	print("--- ALL ENGINE, QUICK WINS, AND ALL PHASES 1 THROUGH 9 TESTS PASSED SUCCESSFULLY! ---")
	quit()
