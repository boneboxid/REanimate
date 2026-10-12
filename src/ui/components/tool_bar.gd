class_name ToolBar
extends PanelContainer

signal tool_selected(tool_name: String)
signal stroke_width_changed(width: float)
signal stroke_color_changed(color: Color)
signal fill_color_changed(color: Color)
signal object_drawing_toggled(enabled: bool)
signal quick_color_changed(color: Color)

# Tool Buttons
@onready var btn_select: Button = %ToolSelect
@onready var btn_subselect: Button = %ToolSubselect
@onready var btn_transform: Button = %ToolTransform
@onready var btn_lasso: Button = %ToolLasso
@onready var btn_pen: Button = %ToolPen
@onready var btn_text: Button = %ToolText
@onready var btn_line: Button = %ToolLine
@onready var btn_rect: Button = %ToolRect
@onready var btn_circle: Button = %ToolCircle
@onready var btn_polystar: Button = %ToolPolystar
@onready var btn_pencil: Button = %ToolPencil
@onready var btn_brush: Button = %ToolBrush
@onready var btn_ink_bottle: Button = %ToolInkBottle
@onready var btn_paint_bucket: Button = %ToolPaintBucket
@onready var btn_eyedropper: Button = %ToolEyedropper
@onready var btn_eraser: Button = %ToolEraser
@onready var btn_hand: Button = %ToolHand
@onready var btn_zoom: Button = %ToolZoom

# Colors and Controls
@onready var stroke_color_picker: ColorPickerButton = %StrokeColorPicker
@onready var fill_color_picker: ColorPickerButton = %FillColorPicker
@onready var btn_swap_colors: Button = %BtnSwapColors
@onready var btn_default_colors: Button = %BtnDefaultColors
@onready var btn_object_drawing: Button = %BtnObjectDrawing
@onready var stroke_width_spin: SpinBox = %StrokeWidthSpin
@onready var quick_color_picker: ColorPickerButton = %QuickColorPicker

var active_tool: String = "Select"
var tool_buttons: Dictionary = {}
var is_object_drawing: bool = false

func _ready() -> void:
	tool_buttons = {
		"Select": btn_select,
		"Subselect": btn_subselect,
		"Transform": btn_transform,
		"Lasso": btn_lasso,
		"Pen": btn_pen,
		"Text": btn_text,
		"Line": btn_line,
		"Rect": btn_rect,
		"Circle": btn_circle,
		"Polystar": btn_polystar,
		"Pencil": btn_pencil,
		"Brush": btn_brush,
		"InkBottle": btn_ink_bottle,
		"PaintBucket": btn_paint_bucket,
		"Eyedropper": btn_eyedropper,
		"Eraser": btn_eraser,
		"Hand": btn_hand,
		"Zoom": btn_zoom
	}
	
	for tool_name in tool_buttons:
		var btn = tool_buttons[tool_name]
		if btn:
			btn.pressed.connect(func(): _select_tool(tool_name))
			
	if stroke_color_picker:
		stroke_color_picker.color_changed.connect(_on_stroke_color_changed)
	if fill_color_picker:
		fill_color_picker.color_changed.connect(_on_fill_color_changed)
		
	if btn_swap_colors:
		btn_swap_colors.pressed.connect(swap_colors)
	if btn_default_colors:
		btn_default_colors.pressed.connect(reset_default_colors)
	if btn_object_drawing:
		btn_object_drawing.toggled.connect(_on_object_drawing_toggled)
		
	if stroke_width_spin:
		stroke_width_spin.value_changed.connect(func(v): stroke_width_changed.emit(float(v)))
		
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

func _on_stroke_color_changed(col: Color) -> void:
	stroke_color_changed.emit(col)

func _on_fill_color_changed(col: Color) -> void:
	fill_color_changed.emit(col)
	quick_color_changed.emit(col)

func swap_colors() -> void:
	var temp = stroke_color_picker.color
	stroke_color_picker.color = fill_color_picker.color
	fill_color_picker.color = temp
	stroke_color_changed.emit(stroke_color_picker.color)
	fill_color_changed.emit(fill_color_picker.color)
	quick_color_changed.emit(fill_color_picker.color)

func reset_default_colors() -> void:
	stroke_color_picker.color = Color(0.1, 0.1, 0.1, 1.0)
	fill_color_picker.color = Color(1.0, 1.0, 1.0, 1.0)
	stroke_color_changed.emit(stroke_color_picker.color)
	fill_color_changed.emit(fill_color_picker.color)
	quick_color_changed.emit(fill_color_picker.color)

func _on_object_drawing_toggled(toggled_on: bool) -> void:
	is_object_drawing = toggled_on
	object_drawing_toggled.emit(toggled_on)

func set_stroke_color(col: Color) -> void:
	if stroke_color_picker:
		stroke_color_picker.color = col

func set_fill_color(col: Color) -> void:
	if fill_color_picker:
		fill_color_picker.color = col
	if quick_color_picker:
		quick_color_picker.color = col

func set_current_color(col: Color) -> void:
	set_fill_color(col)
