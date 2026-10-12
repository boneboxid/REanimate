class_name GroupElement
extends Element

var elements: Array[Element] = []

func _init() -> void:
	super._init()
	element_type = "group"
	
func to_dict() -> Dictionary:
	var d = super.to_dict()
	var child_arr: Array = []
	for el in elements:
		child_arr.append(el.to_dict())
	d["elements"] = child_arr
	return d
