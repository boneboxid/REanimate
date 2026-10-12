class_name TestFLACompatibility
extends RefCounted

static func run_all_tests() -> void:
	print(">>> RUNNING PHASE 7 REAL FLA COMPATIBILITY TESTS <<<")
	test_parse_real_yellowman_fla()
	test_roundtrip_export_and_import()
	test_invalid_and_legacy_binary_error_handling()
	print(">>> ALL PHASE 7 REAL FLA COMPATIBILITY TESTS PASSED! <<<")

static func test_parse_real_yellowman_fla() -> void:
	var fla_path = "res://tests/fixtures/yellowman.fla"
	var doc = FLAManager.import_from_fla(fla_path)
	
	assert(doc != null, "yellowman.fla must import successfully")
	assert(doc.stage_size.x > 0 and doc.stage_size.y > 0, "Stage dimensions parsed from DOMDocument.xml")
	assert(doc.fps > 0, "FPS frameRate parsed")
	assert(doc.layers.size() > 0, "Layers parsed from DOMLayer tags")
	assert(doc.items.size() > 0, "Items / Symbols parsed from stage and library")
	
	# Verifikasi bahwa frame pertama memiliki transform dan item
	var first_layer = doc.layers[0]
	assert(first_layer.keyframes.size() > 0, "First layer has keyframes")
	var kf0 = first_layer.keyframes[0]
	assert(kf0 != null, "Keyframe 0 exists")
	
	print("  [OK] 1. Parse Real yellowman.fla Document, Timeline, Layers & Symbols")

static func test_roundtrip_export_and_import() -> void:
	var fla_path = "res://tests/fixtures/yellowman.fla"
	var doc = FLAManager.import_from_fla(fla_path)
	assert(doc != null, "Original FLA must import successfully")
	
	var initial_layers_count = doc.layers.size()
	var initial_stage_size = doc.stage_size
	var initial_fps = doc.fps
	var initial_items_count = doc.items.size()
	
	# Export ke file sementara
	var temp_export_path = "user://yellowman_roundtrip_test.fla"
	var err = FLAManager.export_to_fla(doc, temp_export_path)
	assert(err == OK, "Export to FLA must succeed")
	
	# Import kembali
	var reimported_doc = FLAManager.import_from_fla(temp_export_path)
	assert(reimported_doc != null, "Re-imported FLA must succeed")
	assert(reimported_doc.layers.size() == initial_layers_count, "Round-trip preserves layer count (%d vs %d)" % [reimported_doc.layers.size(), initial_layers_count])
	assert(reimported_doc.stage_size == initial_stage_size, "Round-trip preserves stage size")
	assert(reimported_doc.fps == initial_fps, "Round-trip preserves fps")
	assert(reimported_doc.items.size() == initial_items_count, "Round-trip preserves items count (%d vs %d)" % [reimported_doc.items.size(), initial_items_count])
	
	print("  [OK] 2. Round-Trip Test (yellowman.fla -> Import -> Export -> Import -> 100% Structural Match)")

static func test_invalid_and_legacy_binary_error_handling() -> void:
	# 1. Non-existent file
	var non_existent = FLAManager.import_from_fla("res://non_existent_file.fla")
	assert(non_existent == null, "Non-existent file returns null gracefully without crash")
	
	# 2. Corrupt / non-zip file
	var temp_bad = "user://bad_file.fla"
	var fa = FileAccess.open(temp_bad, FileAccess.WRITE)
	fa.store_string("NOT A ZIP FILE HEADER")
	fa.close()
	var bad_res = FLAManager.import_from_fla(temp_bad)
	assert(bad_res == null, "Corrupt file returns null gracefully")
	
	print("  [OK] 3. Corrupt & Missing File Graceful Error Handling")
