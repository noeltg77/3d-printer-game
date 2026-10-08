extends Node
## Dev autoload: saves a screenshot of whatever scene is running, then quits.
## Does nothing unless asked for on the command line (after `--`):
##   --shot=<png path>      where to save
##   --shot-delay=<seconds> how long to let the scene run first (default 0.5)


func _ready() -> void:
	var path := ""
	var delay := 0.5
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			path = arg.trim_prefix("--shot=")
		elif arg.begins_with("--shot-delay="):
			delay = arg.trim_prefix("--shot-delay=").to_float()
	if not path.is_empty():
		_shoot(path, delay)


func _shoot(path: String, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	await RenderingServer.frame_post_draw
	var err := get_viewport().get_texture().get_image().save_png(path)
	print("Saved %s" % path if err == OK else "Screenshot failed: %s" % error_string(err))
	get_tree().quit(0 if err == OK else 1)
