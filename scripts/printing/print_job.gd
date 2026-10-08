class_name PrintJob
extends RefCounted
## One print in progress. Pure logic with no scene dependencies; the printer
## node advances it and reads `progress` to drive the visuals.

var duration: float
var elapsed := 0.0

var progress: float:
	get:
		return clampf(elapsed / duration, 0.0, 1.0)


func _init(p_duration: float) -> void:
	duration = maxf(p_duration, 0.001)


func is_finished() -> bool:
	return elapsed >= duration


## Moves the job on by `delta` seconds. Returns true on the step it finishes.
func advance(delta: float) -> bool:
	if is_finished():
		return false
	elapsed += delta
	return is_finished()
