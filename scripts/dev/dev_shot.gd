extends Node
## Dev autoload: saves screenshots of whatever scene is running, then quits.
## Does nothing unless asked for on the command line (after `--`):
##   --shot=<png path>         where to save
##   --shot-delay=<seconds>    how long to let the scene run first (default 0.5)
##   --shot-times=<a,b,c>      several shots at these times instead, saved as
##                             <name>_1.png, <name>_2.png, ... Quits after the last.
## Times are in game seconds, so they follow --time-scale (see dev_autoplay.gd).


func _ready() -> void:
	var path := ""
	var times: PackedFloat64Array = [0.5]
	var numbered := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			path = arg.trim_prefix("--shot=")
		elif arg.begins_with("--shot-delay="):
			times = [arg.trim_prefix("--shot-delay=").to_float()]
		elif arg.begins_with("--shot-times="):
			times = arg.trim_prefix("--shot-times=").split_floats(",")
			numbered = true
	if not path.is_empty():
		_shoot(path, times, numbered)


func _shoot(path: String, times: PackedFloat64Array, numbered: bool) -> void:
	var elapsed := 0.0
	for index in times.size():
		await get_tree().create_timer(maxf(times[index] - elapsed, 0.0)).timeout
		elapsed = times[index]
		await RenderingServer.frame_post_draw
		var target := "%s_%d.png" % [path.get_basename(), index + 1] if numbered else path
		var err := get_viewport().get_texture().get_image().save_png(target)
		print("Saved %s" % target if err == OK else "Screenshot failed: %s" % error_string(err))
	get_tree().quit()
