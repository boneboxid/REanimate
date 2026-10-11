# Menyimpan data transformasi objek pada keyframe tertentu
class_name ItemTransform
extends RefCounted

var position: Vector2 = Vector2.ZERO
var rotation: float = 0.0 # Dalam radian
var scale: Vector2 = Vector2.ONE
var opacity: float = 1.0

func duplicate_transform() -> ItemTransform:
	var t = ItemTransform.new()
	t.position = position
	t.rotation = rotation
	t.scale = scale
	t.opacity = opacity
	return t

static func interpolate(a: ItemTransform, b: ItemTransform, t: float) -> ItemTransform:
	var res = ItemTransform.new()
	res.position = a.position.lerp(b.position, t)
	res.rotation = lerp_angle(a.rotation, b.rotation, t)
	res.scale = a.scale.lerp(b.scale, t)
	res.opacity = lerp(a.opacity, b.opacity, t)
	return res

func to_dict() -> Dictionary:
	return {
		"position": [position.x, position.y],
		"rotation": rotation,
		"scale": [scale.x, scale.y],
		"opacity": opacity
	}

static func from_dict(d: Dictionary) -> ItemTransform:
	var t = ItemTransform.new()
	var pos = d.get("position", [0.0, 0.0])
	t.position = Vector2(pos[0], pos[1])
	t.rotation = float(d.get("rotation", 0.0))
	var sc = d.get("scale", [1.0, 1.0])
	t.scale = Vector2(sc[0], sc[1])
	t.opacity = float(d.get("opacity", 1.0))
	return t
