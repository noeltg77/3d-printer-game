class_name PrintJob
extends RefCounted
## One print in progress. Pure logic with no scene dependencies; the printer
## node advances it and reads `progress` to drive the visuals.
##
## A job can carry a failure (a row from data/failures.json). One that scraps
## or stops the print ends the job early, at `stop_at`; one that only degrades
## the result lets it run to the end.

var duration: float
var elapsed := 0.0
## The failure this print hits, or {} if it goes well.
var failure: Dictionary = {}
## Progress (0 to 1) at which the job ends. Below 1 only for a ruined print.
var stop_at := 1.0

var progress: float:
	get:
		return clampf(elapsed / duration, 0.0, stop_at)

## True if the failure leaves nothing worth keeping on the plate.
var ruined: bool:
	get:
		return not failure.is_empty() and failure["outcome"] != "degraded"


func _init(p_duration: float) -> void:
	duration = maxf(p_duration, 0.001)


## Makes this print go wrong with `p_failure` once it reaches progress `at`.
func fail(p_failure: Dictionary, at: float) -> void:
	failure = p_failure
	stop_at = clampf(at, 0.0, 1.0) if ruined else 1.0


func is_finished() -> bool:
	return elapsed >= duration * stop_at


## Moves the job on by `delta` seconds. Returns true on the step it ends,
## whether that is finishing or failing.
func advance(delta: float) -> bool:
	if is_finished():
		return false
	elapsed = minf(elapsed + delta, duration * stop_at)
	return is_finished()


func save() -> Dictionary:
	return {"duration": duration, "elapsed": elapsed, "failure": failure, "stop_at": stop_at}


static func restored(data: Dictionary) -> PrintJob:
	var job := PrintJob.new(float(data["duration"]))
	job.elapsed = float(data["elapsed"])
	job.failure = data["failure"]
	job.stop_at = float(data["stop_at"])
	return job
