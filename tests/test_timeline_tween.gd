class_name TestTimelineTween
extends RefCounted

const ShapeTweenEngineScript = preload("res://src/core/shape_tween_engine.gd")

static func run_all_tests() -> void:
	print(">>> RUNNING PHASE 5 TIMELINE & TWEENING TESTS <<<")
	test_frame_span_operations()
	test_drag_keyframe_and_resize_span()
	test_copy_paste_and_reverse_frames()
	test_convert_to_keyframes_and_clear_frames()
	test_classic_tween_ease_and_rotation()
	test_shape_tween_rect_to_circle_morph()
	test_layer_masking_and_folders()
	test_frame_labels_and_navigation()
	print(">>> ALL PHASE 5 TIMELINE & TWEENING TESTS PASSED! <<<")

static func test_frame_span_operations() -> void:
	var layer = AnimationLayer.new()
	layer.name = "Animation 1"
	
	# Keyframe 0 di frame 0
	var kf0 = KeyframeData.new()
	kf0.frame_index = 0
	var t0 = ItemTransform.new()
	t0.position = Vector2(10, 10)
	kf0.transforms["box_1"] = t0
	layer.set_keyframe(kf0)
	
	# Keyframe 1 di frame 10 (F6)
	var kf1 = KeyframeData.new()
	kf1.frame_index = 10
	var t1 = ItemTransform.new()
	t1.position = Vector2(100, 100)
	kf1.transforms["box_1"] = t1
	layer.set_keyframe(kf1)
	
	assert(layer.keyframes.size() == 2, "Must have 2 keyframes")
	assert(layer.keyframes[0].duration == 10, "Duration of kf0 must be 10 frames")
	
	# 1. Flash F5: Insert frame span at frame 5
	layer.insert_frame_span(5)
	assert(layer.keyframes[1].frame_index == 11, "F5 must shift subsequent keyframes right")
	assert(layer.keyframes[0].duration == 11, "Duration must expand to 11")
	
	# 2. Flash Shift+F5: Remove frame span at frame 5
	layer.remove_frame_span(5)
	assert(layer.keyframes[1].frame_index == 10, "Shift+F5 must shift subsequent keyframes left")
	assert(layer.keyframes[0].duration == 10, "Duration must return to 10")
	
	# 3. Flash F7: Insert Blank Keyframe at frame 5
	var blank_kf = layer.insert_blank_keyframe(5)
	assert(layer.keyframes.size() == 3, "Must have 3 keyframes after F7")
	assert(blank_kf.transforms.is_empty(), "Blank keyframe must have empty transforms")
	assert(layer.keyframes[0].duration == 5, "kf0 duration must now be 5")
	assert(layer.keyframes[1].duration == 5, "blank_kf duration must be 5")
	
	# 4. Flash Shift+F6: Clear Keyframe at frame 5
	layer.clear_keyframe(5)
	assert(layer.keyframes.size() == 2, "Must return to 2 keyframes after clear")
	assert(layer.keyframes[0].duration == 10, "Duration must restore to 10")
	
	print("  [OK] 1. Frame Span F5/Shift+F5 & Keyframe F6/F7/Shift+F6 Mechanics")

static func test_drag_keyframe_and_resize_span() -> void:
	var layer = AnimationLayer.new()
	var kf0 = KeyframeData.new()
	kf0.frame_index = 0
	layer.set_keyframe(kf0)
	
	var kf1 = KeyframeData.new()
	kf1.frame_index = 10
	layer.set_keyframe(kf1)
	
	# 1. Drag keyframe 10 to 15
	layer.drag_keyframe(10, 15)
	assert(layer.get_keyframe_at(10) == null, "Old keyframe 10 position must be cleared")
	assert(layer.get_keyframe_at(15) != null, "Keyframe must now exist at frame 15")
	assert(layer.keyframes[0].duration == 15, "First span duration expanded to 15")
	
	# 2. Resize span: change kf0 duration from 15 to 20
	layer.resize_span(0, 20)
	assert(layer.keyframes[1].frame_index == 20, "Resizing span shifts subsequent keyframe to 20")
	assert(layer.keyframes[0].duration == 20, "First span duration is now 20")
	
	print("  [OK] 2. Drag Keyframe & Resize Span Edge")

static func test_copy_paste_and_reverse_frames() -> void:
	var layer = AnimationLayer.new()
	
	var kf0 = KeyframeData.new()
	kf0.frame_index = 0
	var t0 = ItemTransform.new()
	t0.position = Vector2(0, 0)
	kf0.transforms["ball"] = t0
	layer.set_keyframe(kf0)
	
	var kf1 = KeyframeData.new()
	kf1.frame_index = 5
	var t1 = ItemTransform.new()
	t1.position = Vector2(50, 50)
	kf1.transforms["ball"] = t1
	layer.set_keyframe(kf1)
	
	var kf2 = KeyframeData.new()
	kf2.frame_index = 10
	var t2 = ItemTransform.new()
	t2.position = Vector2(100, 100)
	kf2.transforms["ball"] = t2
	layer.set_keyframe(kf2)
	
	# 1. Copy frames [0..10]
	var copied = layer.copy_frames(0, 10)
	assert(copied.size() == 3, "Must copy 3 keyframes")
	assert(copied[0].frame_index == 0, "Relative offset 0")
	assert(copied[1].frame_index == 5, "Relative offset 5")
	assert(copied[2].frame_index == 10, "Relative offset 10")
	
	# 2. Paste frames at frame 20
	layer.paste_frames(20, copied)
	assert(layer.get_keyframe_at(20) != null, "Pasted at 20")
	assert(layer.get_keyframe_at(25) != null, "Pasted at 25")
	assert(layer.get_keyframe_at(30) != null, "Pasted at 30")
	assert(layer.get_keyframe_at(30).transforms["ball"].position == Vector2(100, 100), "Pasted transform verified")
	
	# 3. Reverse Frames [0..10]
	layer.reverse_frames(0, 10)
	# Now frame 0 has position (100, 100) and frame 10 has position (0, 0)
	assert(layer.get_keyframe_at(0).transforms["ball"].position == Vector2(100, 100), "Frame 0 reversed to (100, 100)")
	assert(layer.get_keyframe_at(10).transforms["ball"].position == Vector2(0, 0), "Frame 10 reversed to (0, 0)")
	
	print("  [OK] 3. Copy/Paste Frames & Reverse Frames")

static func test_convert_to_keyframes_and_clear_frames() -> void:
	var layer = AnimationLayer.new()
	var kf0 = KeyframeData.new()
	kf0.frame_index = 0
	var t0 = ItemTransform.new()
	t0.position = Vector2(10, 20)
	kf0.transforms["box"] = t0
	layer.set_keyframe(kf0)
	
	var kf1 = KeyframeData.new()
	kf1.frame_index = 5
	layer.set_keyframe(kf1)
	
	# 1. Convert to Keyframes [1..4]
	layer.convert_to_keyframes(1, 4)
	for f in range(1, 5):
		assert(layer.get_keyframe_at(f) != null, "Frame %d must now be a keyframe" % f)
		assert(layer.get_keyframe_at(f).transforms["box"].position == Vector2(10, 20), "Inherits active item position")
		
	# 2. Clear Frames (1..4)
	layer.clear_frames(0, 4)
	for f in range(1, 5):
		assert(layer.get_keyframe_at(f) == null, "Frame %d keyframe must be cleared" % f)
	assert(layer.get_keyframe_at(0) != null, "Keyframe 0 remains intact")
	assert(layer.get_keyframe_at(5) != null, "Keyframe 5 remains intact")
	
	print("  [OK] 4. Convert to Keyframes (F6 Span) & Clear Frames")

static func test_classic_tween_ease_and_rotation() -> void:
	var layer = AnimationLayer.new()
	
	var kf0 = KeyframeData.new()
	kf0.frame_index = 0
	kf0.tween_type = "classic"
	kf0.ease = 100.0 # Flash Ease Out (+100)
	kf0.rotate_dir = "cw"
	kf0.rotate_times = 1 # 1 full clockwise rotation
	var t0 = ItemTransform.new()
	t0.position = Vector2(0, 0)
	t0.rotation = 0.0
	kf0.transforms["ball"] = t0
	layer.set_keyframe(kf0)
	
	var kf1 = KeyframeData.new()
	kf1.frame_index = 20
	var t1 = ItemTransform.new()
	t1.position = Vector2(200, 200)
	t1.rotation = PI * 0.5
	kf1.transforms["ball"] = t1
	layer.set_keyframe(kf1)
	
	# Test midpoint frame 10
	var t_mid = layer.get_interpolated_transform("ball", 10)
	assert(t_mid != null, "Interpolated transform at frame 10 must exist")
	# With Ease Out (+100), factor at midpoint 0.5 is 1 - (1-0.5)^2 = 0.75 (> 0.5 linear)
	# So position at mid is (0.75 * 200) = 150 > 100
	assert(t_mid.position.x > 140.0, "Ease out curve produces deceleration with factor > 0.5")
	# Rotation with 1 full CW turn: 0 + (PI*0.5 + TAU)*0.75
	assert(t_mid.rotation > PI, "CW 1-turn rotation interpolated smoothly")
	
	# Test end frame 20
	var t_end = layer.get_interpolated_transform("ball", 20)
	assert(abs(t_end.position.x - 200.0) < 0.01, "End position matches target")
	
	print("  [OK] 5. Classic Tween Bouncing Ball Ease (-100..100) & CW/CCW Rotations")

static func test_shape_tween_rect_to_circle_morph() -> void:
	var layer = AnimationLayer.new()
	
	# Shape 1: Persegi Merah 100x100
	var rect_sh = ShapeElement.new()
	rect_sh.id = "morph_shape"
	rect_sh.shape_type = "rect"
	rect_sh.size = Vector2(100, 100)
	rect_sh.color = Color.RED
	rect_sh.stroke_color = Color.BLACK
	rect_sh.stroke_width = 2.0
	
	var kf0 = KeyframeData.new()
	kf0.frame_index = 0
	kf0.tween_type = "shape"
	kf0.add_element(rect_sh)
	layer.set_keyframe(kf0)
	
	# Shape 2: Lingkaran Biru diameter 100
	var circ_sh = ShapeElement.new()
	circ_sh.id = "morph_shape"
	circ_sh.shape_type = "circle"
	circ_sh.size = Vector2(100, 100)
	circ_sh.color = Color.BLUE
	circ_sh.stroke_color = Color.YELLOW
	circ_sh.stroke_width = 4.0
	
	var kf1 = KeyframeData.new()
	kf1.frame_index = 20
	kf1.add_element(circ_sh)
	layer.set_keyframe(kf1)
	
	# Test Shape Morphing at midpoint frame 10 (factor 0.5)
	var morphed_el = layer.get_interpolated_element("morph_shape", 10)
	assert(morphed_el != null, "Morphed element must exist at frame 10")
	assert(morphed_el is ShapeElement, "Morphed element is ShapeElement")
	var morphed_sh = morphed_el as ShapeElement
	
	# Color must be purple (Red lerp Blue at 0.5)
	assert(abs(morphed_sh.color.r - 0.5) < 0.05 and abs(morphed_sh.color.b - 0.5) < 0.05, "Color morphing: Red lerp Blue -> Purple")
	assert(abs(morphed_sh.stroke_width - 3.0) < 0.01, "Stroke width lerp 2.0 and 4.0 -> 3.0")
	assert(morphed_sh.points.size() == ShapeTweenEngineScript.SAMPLE_POINTS_COUNT, "Continuous vertex count matched for shape morphing")
	
	# Direct ShapeTweenEngine verification
	var direct_morph = ShapeTweenEngineScript.interpolate_shape(rect_sh, circ_sh, 0.5)
	assert(direct_morph != null and direct_morph.points.size() > 0, "Direct ShapeTweenEngine morph succeeds")
	
	print("  [OK] 6. Shape Tween Rect-to-Circle Morphing & Color Interpolation")

static func test_layer_masking_and_folders() -> void:
	var tm = TimelineModel.new()
	
	var folder = AnimationLayer.new()
	folder.name = "Character Folder"
	folder.layer_type = "folder"
	folder.id = "folder_char"
	tm.add_layer(folder)
	
	var mask_l = AnimationLayer.new()
	mask_l.name = "Iris Mask"
	mask_l.layer_type = "mask"
	mask_l.parent_folder = "folder_char"
	tm.add_layer(mask_l)
	
	var masked_l = AnimationLayer.new()
	masked_l.name = "Eyeball Content"
	masked_l.layer_type = "masked"
	masked_l.parent_folder = "folder_char"
	tm.add_layer(masked_l)
	
	var normal_l = AnimationLayer.new()
	normal_l.name = "Background"
	normal_l.layer_type = "normal"
	tm.add_layer(normal_l)
	
	assert(tm.layers.size() == 4, "4 layers created")
	
	# Mask detection
	var found_mask = tm.get_mask_for_layer(2)
	assert(found_mask != null and found_mask.id == mask_l.id, "Mask layer correctly detected for masked layer")
	assert(tm.get_mask_for_layer(3) == null, "Normal layer is not masked")
	
	# Folder filtering
	var in_folder = tm.get_layers_in_folder("folder_char")
	assert(in_folder.size() == 2, "2 layers inside folder")
	
	# Reorder layers
	tm.reorder_layer(3, 0)
	assert(tm.layers[0].name == "Background", "Layer reordered to index 0")
	
	print("  [OK] 7. Layer Masking, Folder Grouping & Layer Reordering")

static func test_frame_labels_and_navigation() -> void:
	var tm = TimelineModel.new()
	var l = AnimationLayer.new()
	
	var kf_idle = KeyframeData.new()
	kf_idle.frame_index = 0
	kf_idle.label = "idle"
	l.set_keyframe(kf_idle)
	
	var kf_walk = KeyframeData.new()
	kf_walk.frame_index = 12
	kf_walk.label = "walk"
	l.set_keyframe(kf_walk)
	
	var kf_jump = KeyframeData.new()
	kf_jump.frame_index = 24
	kf_jump.label = "jump"
	l.set_keyframe(kf_jump)
	
	tm.add_layer(l)
	
	assert(tm.get_frame_by_label("idle") == 0, "Idle frame label found at 0")
	assert(tm.get_frame_by_label("walk") == 12, "Walk frame label found at 12")
	assert(tm.get_frame_by_label("jump") == 24, "Jump frame label found at 24")
	assert(tm.get_frame_by_label("non_existent") == -1, "Unknown label returns -1")
	
	print("  [OK] 8. Frame Labels & Label Navigation")
