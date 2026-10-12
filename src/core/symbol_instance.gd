# Instance dari SymbolItem yang diletakkan pada stage atau keyframe timeline
class_name SymbolInstance
extends Element

var library_ref: String = "" # Identifier SymbolItem di Library
var symbol_type: String = "graphic" # "graphic", "movie_clip", "button"
var instance_name: String = "" # Nama instance untuk ActionScript/referensi

# Color Effects khas Flash
var color_effect: String = "none" # "none", "brightness", "tint", "alpha", "advanced"
var tint_color: Color = Color.WHITE
var tint_ratio: float = 0.0 # 0.0 - 1.0 (0% - 100%)
var alpha: float = 1.0 # 0.0 - 1.0 (0% - 100%)
var brightness: float = 0.0 # -1.0 - 1.0 (-100% - 100%)

# Looping Options (Graphic / MovieClip)
var loop_mode: String = "loop" # "loop", "play_once", "single_frame"
var first_frame: int = 0

func _init() -> void:
	super._init()
	element_type = "symbol_instance"

# Terapkan Color Effect khas Flash ke suatu warna
func apply_color_effect(base_color: Color) -> Color:
	match color_effect:
		"tint":
			var r = lerpf(base_color.r, tint_color.r, tint_ratio)
			var g = lerpf(base_color.g, tint_color.g, tint_ratio)
			var b = lerpf(base_color.b, tint_color.b, tint_ratio)
			return Color(r, g, b, base_color.a * alpha)
		"alpha":
			return Color(base_color.r, base_color.g, base_color.b, base_color.a * alpha)
		"brightness":
			if brightness > 0.0:
				return base_color.lightened(brightness)
			else:
				return base_color.darkened(-brightness)
		_:
			return base_color

func to_dict() -> Dictionary:
	var d = super.to_dict()
	d["library_ref"] = library_ref
	d["symbol_type"] = symbol_type
	d["instance_name"] = instance_name
	d["color_effect"] = color_effect
	d["tint_color"] = [tint_color.r, tint_color.g, tint_color.b, tint_color.a]
	d["tint_ratio"] = tint_ratio
	d["alpha"] = alpha
	d["brightness"] = brightness
	d["loop_mode"] = loop_mode
	d["first_frame"] = first_frame
	return d

static func from_dict(d: Dictionary) -> Element:
	var inst = SymbolInstance.new()
	inst.id = d.get("id", "el_" + str(Time.get_ticks_usec()))
	inst.name = d.get("name", "Symbol Instance")
	inst.element_type = "symbol_instance"
	inst.library_ref = d.get("library_ref", "")
	inst.symbol_type = d.get("symbol_type", "graphic")
	inst.instance_name = d.get("instance_name", "")
	inst.color_effect = d.get("color_effect", "none")
	var tc = d.get("tint_color", [1.0, 1.0, 1.0, 1.0])
	inst.tint_color = Color(tc[0], tc[1], tc[2], tc[3])
	inst.tint_ratio = float(d.get("tint_ratio", 0.0))
	inst.alpha = float(d.get("alpha", 1.0))
	inst.brightness = float(d.get("brightness", 0.0))
	inst.loop_mode = d.get("loop_mode", "loop")
	inst.first_frame = int(d.get("first_frame", 0))
	var tp = d.get("transformation_point", [0.0, 0.0])
	inst.transformation_point = Vector2(tp[0], tp[1])
	if d.has("transform"):
		inst.transform = ItemTransform.from_dict(d["transform"])
	return inst
