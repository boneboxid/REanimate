class_name TimelineDock
extends PanelContainer

signal play_toggled(is_playing: bool)
signal loop_toggled(is_looping: bool)
signal stop_requested()
signal step_frame_requested(delta_frame: int)
signal keyframe_insert_requested()
signal keyframe_remove_requested()
signal frame_changed(frame: int)
signal onion_skin_toggled(enabled: bool)
signal fps_changed(new_fps: int)
signal max_frames_changed(new_max: int)
signal layer_selected(index: int)
signal layer_add_requested()
signal layer_remove_requested()

@onready var play_btn: Button = %PlayButton
@onready var stop_btn: Button = %StopBtn
@onready var prev_frame_btn: Button = %PrevFrameBtn
@onready var next_frame_btn: Button = %NextFrameBtn
@onready var loop_btn: Button = %LoopBtn
@onready var insert_keyframe_btn: Button = %InsertKeyframeBtn
@onready var remove_keyframe_btn: Button = %RemoveKeyframeBtn
@onready var frame_label: Label = %FrameLabel
@onready var onion_skin_check: CheckBox = %OnionSkinCheck
@onready var fps_spin: SpinBox = %FpsSpin
@onready var max_frames_spin: SpinBox = %MaxFramesSpin
@onready var collapse_btn: Button = %CollapseBtn

@onready var timeline_slider: HSlider = %TimelineSlider
@onready var add_layer_btn: Button = %AddLayerBtn
@onready var remove_layer_btn: Button = %RemoveLayerBtn
@onready var layer_list: ItemList = %LayerList
@onready var frames_scroll: ScrollContainer = %FramesScrollContainer
@onready var content_box: HBoxContainer = %TimelineContentHBox

@onready var zoom_in_btn: Button = %TimelineZoomInBtn
@onready var zoom_out_btn: Button = %TimelineZoomOutBtn

var timeline_grid: TimelineGrid
var is_playing: bool = false
var is_looping: bool = true
var is_collapsed: bool = false
var current_cell_width: float = 16.0

func _ready() -> void:
	timeline_grid = TimelineGrid.new()
	frames_scroll.add_child(timeline_grid)
	timeline_grid.frame_clicked.connect(func(f): frame_changed.emit(f))
	
	play_btn.pressed.connect(_on_play_pressed)
	stop_btn.pressed.connect(func(): stop_requested.emit())
	prev_frame_btn.pressed.connect(func(): step_frame_requested.emit(-1))
	next_frame_btn.pressed.connect(func(): step_frame_requested.emit(1))
	loop_btn.pressed.connect(_on_loop_pressed)
	
	insert_keyframe_btn.pressed.connect(func(): keyframe_insert_requested.emit())
	remove_keyframe_btn.pressed.connect(func(): keyframe_remove_requested.emit())
	onion_skin_check.toggled.connect(func(v): onion_skin_toggled.emit(v))
	
	fps_spin.value_changed.connect(func(v): fps_changed.emit(int(v)))
	max_frames_spin.value_changed.connect(func(v): max_frames_changed.emit(int(v)))
	
	timeline_slider.value_changed.connect(func(v): frame_changed.emit(int(v)))
	add_layer_btn.pressed.connect(func(): layer_add_requested.emit())
	remove_layer_btn.pressed.connect(func(): layer_remove_requested.emit())
	layer_list.item_selected.connect(func(idx): layer_selected.emit(idx))
	
	collapse_btn.pressed.connect(_toggle_collapsed)
	zoom_in_btn.pressed.connect(_zoom_in_timeline)
	zoom_out_btn.pressed.connect(_zoom_out_timeline)

func _on_play_pressed() -> void:
	is_playing = !is_playing
	play_btn.text = "⏸" if is_playing else "▶"
	play_toggled.emit(is_playing)

func set_playing_state(playing: bool) -> void:
	is_playing = playing
	play_btn.text = "⏸" if is_playing else "▶"

func _on_loop_pressed() -> void:
	is_looping = !is_looping
	loop_btn.modulate = Color(1, 1, 1, 1) if is_looping else Color(0.6, 0.6, 0.6, 1)
	loop_toggled.emit(is_looping)

func set_looping_state(looping: bool) -> void:
	is_looping = looping
	loop_btn.modulate = Color(1, 1, 1, 1) if is_looping else Color(0.6, 0.6, 0.6, 1)

func _toggle_collapsed() -> void:
	is_collapsed = !is_collapsed
	content_box.visible = !is_collapsed
	collapse_btn.text = "▲" if is_collapsed else "▼"
	custom_minimum_size.y = 65 if is_collapsed else 160

func _zoom_in_timeline() -> void:
	current_cell_width = clampf(current_cell_width + 4.0, 8.0, 48.0)
	timeline_grid.set_cell_width(current_cell_width)

func _zoom_out_timeline() -> void:
	current_cell_width = clampf(current_cell_width - 4.0, 8.0, 48.0)
	timeline_grid.set_cell_width(current_cell_width)

func update_frame_info(current_frame: int, max_frames: int, fps: int) -> void:
	timeline_slider.max_value = max_frames - 1
	timeline_slider.set_value_no_signal(current_frame)
	frame_label.text = "%d / %d (%.2fs)" % [current_frame, max_frames, float(current_frame) / float(fps)]
	fps_spin.set_value_no_signal(fps)
	max_frames_spin.set_value_no_signal(max_frames)

func update_timeline_grid(layers: Array[AnimationLayer], active_layer: int, current_frame: int, max_frames: int) -> void:
	if timeline_grid:
		timeline_grid.set_timeline_state(layers, active_layer, current_frame, max_frames)

func refresh_layers_ui(layers: Array[AnimationLayer], active_index: int) -> void:
	layer_list.clear()
	for i in range(layers.size()):
		var l = layers[i]
		var title = "%s (%s)" % [l.name, "Visible" if l.is_visible else "Hidden"]
		layer_list.add_item(title)
	if active_index >= 0 and active_index < layer_list.item_count:
		layer_list.select(active_index)
