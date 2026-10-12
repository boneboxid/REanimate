class_name BitmapInstance
extends Element

var texture_path: String = ""
var size: Vector2 = Vector2(100, 100)

func _init() -> void:
	super._init()
	element_type = "bitmap"
	
func to_dict() -> Dictionary:
	var d = super.to_dict()
	d["texture_path"] = texture_path
	d["size"] = [size.x, size.y]
	return d
