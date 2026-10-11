class_name TopMenuBar
extends PanelContainer

signal action_requested(action_name: String)
signal toggle_panel_requested(panel_name: String)

@onready var current_tool_label: Label = %CurrentToolLabel
@onready var btn_new: Button = %NewFileBtn
@onready var btn_open: Button = %OpenFileBtn
@onready var btn_save: Button = %SaveFileBtn
@onready var btn_export_json: Button = %ExportJsonBtn
@onready var btn_export_png: Button = %ExportPngSeqBtn
@onready var btn_reset_view: Button = %ResetViewBtn
@onready var btn_toggle_tools: Button = %ToggleToolsBtn
@onready var btn_toggle_timeline: Button = %ToggleTimelineBtn
@onready var btn_toggle_inspector: Button = %ToggleInspectorBtn

func _ready() -> void:
	btn_new.pressed.connect(func(): action_requested.emit("new"))
	btn_open.pressed.connect(func(): action_requested.emit("open"))
	btn_save.pressed.connect(func(): action_requested.emit("save"))
	btn_export_json.pressed.connect(func(): action_requested.emit("export_json"))
	btn_export_png.pressed.connect(func(): action_requested.emit("export_png"))
	btn_reset_view.pressed.connect(func(): action_requested.emit("reset_view"))
	
	btn_toggle_tools.pressed.connect(func(): toggle_panel_requested.emit("tools"))
	btn_toggle_timeline.pressed.connect(func(): toggle_panel_requested.emit("timeline"))
	btn_toggle_inspector.pressed.connect(func(): toggle_panel_requested.emit("inspector"))

func set_active_tool_name(tool_name: String) -> void:
	if current_tool_label:
		current_tool_label.text = "Tool: " + tool_name
