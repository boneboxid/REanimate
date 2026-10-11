extends SceneTree

func _init() -> void:
	root.size = Vector2i(1280, 720)
	change_scene_to_file("res://src/ui/editor_main.tscn")
	for i in range(12):
		await process_frame
		
	var image = root.get_texture().get_image()
	var screenshot_path = "user://screenshot.png"
	image.save_png(screenshot_path)
	print("SCREENSHOT_SAVED_AT: " + OS.get_user_data_dir() + "/screenshot.png")
	quit()
