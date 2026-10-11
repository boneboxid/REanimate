# Data model untuk elemen di atas stage
class_name StageItem
extends RefCounted

var id: String = ""
var name: String = "Item"
var shape_type: String = "rect" # "rect", "circle", "line", "path", "sprite"
var size: Vector2 = Vector2(100, 100)
var color: Color = Color(0.9, 0.35, 0.35, 1.0)
var stroke_color: Color = Color(0.2, 0.2, 0.2, 1.0)
var stroke_width: float = 2.0
var texture: Texture2D = null
var texture_path: String = ""
var points: PackedVector2Array = PackedVector2Array() # Untuk freehand / pen brush paths

func to_dict() -> Dictionary:
	var pts: Array = []
	for p in points:
		pts.append([p.x, p.y])
	return {
		"id": id,
		"name": name,
		"shape_type": shape_type,
		"size": [size.x, size.y],
		"color": [color.r, color.g, color.b, color.a],
		"stroke_color": [stroke_color.r, stroke_color.g, stroke_color.b, stroke_color.a],
		"stroke_width": stroke_width,
		"texture_path": texture_path,
		"points": pts
	}

static func from_dict(d: Dictionary) -> StageItem:
	var item = StageItem.new()
	item.id = d.get("id", str(Time.get_ticks_usec()))
	item.name = d.get("name", "Item")
	item.shape_type = d.get("shape_type", "rect")
	var sz = d.get("size", [100.0, 100.0])
	item.size = Vector2(sz[0], sz[1])
	var c = d.get("color", [0.9, 0.35, 0.35, 1.0])
	item.color = Color(c[0], c[1], c[2], c[3])
	var sc = d.get("stroke_color", [0.2, 0.2, 0.2, 1.0])
	item.stroke_color = Color(sc[0], sc[1], sc[2], sc[3])
	item.stroke_width = float(d.get("stroke_width", 2.0))
	item.texture_path = d.get("texture_path", "")
	
	if item.texture_path != "" and FileAccess.file_exists(item.texture_path):
		var img = Image.load_from_file(item.texture_path)
		if img != null:
			item.texture = ImageTexture.create_from_image(img)
			
	var pts_data = d.get("points", [])
	var pts = PackedVector2Array()
	for pt in pts_data:
		pts.append(Vector2(pt[0], pt[1]))
	item.points = pts
	return item
