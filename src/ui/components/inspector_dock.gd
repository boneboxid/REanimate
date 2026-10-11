class_name InspectorDock
extends PanelContainer

signal transform_changed(pos: Vector2, rot: float, scale: Vector2, opacity: float)
signal item_name_changed(new_name: String)
signal item_color_changed(new_color: Color)
signal item_stroke_changed(stroke_col: Color, stroke_width: float)
signal item_delete_requested()
signal item_duplicate_requested()
signal item_selected_from_library(item_id: String)
signal project_settings_changed(stage_size: Vector2, bg_color: Color)
signal keyframe_tween_changed(tween_type: String)

# Tabs
@onready var dock_tabs: TabContainer = %DockTabs

# Properties tab
@onready var prop_name_edit: LineEdit = %PropNameEdit
@onready var prop_pos_x: SpinBox = %PropPosX
@onready var prop_pos_y: SpinBox = %PropPosY
@onready var prop_rot: SpinBox = %PropRot
@onready var prop_scale_x: SpinBox = %PropScaleX
@onready var prop_scale_y: SpinBox = %PropScaleY
@onready var prop_opacity: HSlider = %PropOpacity
@onready var prop_opacity_label: Label = %PropOpacityLabel
@onready var prop_color_picker: ColorPickerButton = %PropColorPicker
@onready var prop_stroke_picker: ColorPickerButton = %PropStrokePicker
@onready var prop_stroke_width: SpinBox = %PropStrokeWidth
@onready var delete_item_btn: Button = %DeleteItemBtn
@onready var duplicate_item_btn: Button = %DuplicateItemBtn

# Project settings tab
@onready var proj_width_spin: SpinBox = %ProjWidthSpin
@onready var proj_height_spin: SpinBox = %ProjHeightSpin
@onready var proj_preset_opt: OptionButton = %ProjPresetOpt
@onready var proj_bg_color: ColorPickerButton = %ProjBgColorPicker
@onready var proj_apply_btn: Button = %ProjApplyBtn

# Library tab
@onready var library_items_list: ItemList = %LibraryItemsList
@onready var library_delete_btn: Button = %LibraryDeleteBtn

# Tween tab
@onready var tween_option: OptionButton = %TweenOption

var active_item_id: String = ""
var is_updating_ui: bool = false

func _ready() -> void:
	_setup_properties_tab()
	_setup_project_tab()
	_setup_library_tab()
	_setup_tween_tab()

func _setup_properties_tab() -> void:
	prop_name_edit.text_submitted.connect(func(n): item_name_changed.emit(n))
	prop_pos_x.value_changed.connect(func(_v): _emit_transform())
	prop_pos_y.value_changed.connect(func(_v): _emit_transform())
	prop_rot.value_changed.connect(func(_v): _emit_transform())
	prop_scale_x.value_changed.connect(func(_v): _emit_transform())
	prop_scale_y.value_changed.connect(func(_v): _emit_transform())
	prop_opacity.value_changed.connect(func(v): 
		prop_opacity_label.text = "%d%%" % int(v * 100)
		_emit_transform()
	)
	prop_color_picker.color_changed.connect(func(c): item_color_changed.emit(c))
	prop_stroke_picker.color_changed.connect(func(c): item_stroke_changed.emit(c, float(prop_stroke_width.value)))
	prop_stroke_width.value_changed.connect(func(w): item_stroke_changed.emit(prop_stroke_picker.color, float(w)))
	
	delete_item_btn.pressed.connect(func(): item_delete_requested.emit())
	duplicate_item_btn.pressed.connect(func(): item_duplicate_requested.emit())

func _setup_project_tab() -> void:
	proj_preset_opt.clear()
	proj_preset_opt.add_item("Custom", 0)
	proj_preset_opt.add_item("1280 x 720 (HD)", 1)
	proj_preset_opt.add_item("1920 x 1080 (FHD)", 2)
	proj_preset_opt.add_item("1080 x 1080 (Square)", 3)
	proj_preset_opt.add_item("800 x 450 (Retro)", 4)
	
	proj_preset_opt.item_selected.connect(_on_preset_selected)
	proj_apply_btn.pressed.connect(_on_apply_project_settings)

func _on_preset_selected(idx: int) -> void:
	match idx:
		1:
			proj_width_spin.value = 1280
			proj_height_spin.value = 720
		2:
			proj_width_spin.value = 1920
			proj_height_spin.value = 1080
		3:
			proj_width_spin.value = 1080
			proj_height_spin.value = 1080
		4:
			proj_width_spin.value = 800
			proj_height_spin.value = 450
	_on_apply_project_settings()

func _on_apply_project_settings() -> void:
	var sz = Vector2(proj_width_spin.value, proj_height_spin.value)
	var bg = proj_bg_color.color
	project_settings_changed.emit(sz, bg)

func _setup_library_tab() -> void:
	library_items_list.item_selected.connect(func(idx):
		var id = library_items_list.get_item_metadata(idx)
		if id: item_selected_from_library.emit(str(id))
	)
	library_delete_btn.pressed.connect(func(): item_delete_requested.emit())

func _setup_tween_tab() -> void:
	tween_option.clear()
	tween_option.add_item("Linear (Default)", 0)
	tween_option.add_item("Ease In", 1)
	tween_option.add_item("Ease Out", 2)
	tween_option.add_item("Ease In-Out", 3)
	tween_option.add_item("None (Hold Frame)", 4)
	tween_option.item_selected.connect(func(idx):
		var type = "linear"
		match idx:
			0: type = "linear"
			1: type = "ease_in"
			2: type = "ease_out"
			3: type = "ease_in_out"
			4: type = "none"
		keyframe_tween_changed.emit(type)
	)

func _emit_transform() -> void:
	if is_updating_ui: return
	var p = Vector2(prop_pos_x.value, prop_pos_y.value)
	var r = deg_to_rad(prop_rot.value)
	var s = Vector2(prop_scale_x.value, prop_scale_y.value)
	var o = prop_opacity.value
	transform_changed.emit(p, r, s, o)

func update_active_item(item: StageItem, t: ItemTransform) -> void:
	is_updating_ui = true
	if item == null:
		active_item_id = ""
		prop_name_edit.text = ""
		prop_name_edit.editable = false
		delete_item_btn.disabled = true
		duplicate_item_btn.disabled = true
		is_updating_ui = false
		return
		
	active_item_id = item.id
	prop_name_edit.editable = true
	prop_name_edit.text = item.name
	prop_color_picker.color = item.color
	prop_stroke_picker.color = item.stroke_color
	prop_stroke_width.value = item.stroke_width
	delete_item_btn.disabled = false
	duplicate_item_btn.disabled = false
	
	if t != null:
		prop_pos_x.set_value_no_signal(t.position.x)
		prop_pos_y.set_value_no_signal(t.position.y)
		prop_rot.set_value_no_signal(rad_to_deg(t.rotation))
		prop_scale_x.set_value_no_signal(t.scale.x)
		prop_scale_y.set_value_no_signal(t.scale.y)
		prop_opacity.set_value_no_signal(t.opacity)
		prop_opacity_label.text = "%d%%" % int(t.opacity * 100)
		
	is_updating_ui = false

func update_project_data(stage_size: Vector2, bg_color: Color) -> void:
	proj_width_spin.set_value_no_signal(stage_size.x)
	proj_height_spin.set_value_no_signal(stage_size.y)
	proj_bg_color.color = bg_color

func update_library_list(items: Dictionary, selected_id: String) -> void:
	library_items_list.clear()
	var select_idx = -1
	for id in items:
		var it: StageItem = items[id]
		var idx = library_items_list.add_item("%s (%s)" % [it.name, it.shape_type])
		library_items_list.set_item_metadata(idx, id)
		if id == selected_id:
			select_idx = idx
	if select_idx != -1:
		library_items_list.select(select_idx)

func update_tween_type(tween_type: String) -> void:
	match tween_type:
		"linear": tween_option.select(0)
		"ease_in": tween_option.select(1)
		"ease_out": tween_option.select(2)
		"ease_in_out": tween_option.select(3)
		"none": tween_option.select(4)
		_: tween_option.select(0)
