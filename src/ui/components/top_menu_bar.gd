class_name TopMenuBar
extends PanelContainer

signal action_requested(action_name: String)
signal toggle_panel_requested(panel_name: String)

@onready var current_tool_label: Label = %CurrentToolLabel
@onready var btn_new: Button = %NewFileBtn
@onready var btn_open: Button = %OpenFileBtn
@onready var btn_save: Button = %SaveFileBtn
@onready var project_menu_btn: MenuButton = %ProjectMenuBtn
@onready var btn_import_fla: Button = %ImportFLABtn
@onready var btn_export_fla: Button = %ExportFLABtn
@onready var btn_export_json: Button = %ExportJsonBtn
@onready var btn_export_png: Button = %ExportPngSeqBtn
@onready var btn_convert_symbol: Button = %ConvertSymbolBtn
@onready var btn_test_movie: Button = %TestMovieBtn
@onready var btn_reset_view: Button = %ResetViewBtn
@onready var btn_toggle_tablet: Button = %ToggleTabletBtn
@onready var btn_toggle_tools: Button = %ToggleToolsBtn
@onready var btn_toggle_timeline: Button = %ToggleTimelineBtn
@onready var btn_toggle_inspector: Button = %ToggleInspectorBtn
@onready var btn_toggle_library: Button = %ToggleLibraryBtn

func _ready() -> void:
	_setup_project_menu()
	btn_new.pressed.connect(func(): action_requested.emit("new"))
	btn_open.pressed.connect(func(): action_requested.emit("open"))
	btn_save.pressed.connect(func(): action_requested.emit("save"))
	btn_import_fla.pressed.connect(func(): action_requested.emit("import_fla"))
	btn_export_fla.pressed.connect(func(): action_requested.emit("export_fla"))
	btn_export_json.pressed.connect(func(): action_requested.emit("export_json"))
	btn_export_png.pressed.connect(func(): action_requested.emit("export_png"))
	btn_convert_symbol.pressed.connect(func(): action_requested.emit("convert_symbol"))
	btn_test_movie.pressed.connect(func(): action_requested.emit("test_movie"))
	btn_reset_view.pressed.connect(func(): action_requested.emit("reset_view"))
	btn_toggle_tablet.pressed.connect(func(): action_requested.emit("toggle_tablet"))
	
	btn_toggle_tools.pressed.connect(func(): toggle_panel_requested.emit("tools"))
	btn_toggle_timeline.pressed.connect(func(): toggle_panel_requested.emit("timeline"))
	btn_toggle_inspector.pressed.connect(func(): toggle_panel_requested.emit("inspector"))
	if btn_toggle_library:
		btn_toggle_library.pressed.connect(func(): toggle_panel_requested.emit("library"))

func _setup_project_menu() -> void:
	if not project_menu_btn:
		return
	var popup = project_menu_btn.get_popup()
	popup.clear()
	popup.add_item("🏠 Project Manager / Welcome Screen", 0)
	popup.add_separator()
	popup.add_item("⚙ Project Settings... (Ctrl+J)", 1)
	popup.add_item("ℹ Project Summary", 2)
	popup.add_separator()
	popup.add_item("🌐 Export HTML5 Player (.html)", 3)
	popup.add_item("💾 Export Adobe Flash (.fla)", 4)
	popup.add_item("📦 Export Texture Atlas (.json)", 5)
	popup.add_item("🎞 Export PNG Frame Sequence", 6)
	popup.add_separator()
	popup.add_item("📐 Preset: 1920x1080 (FHD 16:9)", 10)
	popup.add_item("📐 Preset: 1280x720 (HD 16:9)", 11)
	popup.add_item("📐 Preset: 1080x1920 (Mobile 9:16)", 12)
	popup.add_item("📐 Preset: 1080x1080 (Square 1:1)", 13)
	popup.add_item("📐 Preset: 800x450 (Retro 16:9)", 14)
	popup.add_separator()
	popup.add_item("🎬 Framerate: 12 FPS (Animation)", 20)
	popup.add_item("🎬 Framerate: 24 FPS (Cinema)", 21)
	popup.add_item("🎬 Framerate: 30 FPS (Standard)", 22)
	popup.add_item("🎬 Framerate: 60 FPS (Smooth)", 23)
	
	popup.id_pressed.connect(_on_project_menu_item_selected)

func _on_project_menu_item_selected(id: int) -> void:
	match id:
		0: action_requested.emit("project_launcher")
		1: action_requested.emit("project_settings")
		2: action_requested.emit("project_info")
		3: action_requested.emit("export_html")
		4: action_requested.emit("export_fla")
		5: action_requested.emit("export_json")
		6: action_requested.emit("export_png")
		10: action_requested.emit("preset_res_1080p")
		11: action_requested.emit("preset_res_720p")
		12: action_requested.emit("preset_res_mobile")
		13: action_requested.emit("preset_res_square")
		14: action_requested.emit("preset_res_retro")
		20: action_requested.emit("preset_fps_12")
		21: action_requested.emit("preset_fps_24")
		22: action_requested.emit("preset_fps_30")
		23: action_requested.emit("preset_fps_60")

func set_active_tool_name(tool_name: String) -> void:
	if current_tool_label:
		current_tool_label.text = "Tool: " + tool_name
