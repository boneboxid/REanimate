# Centralized HitTester untuk StageItem dan Elements
class_name HitTester
extends RefCounted

static func hit_test_item(item: StageItem, t: ItemTransform, mouse_pos: Vector2) -> bool:
	if item == null or t == null: return false
	var local_to_item = (mouse_pos - t.position).rotated(-t.rotation) / t.scale
	var half_size = item.size * 0.5
	
	match item.shape_type:
		"rect", "sprite", "symbol", "text":
			return Rect2(-half_size, item.size).has_point(local_to_item)
		"circle":
			var rx = maxf(1.0, half_size.x)
			var ry = maxf(1.0, half_size.y)
			var nx = local_to_item.x / rx
			var ny = local_to_item.y / ry
			var dist_sq = nx * nx + ny * ny
			if dist_sq > 1.0: return false
			if item.oval_inner_radius_ratio > 0.01:
				var in_r = item.oval_inner_radius_ratio
				if dist_sq < (in_r * in_r): return false
			if abs((item.oval_end_angle - item.oval_start_angle) - TAU) > 0.01:
				var a = atan2(local_to_item.y, local_to_item.x)
				while a < 0.0: a += TAU
				var s = item.oval_start_angle
				var e = item.oval_end_angle
				while s < 0.0: s += TAU
				while e < 0.0: e += TAU
				if s < e:
					if a < s or a > e: return false
				else:
					if a < s and a > e: return false
			return true
		"polystar":
			return local_to_item.length() <= half_size.x
		"path", "line":
			var thresh = maxf(8.0, item.stroke_width * 0.5 + 4.0)
			for pt in item.points:
				if pt.distance_to(local_to_item) <= thresh:
					return true
			if item.points.size() >= 2:
				for i in range(item.points.size() - 1):
					var p0 = item.points[i]
					var p1 = item.points[i + 1]
					var seg = p1 - p0
					var len_sq = seg.length_squared()
					if len_sq > 0.0001:
						var u = clampf((local_to_item - p0).dot(seg) / len_sq, 0.0, 1.0)
						var proj = p0 + u * seg
						if local_to_item.distance_to(proj) <= thresh:
							return true
			if not item.sub_paths.is_empty():
				for sp in item.sub_paths:
					var s_pts = sp.get("points", PackedVector2Array())
					for i in range(s_pts.size() - 1):
						var p0 = s_pts[i]
						var p1 = s_pts[i + 1]
						var seg = p1 - p0
						var len_sq = seg.length_squared()
						if len_sq > 0.0001:
							var u = clampf((local_to_item - p0).dot(seg) / len_sq, 0.0, 1.0)
							var proj = p0 + u * seg
							if local_to_item.distance_to(proj) <= thresh:
								return true
	return false
