class_name LibraryDock
extends PanelContainer

signal symbol_selected(symbol_id: String)
signal symbol_edit_requested(symbol_id: String)
signal symbol_place_requested(symbol_id: String)
signal symbol_create_requested(name: String, type: String, reg_index: int)
signal symbol_duplicate_requested(symbol_id: String)
signal symbol_rename_requested(symbol_id: String, new_name: String)
signal symbol_delete_requested(symbol_id: String)
signal library_close_requested()

# Node References
@onready var search_edit: LineEdit = %LibrarySearchEdit
@onready var preview_canvas: Control = %LibraryPreviewCanvas
@onready var preview_info_label: Label = %LibraryPreviewInfo
@onready var symbol_list: ItemList = %LibraryList
@onready var btn_new_symbol: Button = %BtnNewSymbol
@onready var btn_place_on_stage: Button = %BtnPlaceOnStage
@onready var btn_edit_symbol: Button = %BtnEditSymbol
@onready var btn_duplicate_symbol: Button = %BtnDuplicateSymbol
@onready var btn_rename_symbol: Button = %BtnRenameSymbol
@onready var btn_delete_symbol: Button = %BtnDeleteSymbol
@onready var btn_close_library: Button = %BtnCloseLibrary

# Internal Dialogs
@onready var new_symbol_dialog: ConfirmationDialog = %NewSymbolDialog
@onready var new_sym_name_edit: LineEdit = %NewSymNameEdit
@onready var new_sym_type_option: OptionButton = %NewSymTypeOption
@onready var rename_dialog: ConfirmationDialog = %RenameSymbolDialog
@onready var rename_edit: LineEdit = %RenameSymEdit

var current_library: Dictionary = {}
var selected_symbol_id: String = ""
var filter_query: String = ""

func _ready() -> void:
	_setup_ui_signals()
	_setup_dialogs()
	if preview_canvas:
		preview_canvas.draw.connect(_on_draw_preview)

func _setup_ui_signals() -> void:
	if search_edit:
		search_edit.text_changed.connect(func(new_text):
			filter_query = new_text.strip_edges().to_lower()
			_rebuild_list_ui()
		)
		
	if symbol_list:
		symbol_list.item_selected.connect(_on_item_selected)
		symbol_list.item_activated.connect(_on_item_activated)
		
	if btn_place_on_stage:
		btn_place_on_stage.pressed.connect(func():
			if selected_symbol_id != "":
				symbol_place_requested.emit(selected_symbol_id)
		)
		
	if btn_edit_symbol:
		btn_edit_symbol.pressed.connect(func():
			if selected_symbol_id != "":
				symbol_edit_requested.emit(selected_symbol_id)
		)
		
	if btn_new_symbol:
		btn_new_symbol.pressed.connect(_open_new_symbol_dialog)
		
	if btn_duplicate_symbol:
		btn_duplicate_symbol.pressed.connect(func():
			if selected_symbol_id != "":
				symbol_duplicate_requested.emit(selected_symbol_id)
		)
		
	if btn_rename_symbol:
		btn_rename_symbol.pressed.connect(_open_rename_dialog)
		
	if btn_delete_symbol:
		btn_delete_symbol.pressed.connect(func():
			if selected_symbol_id != "":
				symbol_delete_requested.emit(selected_symbol_id)
		)
		
	if btn_close_library:
		btn_close_library.pressed.connect(func(): library_close_requested.emit())

func _setup_dialogs() -> void:
	if new_symbol_dialog:
		new_symbol_dialog.confirmed.connect(_on_new_symbol_confirmed)
		new_sym_type_option.clear()
		new_sym_type_option.add_item("Graphic", 0)
		new_sym_type_option.add_item("Movie Clip", 1)
		new_sym_type_option.add_item("Button", 2)
		
	if rename_dialog:
		rename_dialog.confirmed.connect(_on_rename_confirmed)

func refresh_library(library_dict: Dictionary, p_selected_id: String = "") -> void:
	current_library = library_dict
	if p_selected_id != "" and current_library.has(p_selected_id):
		selected_symbol_id = p_selected_id
	elif not current_library.has(selected_symbol_id):
		selected_symbol_id = "" if current_library.is_empty() else current_library.keys()[0]
		
	_rebuild_list_ui()
	_update_preview()

func _rebuild_list_ui() -> void:
	if not symbol_list:
		return
	symbol_list.clear()
	
	var select_idx = -1
	for id in current_library:
		var sym = current_library[id]
		var sym_name: String = sym.name if sym != null else "Unnamed"
		if filter_query != "" and not sym_name.to_lower().contains(filter_query):
			continue
			
		var type_prefix = "🎨 Graphic"
		var s_type = sym.symbol_type if sym != null else "graphic"
		match s_type:
			"movie_clip": type_prefix = "🎬 MovieClip"
			"button": type_prefix = "🔘 Button"
			_: type_prefix = "🎨 Graphic"
			
		var label_str = "%s : %s" % [type_prefix, sym_name]
		var idx = symbol_list.add_item(label_str)
		symbol_list.set_item_metadata(idx, id)
		
		if id == selected_symbol_id:
			select_idx = idx
			
	if select_idx != -1:
		symbol_list.select(select_idx)
	_update_buttons_state()

func _update_buttons_state() -> void:
	var has_sel = (selected_symbol_id != "" and current_library.has(selected_symbol_id))
	if btn_place_on_stage: btn_place_on_stage.disabled = not has_sel
	if btn_edit_symbol: btn_edit_symbol.disabled = not has_sel
	if btn_duplicate_symbol: btn_duplicate_symbol.disabled = not has_sel
	if btn_rename_symbol: btn_rename_symbol.disabled = not has_sel
	if btn_delete_symbol: btn_delete_symbol.disabled = not has_sel

func _on_item_selected(idx: int) -> void:
	var id = str(symbol_list.get_item_metadata(idx))
	selected_symbol_id = id
	symbol_selected.emit(id)
	_update_preview()
	_update_buttons_state()

func _on_item_activated(idx: int) -> void:
	var id = str(symbol_list.get_item_metadata(idx))
	selected_symbol_id = id
	symbol_edit_requested.emit(id)

func _update_preview() -> void:
	if preview_canvas:
		preview_canvas.queue_redraw()
		
	if not preview_info_label:
		return
		
	if selected_symbol_id == "" or not current_library.has(selected_symbol_id):
		preview_info_label.text = "No symbol selected (%d in library)" % current_library.size()
		return
		
	var sym = current_library[selected_symbol_id]
	var total_layers = sym.timeline.layers.size() if sym.timeline != null else 0
	var total_frames = sym.timeline.max_frames if sym.timeline != null else 0
	preview_info_label.text = "%s [%s]\n%d layer(s), %d frames" % [
		sym.name,
		sym.symbol_type.capitalize(),
		total_layers,
		total_frames
	]

func _on_draw_preview() -> void:
	if not preview_canvas:
		return
	var size = preview_canvas.size
	var center = size * 0.5
	
	# Background grid / origin axis
	preview_canvas.draw_line(Vector2(center.x, 0), Vector2(center.x, size.y), Color(0.25, 0.25, 0.3, 0.6), 1.0)
	preview_canvas.draw_line(Vector2(0, center.y), Vector2(size.x, center.y), Color(0.25, 0.25, 0.3, 0.6), 1.0)
	
	if selected_symbol_id == "" or not current_library.has(selected_symbol_id):
		var font = ThemeDB.fallback_font
		preview_canvas.draw_string(font, center + Vector2(-60, 4), "No Preview Available", HORIZONTAL_ALIGNMENT_CENTER, 120, 11, Color(0.5, 0.5, 0.55, 0.8))
		return
		
	var sym = current_library[selected_symbol_id]
	if sym == null or sym.timeline == null:
		return
		
	# Gambarkan elemen visual di frame 0 layer pertama jika ada
	var drawn_any = false
	for l in sym.timeline.layers:
		if l.keyframes.size() > 0:
			var kf = l.keyframes[0]
			for el in kf.elements:
				_draw_preview_element(el, center)
				drawn_any = true
				break
		if drawn_any:
			break
			
	if not drawn_any:
		# Gambarkan placeholder bentuk symbol khas Flash
		var p_col = Color(0.3, 0.6, 0.9, 0.7)
		if sym.symbol_type == "movie_clip": p_col = Color(0.2, 0.8, 0.4, 0.7)
		elif sym.symbol_type == "button": p_col = Color(0.9, 0.6, 0.2, 0.7)
		preview_canvas.draw_rect(Rect2(center - Vector2(25, 25), Vector2(50, 50)), p_col, false, 2.0)
		var font = ThemeDB.fallback_font
		preview_canvas.draw_string(font, center + Vector2(-40, 4), "[%s]" % sym.name, HORIZONTAL_ALIGNMENT_CENTER, 80, 10, Color.WHITE)
		
	# Registration point crosshair
	preview_canvas.draw_circle(center, 3.5, Color(1.0, 0.2, 0.2, 0.9))
	preview_canvas.draw_circle(center, 3.5, Color.WHITE, false, 1.0)

func _draw_preview_element(el, center: Vector2) -> void:
	var el_pos = center
	if el.transform != null:
		el_pos += el.transform.position
		
	var col = el.color
	var scol = el.stroke_color
	var sw = maxf(1.0, el.stroke_width * 0.7)
	
	if el.shape_type == "rect":
		var r_sz = Vector2(50, 50)
		preview_canvas.draw_rect(Rect2(el_pos - r_sz * 0.5, r_sz), col)
		if sw > 0:
			preview_canvas.draw_rect(Rect2(el_pos - r_sz * 0.5, r_sz), scol, false, sw)
	elif el.shape_type == "circle":
		preview_canvas.draw_circle(el_pos, 25.0, col)
		if sw > 0:
			preview_canvas.draw_circle(el_pos, 25.0, scol, false, sw)
	elif el.points.size() >= 2:
		var pts = PackedVector2Array()
		for pt in el.points:
			pts.append(el_pos + pt * 0.5)
		if pts.size() >= 3 and col.a > 0.05:
			preview_canvas.draw_colored_polygon(pts, col)
		preview_canvas.draw_polyline(pts, scol, sw, true)
	else:
		preview_canvas.draw_rect(Rect2(el_pos - Vector2(20, 20), Vector2(40, 40)), col)

# Dialog Handlers
func _open_new_symbol_dialog() -> void:
	if new_symbol_dialog:
		new_sym_name_edit.text = "Symbol %d" % (current_library.size() + 1)
		new_sym_type_option.selected = 0
		new_symbol_dialog.popup_centered()

func _on_new_symbol_confirmed() -> void:
	var s_name = new_sym_name_edit.text.strip_edges()
	if s_name == "": s_name = "Symbol %d" % (current_library.size() + 1)
	var type_idx = new_sym_type_option.selected
	var types = ["graphic", "movie_clip", "button"]
	var s_type = types[clampi(type_idx, 0, 2)]
	symbol_create_requested.emit(s_name, s_type, 4)

func _open_rename_dialog() -> void:
	if selected_symbol_id == "" or not current_library.has(selected_symbol_id):
		return
	if rename_dialog:
		rename_edit.text = current_library[selected_symbol_id].name
		rename_dialog.popup_centered()

func _on_rename_confirmed() -> void:
	if selected_symbol_id == "" or not current_library.has(selected_symbol_id):
		return
	var new_n = rename_edit.text.strip_edges()
	if new_n != "":
		symbol_rename_requested.emit(selected_symbol_id, new_n)
