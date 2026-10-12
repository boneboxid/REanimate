# Shape Tween Engine untuk Flash morphing antar bentuk vektor (persegi -> lingkaran, path morphing, dll)
class_name ShapeTweenEngine
extends RefCounted

const SAMPLE_POINTS_COUNT: int = 48

# Menginterpolasi dua ShapeElement pada faktor 0.0 - 1.0
static func interpolate_shape(shape_a: ShapeElement, shape_b: ShapeElement, factor: float, blend_mode: String = "distributive") -> ShapeElement:
	var result = ShapeElement.new()
	result.id = "morph_" + shape_a.id + "_" + shape_b.id
	result.name = "Shape Tween"
	result.shape_type = "path" # Hasil morphing selalu berupa kurva/poligon kontinu
	
	# Interpolasi Warna & Stroke
	result.color = shape_a.color.lerp(shape_b.color, factor)
	result.stroke_color = shape_a.stroke_color.lerp(shape_b.stroke_color, factor)
	result.stroke_width = lerpf(shape_a.stroke_width, shape_b.stroke_width, factor)
	
	# Ekstraksi poligon titik sampel dari shape A dan shape B
	var poly_a = _sample_shape_polygon(shape_a, SAMPLE_POINTS_COUNT)
	var poly_b = _sample_shape_polygon(shape_b, SAMPLE_POINTS_COUNT)
	
	if blend_mode == "angular":
		# Angular: match vertices by angle from centroid
		poly_b = _align_points_angular(poly_a, poly_b)
		
	# Interpolasi posisi tiap titik (morphing)
	var morphed_pts = PackedVector2Array()
	var n = mini(poly_a.size(), poly_b.size())
	for i in range(n):
		morphed_pts.append(poly_a[i].lerp(poly_b[i], factor))
		
	result.points = morphed_pts
	
	# Hitung bounding box size untuk hasil morphing
	if not morphed_pts.is_empty():
		var min_v = morphed_pts[0]
		var max_v = morphed_pts[0]
		for p in morphed_pts:
			min_v.x = minf(min_v.x, p.x)
			min_v.y = minf(min_v.y, p.y)
			max_v.x = maxf(max_v.x, p.x)
			max_v.y = maxf(max_v.y, p.y)
		result.size = max_v - min_v
		
	# Interpolasi Transform
	if shape_a.transform != null and shape_b.transform != null:
		result.transform = ItemTransform.interpolate(shape_a.transform, shape_b.transform, factor)
	elif shape_a.transform != null:
		result.transform = shape_a.transform.duplicate_transform()
		
	return result

# Mengambil titik-titik sampel perimeter dari shape apa pun
static func _sample_shape_polygon(shape: ShapeElement, count: int) -> PackedVector2Array:
	var pts = PackedVector2Array()
	var half_sz = shape.size * 0.5
	
	match shape.shape_type:
		"rect":
			# Sample 4 sisi persegi secara merata
			var perimeter = (shape.size.x + shape.size.y) * 2.0
			var corners = [
				-half_sz, # Top-Left
				Vector2(half_sz.x, -half_sz.y), # Top-Right
				half_sz, # Bottom-Right
				Vector2(-half_sz.x, half_sz.y) # Bottom-Left
			]
			for i in range(count):
				var t = float(i) / float(count) * 4.0
				var seg = int(t) % 4
				var seg_t = t - float(int(t))
				var p0 = corners[seg]
				var p1 = corners[(seg + 1) % 4]
				pts.append(p0.lerp(p1, seg_t))
				
		"circle":
			# Sample elips secara radial
			for i in range(count):
				var angle = float(i) / float(count) * TAU
				pts.append(Vector2(cos(angle) * half_sz.x, sin(angle) * half_sz.y))
				
		"polystar":
			var sides = maxi(3, shape.polystar_sides)
			var star_pts = PackedVector2Array()
			var radius = minf(half_sz.x, half_sz.y)
			var inner_r = radius * shape.star_inner_radius_ratio if shape.is_star else radius
			var total_vertices = sides * 2 if shape.is_star else sides
			for i in range(total_vertices):
				var angle = (float(i) / float(total_vertices)) * TAU - (PI * 0.5)
				var r = radius if (i % 2 == 0 or not shape.is_star) else inner_r
				star_pts.append(Vector2(cos(angle) * r, sin(angle) * r))
			pts = _resample_polygon(star_pts, count)
			
		"path", "line":
			if shape.points.size() >= 2:
				pts = _resample_polygon(shape.points, count)
			else:
				for i in range(count):
					pts.append(Vector2.ZERO)
					
		_:
			for i in range(count):
				pts.append(Vector2.ZERO)
				
	return pts

# Resample poligon terbuka/tertutup menjadi N titik dengan jarak seragam
static func _resample_polygon(in_pts: PackedVector2Array, count: int) -> PackedVector2Array:
	if in_pts.size() < 2:
		var r = PackedVector2Array()
		for i in range(count): r.append(in_pts[0] if in_pts.size() == 1 else Vector2.ZERO)
		return r
		
	# Hitung total panjang perimeter
	var lengths: Array[float] = [0.0]
	var total_len = 0.0
	for i in range(in_pts.size() - 1):
		var d = in_pts[i].distance_to(in_pts[i + 1])
		total_len += d
		lengths.append(total_len)
		
	if total_len <= 0.001:
		var r = PackedVector2Array()
		for i in range(count): r.append(in_pts[0])
		return r
		
	var out_pts = PackedVector2Array()
	var step = total_len / float(count)
	var cur_seg = 0
	
	for i in range(count):
		var target_d = float(i) * step
		while cur_seg < in_pts.size() - 2 and lengths[cur_seg + 1] < target_d:
			cur_seg += 1
		var seg_start_d = lengths[cur_seg]
		var seg_len = in_pts[cur_seg].distance_to(in_pts[cur_seg + 1])
		var t = (target_d - seg_start_d) / seg_len if seg_len > 0.0001 else 0.0
		out_pts.append(in_pts[cur_seg].lerp(in_pts[cur_seg + 1], clampf(t, 0.0, 1.0)))
		
	return out_pts

# Rotasi urutan titik poly_b agar sejajar arah sudut dengan poly_a (mode Angular)
static func _align_points_angular(poly_a: PackedVector2Array, poly_b: PackedVector2Array) -> PackedVector2Array:
	if poly_a.is_empty() or poly_b.is_empty():
		return poly_b
	var best_offset = 0
	var min_sq_dist = INF
	var n = mini(poly_a.size(), poly_b.size())
	
	for shift in range(0, n, 4):
		var sq_dist = 0.0
		for i in range(n):
			var b_idx = (i + shift) % n
			sq_dist += poly_a[i].distance_squared_to(poly_b[b_idx])
		if sq_dist < min_sq_dist:
			min_sq_dist = sq_dist
			best_offset = shift
			
	var aligned = PackedVector2Array()
	for i in range(n):
		aligned.append(poly_b[(i + best_offset) % n])
	return aligned
