class_name Research
extends RefCounted
## What the owner has learned: courses from data/research.json, studied at
## the PC. A course costs a fee, paid once on starting it, and game minutes of
## study, which can be left and picked up again. It needs the course before
## it in its branch, and premises big enough. Once learned it is kept for
## good, and its `effects` scale the rules they name.
##
## An effect is a multiplier by key: "fail_chance", "print_time", "clear_time",
## "wear", "replace_time", "worn_risk", "spool_price", "parts_price",
## "packaging_price" or "lead_time". Everything learned multiplies together.

const EFFECTS: PackedStringArray = ["fail_chance", "print_time", "clear_time", "wear", "replace_time", "worn_risk",
	"spool_price", "parts_price", "packaging_price", "lead_time"]

## Course rows, by id, in the order they are taught.
var courses: Dictionary
var learned: Array[StringName] = []
## Course id -> game minutes studied so far, for those started and not finished.
var progress: Dictionary[StringName, float] = {}
## The course being worked through: the one a sit at the desk carries on with. &"" for none.
var current: StringName = &""


func _init(p_courses: Dictionary) -> void:
	courses = p_courses


func is_learned(id: StringName) -> bool:
	return learned.has(id)


## True once a course has been paid for and begun, and not yet finished.
func is_started(id: StringName) -> bool:
	return progress.has(id)


## Why a course can't be studied, or "" if it can. `tier` is the premises'
## and `cash` what is in the bank, which only matters before the fee is paid.
func problem(id: StringName, tier: int, cash: int) -> String:
	var row: Dictionary = courses[id]
	if is_learned(id):
		return "Already learned"
	if int(row["unlock_tier"]) > tier:
		return "Needs bigger premises"
	var before := String(row.get("requires", ""))
	if before != "" and not is_learned(StringName(before)):
		return "Take %s first" % courses[before]["name"]
	if not is_started(id) and cash < int(row["fee_pence"]):
		return "Not enough cash"
	return ""


## What starting a course costs now: its fee, or nothing if that is paid.
func fee_due(id: StringName) -> int:
	return 0 if is_started(id) or is_learned(id) else int(courses[id]["fee_pence"])


## Begins a course, or goes back to one. Paying the fee is the caller's job.
func start(id: StringName) -> void:
	if not is_learned(id):
		if not progress.has(id):
			progress[id] = 0.0
		current = id


## Game minutes of study a course still needs.
func minutes_left(id: StringName) -> float:
	if is_learned(id):
		return 0.0
	return maxf(float(courses[id]["minutes"]) - float(progress.get(id, 0.0)), 0.0)


## How far through a course is, 0 to 1.
func fraction(id: StringName) -> float:
	return 1.0 if is_learned(id) else clampf(float(progress.get(id, 0.0)) / float(courses[id]["minutes"]), 0.0, 1.0)


## Adds study to a started course. True on the minutes that finish it.
func study(id: StringName, minutes: float) -> bool:
	if not is_started(id):
		return false
	progress[id] += minutes
	if progress[id] < float(courses[id]["minutes"]):
		return false
	progress.erase(id)
	learned.append(id)
	if current == id:
		current = &""
	return true


## What everything learned does to a rule: 1.0 if nothing touches it.
func effect(key: String) -> float:
	var scale := 1.0
	for id in learned:
		scale *= float(courses[id]["effects"].get(key, 1.0))
	return scale


func save() -> Dictionary:
	return {"learned": learned, "progress": progress, "current": current}


## Puts back what was learned. Courses the game no longer has are dropped.
func restore(saved: Dictionary) -> void:
	learned.clear()
	progress.clear()
	for id: String in saved.get("learned", []):
		if courses.has(id):
			learned.append(StringName(id))
	for id: String in saved.get("progress", {}):
		if courses.has(id) and not learned.has(StringName(id)):
			progress[StringName(id)] = float(saved["progress"][id])
	current = StringName(saved.get("current", ""))
	if not progress.has(current):
		current = &""
