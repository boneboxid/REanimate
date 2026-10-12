class_name TestVectorEngine
extends RefCounted

static func run_all_tests() -> void:
	print(">>> RUNNING PHASE 3 FLASH VECTOR ENGINE TESTS <<<")
	test_flash_merge_drawing_and_cut_acceptance()
	test_paint_bucket_flood_fill()
	test_fill_vs_stroke_hit_test()
	test_object_drawing_mode()
	print(">>> ALL PHASE 3 FLASH VECTOR ENGINE TESTS PASSED! <<<")

static func test_flash_merge_drawing_and_cut_acceptance() -> void:
	# PHASE 3 ACCEPTANCE:
	# Gambar 2 rect tumpang tindih -> hapus (Delete/Cut) potongan tengah -> region terpisah seperti Flash
	var vs = VectorShape.new()
	
	# Rect 1: [0, 0] ke [100, 100] (RED)
	var rect1_poly = PackedVector2Array([
		Vector2(0, 0), Vector2(100, 0), Vector2(100, 100), Vector2(0, 100)
	])
	vs.merge_polygon(rect1_poly, Color.RED)
	assert(vs.fill_regions.size() == 1, "Must have 1 region initially")
	
	# Rect 2 overlapping: [50, 0] ke [150, 100] (BLUE)
	var rect2_poly = PackedVector2Array([
		Vector2(50, 0), Vector2(150, 0), Vector2(150, 100), Vector2(50, 100)
	])
	vs.merge_polygon(rect2_poly, Color.BLUE)
	
	# In Flash Merge Drawing:
	# Rect 1 is clipped to [0..50], Rect 2 takes [50..150]
	assert(vs.fill_regions.size() == 2, "Must have 2 regions after overlap with different colors")
	
	# Hapus (Delete/Cut) potongan tengah di [40..110]
	var cut_poly = PackedVector2Array([
		Vector2(40, -10), Vector2(110, -10), Vector2(110, 110), Vector2(40, 110)
	])
	vs.cut_polygon(cut_poly)
	
	# Setelah dipotong di tengah:
	# Ada region kiri [0..40] dan region kanan [110..150]
	assert(vs.fill_regions.size() == 2, "Must have 2 disjoint regions remaining")
	
	# Titik di tengah (75, 50) yang dipotong harus KOSONG (tidak kena region mana pun)
	var hit_mid = vs.hit_test_subparts(Vector2(75, 50))
	assert(hit_mid["part"] == "none", "Deleted middle section must be empty")
	
	# Titik kiri (20, 50) harus mengenai region RED
	var hit_left = vs.hit_test_subparts(Vector2(20, 50))
	assert(hit_left["part"] == "fill", "Left piece must be a fill region")
	assert(vs.fill_styles[hit_left["index"]].color == Color.RED, "Left piece must be RED")
	
	# Titik kanan (130, 50) harus mengenai region BLUE
	var hit_right = vs.hit_test_subparts(Vector2(130, 50))
	assert(hit_right["part"] == "fill", "Right piece must be a fill region")
	assert(vs.fill_styles[hit_right["index"]].color == Color.BLUE, "Right piece must be BLUE")
	print("  [OK] 1. Flash Merge Drawing & Cut Region Acceptance Verified")

static func test_paint_bucket_flood_fill() -> void:
	var vs = VectorShape.new()
	var poly = PackedVector2Array([
		Vector2(0, 0), Vector2(100, 0), Vector2(100, 100), Vector2(0, 100)
	])
	vs.merge_polygon(poly, Color.RED)
	
	# Paint Bucket di (50, 50) dengan warna KUNING
	var success = vs.paint_bucket_at(Vector2(50, 50), Color.YELLOW)
	assert(success, "Paint bucket must succeed inside region")
	
	var hit = vs.hit_test_subparts(Vector2(50, 50))
	assert(vs.fill_styles[hit["index"]].color == Color.YELLOW, "Color must be changed to YELLOW by paint bucket")
	print("  [OK] 2. Paint Bucket region recoloring")

static func test_fill_vs_stroke_hit_test() -> void:
	var vs = VectorShape.new()
	var poly = PackedVector2Array([
		Vector2(0, 0), Vector2(100, 0), Vector2(100, 100), Vector2(0, 100)
	])
	vs.merge_polygon(poly, Color.RED, Color.BLACK, 4.0)
	
	# Point on stroke edge (0, 50)
	var hit_stroke = vs.hit_test_subparts(Vector2(0, 50))
	assert(hit_stroke["part"] == "stroke", "Clicking near border must hit stroke")
	
	# Point deep inside fill (50, 50)
	var hit_fill = vs.hit_test_subparts(Vector2(50, 50))
	assert(hit_fill["part"] == "fill", "Clicking inside must hit fill")
	print("  [OK] 3. Sub-part Hit Testing (Fill vs Stroke separation)")

static func test_object_drawing_mode() -> void:
	# Object Drawing Mode ('J'): shapes do not merge or clip each other
	var vs = VectorShape.new()
	vs.is_drawing_object = true
	
	var poly1 = PackedVector2Array([Vector2(0, 0), Vector2(100, 0), Vector2(100, 100), Vector2(0, 100)])
	var poly2 = PackedVector2Array([Vector2(50, 0), Vector2(150, 0), Vector2(150, 100), Vector2(50, 100)])
	
	vs.merge_polygon(poly1, Color.RED)
	vs.merge_polygon(poly2, Color.BLUE)
	
	# Kedua poligon utuh tanpa terpotong
	assert(vs.fill_regions.size() == 2, "Object Drawing preserves isolated shapes")
	print("  [OK] 4. Object Drawing Mode ('J') isolated shapes")
