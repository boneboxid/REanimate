class_name TestDrawingTools
extends RefCounted

static func run_all_tests() -> void:
	print(">>> RUNNING PHASE 4 DRAWING TOOLS TESTS <<<")
	test_selection_marquee_and_nudge()
	test_subselection_tangents_and_corner_smooth()
	test_rect_corner_radius()
	test_oval_angles_and_donut()
	test_polystar_parameters()
	test_pencil_rdp_modes()
	test_pen_tool_close_path_fill()
	print(">>> ALL PHASE 4 DRAWING TOOLS TESTS PASSED! <<<")

static func test_selection_marquee_and_nudge() -> void:
	var canvas = StageCanvas.new()
	var itm1 = StageItem.new()
	itm1.id = "item_1"
	itm1.size = Vector2(50, 50)
	var t1 = ItemTransform.new()
	t1.position = Vector2(100, 100)
	
	var itm2 = StageItem.new()
	itm2.id = "item_2"
	itm2.size = Vector2(50, 50)
	var t2 = ItemTransform.new()
	t2.position = Vector2(200, 200)
	
	canvas.set_stage_data({"item_1": itm1, "item_2": itm2}, {"item_1": t1, "item_2": t2})
	
	# 1. Marquee selection covering both items [50, 50] to [250, 250]
	canvas.active_tool = "Select"
	canvas.marquee_start = Vector2(50, 50)
	canvas.marquee_current = Vector2(250, 250)
	canvas.is_marquee_selecting = true
	canvas._handle_release(Vector2(250, 250))
	
	assert(canvas.selected_item_ids.size() == 2, "Marquee must select both items")
	assert(canvas.selected_item_ids.has("item_1") and canvas.selected_item_ids.has("item_2"), "Both item_1 and item_2 selected")
	
	# 2. Keyboard Nudge (1px normal, 10px shift)
	canvas.selected_item_id = "item_1"
	var key_ev = InputEventKey.new()
	key_ev.pressed = true
	key_ev.keycode = KEY_RIGHT
	key_ev.shift_pressed = false
	canvas._unhandled_input(key_ev)
	assert(t1.position.x == 101.0, "Nudge right 1px must move position.x by 1")
	
	key_ev.shift_pressed = true
	canvas._unhandled_input(key_ev)
	assert(t1.position.x == 111.0, "Shift + Nudge right must move position.x by 10")
	
	canvas.free()
	print("  [OK] 1. Selection Marquee & Nudge Interaction")

static func test_subselection_tangents_and_corner_smooth() -> void:
	var canvas = StageCanvas.new()
	var path_itm = StageItem.new()
	path_itm.id = "path_1"
	path_itm.shape_type = "path"
	path_itm.points = PackedVector2Array([Vector2(0, 0), Vector2(100, 0), Vector2(100, 100)])
	path_itm.curve_controls = PackedVector2Array([Vector2(50, 0), Vector2(100, 50)])
	
	var t = ItemTransform.new()
	t.position = Vector2(100, 100)
	canvas.set_stage_data({"path_1": path_itm}, {"path_1": t})
	canvas.selected_item_id = "path_1"
	canvas.active_tool = "Subselect"
	
	# 1. Click on node (100, 100) + (100, 0) = (200, 100) -> Node 1
	canvas._handle_subselect_press(Vector2(200, 100))
	assert(canvas.selected_subnode_idx == 1, "Subselect must select anchor node 1")
	
	# 2. Drag anchor node to (220, 110)
	canvas._handle_motion(Vector2(220, 110), 1.0)
	assert(path_itm.points[1] == Vector2(120, 10), "Dragging subnode updates anchor coordinates")
	
	# 3. Alt-click on anchor node to toggle smooth tangent
	canvas.is_alt_pressed = true
	# node 1 is at local Vector2(120, 10), so global is (100, 100) + (120, 10) = (220, 110)
	# Initially curve_controls[1] is Vector2(100, 50). Distance to p1 (120, 10) is > 2.0, so Alt-click collapses it to p_cur
	canvas._handle_subselect_press(Vector2(220, 110))
	canvas.is_alt_pressed = false
	assert(path_itm.curve_controls[1] == path_itm.points[1], "Alt-click on smooth node collapses tangent to corner node")
	
	canvas.free()
	print("  [OK] 2. Subselection Nodes, Tangents & Corner/Smooth Toggle")

static func test_rect_corner_radius() -> void:
	var canvas = StageCanvas.new()
	canvas.active_tool = "Rect"
	canvas.rect_corner_radius = Vector4(12, 12, 12, 12)
	canvas.shape_draw_start = Vector2(0, 0)
	canvas.shape_draw_current = Vector2(100, 80)
	canvas.is_drawing_stroke = true
	
	var box = [null]
	canvas.drawing_finished.connect(func(itm, center): box[0] = itm)
	canvas._handle_release(Vector2(100, 80))
	var created_item: StageItem = box[0]
	
	assert(created_item != null, "Drawing must create item")
	assert(created_item.shape_type == "rect", "Shape type must be rect")
	assert(created_item.corner_radius == Vector4(12, 12, 12, 12), "Item must have corner radius Vector4(12, 12, 12, 12)")
	
	canvas.free()
	print("  [OK] 3. Rectangle 4-Corner Radius")

static func test_oval_angles_and_donut() -> void:
	var canvas = StageCanvas.new()
	canvas.active_tool = "Circle"
	canvas.oval_start_angle = 0.0
	canvas.oval_end_angle = PI
	canvas.oval_inner_radius_ratio = 0.5
	canvas.shape_draw_start = Vector2(0, 0)
	canvas.shape_draw_current = Vector2(100, 100)
	canvas.is_drawing_stroke = true
	
	var box = [null]
	canvas.drawing_finished.connect(func(itm, center): box[0] = itm)
	canvas._handle_release(Vector2(100, 100))
	var created_item: StageItem = box[0]
	
	assert(created_item != null, "Drawing must create item")
	assert(created_item.oval_start_angle == 0.0, "Start angle preserved")
	assert(abs(created_item.oval_end_angle - PI) < 0.001, "End angle preserved")
	assert(created_item.oval_inner_radius_ratio == 0.5, "Inner radius donut preserved")
	
	# Hit-test exact donut logic
	var t = ItemTransform.new()
	t.position = Vector2(50, 50)
	# Center of donut (50, 50) is empty hole (inner radius 0.5)
	assert(HitTester.hit_test_item(created_item, t, Vector2(50, 50)) == false, "Donut hole must not hit-test")
	# Outside sector (bottom half, since angles are 0..PI top half in screen space y)
	assert(HitTester.hit_test_item(created_item, t, Vector2(50, 80)) == true, "Donut solid arc must hit-test")
	
	canvas.free()
	print("  [OK] 4. Oval Start/End Angle & Inner Radius Donut")

static func test_polystar_parameters() -> void:
	var canvas = StageCanvas.new()
	canvas.active_tool = "Polystar"
	canvas.polystar_sides = 8
	canvas.polystar_is_star = true
	canvas.polystar_inner_ratio = 0.35
	canvas.shape_draw_start = Vector2(0, 0)
	canvas.shape_draw_current = Vector2(80, 80)
	canvas.is_drawing_stroke = true
	
	var box = [null]
	canvas.drawing_finished.connect(func(itm, center): box[0] = itm)
	canvas._handle_release(Vector2(80, 80))
	var created_item: StageItem = box[0]
	
	assert(created_item != null, "Drawing must create item")
	assert(created_item.shape_type == "polystar", "Shape type must be polystar")
	assert(created_item.polystar_sides == 8, "Sides must be 8")
	assert(created_item.is_star == true, "Must be star")
	assert(created_item.star_inner_radius_ratio == 0.35, "Inner ratio must be 0.35")
	
	canvas.free()
	print("  [OK] 5. Polystar Sides 3-32 & Star Point Ratio")

static func test_pencil_rdp_modes() -> void:
	var canvas = StageCanvas.new()
	canvas.active_tool = "Pencil"
	canvas.pencil_mode = "Straighten"
	
	# Raw dense points on straight line with tiny noise
	var raw_pts = PackedVector2Array()
	for i in range(20):
		raw_pts.append(Vector2(i * 10, i * 10 + (sin(float(i)) * 2.0)))
	canvas.current_stroke_points = raw_pts
	canvas.is_drawing_stroke = true
	
	var initial_count = raw_pts.size()
	var box = [null]
	canvas.drawing_finished.connect(func(itm, center): box[0] = itm)
	canvas._handle_release(raw_pts[-1])
	var created_item: StageItem = box[0]
	
	assert(created_item != null, "Pencil item must be created")
	assert(created_item.points.size() < initial_count, "Straighten mode with RDP must simplify points")
	assert(created_item.points.size() <= 4, "Straighten mode simplifies dense stroke to endpoints")
	
	canvas.free()
	print("  [OK] 6. Pencil Ramer-Douglas-Peucker Straighten & Smoothing")

static func test_pen_tool_close_path_fill() -> void:
	var canvas = StageCanvas.new()
	canvas.active_tool = "Pen"
	canvas.current_fill_color = Color.MAGENTA
	
	var box = [null]
	canvas.drawing_finished.connect(func(itm, center):
		box[0] = itm
		canvas.items[itm.id] = itm
		var t = ItemTransform.new()
		t.position = center
		canvas.current_transforms[itm.id] = t
	)
	
	# 1. Click 1 at (0, 0) -> creates Pen Path
	canvas._handle_pen_click(Vector2(0, 0))
	var pen_item: StageItem = box[0]
	assert(pen_item != null, "Clicking empty with pen creates new item")
	assert(canvas.selected_item_id == pen_item.id, "Pen item is selected")
	
	# 2. Click 2 at (100, 0)
	canvas._handle_pen_click(Vector2(100, 0))
	# 3. Click 3 at (100, 100)
	canvas._handle_pen_click(Vector2(100, 100))
	# 4. Click 4 at (0, 0) -> close path!
	canvas._handle_pen_click(Vector2(2, 2))
	
	assert(pen_item.color == Color.MAGENTA, "Closing pen path must fill with current_fill_color")
	assert(canvas.selected_item_id == "", "Closing pen path deselects/completes the path")
	
	canvas.free()
	print("  [OK] 7. Pen Tool Click Handles & Close Path Fill")
