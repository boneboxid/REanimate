# Model untuk mengelola seleksi objek tunggal & jamak (multi-selection)
class_name SelectionModel
extends RefCounted

signal selection_changed(primary_id: String, selected_ids: Array[String])

var selected_ids: Array[String] = []

func get_primary_id() -> String:
	return selected_ids[-1] if not selected_ids.is_empty() else ""

func is_selected(id: String) -> bool:
	return selected_ids.has(id)

func select(id: String, additive: bool = false) -> void:
	if id == "":
		clear()
		return
	if not additive:
		selected_ids.clear()
	if not selected_ids.has(id):
		selected_ids.append(id)
	selection_changed.emit(get_primary_id(), selected_ids)

func toggle(id: String) -> void:
	if selected_ids.has(id):
		selected_ids.erase(id)
	else:
		selected_ids.append(id)
	selection_changed.emit(get_primary_id(), selected_ids)

func select_multiple(ids: Array[String], additive: bool = false) -> void:
	if not additive:
		selected_ids.clear()
	for id in ids:
		if not selected_ids.has(id):
			selected_ids.append(id)
	selection_changed.emit(get_primary_id(), selected_ids)

func deselect(id: String) -> void:
	if selected_ids.has(id):
		selected_ids.erase(id)
		selection_changed.emit(get_primary_id(), selected_ids)

func clear() -> void:
	if not selected_ids.is_empty():
		selected_ids.clear()
		selection_changed.emit("", selected_ids)
