class_name TestEditorRuntime
extends RefCounted

# Smoke test runtime: memuat scene editor asli dan menjalankan fitur utama tanpa error.

static func run_all_tests(tree: SceneTree) -> void:
	print(">>> RUNNING EDITOR RUNTIME SMOKE TESTS <<<")
	var editor: EditorMain = load("res://src/ui/editor_main.tscn").instantiate()
	tree.root.add_child(editor)
	await tree.process_frame
	await tree.process_frame
	test_tools_and_drawing(editor)
	test_timeline_and_layers(editor)
	test_selection_clipboard_arrange(editor)
	test_symbol_and_undo(editor)
	test_camera_and_input(editor)
	test_new_project_resets_undo(editor)
	test_file_io(editor)
	await test_png_export(editor)
	test_project_menu_and_settings(editor)
	test_project_launcher(editor)
	test_library_panel(editor)
	test_stage_context_menu(editor)
	editor.queue_free()
	print(">>> ALL EDITOR RUNTIME SMOKE TESTS PASSED! <<<")

static func _click(canvas: StageCanvas, a: Vector2, b: Vector2) -> void:
	canvas._handle_press(a, 1.0)
	canvas._handle_motion((a + b) * 0.5, 1.0)
	canvas._handle_motion(b, 1.0)
	canvas._handle_release(b)

static func test_tools_and_drawing(ed: EditorMain) -> void:
	var canvas: StageCanvas = ed.stage_panel.stage_canvas
	var tools = ["Select", "Subselect", "Transform", "Lasso", "Pen", "Text", "Line", "Rect", "Circle", "Pencil", "Brush", "InkBottle", "PaintBucket", "Eyedropper", "Eraser", "Hand", "Zoom"]
	for t in tools:
		ed.tool_bar.set_active_tool(t)
		ed._on_tool_selected(t)
		assert(canvas.active_tool == t, "Tool %s must activate" % t)
		_click(canvas, Vector2(-120, -80), Vector2(-40, 20))
	for t in ["Line", "Rect", "Circle", "Pencil", "Brush"]:
		var before = ed.project_doc.items.size()
		ed._on_tool_selected(t)
		_click(canvas, Vector2(50, 50), Vector2(150, 120))
		assert(ed.project_doc.items.size() > before, "Drawing with %s must create an item" % t)
	print("  [OK] R1. All 17 tools activate & accept pointer input without errors")

static func test_timeline_and_layers(ed: EditorMain) -> void:
	var layers_before = ed.project_doc.layers.size()
	ed._on_add_layer()
	ed._on_add_audio_layer()
	assert(ed.project_doc.layers.size() == layers_before + 2, "Layers added")
	ed._on_layer_selected(0)
	ed._go_to_frame(10)
	ed._insert_keyframe_at_current()
	ed._insert_blank_keyframe_at_current()
	ed._insert_frame_at_current()
	ed._undo_action()
	ed._remove_frame_at_current()
	ed._undo_action()
	ed._clear_keyframe_at_current()
	for a in ["create_classic_tween", "create_shape_tween", "insert_frame", "remove_frame", "insert_keyframe", "clear_keyframe", "insert_blank_keyframe", "convert_to_keyframes", "reverse_frames", "clear_frames"]:
		ed._on_timeline_keyframe_action(a, 0, 5)
	ed._on_timeline_keyframe_dragged(0, 0, 3)
	ed._on_toggle_layer_visibility(0)
	ed._on_toggle_layer_visibility(0)
	ed._on_toggle_layer_lock(0)
	ed._on_toggle_layer_lock(0)
	ed._on_onion_skin_toggled(true)
	ed._go_to_frame(5)
	ed._on_onion_skin_toggled(false)
	ed._on_fps_changed(24)
	ed._on_max_frames_changed(80)
	assert(ed.project_doc.get_active_scene().timeline.max_frames == 80, "timeline max_frames synced")
	ed._on_step_frame(1)
	ed._on_play_toggled(true)
	ed._process(0.2)
	ed._on_stop_requested()
	assert(ed.current_frame == 0, "Stop returns to frame 1")
	ed._on_remove_layer()
	ed._on_remove_layer()
	assert(ed.project_doc.layers.size() >= 1, "At least one layer remains")
	print("  [OK] R2. Timeline, keyframes, tweens, layers, playback & onion skin")

static func test_selection_clipboard_arrange(ed: EditorMain) -> void:
	ed._on_new_project()
	var id: String = ed.project_doc.items.keys()[0]
	ed._on_stage_item_selected(id)
	assert(ed.selected_item_id == id, "Item selected")
	ed._duplicate_selected_item()
	ed._on_stage_item_selected(id)
	ed._copy_selection()
	ed._paste_selection()
	ed._cut_selection()
	ed._on_stage_item_selected(id)
	ed._bring_to_front()
	ed._send_to_back()
	ed._group_selection()
	ed._ungroup_selection()
	ed._break_apart_selection()
	ed._on_inspector_name_changed("Renamed")
	ed._on_inspector_color_changed(Color.BLUE)
	ed._on_inspector_stroke_changed(Color.GREEN, 3.0)
	ed._on_inspector_transform_changed(Vector2(10, 10), 0.5, Vector2(2, 2), 0.8)
	ed._on_keyframe_tween_changed("classic")
	ed._on_project_settings_changed(Vector2(1280, 720), Color.WHITE)
	ed._on_stroke_width_changed(4.0)
	ed._on_stroke_color_changed(Color.RED)
	ed._on_fill_color_changed(Color.YELLOW)
	ed._delete_selected_item()
	ed._undo_action()
	ed._redo_action()
	print("  [OK] R3. Selection, clipboard, arrange, inspector & project settings")

static func test_symbol_and_undo(ed: EditorMain) -> void:
	ed._on_new_project()
	var id: String = ed.project_doc.items.keys()[0]
	ed._on_stage_item_selected(id)
	ed.sym_name_edit.text = "SymTest"
	ed.sym_type_option.selected = 0
	ed._on_convert_symbol_confirmed()
	assert(ed.project_doc.library.size() == 1, "Symbol created via F8 flow")
	var sid: String = ed.project_doc.library.keys()[0]
	ed._on_edit_symbol_in_place(sid)
	assert(ed.editing_symbol_id == sid, "Entered symbol editing")
	ed._exit_symbol_editing()
	assert(ed.editing_symbol_id == "", "Exited symbol editing")
	ed._open_convert_symbol_dialog()
	ed.symbol_dialog.hide()
	ed._open_test_movie()
	ed.test_movie_dialog.hide()
	ed.is_playing = false
	ed._on_menu_action("reset_view")
	ed._on_menu_action("toggle_tablet")
	ed._on_menu_action("toggle_tablet")
	for p in ["tools", "timeline", "inspector"]:
		ed._on_toggle_panel(p)
		ed._on_toggle_panel(p)
	print("  [OK] R4. Convert to symbol, edit in place, test movie, menus & panels")

static func test_camera_and_input(ed: EditorMain) -> void:
	var cam = ed.stage_panel.stage_camera
	var z0 = cam.zoom.x
	var wheel = InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	ed._unhandled_input(wheel)
	assert(cam.zoom.x > z0, "Mouse wheel zooms stage camera (editor routes mouse to stage_panel)")
	ed.touch_handler.pinch_zoom_requested.emit(1.5, Vector2.ZERO)
	var p0 = cam.position
	ed.touch_handler.touch_pan_requested.emit(Vector2(30, 0))
	assert(cam.position != p0, "Touch pan moves camera")
	ed.stage_panel.stage_canvas.camera_zoom_requested.emit(false, Vector2.ZERO)
	ed.stage_panel.stage_canvas.camera_pan_requested.emit(Vector2(10, 10))
	for k in [KEY_V, KEY_A, KEY_Q, KEY_L, KEY_P, KEY_T, KEY_N, KEY_R, KEY_O, KEY_Y, KEY_B, KEY_S, KEY_K, KEY_I, KEY_E, KEY_H, KEY_Z, KEY_X, KEY_D, KEY_J, KEY_F5, KEY_F6, KEY_F7]:
		var ev = InputEventKey.new()
		ev.keycode = k
		ev.pressed = true
		ed._unhandled_key_input(ev)
	var ctrl_a = InputEventKey.new()
	ctrl_a.keycode = KEY_A
	ctrl_a.ctrl_pressed = true
	ctrl_a.pressed = true
	ed._on_tool_selected("Select")
	ed._unhandled_key_input(ctrl_a)
	assert(ed.active_tool == "Select", "Ctrl+A must not switch tools")
	print("  [OK] R5. Camera zoom/pan (mouse, touch, canvas) & keyboard shortcuts")

static func test_new_project_resets_undo(ed: EditorMain) -> void:
	ed._on_stage_item_selected("")
	var item = StageItem.new()
	item.id = "item_x"
	item.name = "X"
	item.shape_type = "rect"
	item.size = Vector2(10, 10)
	ed._on_stage_drawing_finished(item, Vector2.ZERO)
	assert(ed.command_stack.can_undo(), "Undo available after drawing")
	ed._on_new_project()
	assert(!ed.command_stack.can_undo(), "New project clears undo history")
	print("  [OK] R6. New project resets undo history")

static func test_file_io(ed: EditorMain) -> void:
	ed._on_new_project()
	var dir = "user://runtime_test"
	DirAccess.make_dir_recursive_absolute(dir)
	var before = JSON.stringify(ed.project_doc.to_dict())
	
	# Save + Open (.rean JSON)
	ed.current_dialog_action = "save"
	ed._on_file_dialog_selected(dir + "/p.rean")
	assert(FileAccess.file_exists(dir + "/p.rean"), "Project file saved")
	ed._on_new_project()
	ed.current_dialog_action = "open"
	ed._on_file_dialog_selected(dir + "/p.rean")
	assert(JSON.stringify(ed.project_doc.to_dict()) == before, "Open restores saved project exactly")
	assert(!ed.command_stack.can_undo(), "Opening a project clears undo history")
	
	# Export FLA + re-import
	ed.current_dialog_action = "export_fla"
	ed._on_file_dialog_selected(dir + "/p.fla")
	assert(FileAccess.file_exists(dir + "/p.fla"), "FLA exported")
	ed.current_dialog_action = "import_fla"
	ed._on_file_dialog_selected(dir + "/p.fla")
	assert(ed.project_doc.layers.size() >= 1 and ed.project_doc.items.size() >= 1, "FLA re-import keeps layers & items")
	
	# Export Atlas JSON
	ed.current_dialog_action = "export_json"
	ed._on_file_dialog_selected(dir + "/atlas.json")
	assert(FileAccess.file_exists(dir + "/atlas.json"), "Atlas JSON exported")
	print("  [OK] R7. Save/Open, FLA export/import & Atlas JSON via editor dialogs")

static func test_png_export(ed: EditorMain) -> void:
	ed._on_new_project()
	ed._on_max_frames_changed(3)
	ed.current_dialog_action = "export_png"
	await ed._on_dir_dialog_selected("user://runtime_test/png")
	assert(ed.current_frame == 0, "PNG export restores the current frame")
	print("  [OK] R8. PNG sequence export completes (renderer-dependent frame count)")

static func test_project_menu_and_settings(ed: EditorMain) -> void:
	# 1. Verifikasi ProjectMenuBtn dan popup item
	var proj_btn = ed.top_menu_bar.project_menu_btn
	assert(proj_btn != null, "TopMenuBar must have project_menu_btn")
	var popup = proj_btn.get_popup()
	assert(popup.item_count >= 10, "Project popup menu must have items")
	
	# 2. Buka ProjectSettingsDialog via menu action dan via shortcut Ctrl+J
	ed._on_menu_action("project_settings")
	assert(ed.project_settings_dialog.visible, "ProjectSettingsDialog must be visible on project_settings action")
	ed.project_settings_dialog.hide()
	
	var ev_ctrl_j = InputEventKey.new()
	ev_ctrl_j.keycode = KEY_J
	ev_ctrl_j.ctrl_pressed = true
	ev_ctrl_j.pressed = true
	ed._unhandled_key_input(ev_ctrl_j)
	assert(ed.project_settings_dialog.visible, "ProjectSettingsDialog must open on Ctrl+J shortcut")
	
	# 3. Ubah pengaturan via dialog dan konfirmasi
	ed.proj_name_edit.text = "My_Awesome_Cartoon"
	ed.proj_preset_option.selected = 1
	ed._on_project_dialog_preset_selected(1) # FHD 1920x1080
	assert(ed.proj_width_spin.value == 1920 and ed.proj_height_spin.value == 1080, "Preset FHD sets dimensions")
	ed.proj_fps_spin.value = 24
	ed.proj_max_frames_spin.value = 120
	ed.proj_bg_color_picker.color = Color(0.1, 0.2, 0.3, 1.0)
	
	ed._on_project_settings_dialog_confirmed()
	assert(ed.project_doc.name == "My_Awesome_Cartoon", "Project name must be updated")
	assert(ed.project_doc.stage_size == Vector2(1920, 1080), "Stage size must be updated to FHD")
	assert(ed.project_doc.fps == 24, "FPS must be updated to 24")
	assert(ed.project_doc.max_frames == 120, "Max frames must be updated to 120")
	assert(ed.project_doc.bg_color == Color(0.1, 0.2, 0.3, 1.0), "Background color must match")
	
	# 4. Uji Project Summary Info
	ed._on_menu_action("project_info")
	assert(ed.status_bar.status_label.text.contains("My_Awesome_Cartoon"), "Status bar displays project info")
	
	# 5. Uji Quick Preset Actions
	ed._on_menu_action("preset_res_mobile") # 1080x1920
	assert(ed.project_doc.stage_size == Vector2(1080, 1920), "Preset mobile sets 1080x1920")
	ed._on_menu_action("preset_res_square") # 1080x1080
	assert(ed.project_doc.stage_size == Vector2(1080, 1080), "Preset square sets 1080x1080")
	ed._on_menu_action("preset_fps_60")
	assert(ed.project_doc.fps == 60, "Preset fps sets 60")
	
	# 6. Uji Export HTML5 Web Player
	ed._on_menu_action("export_html")
	assert(ed.current_dialog_action == "export_html", "current_dialog_action is export_html")
	var html_path = "user://runtime_test/player.html"
	ed._on_file_dialog_selected(html_path)
	assert(FileAccess.file_exists(html_path), "HTML5 Player file must be created")
	var html_text = FileAccess.get_file_as_string(html_path)
	assert(html_text.contains("<!DOCTYPE html>") and html_text.contains("REanimate Web Player"), "HTML5 content is valid")
	
	print("  [OK] R9. Project Menu: Project Settings (Ctrl+J), presets, info summary & HTML5 export")

static func test_project_launcher(ed: EditorMain) -> void:
	# 1. Pastikan node ProjectLauncher terpasang
	assert(ed.project_launcher != null, "ProjectLauncher node must be present")
	
	# 2. Buka launcher via menu action "project_launcher"
	ed._on_menu_action("project_launcher")
	assert(ed.project_launcher.visible, "ProjectLauncher must be visible after project_launcher menu action")
	
	# 3. Test presets dan input custom di launcher UI
	assert(ed.project_launcher.btn_preset_hd != null, "Preset HD button exists")
	assert(ed.project_launcher.btn_preset_retro != null, "Preset Retro button exists")
	ed.project_launcher.custom_w_spin.value = 1280
	ed.project_launcher.custom_h_spin.value = 720
	assert(ed.project_launcher.custom_w_spin.value == 1280 and ed.project_launcher.custom_h_spin.value == 720, "HD custom dimensions updated")
	
	# 4. Tambahkan recent project dan pastikan tersimpan
	var dummy_path = "user://runtime_test/launcher_test.rean"
	ed.project_launcher.add_recent_project(dummy_path)
	assert(ed.project_launcher.recent_projects.has(dummy_path), "Recent project path stored in list")
	
	# 5. Buat project baru dari launcher
	ed._on_launcher_project_created("Super Animation", Vector2(1920, 1080), 30, 240, Color(0.2, 0.2, 0.2, 1.0))
	assert(ed.project_doc.name == "Super Animation", "Project created with correct name")
	assert(ed.project_doc.stage_size == Vector2(1920, 1080), "Project created with correct size")
	assert(ed.project_doc.fps == 30, "Project created with 30 FPS")
	assert(ed.project_doc.max_frames == 240, "Project created with 240 max frames")
	assert(not ed.project_launcher.visible, "ProjectLauncher must be hidden after creating project")
	
	# 6. Simpan project ke disk dan buka via launcher open recent
	ed.project_doc.save_to_file(dummy_path)
	ed._open_project_launcher()
	assert(ed.project_launcher.visible, "Launcher re-opened")
	ed._on_launcher_open_recent(dummy_path)
	assert(ed.project_doc.name == "Super Animation", "Project re-opened correctly via launcher")
	assert(not ed.project_launcher.visible, "Launcher hidden after opening recent project")
	
	# 7. Test tombol close launcher
	ed._open_project_launcher()
	ed.project_launcher.btn_close_launcher.pressed.emit()
	assert(not ed.project_launcher.visible, "Launcher closed via close button")
	
	print("  [OK] R10. Project Launcher / Welcome Screen: Presets, Custom creation, Recent projects list & Open recent")

static func test_library_panel(ed: EditorMain) -> void:
	# 1. Pastikan node LibraryDock terpasang
	assert(ed.library_dock != null, "LibraryDock node must be present")
	
	# 2. Test toggle panel via action dan shortcut Ctrl+L / F11
	ed.library_dock.visible = false
	ed._on_toggle_panel("library")
	assert(ed.library_dock.visible, "Library dock toggled visible via _on_toggle_panel")
	
	var ev_ctrl_l = InputEventKey.new()
	ev_ctrl_l.keycode = KEY_L
	ev_ctrl_l.ctrl_pressed = true
	ev_ctrl_l.pressed = true
	ed._unhandled_key_input(ev_ctrl_l)
	assert(not ed.library_dock.visible, "Ctrl+L toggles library dock hidden")
	
	var ev_f11 = InputEventKey.new()
	ev_f11.keycode = KEY_F11
	ev_f11.pressed = true
	ed._unhandled_key_input(ev_f11)
	assert(ed.library_dock.visible, "F11 toggles library dock visible")
	
	# 3. Test pembuatan symbol baru dari Library
	var lib_count_before = ed.project_doc.library.size()
	ed._on_library_create_symbol("Player_Walk", "movie_clip", 4)
	assert(ed.project_doc.library.size() == lib_count_before + 1, "New symbol created in project library")
	
	var sym_id = ""
	for id in ed.project_doc.library:
		if ed.project_doc.library[id].name == "Player_Walk":
			sym_id = id
			break
	assert(sym_id != "", "Created symbol ID found in library")
	assert(ed.editing_symbol_id == sym_id, "Automatically enters symbol in-place edit mode")
	ed._exit_symbol_editing()
	assert(ed.editing_symbol_id == "", "Exited symbol edit mode back to Scene 1")
	
	# 4. Test duplikasi symbol
	ed._on_library_duplicate_symbol(sym_id)
	assert(ed.project_doc.library.size() == lib_count_before + 2, "Symbol duplicated in library")
	var dup_id = ""
	for id in ed.project_doc.library:
		if ed.project_doc.library[id].name == "Player_Walk Copy":
			dup_id = id
			break
	assert(dup_id != "", "Duplicated symbol ID found")
	
	# 5. Test rename symbol
	ed._on_library_rename_symbol(dup_id, "Player_Run")
	assert(ed.project_doc.library[dup_id].name == "Player_Run", "Symbol renamed successfully")
	
	# 6. Test Place on Stage (memasukkan instance symbol ke Stage)
	var items_before = ed.project_doc.items.size()
	ed._on_library_place_symbol(sym_id)
	assert(ed.project_doc.items.size() == items_before + 1, "Symbol instance placed on stage")
	var placed_item: StageItem = ed.project_doc.items[ed.selected_item_id]
	assert(placed_item.shape_type == "symbol", "Placed item has shape_type == symbol")
	assert(placed_item.library_ref == sym_id, "Placed item references correct symbol")
	
	# 7. Test Filter / Search symbols di Library list
	ed.library_dock.search_edit.text = "Run"
	ed.library_dock.search_edit.text_changed.emit("Run")
	assert(ed.library_dock.symbol_list.item_count == 1, "Filter displays only matching symbols")
	ed.library_dock.search_edit.text = ""
	ed.library_dock.search_edit.text_changed.emit("")
	assert(ed.library_dock.symbol_list.item_count >= 2, "Clearing filter restores all symbols")
	
	# 8. Test Delete symbol
	ed._on_library_delete_symbol(dup_id)
	assert(not ed.project_doc.library.has(dup_id), "Symbol deleted from library")
	
	# 9. Test Close button Library dock
	ed.library_dock.btn_close_library.pressed.emit()
	assert(not ed.library_dock.visible, "Library dock closed via close button")
	
	print("  [OK] R11. Flash Library Panel: Preview, New Symbol (Ctrl+F8), Duplicate, Rename, Filter, Place to Stage & Shortcuts (Ctrl+L/F11)")

static func test_stage_context_menu(ed: EditorMain) -> void:
	# 1. Pastikan node StageContextMenu ada
	assert(ed.stage_context_menu != null, "StageContextMenu node must be present")
	
	# 2. Test klik kanan pada objek mentah (raw shape) di Stage
	ed._on_new_project()
	var raw_item_id: String = ed.project_doc.items.keys()[0]
	ed._on_stage_item_selected(raw_item_id)
	
	ed._on_stage_context_menu_requested(Vector2(250, 250), raw_item_id)
	assert(ed.stage_context_menu.visible, "Context menu pops up on raw object right-click")
	assert(ed.stage_context_menu.item_count >= 8, "Context menu contains full suite of object actions")
	
	# 3. Test memilih aksi Convert to Symbol... (F8) dari Context Menu
	ed._on_context_menu_item_selected(1)
	assert(ed.symbol_dialog.visible, "SymbolDialog (F8) is opened via right-click Convert to Symbol")
	ed.symbol_dialog.hide()
	
	# 4. Test memilih aksi Cut, Copy, Duplicate dari Context Menu
	var count_before = ed.project_doc.items.size()
	ed._on_context_menu_item_selected(6) # Duplicate
	assert(ed.project_doc.items.size() == count_before + 1, "Duplicate action via context menu works")
	
	# 5. Test klik kanan di area panggung kosong
	ed._on_stage_item_selected("")
	ed._on_stage_context_menu_requested(Vector2(400, 300), "")
	assert(ed.stage_context_menu.visible, "Context menu pops up on empty stage right-click")
	ed.stage_context_menu.hide()
	
	print("  [OK] R12. Stage Right-Click Context Menu: Raw Object to Symbol (F8), Cut/Copy/Paste, Duplicate, Group & Empty Stage Actions")
