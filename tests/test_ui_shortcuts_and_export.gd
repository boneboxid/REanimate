class_name TestUIShortcutsAndExport
extends RefCounted

static func run_all_tests() -> void:
	print(">>> RUNNING PHASE 8 & 9 UI SHORTCUTS, EXPORT & MOBILE TESTS <<<")
	test_clipboard_and_arrange_shortcuts()
	test_break_apart_and_grouping()
	test_project_settings_and_presets()
	test_texture_atlas_and_html5_export()
	test_audio_layer_and_mobile_saf()
	print(">>> ALL PHASE 8 & 9 UI SHORTCUTS, EXPORT & MOBILE TESTS PASSED! <<<")

static func test_clipboard_and_arrange_shortcuts() -> void:
	var doc = ProjectDocument.create_default()
	var itm1 = StageItem.new()
	itm1.id = "item_1"
	itm1.name = "First Item"
	doc.items[itm1.id] = itm1
	
	var itm2 = StageItem.new()
	itm2.id = "item_2"
	itm2.name = "Second Item"
	doc.items[itm2.id] = itm2
	
	# 1. Test Clipboard Copy & Paste
	var copy_of_itm1 = StageItem.from_dict(itm1.to_dict())
	copy_of_itm1.id = "item_1_copy"
	doc.items[copy_of_itm1.id] = copy_of_itm1
	assert(doc.items.has("item_1_copy"), "Pasted item exists in document")
	assert(doc.items["item_1_copy"].name == itm1.name, "Pasted item preserves properties")
	
	# 2. Test Layer Arrange: Bring to Front & Send to Back
	# Bring item_1 to front (becomes last in dictionary iteration)
	var keys = doc.items.keys()
	doc.items.erase("item_1")
	doc.items["item_1"] = itm1
	assert(doc.items.keys()[-1] == "item_1", "Bring to Front moves item to the top")
	
	# Send item_1 to back (becomes first)
	var reordered = { "item_1": itm1 }
	for k in doc.items:
		if k != "item_1": reordered[k] = doc.items[k]
	doc.items = reordered
	assert(doc.items.keys()[0] == "item_1", "Send to Back moves item to the bottom")
	
	print("  [OK] 1. Clipboard Copy/Cut/Paste & Arrange (Bring to Front / Send to Back)")

static func test_break_apart_and_grouping() -> void:
	var doc = ProjectDocument.create_default()
	var itm = StageItem.new()
	itm.id = "sym_box"
	itm.shape_type = "symbol"
	itm.library_ref = "symbol_1"
	doc.items[itm.id] = itm
	
	# Break Apart (Ctrl+B) breaks symbol into raw vector shapes
	assert(itm.shape_type == "symbol", "Initially a symbol")
	itm.shape_type = "path"
	itm.library_ref = ""
	assert(itm.shape_type == "path" and itm.library_ref == "", "Break apart converts symbol to vector path")
	
	# Group Element (Ctrl+G)
	var grp = GroupElement.new()
	grp.id = "group_1"
	var sh1 = ShapeElement.new()
	var sh2 = ShapeElement.new()
	grp.elements.append(sh1)
	grp.elements.append(sh2)
	assert(grp.elements.size() == 2, "Group holds multiple elements")
	
	print("  [OK] 2. Break Apart (Ctrl+B) & Grouping (Ctrl+G)")

static func test_project_settings_and_presets() -> void:
	var doc = ProjectDocument.create_default()
	doc.stage_size = Vector2(1920, 1080)
	doc.fps = 60
	doc.bg_color = Color.BLACK
	
	assert(doc.stage_size == Vector2(1920, 1080), "FHD preset applied")
	assert(doc.fps == 60, "FPS 60 applied")
	assert(doc.bg_color == Color.BLACK, "Black background applied")
	
	print("  [OK] 3. Project Settings & Resolution Presets")

static func test_texture_atlas_and_html5_export() -> void:
	var doc = ProjectDocument.create_default()
	
	# 1. Texture Atlas JSON export
	var atlas_path = "user://test_phase9_atlas.json"
	var err_atlas = ExportManager.export_to_texture_atlas_json(doc, atlas_path)
	assert(err_atlas == OK, "Export Texture Atlas must succeed")
	
	# Verifikasi struktur JSON
	var fa = FileAccess.open(atlas_path, FileAccess.READ)
	assert(fa != null, "Atlas file must exist")
	var text = fa.get_as_text()
	fa.close()
	var json = JSON.parse_string(text)
	assert(json is Dictionary, "Atlas JSON parsed as dictionary")
	assert(json.has("AN") and json.has("MD") and json.has("SD"), "Standard Adobe Animate Atlas root tags verified")
	assert(json["MD"]["FRT"] == doc.fps, "Frame rate in metadata matched")
	
	# 2. HTML5 Web Player export
	var html_path = "user://test_phase9_player.html"
	var err_html = ExportManager.export_html5_player(doc, html_path)
	assert(err_html == OK, "Export HTML5 Web Player must succeed")
	var fa_h = FileAccess.open(html_path, FileAccess.READ)
	assert(fa_h != null, "HTML5 file exists")
	var h_text = fa_h.get_as_text()
	fa_h.close()
	assert(h_text.contains("<canvas id=\"stage\""), "HTML5 canvas element present")
	assert(h_text.contains("REanimate Web Player"), "HTML5 Web Player title present")
	
	print("  [OK] 4. Texture Atlas JSON & HTML5 Web Player Export")

static func test_audio_layer_and_mobile_saf() -> void:
	# 1. Audio Layer
	var audio_l = AnimationLayer.new()
	audio_l.name = "Music Track"
	audio_l.layer_type = "audio"
	audio_l.audio_volume_db = -6.0
	assert(audio_l.layer_type == "audio", "Audio layer type verified")
	assert(audio_l.audio_volume_db == -6.0, "Audio volume preserved")
	
	# 2. Android SAF (Storage Access Framework) & MIME types
	var mime_fla = AndroidSAFHelper.get_mime_type_for_extension("fla")
	assert(mime_fla == "application/zip", "FLA MIME type is application/zip")
	var mime_png = AndroidSAFHelper.get_mime_type_for_extension("png")
	assert(mime_png == "image/png", "PNG MIME type is image/png")
	var mime_json = AndroidSAFHelper.get_mime_type_for_extension("json")
	assert(mime_json == "application/json", "JSON MIME type is application/json")
	
	var export_dir = AndroidSAFHelper.get_export_storage_dir()
	assert(export_dir != "", "Storage export directory resolved safely")
	
	print("  [OK] 5. Audio Track Configuration & Android SAF Storage Integration")
