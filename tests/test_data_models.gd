class_name TestDataModels
extends RefCounted

static func run_all_tests() -> void:
	print(">>> RUNNING PHASE 1 DATA MODEL TESTS <<<")
	test_round_trip_serialization()
	test_frame_by_frame_element_independence()
	test_transform_matrix_and_skew()
	test_timeline_and_scene_model()
	test_keyframe_easing_and_span_hold()
	test_edge_cases_and_serialization_integrity()
	print(">>> ALL PHASE 1 DATA MODEL TESTS PASSED! <<<")

static func test_round_trip_serialization() -> void:
	var doc = ProjectDocument.create_default()
	assert(doc.version == "2.0.0", "Version must be 2.0.0")
	assert(doc.scenes.size() == 1, "Must have 1 scene")
	assert(doc.layers.size() == 1, "Must have 1 layer")
	
	# Add symbol to library
	var sym = SymbolItem.new()
	sym.id = "star_symbol"
	sym.name = "My Star"
	doc.library[sym.id] = sym
	
	var serialized = doc.to_dict()
	assert(serialized["version"] == "2.0.0", "Serialized version must be 2.0.0")
	assert(serialized["scenes"].size() == 1, "Serialized scenes count must be 1")
	assert(serialized["library"].has("star_symbol"), "Serialized library must contain star_symbol")
	
	# Deserialization
	var loaded = ProjectDocument.from_dict(serialized)
	assert(loaded.version == "2.0.0", "Loaded version must be 2.0.0")
	assert(loaded.scenes.size() == 1, "Loaded scenes must match")
	assert(loaded.library.has("star_symbol"), "Loaded library must match")
	assert(loaded.layers.size() == 1, "Loaded layers must match")
	assert(loaded.layers[0].keyframes.size() == 2, "Keyframes count must match")
	
	# Test backward compatibility with v1.0.0 dictionary
	var v1_dict = {
		"version": "1.0.0",
		"name": "Legacy Anim",
		"stage_size": [1920.0, 1080.0],
		"fps": 24,
		"max_frames": 120,
		"bg_color": [1.0, 1.0, 1.0, 1.0],
		"items": {},
		"symbols": {},
		"layers": [
			{
				"id": "l1",
				"name": "Old Layer",
				"is_visible": true,
				"is_locked": false,
				"keyframes": [
					{
						"frame_index": 0,
						"tween_to_next": "none",
						"transforms": {}
					}
				]
			}
		]
	}
	var loaded_v1 = ProjectDocument.from_dict(v1_dict)
	assert(loaded_v1.scenes.size() == 1, "v1 doc must automatically get 1 scene")
	assert(loaded_v1.layers.size() == 1, "v1 layer must be present")
	assert(loaded_v1.layers[0].name == "Old Layer", "v1 layer name must match")
	print("  [OK] 1. Round-trip serialization & v1.0.0 backward compatibility")

static func test_frame_by_frame_element_independence() -> void:
	# Flash Frame-by-Frame: Editing shape on keyframe 10 must NOT affect keyframe 0!
	var doc = ProjectDocument.new()
	var scene = SceneModel.new("Scene 1")
	doc.scenes.append(scene)
	var layer = AnimationLayer.new()
	scene.timeline.add_layer(layer)
	
	# Keyframe 0 with a red rectangle
	var kf0 = KeyframeData.new()
	kf0.frame_index = 0
	var red_rect = ShapeElement.new()
	red_rect.id = "shape_1"
	red_rect.shape_type = "rect"
	red_rect.color = Color.RED
	kf0.add_element(red_rect)
	layer.set_keyframe(kf0)
	
	# Duplicate keyframe at frame 10 (or new keyframe)
	var kf10 = kf0.duplicate_keyframe()
	kf10.frame_index = 10
	
	# Mutate shape in kf10 to blue circle
	var shape_in_kf10 = kf10.get_element("shape_1") as ShapeElement
	shape_in_kf10.color = Color.BLUE
	shape_in_kf10.shape_type = "circle"
	layer.set_keyframe(kf10)
	
	# VERIFY: kf0 shape must STILL be RED RECT!
	var shape_in_kf0 = kf0.get_element("shape_1") as ShapeElement
	assert(shape_in_kf0.color == Color.RED, "Keyframe 0 shape must remain RED")
	assert(shape_in_kf0.shape_type == "rect", "Keyframe 0 shape must remain RECT")
	
	# VERIFY: kf10 shape is BLUE CIRCLE!
	assert(shape_in_kf10.color == Color.BLUE, "Keyframe 10 shape must be BLUE")
	assert(shape_in_kf10.shape_type == "circle", "Keyframe 10 shape must be CIRCLE")
	print("  [OK] 2. Frame-by-frame element independence (A3 Root Cause Solved)")

static func test_transform_matrix_and_skew() -> void:
	var t = ItemTransform.new()
	t.position = Vector2(100, 200)
	t.rotation = deg_to_rad(45)
	t.scale = Vector2(2.0, 1.5)
	t.skew = Vector2(deg_to_rad(15), 0.0)
	
	var mat = t.to_transform_2d()
	assert(is_equal_approx(mat.origin.x, 100.0), "Origin X must be 100")
	assert(is_equal_approx(mat.origin.y, 200.0), "Origin Y must be 200")
	
	var comp = t.get_matrix_components()
	assert(comp.has("a") and comp.has("b") and comp.has("c") and comp.has("d"), "Matrix components must have a,b,c,d")
	
	# Matrix round-trip from a,b,c,d,tx,ty
	var from_m = ItemTransform.from_matrix(comp["a"], comp["b"], comp["c"], comp["d"], comp["tx"], comp["ty"])
	assert(is_equal_approx(from_m.position.x, 100.0), "Decomposed pos X must match")
	assert(is_equal_approx(from_m.position.y, 200.0), "Decomposed pos Y must match")
	print("  [OK] 3. Matrix2D affine skew and decomposition")

static func test_timeline_and_scene_model() -> void:
	var timeline = TimelineModel.new()
	timeline.max_frames = 50
	var layer1 = AnimationLayer.new()
	layer1.name = "Layer 1"
	timeline.add_layer(layer1)
	
	assert(timeline.layers.size() == 1, "Timeline layers count must be 1")
	
	# Test F5 frame span insertion on timeline
	timeline.insert_frame_all_layers(10)
	assert(timeline.max_frames == 51, "Max frames should increase to 51")
	
	var scene = SceneModel.new("Scene 2")
	scene.timeline = timeline
	assert(scene.name == "Scene 2", "Scene name must match")
	assert(scene.timeline.max_frames == 51, "Scene timeline max_frames must match")
	print("  [OK] 4. TimelineModel & SceneModel architecture")

static func test_keyframe_easing_and_span_hold() -> void:
	var layer = AnimationLayer.new()
	var kf0 = KeyframeData.new()
	kf0.frame_index = 0
	kf0.duration = 20
	kf0.tween_type = "classic"
	kf0.ease = 100.0 # Ease out (slow down at end)
	
	var t0 = ItemTransform.new()
	t0.position = Vector2(0, 0)
	kf0.transforms["box"] = t0
	layer.set_keyframe(kf0)
	
	var kf20 = KeyframeData.new()
	kf20.frame_index = 20
	kf20.duration = 10
	var t20 = ItemTransform.new()
	t20.position = Vector2(100, 0)
	kf20.transforms["box"] = t20
	layer.set_keyframe(kf20)
	
	# At frame 10 (halfway), linear would be 50.0. With Ease Out (+100), factor is greater than 0.5 (e.g. 0.75)!
	var t_half = layer.get_interpolated_transform("box", 10)
	assert(t_half != null, "Interpolated transform at frame 10 must exist")
	assert(t_half.position.x > 50.0, "Ease out position at midpoint must be > 50.0, got: " + str(t_half.position.x))
	
	# Beyond keyframe 20's duration (frame 35, where kf20 duration is 10, i.e. ends at 29):
	# Frame after span ends must be null (blank frame)!
	var t_beyond = layer.get_interpolated_transform("box", 35)
	assert(t_beyond == null, "Frame beyond last keyframe duration must be null (blank)")
	print("  [OK] 5. Classic tween Flash easing & span hold vs blank frames")

static func test_edge_cases_and_serialization_integrity() -> void:
	# 1. SelectionModel clear signal typed Array[String]
	var sm = SelectionModel.new()
	var signal_log: Array = []
	sm.selection_changed.connect(func(_primary, ids):
		signal_log.append(ids)
	)
	sm.select("item_1")
	sm.clear()
	assert(signal_log.size() >= 2, "Signal selection_changed must emit on select and clear")
	assert(signal_log[-1].is_empty(), "Last emitted selection must be empty")
	
	# 2. HitTester zero scale protection
	var item = StageItem.new()
	item.shape_type = "rect"
	item.size = Vector2(100, 100)
	var t_zero = ItemTransform.new()
	t_zero.scale = Vector2.ZERO
	assert(!HitTester.hit_test_item(item, t_zero, Vector2(50, 50)), "Zero scale hit test must safely return false")
	
	# 3. ShapeElement and SymbolInstance full properties round-trip
	var sh = ShapeElement.new()
	sh.corner_radius = Vector4(5, 10, 15, 20)
	sh.oval_start_angle = 0.5
	sh.oval_end_angle = 3.0
	sh.oval_inner_radius_ratio = 0.4
	var sh_dict = sh.to_dict()
	var loaded_sh = Element.from_dict(sh_dict) as ShapeElement
	assert(loaded_sh.corner_radius == Vector4(5, 10, 15, 20), "Shape corner_radius must be preserved")
	assert(absf(loaded_sh.oval_start_angle - 0.5) < 0.001, "Shape oval_start_angle must be preserved")
	assert(absf(loaded_sh.oval_end_angle - 3.0) < 0.001, "Shape oval_end_angle must be preserved")
	assert(absf(loaded_sh.oval_inner_radius_ratio - 0.4) < 0.001, "Shape oval_inner_radius_ratio must be preserved")
	
	var si = SymbolInstance.new()
	si.instance_name = "hero_inst"
	si.brightness = 0.75
	var si_dict = si.to_dict()
	var loaded_si = Element.from_dict(si_dict) as SymbolInstance
	assert(loaded_si.instance_name == "hero_inst", "SymbolInstance instance_name must be preserved")
	assert(absf(loaded_si.brightness - 0.75) < 0.001, "SymbolInstance brightness must be preserved")
	
	# 4. VectorShape stroke_paths and edges round-trip
	var vs = VectorShape.new()
	vs.merge_polygon(PackedVector2Array([Vector2(0, 0), Vector2(50, 0), Vector2(50, 50)]), Color.RED, Color.BLACK, 2.0)
	var edge = VectorShape.Edge.new(Vector2(0, 0), Vector2(10, 20), Vector2(50, 50))
	vs.edges.append(edge)
	var vs_dict = vs.to_dict()
	var loaded_vs = VectorShape.from_dict(vs_dict)
	assert(loaded_vs.stroke_paths.size() == vs.stroke_paths.size(), "VectorShape stroke_paths must be preserved")
	assert(loaded_vs.edges.size() == 1, "VectorShape edges must be preserved")
	assert(loaded_vs.edges[0].c == Vector2(10, 20), "VectorShape edge control point must match")
	print("  [OK] 6. Serialization integrity & edge cases (HitTester, SelectionModel, VectorShape, Elements)")
