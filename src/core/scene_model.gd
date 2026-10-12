# Model untuk Scene (Document berisi Array of SceneModel)
class_name SceneModel
extends RefCounted

var name: String = "Scene 1"
var timeline: TimelineModel

func _init(p_name: String = "Scene 1") -> void:
	name = p_name
	timeline = TimelineModel.new()

func to_dict() -> Dictionary:
	return {
		"name": name,
		"timeline": timeline.to_dict() if timeline != null else {}
	}

static func from_dict(d: Dictionary) -> SceneModel:
	var sc = SceneModel.new(d.get("name", "Scene 1"))
	if d.has("timeline"):
		sc.timeline = TimelineModel.from_dict(d["timeline"])
	return sc
