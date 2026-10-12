extends SceneTree

func _init() -> void:
	root.size = Vector2i(1280, 720)
	change_scene_to_file("res://src/ui/editor_main.tscn")
	for i in range(15):
		await process_frame
		
	var image = root.get_texture().get_image()
	image.save_png("res://screenshot.png")
	print("SCREENSHOT_SAVED_AT: res://screenshot.png")
	quit()
