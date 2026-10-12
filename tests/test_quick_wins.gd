class_name TestQuickWins
extends RefCounted

static func run_all_tests() -> void:
	print(">>> RUNNING QUICK WINS ACCEPTANCE TESTS <<<")
	test_transform_scale_handles()
	test_ellipse_hit_test()
	test_eraser_keyframe_cleanup()
	test_topmost_and_layer_lock_hit_test()
	test_line_segment_hit_test()
	test_lasso_selection()
	print(">>> ALL QUICK WINS ACCEPTANCE TESTS PASSED! <<<")

static func test_transform_scale_handles() -> void:
	var canvas = StageCanvas.new()
	var item = StageItem.new()
	item.id = "test_rect"
	item.shape_type = "rect"
	item.size = Vector2(100, 100)
	
	var t = ItemTransform.new()
	t.position = Vector2(200, 200)
	t.scale = Vector2.ONE
	
	canvas.set_stage_data({ item.id: item }, { item.id: t })
	canvas.active_tool = "Transform"
	canvas.selected_item_id = item.id
	
	# Handle 3 is right center: (200 + 50, 200) = (250, 200)
	canvas._handle_press(Vector2(250, 200), 1.0)
	assert(canvas.is_scaling, "Must be scaling")
	assert(canvas.scale_handle_index == 3, "Handle index must be 3 (Right-Center)")
	
	# Drag to x = 300 (offset from 200 is 100, original half_size was 50, so scale.x = 2.0)
	canvas._handle_motion(Vector2(300, 200), 1.0)
	assert(is_equal_approx(t.scale.x, 2.0), "Scale X should be 2.0 after drag")
	
	canvas._handle_release(Vector2(300, 200))
	assert(!canvas.is_scaling, "Scaling must finish on release")
	canvas.free()
	print("  [OK] 1. Free Transform 8-handle scale interaction")

static func test_ellipse_hit_test() -> void:
	var canvas = StageCanvas.new()
	var item = StageItem.new()
	item.id = "test_oval"
	item.shape_type = "circle"
	item.size = Vector2(200, 100) # rx = 100, ry = 50
	
	var t = ItemTransform.new()
	t.position = Vector2(0, 0)
	t.scale = Vector2.ONE
	
	canvas.set_stage_data({ item.id: item }, { item.id: t })
	
	# Point (80, 0): inside ellipse (80/100)^2 = 0.64 <= 1.0
	assert(canvas._hit_test_item(Vector2(80, 0)) == item.id, "Point (80,0) must hit ellipse")
	
	# Point (0, 40): inside ellipse (40/50)^2 = 0.64 <= 1.0
	assert(canvas._hit_test_item(Vector2(0, 40)) == item.id, "Point (0,40) must hit ellipse")
	
	# Point (0, 70): outside ellipse (70/50)^2 = 1.96 > 1.0
	# Previously would hit because it wrongly checked length <= rx (70 <= 100)
	assert(canvas._hit_test_item(Vector2(0, 70)) == "", "Point (0,70) must NOT hit ellipse")
	canvas.free()
	print("  [OK] 2. Oval ellipse drawing & exact elliptical hit-testing")

static func test_eraser_keyframe_cleanup() -> void:
	var doc = ProjectDocument.create_default()
	var box_id = doc.items.keys()[0]
	
	# Ensure item is in layer 0 keyframes
	assert(doc.layers[0].keyframes[0].transforms.has(box_id), "Keyframe 0 must have item")
	assert(doc.layers[0].keyframes[1].transforms.has(box_id), "Keyframe 1 must have item")
	
	# Delete item and clean up keyframes
	doc.items.erase(box_id)
	for l in doc.layers:
		for kf in l.keyframes:
			kf.transforms.erase(box_id)
			
	assert(!doc.items.has(box_id), "Document items must not have deleted item")
	assert(!doc.layers[0].keyframes[0].transforms.has(box_id), "Keyframe 0 must have item erased")
	assert(!doc.layers[0].keyframes[1].transforms.has(box_id), "Keyframe 1 must have item erased")
	print("  [OK] 3. Eraser removes item from document and all keyframe transforms")

static func test_topmost_and_layer_lock_hit_test() -> void:
	var canvas = StageCanvas.new()
	var item_bottom = StageItem.new()
	item_bottom.id = "item_bottom"
	item_bottom.shape_type = "rect"
	item_bottom.size = Vector2(100, 100)
	
	var item_top = StageItem.new()
	item_top.id = "item_top"
	item_top.shape_type = "rect"
	item_top.size = Vector2(100, 100)
	
	var t_bottom = ItemTransform.new()
	t_bottom.position = Vector2(0, 0)
	var t_top = ItemTransform.new()
	t_top.position = Vector2(0, 0)
	
	var items = { item_bottom.id: item_bottom, item_top.id: item_top }
	var transforms = { item_bottom.id: t_bottom, item_top.id: t_top }
	
	# item_top is on top (first in layer_order)
	canvas.set_stage_data(items, transforms, [], {}, [], [item_top.id, item_bottom.id])
	assert(canvas._hit_test_item(Vector2.ZERO) == item_top.id, "Topmost item must be hit first")
	
	# If top item is on locked layer, bottom item must be selected
	canvas.set_stage_data(items, transforms, [], {}, [], [item_top.id, item_bottom.id], { item_top.id: true })
	assert(canvas._hit_test_item(Vector2.ZERO) == item_bottom.id, "Locked top item must be skipped for bottom item")
	
	# If top item is hidden, bottom item must be selected
	canvas.set_stage_data(items, transforms, [], {}, [], [item_top.id, item_bottom.id], {}, { item_top.id: false })
	assert(canvas._hit_test_item(Vector2.ZERO) == item_bottom.id, "Hidden top item must be skipped for bottom item")
	canvas.free()
	print("  [OK] 4. Topmost hit-test priority and respect for locked/hidden layers")

static func test_line_segment_hit_test() -> void:
	var canvas = StageCanvas.new()
	var line_item = StageItem.new()
	line_item.id = "line_1"
	line_item.shape_type = "line"
	line_item.points = PackedVector2Array([Vector2(-100, -100), Vector2(100, 100)])
	line_item.stroke_width = 4.0
	
	var t = ItemTransform.new()
	t.position = Vector2(200, 200)
	
	canvas.set_stage_data({ line_item.id: line_item }, { line_item.id: t })
	
	# Midpoint in stage space is (200, 200). Distance to endpoints is ~141px (far > 10px).
	assert(canvas._hit_test_item(Vector2(200, 200)) == line_item.id, "Clicking midpoint of line segment must hit")
	
	# Point 50px away perpendicularly (200, 250) must not hit
	assert(canvas._hit_test_item(Vector2(200, 250)) == "", "Point far from line segment must NOT hit")
	canvas.free()
	print("  [OK] 5. Path/Line segment proximity hit-testing")

static func test_lasso_selection() -> void:
	var canvas = StageCanvas.new()
	var item_a = StageItem.new()
	item_a.id = "item_a"
	item_a.size = Vector2(20, 20)
	var t_a = ItemTransform.new()
	t_a.position = Vector2(50, 50)
	
	var item_b = StageItem.new()
	item_b.id = "item_b"
	item_b.size = Vector2(20, 20)
	var t_b = ItemTransform.new()
	t_b.position = Vector2(300, 300)
	
	canvas.set_stage_data({ item_a.id: item_a, item_b.id: item_b }, { item_a.id: t_a, item_b.id: t_b })
	canvas.active_tool = "Lasso"
	
	# Draw lasso loop around (0,0) to (100, 100)
	canvas.current_stroke_points = PackedVector2Array([
		Vector2(0, 0), Vector2(100, 0), Vector2(100, 100), Vector2(0, 100), Vector2(0, 0)
	])
	canvas.is_drawing_stroke = true
	canvas._handle_release(Vector2(0, 0))
	
	assert(canvas.selected_item_id == item_a.id, "Lasso must select item_a inside polygon")
	canvas.free()
	print("  [OK] 6. Lasso polygon selection")
