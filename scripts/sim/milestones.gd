class_name Milestones
extends RefCounted
## The sandbox's sense of direction: a list of firsts and totals to reach
## (data/milestones.json). Each is one figure about the business passing a
## mark. Reaching one is remembered, with when.

## Milestone rows by id, in the order they are shown.
var rows: Dictionary
## Id -> game minute it was reached.
var reached: Dictionary[String, float] = {}


func _init(p_rows: Dictionary) -> void:
	rows = p_rows


func is_reached(id: String) -> bool:
	return reached.has(id)


## Marks every milestone the figures now meet. `stats` holds the figures, by
## the name each row's `stat` uses. Returns the rows newly reached.
func check(stats: Dictionary, minute: float) -> Array[Dictionary]:
	var new: Array[Dictionary] = []
	for id: String in rows:
		var row: Dictionary = rows[id]
		if not reached.has(id) and float(stats.get(row["stat"], 0)) >= float(row["at"]):
			reached[id] = minute
			new.append(row)
	return new


## How far along a milestone is, 0 to 1.
func progress(id: String, stats: Dictionary) -> float:
	var row: Dictionary = rows[id]
	return 1.0 if reached.has(id) else clampf(float(stats.get(row["stat"], 0)) / float(row["at"]), 0.0, 1.0)


func save() -> Dictionary:
	return {"reached": reached}


func restore(saved: Dictionary) -> void:
	reached.clear()
	for id: String in saved["reached"]:
		if rows.has(id):
			reached[id] = float(saved["reached"][id])
