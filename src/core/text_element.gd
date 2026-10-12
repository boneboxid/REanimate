class_name TextElement
extends Element

var text_content: String = "REanimate Text"
var font_size: int = 24
var font_family: String = ""
var alignment: String = "left"
var color: Color = Color(0.1, 0.1, 0.1, 1.0)
var size: Vector2 = Vector2(160, 40)

func _init() -> void:
	super._init()
	element_type = "text"
	
func to_dict() -> Dictionary:
	var d = super.to_dict()
	d["text_content"] = text_content
	d["font_size"] = font_size
	d["font_family"] = font_family
	d["alignment"] = alignment
	d["color"] = [color.r, color.g, color.b, color.a]
	d["size"] = [size.x, size.y]
	return d
