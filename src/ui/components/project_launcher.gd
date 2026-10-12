class_name ProjectLauncher
extends Control

signal project_created(name: String, size: Vector2, fps: int, max_frames: int, bg_color: Color)
signal open_project_requested()
signal import_fla_requested()
signal open_recent_requested(file_path: String)
signal launcher_closed()

const RECENT_FILE_PATH = "user://recent_projects.json"

@onready var recent_list: ItemList = %RecentItemList
@onready var btn_clear_recent: Button = %ClearRecentBtn
@onready var custom_name_edit: LineEdit = %CustomNameEdit
@onready var custom_w_spin: SpinBox = %CustomWidthSpin
@onready var custom_h_spin: SpinBox = %CustomHeightSpin
@onready var custom_fps_spin: SpinBox = %CustomFpsSpin
@onready var custom_frames_spin: SpinBox = %CustomFramesSpin
@onready var custom_bg_color: ColorPickerButton = %CustomBgColorPicker
@onready var btn_create_custom: Button = %CreateCustomBtn

@onready var btn_preset_fhd: Button = %PresetFhdBtn
@onready var btn_preset_hd: Button = %PresetHdBtn
@onready var btn_preset_mobile: Button = %PresetMobileBtn
@onready var btn_preset_square: Button = %PresetSquareBtn
@onready var btn_preset_retro: Button = %PresetRetroBtn

@onready var btn_open_proj: Button = %OpenProjBtn
@onready var btn_import_fla: Button = %ImportFlaBtn
@onready var btn_close_launcher: Button = %CloseLauncherBtn

var recent_projects: Array[String] = []

func _ready() -> void:
	_load_recent_projects()
	_connect_signals()

func _connect_signals() -> void:
	if btn_close_launcher:
		btn_close_launcher.pressed.connect(func(): launcher_closed.emit())
	if btn_open_proj:
		btn_open_proj.pressed.connect(func(): open_project_requested.emit())
	if btn_import_fla:
		btn_import_fla.pressed.connect(func(): import_fla_requested.emit())
		
	# Preset buttons
	if btn_preset_fhd:
		btn_preset_fhd.pressed.connect(func():
			project_created.emit("Full_HD_Animation", Vector2(1920, 1080), 24, 60, Color(0.98, 0.98, 0.98, 1.0))
		)
	if btn_preset_hd:
		btn_preset_hd.pressed.connect(func():
			project_created.emit("HD_Animation", Vector2(1280, 720), 30, 60, Color(0.98, 0.98, 0.98, 1.0))
		)
	if btn_preset_mobile:
		btn_preset_mobile.pressed.connect(func():
			project_created.emit("Mobile_Shorts_Animation", Vector2(1080, 1920), 30, 60, Color(0.98, 0.98, 0.98, 1.0))
		)
	if btn_preset_square:
		btn_preset_square.pressed.connect(func():
			project_created.emit("Square_Animation", Vector2(1080, 1080), 30, 60, Color(0.98, 0.98, 0.98, 1.0))
		)
	if btn_preset_retro:
		btn_preset_retro.pressed.connect(func():
			project_created.emit("Retro_Flash_Animation", Vector2(800, 450), 24, 60, Color(0.98, 0.98, 0.98, 1.0))
		)
		
	if btn_create_custom:
		btn_create_custom.pressed.connect(_on_create_custom_pressed)
		
	if recent_list:
		recent_list.item_activated.connect(_on_recent_item_activated)
	if btn_clear_recent:
		btn_clear_recent.pressed.connect(_clear_recent_projects)

func _on_create_custom_pressed() -> void:
	var p_name = custom_name_edit.text.strip_edges()
	if p_name == "": p_name = "Untitled_Animation"
	var sz = Vector2(custom_w_spin.value, custom_h_spin.value)
	var fps = int(custom_fps_spin.value)
	var max_f = int(custom_frames_spin.value)
	var bg = custom_bg_color.color
	project_created.emit(p_name, sz, fps, max_f, bg)

func _on_recent_item_activated(idx: int) -> void:
	if idx >= 0 and idx < recent_projects.size():
		var path = recent_projects[idx]
		open_recent_requested.emit(path)

func add_recent_project(path: String) -> void:
	if path == "": return
	if recent_projects.has(path):
		recent_projects.erase(path)
	recent_projects.push_front(path)
	if recent_projects.size() > 10:
		recent_projects.resize(10)
	_save_recent_projects()
	_refresh_recent_list_ui()

func _load_recent_projects() -> void:
	recent_projects.clear()
	if FileAccess.file_exists(RECENT_FILE_PATH):
		var fa = FileAccess.open(RECENT_FILE_PATH, FileAccess.READ)
		if fa != null:
			var txt = fa.get_as_text()
			fa.close()
			var parsed = JSON.parse_string(txt)
			if parsed is Array:
				for p in parsed:
					if p is String and FileAccess.file_exists(p):
						recent_projects.append(p)
	_refresh_recent_list_ui()

func _save_recent_projects() -> void:
	var fa = FileAccess.open(RECENT_FILE_PATH, FileAccess.WRITE)
	if fa != null:
		fa.store_string(JSON.stringify(recent_projects, "\t"))
		fa.close()

func _clear_recent_projects() -> void:
	recent_projects.clear()
	_save_recent_projects()
	_refresh_recent_list_ui()

func _refresh_recent_list_ui() -> void:
	if not recent_list: return
	recent_list.clear()
	for p in recent_projects:
		var fname = p.get_file()
		recent_list.add_item("%s  (%s)" % [fname, p])
