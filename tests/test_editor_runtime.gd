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
