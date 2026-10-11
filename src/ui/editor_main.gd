class_name EditorMain
extends Control

# Modular Component References
@onready var top_menu_bar: TopMenuBar = %TopMenuBar
@onready var tool_bar: ToolBar = %ToolBar
@onready var stage_panel: StagePanel = %StagePanel
@onready var timeline_dock: TimelineDock = %TimelineDock
@onready var inspector_dock: InspectorDock = %InspectorDock
@onready var status_bar: StatusBar = %StatusBar
@onready var file_dialog: FileDialog = %EditorFileDialog

# Data Document & Animation State
var project_doc: ProjectDocument
var active_layer_index: int = 0
var current_frame: int = 0
var is_playing: bool = false
var is_looping: bool = true
var playback_timer: float = 0.0

var selected_item_id: String = ""
var active_tool: String = "Select"
var is_onion_skin: bool = false

# File dialog action state: "open", "save", "export_json", "export_png"
var current_dialog_action: String = ""

func _ready() -> void:
	project_doc = ProjectDocument.create_default()
	_connect_component_signals()
	_sync_project_to_ui()
	_update_stage_at_frame(0)
	status_bar.set_status("Welcome to REanimate! Ready.")

func _connect_component_signals() -> void:
	# 1. Top Menu Bar
	top_menu_bar.action_requested.connect(_on_menu_action)
	top_menu_bar.toggle_panel_requested.connect(_on_toggle_panel)
	
	# 2. Tool Bar
	tool_bar.tool_selected.connect(_on_tool_selected)
	tool_bar.stroke_width_changed.connect(_on_stroke_width_changed)
	tool_bar.quick_color_changed.connect(_on_quick_color_changed)
	
	# 3. Stage Panel
	stage_panel.item_selected.connect(_on_stage_item_selected)
	stage_panel.item_transformed.connect(_on_stage_item_transformed)
	stage_panel.drawing_finished.connect(_on_stage_drawing_finished)
	stage_panel.zoom_changed.connect(_on_stage_zoom_changed)
	stage_panel.mouse_stage_pos_changed.connect(func(pos): status_bar.set_cursor_position(pos))
	
	# 4. Timeline Dock
	timeline_dock.play_toggled.connect(_on_play_toggled)
	timeline_dock.loop_toggled.connect(_on_loop_toggled)
	timeline_dock.stop_requested.connect(_on_stop_requested)
	timeline_dock.step_frame_requested.connect(_on_step_frame)
	timeline_dock.keyframe_insert_requested.connect(_insert_keyframe_at_current)
	timeline_dock.keyframe_remove_requested.connect(_remove_keyframe_at_current)
	timeline_dock.frame_changed.connect(_go_to_frame)
	timeline_dock.onion_skin_toggled.connect(_on_onion_skin_toggled)
	timeline_dock.fps_changed.connect(_on_fps_changed)
	timeline_dock.max_frames_changed.connect(_on_max_frames_changed)
	timeline_dock.layer_selected.connect(_on_layer_selected)
	timeline_dock.layer_add_requested.connect(_on_add_layer)
	timeline_dock.layer_remove_requested.connect(_on_remove_layer)
	
	# 5. Inspector Dock
	inspector_dock.transform_changed.connect(_on_inspector_transform_changed)
	inspector_dock.item_name_changed.connect(_on_inspector_name_changed)
	inspector_dock.item_color_changed.connect(_on_inspector_color_changed)
	inspector_dock.item_stroke_changed.connect(_on_inspector_stroke_changed)
	inspector_dock.item_delete_requested.connect(_delete_selected_item)
	inspector_dock.item_duplicate_requested.connect(_duplicate_selected_item)
	inspector_dock.item_selected_from_library.connect(_on_stage_item_selected)
	inspector_dock.project_settings_changed.connect(_on_project_settings_changed)
	inspector_dock.keyframe_tween_changed.connect(_on_keyframe_tween_changed)
	
	# 6. File Dialog
	file_dialog.file_selected.connect(_on_file_dialog_selected)
	file_dialog.dir_selected.connect(_on_dir_dialog_selected)

func _sync_project_to_ui() -> void:
	stage_panel.stage_canvas.stage_size = project_doc.stage_size
	stage_panel.stage_canvas.bg_color = project_doc.bg_color
	inspector_dock.update_project_data(project_doc.stage_size, project_doc.bg_color)
	inspector_dock.update_library_list(project_doc.items, selected_item_id)
	timeline_dock.refresh_layers_ui(project_doc.layers, active_layer_index)
	timeline_dock.update_frame_info(current_frame, project_doc.max_frames, project_doc.fps)

# Playback engine
func _process(delta: float) -> void:
	if is_playing:
		playback_timer += delta
		var frame_time: float = 1.0 / float(project_doc.fps)
		if playback_timer >= frame_time:
			playback_timer -= frame_time
			var next_frame = current_frame + 1
			if next_frame >= project_doc.max_frames:
				if is_looping:
					next_frame = 0
				else:
					is_playing = false
					timeline_dock.set_playing_state(false)
					return
			_go_to_frame(next_frame)

func _on_play_toggled(playing: bool) -> void:
	is_playing = playing
	status_bar.set_status("Playback " + ("started" if is_playing else "paused"))

func _on_loop_toggled(looping: bool) -> void:
	is_looping = looping

func _on_stop_requested() -> void:
	is_playing = false
	timeline_dock.set_playing_state(false)
	_go_to_frame(0)
	status_bar.set_status("Playback stopped at Frame 0")

func _on_step_frame(delta_frame: int) -> void:
	_go_to_frame(current_frame + delta_frame)

func _go_to_frame(frame: int) -> void:
	current_frame = clampi(frame, 0, project_doc.max_frames - 1)
	_update_stage_at_frame(current_frame)

func _update_stage_at_frame(frame: int) -> void:
	var active_transforms: Dictionary = {}
	for layer in project_doc.layers:
		if not layer.is_visible: continue
		for id in project_doc.items:
			var t = layer.get_interpolated_transform(id, frame)
			if t != null:
				active_transforms[id] = t.duplicate_transform()
				
	var onion_skins: Array[Dictionary] = []
	if is_onion_skin and not is_playing:
		for offset in [-2, -1, 1, 2]:
			var target_f = frame + offset
			if target_f >= 0 and target_f < project_doc.max_frames:
				var os_transforms: Dictionary = {}
				for layer in project_doc.layers:
					if not layer.is_visible: continue
					for id in project_doc.items:
						var t = layer.get_interpolated_transform(id, target_f)
						if t != null:
							os_transforms[id] = t
				var alpha = 0.35 if abs(offset) == 1 else 0.18
				onion_skins.append({ "transforms": os_transforms, "alpha": alpha })
				
	stage_panel.stage_canvas.set_stage_data(project_doc.items, active_transforms, onion_skins)
	timeline_dock.update_timeline_grid(project_doc.layers, active_layer_index, current_frame, project_doc.max_frames)
	timeline_dock.update_frame_info(current_frame, project_doc.max_frames, project_doc.fps)
	_update_inspector_display()

func _update_inspector_display() -> void:
	if selected_item_id != "" and project_doc.items.has(selected_item_id):
		var item: StageItem = project_doc.items[selected_item_id]
		var active_layer = project_doc.layers[active_layer_index]
		var t = active_layer.get_interpolated_transform(selected_item_id, current_frame)
		inspector_dock.update_active_item(item, t)
		var kf = active_layer.get_keyframe_at(current_frame)
		if kf != null:
			inspector_dock.update_tween_type(kf.tween_to_next)
	else:
		inspector_dock.update_active_item(null, null)
	inspector_dock.update_library_list(project_doc.items, selected_item_id)

# Tools & Brush Settings
func _on_tool_selected(tool_name: String) -> void:
	active_tool = tool_name
	stage_panel.stage_canvas.active_tool = tool_name
	top_menu_bar.set_active_tool_name(tool_name)
	status_bar.set_status("Tool switched to: " + tool_name)

func _on_stroke_width_changed(w: float) -> void:
	stage_panel.stage_canvas.current_stroke_width = w

func _on_quick_color_changed(col: Color) -> void:
	stage_panel.stage_canvas.current_draw_color = col
	if selected_item_id != "" and project_doc.items.has(selected_item_id):
		project_doc.items[selected_item_id].color = col
		inspector_dock.prop_color_picker.color = col
		stage_panel.stage_canvas.queue_redraw()

# Keyframes & Layers
func _insert_keyframe_at_current() -> void:
	if active_layer_index < 0 or active_layer_index >= project_doc.layers.size():
		return
	var layer = project_doc.layers[active_layer_index]
	var kf = KeyframeData.new()
	kf.frame_index = current_frame
	kf.tween_to_next = "linear"
	
	for id in project_doc.items:
		var cur_t = layer.get_interpolated_transform(id, current_frame)
		if cur_t != null:
			kf.transforms[id] = cur_t.duplicate_transform()
			
	layer.set_keyframe(kf)
	_update_stage_at_frame(current_frame)
	status_bar.set_status("Keyframe inserted on %s at Frame %d (F6)" % [layer.name, current_frame])

func _remove_keyframe_at_current() -> void:
	if active_layer_index < 0 or active_layer_index >= project_doc.layers.size():
		return
	var layer = project_doc.layers[active_layer_index]
	if layer.remove_keyframe_at(current_frame):
		_update_stage_at_frame(current_frame)
		status_bar.set_status("Keyframe removed at Frame %d (F7)" % current_frame)

func _on_onion_skin_toggled(enabled: bool) -> void:
	is_onion_skin = enabled
	_update_stage_at_frame(current_frame)

func _on_fps_changed(new_fps: int) -> void:
	project_doc.fps = new_fps

func _on_max_frames_changed(new_max: int) -> void:
	project_doc.max_frames = new_max
	_update_stage_at_frame(current_frame)

func _on_layer_selected(index: int) -> void:
	active_layer_index = index
	timeline_dock.update_timeline_grid(project_doc.layers, active_layer_index, current_frame, project_doc.max_frames)
	_update_inspector_display()

func _on_add_layer() -> void:
	var new_l = AnimationLayer.new()
	new_l.name = "Layer " + str(project_doc.layers.size() + 1)
	project_doc.layers.append(new_l)
	active_layer_index = project_doc.layers.size() - 1
	timeline_dock.refresh_layers_ui(project_doc.layers, active_layer_index)
	_update_stage_at_frame(current_frame)
	status_bar.set_status("Added new layer: " + new_l.name)

func _on_remove_layer() -> void:
	if project_doc.layers.size() <= 1:
		status_bar.set_status("Cannot delete the only layer.")
		return
	project_doc.layers.remove_at(active_layer_index)
	active_layer_index = clampi(active_layer_index, 0, project_doc.layers.size() - 1)
	timeline_dock.refresh_layers_ui(project_doc.layers, active_layer_index)
	_update_stage_at_frame(current_frame)
	status_bar.set_status("Layer removed.")

# Stage Selection & Drawing
func _on_stage_item_selected(id: String) -> void:
	selected_item_id = id
	stage_panel.stage_canvas.selected_item_id = id
	_update_inspector_display()
	if id != "" and project_doc.items.has(id):
		status_bar.set_status("Selected item: " + project_doc.items[id].name)
	else:
		status_bar.set_status("Deselected.")

func _on_stage_item_transformed(id: String, new_t: ItemTransform) -> void:
	if active_layer_index < 0 or active_layer_index >= project_doc.layers.size():
		return
	var layer = project_doc.layers[active_layer_index]
	var kf = layer.get_keyframe_at(current_frame)
	if kf == null:
		kf = KeyframeData.new()
		kf.frame_index = current_frame
		kf.tween_to_next = "linear"
		layer.set_keyframe(kf)
		
	kf.transforms[id] = new_t.duplicate_transform()
	_update_stage_at_frame(current_frame)

func _on_stage_drawing_finished(new_item: StageItem, center: Vector2) -> void:
	project_doc.items[new_item.id] = new_item
	var layer = project_doc.layers[active_layer_index]
	var kf = layer.get_keyframe_at(current_frame)
	if kf == null:
		kf = KeyframeData.new()
		kf.frame_index = current_frame
		kf.tween_to_next = "linear"
		layer.set_keyframe(kf)
		
	var t = ItemTransform.new()
	t.position = center
	t.rotation = 0.0
	t.scale = Vector2.ONE
	kf.transforms[new_item.id] = t
	
	selected_item_id = new_item.id
	stage_panel.stage_canvas.selected_item_id = new_item.id
	tool_bar.set_active_tool("Select")
	_on_tool_selected("Select")
	_update_stage_at_frame(current_frame)
	status_bar.set_status("Created item: " + new_item.name)

func _on_stage_zoom_changed(zoom_val: float) -> void:
	status_bar.set_zoom_text(int(round(zoom_val * 100.0)))

# Inspector Bindings
func _on_inspector_transform_changed(pos: Vector2, rot: float, scale_v: Vector2, opacity: float) -> void:
	if selected_item_id == "" or not project_doc.items.has(selected_item_id): return
	var t = ItemTransform.new()
	t.position = pos
	t.rotation = rot
	t.scale = scale_v
	t.opacity = opacity
	_on_stage_item_transformed(selected_item_id, t)

func _on_inspector_name_changed(new_name: String) -> void:
	if selected_item_id != "" and project_doc.items.has(selected_item_id):
		project_doc.items[selected_item_id].name = new_name
		inspector_dock.update_library_list(project_doc.items, selected_item_id)

func _on_inspector_color_changed(col: Color) -> void:
	if selected_item_id != "" and project_doc.items.has(selected_item_id):
		project_doc.items[selected_item_id].color = col
		stage_panel.stage_canvas.queue_redraw()

func _on_inspector_stroke_changed(stroke_col: Color, stroke_w: float) -> void:
	if selected_item_id != "" and project_doc.items.has(selected_item_id):
		project_doc.items[selected_item_id].stroke_color = stroke_col
		project_doc.items[selected_item_id].stroke_width = stroke_w
		stage_panel.stage_canvas.queue_redraw()

func _delete_selected_item() -> void:
	if selected_item_id != "" and project_doc.items.has(selected_item_id):
		project_doc.items.erase(selected_item_id)
		selected_item_id = ""
		stage_panel.stage_canvas.selected_item_id = ""
		_update_stage_at_frame(current_frame)
		status_bar.set_status("Item deleted.")

func _duplicate_selected_item() -> void:
	if selected_item_id == "" or not project_doc.items.has(selected_item_id): return
	var orig_item: StageItem = project_doc.items[selected_item_id]
	var copy_item = StageItem.from_dict(orig_item.to_dict())
	copy_item.id = "item_" + str(Time.get_ticks_usec())
	copy_item.name = orig_item.name + " Copy"
	project_doc.items[copy_item.id] = copy_item
	
	var active_l = project_doc.layers[active_layer_index]
	var orig_t = active_l.get_interpolated_transform(selected_item_id, current_frame)
	var copy_t = orig_t.duplicate_transform() if orig_t != null else ItemTransform.new()
	copy_t.position += Vector2(20, 20)
	
	var kf = active_l.get_keyframe_at(current_frame)
	if kf == null:
		kf = KeyframeData.new()
		kf.frame_index = current_frame
		kf.tween_to_next = "linear"
		active_l.set_keyframe(kf)
	kf.transforms[copy_item.id] = copy_t
	
	selected_item_id = copy_item.id
	stage_panel.stage_canvas.selected_item_id = copy_item.id
	_update_stage_at_frame(current_frame)
	status_bar.set_status("Item duplicated: " + copy_item.name)

func _on_project_settings_changed(new_sz: Vector2, new_bg: Color) -> void:
	project_doc.stage_size = new_sz
	project_doc.bg_color = new_bg
	stage_panel.stage_canvas.set_stage_settings(new_sz, new_bg)
	status_bar.set_status("Project canvas settings updated: %dx%d" % [int(new_sz.x), int(new_sz.y)])

func _on_keyframe_tween_changed(tween_type: String) -> void:
	var layer = project_doc.layers[active_layer_index]
	var kf = layer.get_keyframe_at(current_frame)
	if kf != null:
		kf.tween_to_next = tween_type
		timeline_dock.update_timeline_grid(project_doc.layers, active_layer_index, current_frame, project_doc.max_frames)
		status_bar.set_status("Keyframe tween set to: " + tween_type)

# Panel Toggling (Expandable UI)
func _on_toggle_panel(panel_name: String) -> void:
	match panel_name:
		"tools":
			tool_bar.visible = !tool_bar.visible
			status_bar.set_status("Toolbar " + ("visible" if tool_bar.visible else "hidden"))
		"timeline":
			timeline_dock.visible = !timeline_dock.visible
			status_bar.set_status("Timeline " + ("visible" if timeline_dock.visible else "hidden"))
		"inspector":
			inspector_dock.visible = !inspector_dock.visible
			status_bar.set_status("Inspector " + ("visible" if inspector_dock.visible else "hidden"))

# Menu & File Actions
func _on_menu_action(action: String) -> void:
	match action:
		"new":
			_on_new_project()
		"open":
			_on_open_project_clicked()
		"save":
			_on_save_project_clicked()
		"export_json":
			_on_export_json_clicked()
		"export_png":
			_on_export_png_seq_clicked()
		"reset_view":
			stage_panel.reset_camera_view()
			status_bar.set_status("Camera view reset to 100%.")

func _on_new_project() -> void:
	project_doc = ProjectDocument.create_default()
	active_layer_index = 0
	current_frame = 0
	selected_item_id = ""
	_sync_project_to_ui()
	_update_stage_at_frame(0)
	status_bar.set_status("New project created.")

func _on_open_project_clicked() -> void:
	current_dialog_action = "open"
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.filters = PackedStringArray(["*.rean ; REanimate Project File", "*.json ; JSON File"])
	file_dialog.popup_centered(Vector2i(720, 460))

func _on_save_project_clicked() -> void:
	current_dialog_action = "save"
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.filters = PackedStringArray(["*.rean ; REanimate Project File"])
	file_dialog.popup_centered(Vector2i(720, 460))

func _on_export_json_clicked() -> void:
	current_dialog_action = "export_json"
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.filters = PackedStringArray(["*.json ; Adobe Animate Atlas JSON"])
	file_dialog.popup_centered(Vector2i(720, 460))

func _on_export_png_seq_clicked() -> void:
	current_dialog_action = "export_png"
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	file_dialog.filters = PackedStringArray([])
	file_dialog.popup_centered(Vector2i(720, 460))

func _on_file_dialog_selected(path: String) -> void:
	if current_dialog_action == "save":
		var err = project_doc.save_to_file(path)
		if err == OK:
			status_bar.set_status("Saved project: " + path)
		else:
			status_bar.set_status("Failed to save project. Error: " + str(err))
	elif current_dialog_action == "open":
		var loaded_doc = ProjectDocument.load_from_file(path)
		if loaded_doc != null:
			project_doc = loaded_doc
			active_layer_index = 0
			current_frame = 0
			_sync_project_to_ui()
			_update_stage_at_frame(0)
			status_bar.set_status("Loaded project: " + path)
		else:
			status_bar.set_status("Failed to load project file.")
	elif current_dialog_action == "export_json":
		var err = ExportManager.export_to_texture_atlas_json(project_doc, path)
		if err == OK:
			status_bar.set_status("Exported Atlas JSON: " + path)
		else:
			status_bar.set_status("Export failed. Error: " + str(err))

func _on_dir_dialog_selected(path: String) -> void:
	if current_dialog_action == "export_png":
		var count = ExportManager.export_png_sequence(stage_panel.stage_viewport, project_doc, path, func(f): _update_stage_at_frame(f))
		status_bar.set_status("Exported %d PNG frames to: %s" % [count, path])

# Global Input & Keyboard Shortcuts
func _unhandled_key_input(event: InputEvent) -> void:
	if stage_panel.handle_key_input(event):
		return
		
	if event.is_pressed() and not event.is_echo():
		match event.keycode:
			KEY_F6:
				_insert_keyframe_at_current()
			KEY_F7:
				_remove_keyframe_at_current()
			KEY_SPACE:
				pass
			KEY_V:
				tool_bar.set_active_tool("Select")
				_on_tool_selected("Select")
			KEY_B:
				tool_bar.set_active_tool("Brush")
				_on_tool_selected("Brush")
			KEY_R:
				tool_bar.set_active_tool("Rect")
				_on_tool_selected("Rect")
			KEY_O:
				tool_bar.set_active_tool("Circle")
				_on_tool_selected("Circle")
			KEY_DELETE, KEY_BACKSPACE:
				_delete_selected_item()

func _unhandled_input(event: InputEvent) -> void:
	stage_panel.handle_mouse_input(event)
