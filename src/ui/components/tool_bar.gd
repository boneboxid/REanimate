class_name ToolBar
extends PanelContainer

signal tool_selected(tool_name: String)
signal stroke_width_changed(width: float)
signal quick_color_changed(color: Color)

@onready var btn_select: Button = %ToolSelect
@onready var btn_transform: Button = %ToolTransform
@onready var btn_brush: Button = %ToolBrush
@onready var btn_rect: Button = %ToolRect
@onready var btn_circle: Button = %ToolCircle

@onready var stroke_width_spin: SpinBox = %StrokeWidthSpin
@onready var quick_color_picker: ColorPickerButton = %QuickColorPicker

var active_tool: String = "Select"
var tool_buttons: Dictionary = {}

func _ready() -> void:
	tool_buttons = {
		"Select": btn_select,
		"Transform": btn_transform,
		"Brush": btn_brush,
		"Rect": btn_rect,
		"Circle": btn_circle
	}
	
	btn_select.pressed.connect(func(): _select_tool("Select"))
	btn_transform.pressed.connect(func(): _select_tool("Transform"))
	btn_brush.pressed.connect(func(): _select_tool("Brush"))
	btn_rect.pressed.connect(func(): _select_tool("Rect"))
	btn_circle.pressed.connect(func(): _select_tool("Circle"))
	
	if stroke_width_spin:
		stroke_width_spin.value_changed.connect(func(v): stroke_width_changed.emit(float(v)))
	if quick_color_picker:
		quick_color_picker.color_changed.connect(func(c): quick_color_changed.emit(c))
		
	set_active_tool("Select")

func _select_tool(tool_name: String) -> void:
	set_active_tool(tool_name)
	tool_selected.emit(tool_name)

func set_active_tool(tool_name: String) -> void:
	active_tool = tool_name
	for t in tool_buttons:
		var btn: Button = tool_buttons[t]
		if btn:
			btn.button_pressed = (t == tool_name)

func set_current_color(col: Color) -> void:
	if quick_color_picker:
		quick_color_picker.color = col
