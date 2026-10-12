# Model untuk Library Symbol Item yang memiliki TimelineModel tersendiri (Flash Graphic, MovieClip, Button)
class_name SymbolItem
extends RefCounted

var id: String = ""
var name: String = "Symbol"
var symbol_type: String = "graphic" # "graphic", "movie_clip", "button"
var timeline: TimelineModel
var registration_point: Vector2 = Vector2.ZERO
var registration_index: int = 4 # 0..8 (0: TL, 1: TC, 2: TR, 3: ML, 4: Center, 5: MR, 6: BL, 7: BC, 8: BR)

func _init() -> void:
	id = "symbol_" + str(Time.get_ticks_usec())
	timeline = TimelineModel.new()

# Konfigurasi standar untuk Button Symbol (4 frame tetap khas Flash: Up, Over, Down, Hit)
func setup_as_button() -> void:
	symbol_type = "button"
	timeline.layers.clear()
	var btn_layer = AnimationLayer.new()
	btn_layer.name = "Layer 1"
	
	var labels = ["Up", "Over", "Down", "Hit"]
	for i in range(4):
		var kf = KeyframeData.new()
		kf.frame_index = i
		kf.label = labels[i]
		btn_layer.set_keyframe(kf)
		
	timeline.add_layer(btn_layer)
	timeline.max_frames = 4

# Buat instance baru yang me-referensikan Symbol ini di stage
func create_instance(p_name: String = "") -> SymbolInstance:
	var inst = SymbolInstance.new()
	inst.library_ref = id
	inst.name = p_name if p_name != "" else name + " Instance"
	inst.symbol_type = symbol_type
	inst.transformation_point = registration_point
	return inst

func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"symbol_type": symbol_type,
		"registration_index": registration_index,
		"registration_point": [registration_point.x, registration_point.y],
		"timeline": timeline.to_dict() if timeline != null else {}
	}

static func from_dict(d: Dictionary) -> SymbolItem:
	var sym = SymbolItem.new()
	sym.id = d.get("id", "symbol_" + str(Time.get_ticks_usec()))
	sym.name = d.get("name", "Symbol")
	sym.symbol_type = d.get("symbol_type", "graphic")
	sym.registration_index = int(d.get("registration_index", 4))
	var rp = d.get("registration_point", [0.0, 0.0])
	sym.registration_point = Vector2(rp[0], rp[1])
	if d.has("timeline"):
		sym.timeline = TimelineModel.from_dict(d["timeline"])
	return sym
