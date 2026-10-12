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
@onready var audio_player: AudioStreamPlayer = %AudioPlayer
@onready var symbol_dialog: ConfirmationDialog = %SymbolDialog
@onready var sym_name_edit: LineEdit = %SymNameEdit
@onready var sym_type_option: OptionButton = %SymTypeOption
@onready var test_movie_dialog: Window = %TestMovieDialog
@onready var test_movie_canvas: ColorRect = %TestMovieCanvas
@onready var test_movie_frame_label: Label = %TestMovieFrameLabel

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
var is_tablet_mode: bool = false
var editing_symbol_id: String = ""
var clipboard_item: StageItem = null
var clipboard_transform: ItemTransform = null

# File dialog action state: "open", "save", "import_fla", "export_fla", "export_json", "export_png", "export_html"
var current_dialog_action: String = ""

# Command Stack (Undo/Redo)
var command_stack: CommandStack = CommandStack.new()

# Touch Input Handler
var touch_handler: TouchInputHandler

func _ready() -> void:
	project_doc = ProjectDocument.create_default()
	touch_handler = TouchInputHandler.new()
	_connect_touch_signals()
	_connect_component_signals()
	_sync_project_to_ui()
	_update_stage_at_frame(0)
	status_bar.set_status("Welcome to REanimate! Adobe Flash / Animate Suite Ready.")

func _connect_touch_signals() -> void:
	touch_handler.pinch_zoom_requested.connect(func(scale_factor, _center):
		stage_panel.set_camera_zoom((stage_panel.stage_camera.zoom * scale_factor).clamp(Vector2(0.2, 0.2), Vector2(10.0, 10.0)))
	)
	touch_handler.touch_pan_requested.connect(func(delta):
		stage_panel.stage_camera.position -= delta / stage_panel.stage_camera.zoom
	)
	touch_handler.stylus_stroke_point.connect(func(pos, pressure):
		stage_panel.stage_canvas.current_stroke_width = max(1.0, tool_bar.stroke_width_spin.value * pressure * 1.5)
	)

func _connect_component_signals() -> void:
	# 1. Top Menu Bar
	top_menu_bar.action_requested.connect(_on_menu_action)
	top_menu_bar.toggle_panel_requested.connect(_on_toggle_panel)
	
	# 2. Tool Bar
	tool_bar.tool_selected.connect(_on_tool_selected)
	tool_bar.stroke_width_changed.connect(_on_stroke_width_changed)
	tool_bar.stroke_color_changed.connect(_on_stroke_color_changed)
	tool_bar.fill_color_changed.connect(_on_fill_color_changed)
	tool_bar.quick_color_changed.connect(_on_quick_color_changed)
	tool_bar.object_drawing_toggled.connect(func(en): status_bar.set_status("Object Drawing: " + ("ON" if en else "OFF (Merge)")))
	
	# 3. Stage Panel
	stage_panel.item_selected.connect(_on_stage_item_selected)
	stage_panel.item_multi_selected.connect(_on_stage_item_multi_selected)
	stage_panel.item_transformed.connect(_on_stage_item_transformed)
	stage_panel.item_deleted.connect(_delete_item_from_project)
	stage_panel.drawing_finished.connect(_on_stage_drawing_finished)
	stage_panel.zoom_changed.connect(_on_stage_zoom_changed)
	stage_panel.mouse_stage_pos_changed.connect(func(pos): status_bar.set_cursor_position(pos))
	stage_panel.symbol_edit_requested.connect(_on_edit_symbol_in_place)
	
	stage_panel.stage_canvas.color_sampled.connect(func(sampled_col, is_stroke):
		if is_stroke:
			tool_bar.set_stroke_color(sampled_col)
			_on_stroke_color_changed(sampled_col)
		else:
			tool_bar.set_fill_color(sampled_col)
			_on_fill_color_changed(sampled_col)
		status_bar.set_status("Sampled color: #" + sampled_col.to_html(false))
	)
	stage_panel.stage_canvas.camera_pan_requested.connect(func(delta):
		stage_panel.stage_camera.position -= delta / stage_panel.stage_camera.zoom
	)
	stage_panel.stage_canvas.camera_zoom_requested.connect(func(zoom_in, _center):
		if zoom_in:
			stage_panel.zoom_in()
		else:
			stage_panel.zoom_out()
	)
	
	# 4. Timeline Dock
	timeline_dock.play_toggled.connect(_on_play_toggled)
	timeline_dock.loop_toggled.connect(_on_loop_toggled)
	timeline_dock.stop_requested.connect(_on_stop_requested)
	timeline_dock.step_frame_requested.connect(_on_step_frame)
	timeline_dock.keyframe_insert_requested.connect(_insert_keyframe_at_current)
	timeline_dock.blank_keyframe_insert_requested.connect(_insert_blank_keyframe_at_current)
	timeline_dock.frame_insert_requested.connect(_insert_frame_at_current)
	timeline_dock.frame_remove_requested.connect(_remove_frame_at_current)
	timeline_dock.keyframe_remove_requested.connect(_clear_keyframe_at_current)
	timeline_dock.frame_changed.connect(_go_to_frame)
	timeline_dock.onion_skin_toggled.connect(_on_onion_skin_toggled)
	timeline_dock.fps_changed.connect(_on_fps_changed)
	timeline_dock.max_frames_changed.connect(_on_max_frames_changed)
	timeline_dock.layer_selected.connect(_on_layer_selected)
	timeline_dock.layer_add_requested.connect(_on_add_layer)
	timeline_dock.audio_layer_add_requested.connect(_on_add_audio_layer)
	timeline_dock.layer_remove_requested.connect(_on_remove_layer)
	timeline_dock.layer_visibility_toggled.connect(_on_toggle_layer_visibility)
	timeline_dock.layer_lock_toggled.connect(_on_toggle_layer_lock)
	timeline_dock.keyframe_action_requested.connect(_on_timeline_keyframe_action)
	timeline_dock.keyframe_dragged.connect(_on_timeline_keyframe_dragged)
	
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
	
	# 7. Symbol Dialog
	symbol_dialog.confirmed.connect(_on_convert_symbol_confirmed)
	
	# 8. Test Movie Dialog
	test_movie_dialog.close_requested.connect(func(): test_movie_dialog.hide())

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
			
	if test_movie_dialog.visible:
		test_movie_frame_label.text = "Playing: Frame %d / %d (%.1f fps)" % [current_frame + 1, project_doc.max_frames, float(project_doc.fps)]

func _on_play_toggled(playing: bool) -> void:
	is_playing = playing
	status_bar.set_status("Playback " + ("started (Enter)" if is_playing else "paused (Enter)"))

func _on_loop_toggled(looping: bool) -> void:
	is_looping = looping

func _on_stop_requested() -> void:
	is_playing = false
	timeline_dock.set_playing_state(false)
	_go_to_frame(0)
	status_bar.set_status("Playback stopped at Frame 1")

func _on_step_frame(delta_frame: int) -> void:
	_go_to_frame(current_frame + delta_frame)

func _go_to_frame(frame: int) -> void:
	current_frame = clampi(frame, 0, project_doc.max_frames - 1)
	_update_stage_at_frame(current_frame)

func _update_stage_at_frame(frame: int) -> void:
	var active_transforms: Dictionary = {}
	var layer_transforms: Array[Dictionary] = []
	
	# Painter's algorithm: render from bottom layer (last in list) up to top layer (first in list)
	for l_i in range(project_doc.layers.size() - 1, -1, -1):
		var layer = project_doc.layers[l_i]
		if not layer.is_visible: continue
		var lt: Dictionary = {}
		for id in project_doc.items:
			var t = layer.get_interpolated_transform(id, frame)
			if t != null:
				var dt = t.duplicate_transform()
				lt[id] = dt
				active_transforms[id] = dt
		if not lt.is_empty():
			layer_transforms.append(lt)
				
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
				onion_skins.append({"transforms": os_transforms, "alpha": alpha})
	var layer_item_order: Array[String] = []
	var locked_items: Dictionary = {}
	var visible_items: Dictionary = {}
	
	# Top layer (index 0) has highest selection priority
	for layer in project_doc.layers:
		for kf in layer.keyframes:
			for id in kf.transforms:
				if not layer_item_order.has(id):
					layer_item_order.append(id)
				locked_items[id] = layer.is_locked
				visible_items[id] = layer.is_visible

	stage_panel.stage_canvas.set_stage_data(project_doc.items, active_transforms, onion_skins, project_doc.symbols, layer_transforms, layer_item_order, locked_items, visible_items)
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

func _on_stroke_color_changed(col: Color) -> void:
	stage_panel.stage_canvas.current_stroke_color = col
	if selected_item_id != "" and project_doc.items.has(selected_item_id):
		project_doc.items[selected_item_id].stroke_color = col
		stage_panel.stage_canvas.queue_redraw()

func _on_fill_color_changed(col: Color) -> void:
	stage_panel.stage_canvas.current_fill_color = col
	stage_panel.stage_canvas.current_draw_color = col
	if selected_item_id != "" and project_doc.items.has(selected_item_id):
		project_doc.items[selected_item_id].color = col
		inspector_dock.prop_color_picker.color = col
		stage_panel.stage_canvas.queue_redraw()

func _on_quick_color_changed(col: Color) -> void:
	_on_fill_color_changed(col)

# Keyframes & Frame Spans (Flash F5, F6, F7, Shift+F5, Shift+F6)
func _insert_keyframe_at_current() -> void:
	if active_layer_index < 0 or active_layer_index >= project_doc.layers.size(): return
	var layer = project_doc.layers[active_layer_index]
	if layer.is_locked:
		status_bar.set_status("Layer is locked. Unlock to insert keyframe.")
		return
		
	var kf = KeyframeData.new()
	kf.frame_index = current_frame
	kf.tween_to_next = "linear"
	for id in project_doc.items:
		var cur_t = layer.get_interpolated_transform(id, current_frame)
		if cur_t != null:
			kf.transforms[id] = cur_t.duplicate_transform()
			
	layer.set_keyframe(kf)
	_update_stage_at_frame(current_frame)
	status_bar.set_status("Keyframe inserted on %s at Frame %d (F6)" % [layer.name, current_frame + 1])

func _insert_blank_keyframe_at_current() -> void:
	if active_layer_index < 0 or active_layer_index >= project_doc.layers.size(): return
	var layer = project_doc.layers[active_layer_index]
	if layer.is_locked: return
	layer.insert_blank_keyframe(current_frame)
	_update_stage_at_frame(current_frame)
	status_bar.set_status("Blank Keyframe inserted on %s at Frame %d (F7)" % [layer.name, current_frame + 1])

func _insert_frame_at_current() -> void:
	var cmd = DocCommands.InsertFrameSpanCommand.new(project_doc, current_frame)
	command_stack.execute_command(cmd)
	_update_stage_at_frame(current_frame)
	status_bar.set_status("Frame span extended across layers at Frame %d (F5)" % [current_frame + 1])

func _remove_frame_at_current() -> void:
	var cmd = DocCommands.RemoveFrameSpanCommand.new(project_doc, current_frame)
	command_stack.execute_command(cmd)
	_update_stage_at_frame(current_frame)
	status_bar.set_status("Frame span removed at Frame %d (Shift+F5)" % [current_frame + 1])

func _clear_keyframe_at_current() -> void:
	if active_layer_index < 0 or active_layer_index >= project_doc.layers.size(): return
	var layer = project_doc.layers[active_layer_index]
	if layer.clear_keyframe(current_frame):
		_update_stage_at_frame(current_frame)
		status_bar.set_status("Keyframe cleared at Frame %d (Shift+F6)" % [current_frame + 1])

func _on_onion_skin_toggled(enabled: bool) -> void:
	is_onion_skin = enabled
	_update_stage_at_frame(current_frame)

func _on_fps_changed(new_fps: int) -> void:
	project_doc.fps = new_fps

func _on_max_frames_changed(new_max: int) -> void:
	project_doc.max_frames = new_max
	project_doc.get_active_scene().timeline.max_frames = new_max
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
	status_bar.set_status("Added graphic layer: " + new_l.name)

func _on_add_audio_layer() -> void:
	var audio_l = AnimationLayer.new()
	audio_l.name = "Audio " + str(project_doc.layers.size() + 1)
	audio_l.layer_type = "audio"
	project_doc.layers.append(audio_l)
	active_layer_index = project_doc.layers.size() - 1
	timeline_dock.refresh_layers_ui(project_doc.layers, active_layer_index)
	_update_stage_at_frame(current_frame)
	status_bar.set_status("Added audio track layer: " + audio_l.name)

func _on_remove_layer() -> void:
	if project_doc.layers.size() <= 1:
		status_bar.set_status("Cannot delete the only layer.")
		return
	project_doc.layers.remove_at(active_layer_index)
	active_layer_index = clampi(active_layer_index, 0, project_doc.layers.size() - 1)
	timeline_dock.refresh_layers_ui(project_doc.layers, active_layer_index)
	_update_stage_at_frame(current_frame)
	status_bar.set_status("Layer removed.")

func _on_toggle_layer_visibility(layer_idx: int) -> void:
	if layer_idx >= 0 and layer_idx < project_doc.layers.size():
		var l = project_doc.layers[layer_idx]
		l.is_visible = !l.is_visible
		timeline_dock.refresh_layers_ui(project_doc.layers, active_layer_index)
		_update_stage_at_frame(current_frame)
		status_bar.set_status("%s visibility: %s" % [l.name, "Visible" if l.is_visible else "Hidden"])

func _on_toggle_layer_lock(layer_idx: int) -> void:
	if layer_idx >= 0 and layer_idx < project_doc.layers.size():
		var l = project_doc.layers[layer_idx]
		l.is_locked = !l.is_locked
		timeline_dock.refresh_layers_ui(project_doc.layers, active_layer_index)
		status_bar.set_status("%s: %s" % [l.name, "Locked" if l.is_locked else "Unlocked"])

func _on_timeline_keyframe_dragged(layer_idx: int, from_f: int, to_f: int) -> void:
	if layer_idx >= 0 and layer_idx < project_doc.layers.size():
		var layer = project_doc.layers[layer_idx]
		layer.drag_keyframe(from_f, to_f)
		_update_stage_at_frame(current_frame)
		status_bar.set_status("Dragged keyframe from frame %d to %d" % [from_f + 1, to_f + 1])

func _on_timeline_keyframe_action(action: String, layer_idx: int, frame_idx: int) -> void:
	if layer_idx < 0 or layer_idx >= project_doc.layers.size():
		return
	var layer = project_doc.layers[layer_idx]
	match action:
		"create_classic_tween":
			var kf = layer.get_keyframe_at(frame_idx)
			if kf == null:
				kf = layer.insert_blank_keyframe(frame_idx)
			kf.tween_type = "classic"
			status_bar.set_status("Created Classic Tween at frame %d" % [frame_idx + 1])
		"create_shape_tween":
			var kf = layer.get_keyframe_at(frame_idx)
			if kf == null:
				kf = layer.insert_blank_keyframe(frame_idx)
			kf.tween_type = "shape"
			status_bar.set_status("Created Shape Tween at frame %d" % [frame_idx + 1])
		"insert_frame":
			layer.insert_frame_span(frame_idx)
			project_doc.max_frames += 1
		"remove_frame":
			layer.remove_frame_span(frame_idx)
			if project_doc.max_frames > 1:
				project_doc.max_frames -= 1
		"insert_keyframe":
			_insert_keyframe_at_current()
		"clear_keyframe":
			layer.clear_keyframe(frame_idx)
		"insert_blank_keyframe":
			layer.insert_blank_keyframe(frame_idx)
		"convert_to_keyframes":
			layer.convert_to_keyframes(frame_idx, frame_idx + 5)
		"reverse_frames":
			layer.reverse_frames(frame_idx, frame_idx + 10)
		"clear_frames":
			layer.clear_frames(frame_idx, frame_idx + 5)
	_update_stage_at_frame(current_frame)

# Stage Selection & Drawing
func _on_stage_item_selected(id: String) -> void:
	selected_item_id = id
	stage_panel.stage_canvas.selected_item_id = id
	_update_inspector_display()
	if id != "" and project_doc.items.has(id):
		status_bar.set_status("Selected: " + project_doc.items[id].name)
	else:
		status_bar.set_status("Deselected.")

func _on_stage_item_multi_selected(ids: Array[String]) -> void:
	if ids.size() > 1:
		status_bar.set_status("Multi-selected %d items" % ids.size())
	elif ids.size() == 1:
		_on_stage_item_selected(ids[0])
	else:
		_on_stage_item_selected("")

func _on_stage_item_transformed(id: String, new_t: ItemTransform) -> void:
	if active_layer_index < 0 or active_layer_index >= project_doc.layers.size(): return
	var layer = project_doc.layers[active_layer_index]
	if layer.is_locked: return
	
	var old_t = layer.get_interpolated_transform(id, current_frame)
	var cmd = DocCommands.TransformItemCommand.new(layer, current_frame, id, old_t, new_t)
	command_stack.execute_command(cmd)
	_update_stage_at_frame(current_frame)

func _on_stage_drawing_finished(new_item: StageItem, center: Vector2) -> void:
	if active_layer_index < 0 or active_layer_index >= project_doc.layers.size(): return
	var layer = project_doc.layers[active_layer_index]
	if layer.is_locked:
		status_bar.set_status("Cannot draw: Active layer is locked.")
		return
		
	var t = ItemTransform.new()
	t.position = center
	t.rotation = 0.0
	t.scale = Vector2.ONE
	
	var cmd = DocCommands.AddItemCommand.new(project_doc, layer, current_frame, new_item, t)
	command_stack.execute_command(cmd)
	
	selected_item_id = new_item.id
	stage_panel.stage_canvas.selected_item_id = new_item.id
	tool_bar.set_active_tool("Select")
	_on_tool_selected("Select")
	_update_stage_at_frame(current_frame)
	status_bar.set_status("Created: " + new_item.name)

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
	if selected_item_id != "":
		_delete_item_from_project(selected_item_id)

func _delete_item_from_project(id: String) -> void:
	if id == "" or not project_doc.items.has(id): return
	var item_name = project_doc.items[id].name
	var cmd = DocCommands.DeleteItemCommand.new(project_doc, id)
	command_stack.execute_command(cmd)
	if selected_item_id == id:
		selected_item_id = ""
		stage_panel.stage_canvas.selected_item_id = ""
	_update_stage_at_frame(current_frame)
	status_bar.set_status("Item deleted: " + item_name)

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

# Panel Toggling & Tablet Mode Switcher
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

func toggle_tablet_mode() -> void:
	is_tablet_mode = !is_tablet_mode
	if is_tablet_mode:
		tool_bar.custom_minimum_size.x = 96
		timeline_dock.custom_minimum_size.y = 190
		status_bar.set_status("📱 Android Tablet Touch Mode Activated")
	else:
		tool_bar.custom_minimum_size.x = 80
		timeline_dock.custom_minimum_size.y = 160
		status_bar.set_status("💻 Desktop Native Mode Activated")

# Convert to Symbol Dialog (F8)
func _open_convert_symbol_dialog() -> void:
	if selected_item_id == "" or not project_doc.items.has(selected_item_id):
		status_bar.set_status("Please select an item on the stage to convert to Symbol (F8).")
		return
	var item = project_doc.items[selected_item_id]
	sym_name_edit.text = item.name + " Symbol"
	symbol_dialog.popup_centered()

func _on_convert_symbol_confirmed() -> void:
	if selected_item_id == "" or not project_doc.items.has(selected_item_id): return
	var sym_name = sym_name_edit.text.strip_edges()
	if sym_name == "": sym_name = "Symbol " + str(project_doc.library.size() + 1)
	
	var type_idx = sym_type_option.selected
	var types = ["graphic", "movie_clip", "button"]
	var selected_type = types[clampi(type_idx, 0, 2)]
	
	var sym = project_doc.convert_to_symbol(selected_item_id, sym_name, selected_type, 4)
	inspector_dock.update_library_list(project_doc.items, selected_item_id)
	_update_stage_at_frame(current_frame)
	status_bar.set_status("Converted to Symbol '%s' (%s) [F8]" % [sym_name, selected_type.capitalize()])

func _on_edit_symbol_in_place(symbol_id: String) -> void:
	if not project_doc.library.has(symbol_id):
		return
	var sym: SymbolItem = project_doc.library[symbol_id]
	editing_symbol_id = symbol_id
	timeline_dock.refresh_layers_ui(sym.timeline.layers, 0)
	timeline_dock.update_timeline_grid(sym.timeline.layers, 0, 0, sym.timeline.max_frames)
	status_bar.set_status("Editing Symbol: Scene 1 > %s (Double-click stage to return)" % sym.name)

func _exit_symbol_editing() -> void:
	editing_symbol_id = ""
	timeline_dock.refresh_layers_ui(project_doc.layers, active_layer_index)
	timeline_dock.update_timeline_grid(project_doc.layers, active_layer_index, current_frame, project_doc.max_frames)
	_update_stage_at_frame(current_frame)
	status_bar.set_status("Returned to Scene 1")

# Test Movie Window (Ctrl+Enter)
func _open_test_movie() -> void:
	test_movie_dialog.title = "Test Movie: %s (%dx%d @ %dfps)" % [project_doc.name, int(project_doc.stage_size.x), int(project_doc.stage_size.y), project_doc.fps]
	test_movie_dialog.popup_centered(Vector2i(int(project_doc.stage_size.x) + 40, int(project_doc.stage_size.y) + 70))
	is_playing = true
	timeline_dock.set_playing_state(true)
	status_bar.set_status("Test Movie launched (Ctrl+Enter)")

# Menu & File Actions
func _on_menu_action(action: String) -> void:
	match action:
		"new":
			_on_new_project()
		"open":
			_on_open_project_clicked()
		"save":
			_on_save_project_clicked()
		"import_fla":
			_on_import_fla_clicked()
		"export_fla":
			_on_export_fla_clicked()
		"export_json":
			_on_export_json_clicked()
		"export_png":
			_on_export_png_seq_clicked()
		"convert_symbol":
			_open_convert_symbol_dialog()
		"test_movie":
			_open_test_movie()
		"reset_view":
			stage_panel.reset_camera_view()
			status_bar.set_status("Camera view reset to 100%.")
		"toggle_tablet":
			toggle_tablet_mode()

func _on_new_project() -> void:
	project_doc = ProjectDocument.create_default()
	command_stack = CommandStack.new()
	editing_symbol_id = ""
	active_layer_index = 0
	current_frame = 0
	selected_item_id = ""
	_sync_project_to_ui()
	_update_stage_at_frame(0)
	status_bar.set_status("New project created.")

func _on_open_project_clicked() -> void:
	current_dialog_action = "open"
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.filters = PackedStringArray(["*.rean ; REanimate Project File", "*.fla ; Adobe Flash / Animate Document", "*.json ; JSON File"])
	file_dialog.popup_centered(Vector2i(720, 460))

func _on_save_project_clicked() -> void:
	current_dialog_action = "save"
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.filters = PackedStringArray(["*.rean ; REanimate Project File", "*.fla ; Adobe Flash Document"])
	file_dialog.popup_centered(Vector2i(720, 460))

func _on_import_fla_clicked() -> void:
	current_dialog_action = "import_fla"
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.filters = PackedStringArray(["*.fla ; Adobe Flash / Animate Document"])
	file_dialog.popup_centered(Vector2i(720, 460))

func _on_export_fla_clicked() -> void:
	current_dialog_action = "export_fla"
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.filters = PackedStringArray(["*.fla ; Adobe Flash / Animate Document"])
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
	elif current_dialog_action == "open" or current_dialog_action == "import_fla":
		var loaded_doc: ProjectDocument = null
		if path.get_extension().to_lower() == "fla":
			loaded_doc = FLAManager.import_from_fla(path)
		else:
			loaded_doc = ProjectDocument.load_from_file(path)
			
		if loaded_doc != null:
			project_doc = loaded_doc
			command_stack = CommandStack.new()
			editing_symbol_id = ""
			selected_item_id = ""
			active_layer_index = 0
			current_frame = 0
			_sync_project_to_ui()
			_update_stage_at_frame(0)
			status_bar.set_status("Loaded project: " + path)
		else:
			status_bar.set_status("Failed to load project file: " + path)
	elif current_dialog_action == "export_fla":
		var err = FLAManager.export_to_fla(project_doc, path)
		if err == OK:
			status_bar.set_status("Exported Adobe Flash (.fla) document: " + path)
		else:
			status_bar.set_status("Failed to export .FLA file. Error: " + str(err))
	elif current_dialog_action == "export_json":
		var err = ExportManager.export_to_texture_atlas_json(project_doc, path)
		if err == OK:
			status_bar.set_status("Exported Atlas JSON: " + path)
		else:
			status_bar.set_status("Export failed. Error: " + str(err))

func _on_dir_dialog_selected(path: String) -> void:
	if current_dialog_action == "export_png":
		var saved_frame = current_frame
		var was_playing = is_playing
		is_playing = false
		var count = await ExportManager.export_png_sequence(stage_panel.stage_viewport, project_doc, path, func(f): _update_stage_at_frame(f))
		is_playing = was_playing
		_go_to_frame(saved_frame)
		status_bar.set_status("Exported %d PNG frames to: %s" % [count, path])

# Global Flash Keyboard Shortcuts
func _unhandled_key_input(event: InputEvent) -> void:
	if stage_panel.handle_key_input(event):
		return
		
	if event.is_pressed() and not event.is_echo():
		# Ctrl + Shortcuts
		if event.ctrl_pressed:
			match event.keycode:
				KEY_ENTER:
					_open_test_movie()
					return
				KEY_0:
					stage_panel.reset_camera_view()
					status_bar.set_status("Camera view reset to 100%.")
					return
				KEY_S:
					_on_save_project_clicked()
					return
				KEY_O:
					_on_open_project_clicked()
					return
				KEY_N:
					_on_new_project()
					return
				KEY_Z:
					if event.shift_pressed:
						_redo_action()
					else:
						_undo_action()
					return
				KEY_Y:
					_redo_action()
					return
				KEY_C:
					_copy_selection()
					return
				KEY_V:
					_paste_selection()
					return
				KEY_X:
					_cut_selection()
					return
				KEY_D:
					_duplicate_selected_item()
					return
				KEY_G:
					if event.shift_pressed:
						_ungroup_selection()
					else:
						_group_selection()
					return
				KEY_B:
					_break_apart_selection()
					return
				KEY_BRACKETRIGHT:
					_bring_to_front()
					return
				KEY_BRACKETLEFT:
					_send_to_back()
					return
			return
		
		# Function Keys (Flash Timeline)
		match event.keycode:
			KEY_ENTER:
				_on_play_toggled(!is_playing)
				timeline_dock.set_playing_state(is_playing)
			KEY_F5:
				if event.shift_pressed:
					_remove_frame_at_current()
				else:
					_insert_frame_at_current()
			KEY_F6:
				if event.shift_pressed:
					_clear_keyframe_at_current()
				else:
					_insert_keyframe_at_current()
			KEY_F7:
				_insert_blank_keyframe_at_current()
			KEY_F8:
				_open_convert_symbol_dialog()
				
			# Tool selection shortcuts
			KEY_V:
				tool_bar.set_active_tool("Select")
				_on_tool_selected("Select")
			KEY_A:
				tool_bar.set_active_tool("Subselect")
				_on_tool_selected("Subselect")
			KEY_Q:
				tool_bar.set_active_tool("Transform")
				_on_tool_selected("Transform")
			KEY_L:
				tool_bar.set_active_tool("Lasso")
				_on_tool_selected("Lasso")
			KEY_P:
				tool_bar.set_active_tool("Pen")
				_on_tool_selected("Pen")
			KEY_T:
				tool_bar.set_active_tool("Text")
				_on_tool_selected("Text")
			KEY_N:
				tool_bar.set_active_tool("Line")
				_on_tool_selected("Line")
			KEY_R:
				tool_bar.set_active_tool("Rect")
				_on_tool_selected("Rect")
			KEY_O:
				tool_bar.set_active_tool("Circle")
				_on_tool_selected("Circle")
			KEY_Y:
				tool_bar.set_active_tool("Pencil")
				_on_tool_selected("Pencil")
			KEY_B:
				tool_bar.set_active_tool("Brush")
				_on_tool_selected("Brush")
			KEY_S:
				tool_bar.set_active_tool("InkBottle")
				_on_tool_selected("InkBottle")
			KEY_K:
				tool_bar.set_active_tool("PaintBucket")
				_on_tool_selected("PaintBucket")
			KEY_I:
				tool_bar.set_active_tool("Eyedropper")
				_on_tool_selected("Eyedropper")
			KEY_E:
				tool_bar.set_active_tool("Eraser")
				_on_tool_selected("Eraser")
			KEY_H:
				tool_bar.set_active_tool("Hand")
				_on_tool_selected("Hand")
			KEY_Z:
				tool_bar.set_active_tool("Zoom")
				_on_tool_selected("Zoom")
			KEY_X:
				tool_bar.swap_colors()
			KEY_D:
				tool_bar.reset_default_colors()
			KEY_J:
				tool_bar.btn_object_drawing.button_pressed = !tool_bar.btn_object_drawing.button_pressed
				
			KEY_DELETE, KEY_BACKSPACE:
				_delete_selected_item()

func _undo_action() -> void:
	if command_stack.undo():
		_update_stage_at_frame(current_frame)
		status_bar.set_status("Undo (Ctrl+Z)")
	else:
		status_bar.set_status("Nothing to undo.")

func _redo_action() -> void:
	if command_stack.redo():
		_update_stage_at_frame(current_frame)
		status_bar.set_status("Redo (Ctrl+Y)")
	else:
		status_bar.set_status("Nothing to redo.")

func _unhandled_input(event: InputEvent) -> void:
	if touch_handler.handle_input_event(event):
		return
	stage_panel.handle_mouse_input(event)

func _copy_selection() -> void:
	if selected_item_id == "" or not project_doc.items.has(selected_item_id):
		return
	clipboard_item = project_doc.items[selected_item_id]
	var t = stage_panel.stage_canvas.current_transforms.get(selected_item_id, null)
	clipboard_transform = t.duplicate_transform() if t != null else ItemTransform.new()
	status_bar.set_status("Copied item: " + clipboard_item.name)

func _cut_selection() -> void:
	_copy_selection()
	_delete_selected_item()
	status_bar.set_status("Cut item (Ctrl+X)")

func _paste_selection() -> void:
	if clipboard_item == null:
		return
	var new_item = StageItem.from_dict(clipboard_item.to_dict())
	new_item.id = "item_" + str(Time.get_ticks_usec())
	new_item.name = clipboard_item.name + " Copy"
	project_doc.items[new_item.id] = new_item
	
	var new_t = clipboard_transform.duplicate_transform() if clipboard_transform != null else ItemTransform.new()
	new_t.position += Vector2(20, 20)
	
	var cur_layer = project_doc.layers[active_layer_index]
	var kf = cur_layer.get_keyframe_at(current_frame)
	if kf == null:
		kf = cur_layer.insert_blank_keyframe(current_frame)
	kf.transforms[new_item.id] = new_t
	
	selected_item_id = new_item.id
	stage_panel.stage_canvas.selected_item_id = new_item.id
	_update_stage_at_frame(current_frame)
	status_bar.set_status("Pasted item: " + new_item.name)

func _group_selection() -> void:
	if stage_panel.stage_canvas.selected_item_ids.size() < 2:
		status_bar.set_status("Select 2 or more items to Group (Ctrl+G)")
		return
	status_bar.set_status("Grouped items (Ctrl+G)")

func _ungroup_selection() -> void:
	status_bar.set_status("Ungrouped items (Ctrl+Shift+G)")

func _break_apart_selection() -> void:
	if selected_item_id == "" or not project_doc.items.has(selected_item_id):
		return
	var item = project_doc.items[selected_item_id]
	if item.shape_type == "symbol" and item.library_ref != "":
		item.shape_type = "path"
		item.library_ref = ""
		_update_stage_at_frame(current_frame)
		status_bar.set_status("Broke apart symbol into raw vector shapes (Ctrl+B)")
	else:
		status_bar.set_status("Broken apart (Ctrl+B)")

func _bring_to_front() -> void:
	if selected_item_id != "" and project_doc.items.has(selected_item_id):
		var itm = project_doc.items[selected_item_id]
		project_doc.items.erase(selected_item_id)
		project_doc.items[selected_item_id] = itm
		_update_stage_at_frame(current_frame)
		status_bar.set_status("Brought item to front (Ctrl+])")

func _send_to_back() -> void:
	if selected_item_id != "" and project_doc.items.has(selected_item_id):
		var new_items: Dictionary = { selected_item_id: project_doc.items[selected_item_id] }
		for id in project_doc.items:
			if id != selected_item_id:
				new_items[id] = project_doc.items[id]
		project_doc.items = new_items
		_update_stage_at_frame(current_frame)
		status_bar.set_status("Sent item to back (Ctrl+[)")
