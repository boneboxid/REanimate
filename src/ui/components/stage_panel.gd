class_name StagePanel
extends PanelContainer

signal zoom_changed(zoom_factor: float)
signal item_selected(id: String)
signal item_transformed(id: String, new_t: ItemTransform)
signal drawing_finished(new_item: StageItem, center: Vector2)
signal mouse_stage_pos_changed(pos: Vector2)

@onready var stage_container: SubViewportContainer = %StageContainer
@onready var stage_viewport: SubViewport = %StageViewport
@onready var stage_camera: Camera2D = %StageCamera
@onready var zoom_label: Label = %ZoomLabel
@onready var btn_zoom_in: Button = %ZoomInBtn
@onready var btn_zoom_out: Button = %ZoomOutBtn
@onready var btn_zoom_reset: Button = %ZoomResetBtn

var stage_canvas: StageCanvas
var is_panning: bool = false
var pan_start_pos: Vector2 = Vector2.ZERO
var is_space_pressed: bool = false

func _ready() -> void:
	stage_canvas = StageCanvas.new()
	stage_viewport.add_child(stage_canvas)
	
	stage_canvas.item_selected.connect(func(id): item_selected.emit(id))
	stage_canvas.item_transformed.connect(func(id, t): item_transformed.emit(id, t))
	stage_canvas.drawing_finished.connect(func(item, c): drawing_finished.emit(item, c))
	
	btn_zoom_in.pressed.connect(zoom_in)
	btn_zoom_out.pressed.connect(zoom_out)
	btn_zoom_reset.pressed.connect(reset_camera_view)
	
	reset_camera_view()

func reset_camera_view() -> void:
	stage_camera.position = Vector2.ZERO
	stage_camera.zoom = Vector2(0.9, 0.9)
	_update_zoom_label()

func zoom_in() -> void:
	set_camera_zoom((stage_camera.zoom * 1.15).clamp(Vector2(0.2, 0.2), Vector2(10.0, 10.0)))

func zoom_out() -> void:
	set_camera_zoom((stage_camera.zoom * 0.85).clamp(Vector2(0.2, 0.2), Vector2(10.0, 10.0)))

func set_camera_zoom(new_zoom: Vector2) -> void:
	stage_camera.zoom = new_zoom
	_update_zoom_label()

func _update_zoom_label() -> void:
	var pct = int(round(stage_camera.zoom.x * 100.0))
	if zoom_label:
		zoom_label.text = "%d%%" % pct
	zoom_changed.emit(stage_camera.zoom.x)

func handle_key_input(event: InputEventKey) -> bool:
	if event.keycode == KEY_SPACE:
		if event.pressed and not event.is_echo():
			is_space_pressed = true
			return true
		elif not event.pressed:
			is_space_pressed = false
			is_panning = false
			return true
	elif event.is_pressed() and not event.is_echo() and event.keycode == KEY_0 and event.ctrl_pressed:
		reset_camera_view()
		return true
	return false

func handle_mouse_input(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			zoom_in()
			return true
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			zoom_out()
			return true
		elif event.button_index == MOUSE_BUTTON_MIDDLE or (event.button_index == MOUSE_BUTTON_LEFT and is_space_pressed):
			is_panning = event.pressed
			pan_start_pos = event.position
			return true
	elif event is InputEventMouseMotion:
		if is_panning:
			var delta_pos = (event.position - pan_start_pos) / stage_camera.zoom
			stage_camera.position -= delta_pos
			pan_start_pos = event.position
			return true
		else:
			# Track canvas relative position
			var viewport_center = stage_viewport.size * 0.5
			var mouse_canvas_pos = (event.position - viewport_center) / stage_camera.zoom + stage_camera.position
			mouse_stage_pos_changed.emit(mouse_canvas_pos)
	return false
