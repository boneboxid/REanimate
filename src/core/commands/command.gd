# Base Command class untuk Undo / Redo architecture
class_name Command
extends RefCounted

var name: String = "Command"

func execute() -> void:
	pass

func undo() -> void:
	pass
