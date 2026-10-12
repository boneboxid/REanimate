# CommandStack / History manager untuk Undo / Redo
class_name CommandStack
extends RefCounted

signal history_changed(can_undo: bool, can_redo: bool)

var undo_stack: Array[Command] = []
var redo_stack: Array[Command] = []
var max_history: int = 100

func execute_command(cmd: Command) -> void:
	if cmd == null: return
	cmd.execute()
	undo_stack.append(cmd)
	if undo_stack.size() > max_history:
		undo_stack.remove_at(0)
	redo_stack.clear()
	history_changed.emit(can_undo(), can_redo())

func undo() -> bool:
	if undo_stack.is_empty():
		return false
	var cmd = undo_stack.pop_back()
	cmd.undo()
	redo_stack.append(cmd)
	history_changed.emit(can_undo(), can_redo())
	return true

func redo() -> bool:
	if redo_stack.is_empty():
		return false
	var cmd = redo_stack.pop_back()
	cmd.execute()
	undo_stack.append(cmd)
	history_changed.emit(can_undo(), can_redo())
	return true

func can_undo() -> bool:
	return not undo_stack.is_empty()

func can_redo() -> bool:
	return not redo_stack.is_empty()

func clear() -> void:
	undo_stack.clear()
	redo_stack.clear()
	history_changed.emit(false, false)
