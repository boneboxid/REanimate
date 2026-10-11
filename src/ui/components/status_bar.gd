class_name StatusBar
extends PanelContainer

@onready var status_label: Label = %StatusLabel
@onready var cursor_pos_label: Label = %CursorPosLabel
@onready var zoom_info_label: Label = %ZoomInfoLabel

func _ready() -> void:
	set_status("Ready")

func set_status(msg: String) -> void:
	if status_label:
		status_label.text = " " + msg

func set_cursor_position(pos: Vector2) -> void:
	if cursor_pos_label:
		cursor_pos_label.text = "X: %d, Y: %d" % [int(pos.x), int(pos.y)]

func set_zoom_text(zoom_pct: int) -> void:
	if zoom_info_label:
		zoom_info_label.text = "%d%%" % zoom_pct
