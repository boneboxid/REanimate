# Menyimpan data transformasi objek pada keyframe tertentu (Matrix2D affine + decompose)
class_name ItemTransform
extends RefCounted

var position: Vector2 = Vector2.ZERO
var rotation: float = 0.0 # Dalam radian
var scale: Vector2 = Vector2.ONE
var skew: Vector2 = Vector2.ZERO # Skew X dan Y dalam radian
var transform_point: Vector2 = Vector2.ZERO # Transformation point / pivot
var opacity: float = 1.0
var has_affine: bool = false
var affine_matrix: Transform2D = Transform2D.IDENTITY

func duplicate_transform() -> ItemTransform:
	var t = ItemTransform.new()
	t.position = position
	t.rotation = rotation
	t.scale = scale
	t.skew = skew
	t.transform_point = transform_point
	t.opacity = opacity
	t.has_affine = has_affine
	t.affine_matrix = affine_matrix
	return t

func to_transform_2d() -> Transform2D:
	if has_affine:
		return affine_matrix
	var cr = cos(rotation)
	var sr = sin(rotation)
	var rot_mat = Transform2D(Vector2(cr, sr), Vector2(-sr, cr), Vector2.ZERO)
	var skew_mat = Transform2D(Vector2(1.0, tan(skew.y)), Vector2(tan(skew.x), 1.0), Vector2.ZERO)
	var scale_mat = Transform2D(Vector2(scale.x, 0.0), Vector2(0.0, scale.y), Vector2.ZERO)
	var trans_mat = Transform2D(Vector2(1.0, 0.0), Vector2(0.0, 1.0), position)
	return trans_mat * rot_mat * skew_mat * scale_mat

func get_matrix_components() -> Dictionary:
	var mat = to_transform_2d()
	return {
		"a": mat.x.x,
		"b": mat.x.y,
		"c": mat.y.x,
		"d": mat.y.y,
		"tx": mat.origin.x,
		"ty": mat.origin.y
	}

static func from_matrix(a: float, b: float, c: float, d: float, tx: float, ty: float) -> ItemTransform:
	var t = ItemTransform.new()
	t.has_affine = true
	t.affine_matrix = Transform2D(Vector2(a, b), Vector2(c, d), Vector2(tx, ty))
	t.position = Vector2(tx, ty)
	t.scale = Vector2(sqrt(a * a + b * b), sqrt(c * c + d * d))
	t.rotation = atan2(b, a)
	var shear = (a * c + b * d) / maxf(0.0001, (a * a + b * b))
	t.skew = Vector2(atan(shear), 0.0)
	return t

static func interpolate(a: ItemTransform, b: ItemTransform, t: float) -> ItemTransform:
	var res = ItemTransform.new()
	res.position = a.position.lerp(b.position, t)
	res.rotation = lerp_angle(a.rotation, b.rotation, t)
	res.scale = a.scale.lerp(b.scale, t)
	res.skew = a.skew.lerp(b.skew, t)
	res.transform_point = a.transform_point.lerp(b.transform_point, t)
	res.opacity = lerp(a.opacity, b.opacity, t)
	return res

func to_dict() -> Dictionary:
	var d = {
		"position": [position.x, position.y],
		"rotation": rotation,
		"scale": [scale.x, scale.y],
		"skew": [skew.x, skew.y],
		"transform_point": [transform_point.x, transform_point.y],
		"opacity": opacity,
		"has_affine": has_affine
	}
	if has_affine:
		d["affine"] = [affine_matrix.x.x, affine_matrix.x.y, affine_matrix.y.x, affine_matrix.y.y, affine_matrix.origin.x, affine_matrix.origin.y]
	return d

static func from_dict(d: Dictionary) -> ItemTransform:
	var t = ItemTransform.new()
	var pos = d.get("position", [0.0, 0.0])
	t.position = Vector2(pos[0], pos[1])
	t.rotation = float(d.get("rotation", 0.0))
	var sc = d.get("scale", [1.0, 1.0])
	t.scale = Vector2(sc[0], sc[1])
	var sk = d.get("skew", [0.0, 0.0])
	t.skew = Vector2(sk[0], sk[1])
	var tp = d.get("transform_point", [0.0, 0.0])
	t.transform_point = Vector2(tp[0], tp[1])
	t.opacity = float(d.get("opacity", 1.0))
	t.has_affine = bool(d.get("has_affine", false))
	if t.has_affine and d.has("affine"):
		var aff = d["affine"]
		t.affine_matrix = Transform2D(Vector2(aff[0], aff[1]), Vector2(aff[2], aff[3]), Vector2(aff[4], aff[5]))
	return t
