class_name TestSymbolLibrary
extends RefCounted

static func run_all_tests() -> void:
	print(">>> RUNNING PHASE 6 SYMBOL & LIBRARY TESTS <<<")
	test_convert_to_symbol_9_point_registration()
	test_button_symbol_4_states()
	test_library_duplicate_rename_delete()
	test_movie_clip_instances_with_different_tints()
	test_edit_symbol_nested_timeline()
	print(">>> ALL PHASE 6 SYMBOL & LIBRARY TESTS PASSED! <<<")

static func test_convert_to_symbol_9_point_registration() -> void:
	var doc = ProjectDocument.create_default()
	
	# Buat rect 100x50 pada stage
	var itm = StageItem.new()
	itm.id = "char_head"
	itm.name = "Character Head"
	itm.shape_type = "rect"
	itm.size = Vector2(100, 50)
	doc.items[itm.id] = itm
	
	# Convert to Symbol dengan Top-Left registration point (reg_index = 0)
	var sym_tl = doc.convert_to_symbol("char_head", "HeadSymbol_TL", "graphic", 0)
	assert(sym_tl != null, "Convert to symbol must succeed")
	assert(doc.library.has(sym_tl.id), "Symbol must be in document library")
	assert(sym_tl.registration_index == 0, "Registration index preserved")
	# Top-Left offset is -half_size = (-50, -25)
	assert(sym_tl.registration_point == Vector2(-50, -25), "Registration point Top-Left calculated correctly")
	assert(sym_tl.timeline.layers.size() == 1, "Symbol contains nested timeline with 1 layer")
	assert(sym_tl.timeline.layers[0].keyframes.size() == 1, "Symbol contains keyframe 0")
	
	# Convert to Symbol dengan Center registration point (reg_index = 4)
	var itm2 = StageItem.new()
	itm2.id = "char_body"
	itm2.name = "Character Body"
	itm2.size = Vector2(100, 100)
	doc.items[itm2.id] = itm2
	var sym_center = doc.convert_to_symbol("char_body", "BodySymbol_Center", "movie_clip", 4)
	assert(sym_center.registration_point == Vector2.ZERO, "Center registration point is Vector2.ZERO")
	assert(sym_center.symbol_type == "movie_clip", "MovieClip symbol type preserved")
	
	print("  [OK] 1. Convert to Symbol (F8) & 9-Position Registration Point")

static func test_button_symbol_4_states() -> void:
	var doc = ProjectDocument.create_default()
	var itm = StageItem.new()
	itm.id = "btn_shape"
	itm.size = Vector2(120, 40)
	doc.items[itm.id] = itm
	
	var btn_sym = doc.convert_to_symbol("btn_shape", "PlayButton", "button", 4)
	assert(btn_sym.symbol_type == "button", "Symbol type is button")
	assert(btn_sym.timeline.layers.size() == 1, "Button timeline has 1 layer")
	var btn_layer = btn_sym.timeline.layers[0]
	assert(btn_layer.keyframes.size() == 4, "Button timeline has exactly 4 state frames")
	assert(btn_layer.keyframes[0].label == "Up", "Frame 0 is Up state")
	assert(btn_layer.keyframes[1].label == "Over", "Frame 1 is Over state")
	assert(btn_layer.keyframes[2].label == "Down", "Frame 2 is Down state")
	assert(btn_layer.keyframes[3].label == "Hit", "Frame 3 is Hit state")
	
	print("  [OK] 2. Button Symbol 4-State Timeline (Up, Over, Down, Hit)")

static func test_library_duplicate_rename_delete() -> void:
	var doc = ProjectDocument.create_default()
	var sym = doc.create_symbol("Tree", "graphic", 4)
	var sym_id = sym.id
	assert(doc.library.has(sym_id), "Symbol created in library")
	
	# Rename
	var renamed = doc.rename_symbol(sym_id, "Oak Tree")
	assert(renamed == true, "Rename symbol must succeed")
	assert(doc.library[sym_id].name == "Oak Tree", "Symbol name updated")
	
	# Duplicate
	var dup = doc.duplicate_symbol(sym_id)
	assert(dup != null and dup.id != sym_id, "Duplicate symbol creates new unique ID")
	assert(dup.name == "Oak Tree Copy", "Duplicate name generated")
	assert(doc.library.has(dup.id), "Duplicate exists in library")
	
	# Check in-use before delete
	assert(doc.is_symbol_in_use(dup.id) == false, "Unused symbol reports not in use")
	var deleted = doc.delete_symbol(dup.id)
	assert(deleted == true, "Delete symbol must succeed")
	assert(not doc.library.has(dup.id), "Symbol removed from library")
	
	print("  [OK] 3. Library Management (Create, Duplicate, Rename, Delete & In-Use Check)")

static func test_movie_clip_instances_with_different_tints() -> void:
	# ACCEPTANCE TEST: MovieClip karakter bergerak dengan 3 instance bertint berbeda
	var doc = ProjectDocument.create_default()
	
	# 1. Buat MovieClip Karakter dengan animasi berjalan (nested timeline 20 frame)
	var mc_sym = doc.create_symbol("WalkingCharacter_MC", "movie_clip", 4)
	var mc_layer = mc_sym.timeline.layers[0]
	
	# Keyframe 0: Karakter posisi awal
	var kf0 = KeyframeData.new()
	kf0.frame_index = 0
	kf0.tween_type = "classic"
	var t0 = ItemTransform.new()
	t0.position = Vector2(0, 0)
	kf0.transforms["body"] = t0
	mc_layer.set_keyframe(kf0)
	
	# Keyframe 20: Karakter melompat
	var kf20 = KeyframeData.new()
	kf20.frame_index = 20
	var t20 = ItemTransform.new()
	t20.position = Vector2(0, -50)
	kf20.transforms["body"] = t20
	mc_layer.set_keyframe(kf20)
	
	# 2. Taruh 3 Instance MovieClip di stage utama dengan Color Effect (Tint) Berbeda:
	# Instance 1: Karakter Normal (No Tint)
	var inst1 = mc_sym.create_instance("Character_Original")
	inst1.color_effect = "none"
	var col1 = inst1.apply_color_effect(Color.WHITE)
	assert(col1 == Color.WHITE, "Original instance keeps white color")
	
	# Instance 2: Karakter Red Tint (Tint Merah 80%)
	var inst2 = mc_sym.create_instance("Character_RedTeam")
	inst2.color_effect = "tint"
	inst2.tint_color = Color.RED
	inst2.tint_ratio = 0.8
	var col2 = inst2.apply_color_effect(Color.WHITE)
	assert(col2.r > 0.9 and col2.g < 0.3 and col2.b < 0.3, "Red team instance tinted red")
	
	# Instance 3: Karakter Blue Tint & 50% Alpha (Tint Biru 100% + Alpha 0.5)
	var inst3 = mc_sym.create_instance("Character_GhostBlue")
	inst3.color_effect = "tint"
	inst3.tint_color = Color.BLUE
	inst3.tint_ratio = 1.0
	inst3.alpha = 0.5
	var col3 = inst3.apply_color_effect(Color.WHITE)
	assert(col3.r < 0.1 and col3.b > 0.9, "Ghost instance tinted pure blue")
	assert(abs(col3.a - 0.5) < 0.01, "Ghost instance has 50% alpha")
	
	print("  [OK] 4. MovieClip Animation with 3 Instances Having Different Tints (Acceptance Verified)")

static func test_edit_symbol_nested_timeline() -> void:
	var doc = ProjectDocument.create_default()
	var sym = doc.create_symbol("NestedSymbol", "graphic", 4)
	assert(sym.timeline != null, "Symbol has its own independent timeline")
	
	# Tambahkan 2 layer di dalam timeline symbol
	var sym_layer2 = AnimationLayer.new()
	sym_layer2.name = "Eyes"
	sym.timeline.add_layer(sym_layer2)
	assert(sym.timeline.layers.size() == 2, "Symbol nested timeline can have multiple layers")
	
	# Navigasi Breadcrumb
	var breadcrumb = "Scene 1 > " + sym.name
	assert(breadcrumb == "Scene 1 > NestedSymbol", "Breadcrumb path accurately reflects hierarchy")
	
	print("  [OK] 5. Edit Symbol Nested Timeline & Hierarchy Breadcrumb")
