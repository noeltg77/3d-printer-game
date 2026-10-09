class_name Staff
extends RefCounted
## The people the business employs: who is on the team, what each does and
## when, what they cost, and who has applied for a job.
##
## A role (data/staff.json) is a wage and a list of duties: the kinds of task
## its holder looks for on the floor. A member of staff works one shift a day
## and is paid for every day on the books. Applicants change each day.

## Role and shift tables by id, and the rest of data/staff.json.
var roles: Dictionary
var shifts: Dictionary
var config: Dictionary
## Each: { id, name, role, shift, look, hired_at }. `look` is a character model.
var team: Array[Dictionary] = []
## People who could be taken on today. Each: { name, role, look }.
var applicants: Array[Dictionary] = []

var _next_id := 1


func _init(data: GameData) -> void:
	roles = data.roles
	shifts = data.shifts
	config = data.staff_config


## Draws a new set of applicants for the roles open at `tier`.
func refresh_applicants(rng: RandomNumberGenerator, tier: int) -> void:
	applicants.clear()
	var open: Array[String] = []
	for role_id: String in roles:
		if int(roles[role_id]["unlock_tier"]) <= tier:
			open.append(role_id)
	var free_names: Array = config["names"].filter(func(candidate: String) -> bool:
		return not team.any(func(member: Dictionary) -> bool: return member["name"] == candidate))
	if open.is_empty():
		return
	for index in int(config["applicants"]):
		if free_names.is_empty():
			break
		var looks: Array = config["looks"]
		applicants.append({
			# The first few cover every role, so there is always someone for each.
			"role": open[index % open.size()] if index < open.size() else open[rng.randi() % open.size()],
			"name": free_names.pop_at(rng.randi() % free_names.size()),
			"look": looks[rng.randi() % looks.size()],
		})


## Why an applicant can't be taken on, or "" if they can. `capacity` is how
## many staff the premises have room for.
func hire_problem(index: int, capacity: int) -> String:
	if index < 0 or index >= applicants.size():
		return "They have found another job"
	if team.size() >= capacity:
		return "No room for more staff here"
	return ""


## Takes an applicant on, starting on the first shift. Returns the new member
## of staff, or {} if it can't be done.
func hire(index: int, minute: float, capacity: int) -> Dictionary:
	if hire_problem(index, capacity) != "":
		return {}
	var applicant: Dictionary = applicants.pop_at(index)
	var member := {"id": _next_id, "name": applicant["name"], "role": applicant["role"], "shift": shifts.keys()[0],
		"look": applicant["look"], "hired_at": minute}
	_next_id += 1
	team.append(member)
	return member


func fire(id: int) -> void:
	team = team.filter(func(member: Dictionary) -> bool: return int(member["id"]) != id)


## The member of staff with this id, or {} if they have gone.
func member(id: int) -> Dictionary:
	for each in team:
		if int(each["id"]) == id:
			return each
	return {}


func set_shift(id: int, shift: String) -> void:
	if shifts.has(shift) and not member(id).is_empty():
		member(id)["shift"] = shift


## Pence the whole team costs for a day.
func wages_per_day() -> int:
	var total := 0
	for each in team:
		total += int(roles[each["role"]]["wage_pence_per_day"])
	return total


## True if a member of staff is at work at this minute of the day.
func on_shift(each: Dictionary, minute_of_day: float) -> bool:
	var shift: Dictionary = shifts[each["shift"]]
	return minute_of_day >= float(shift["start_minute"]) and minute_of_day < float(shift["end_minute"])


## The kinds of task a member of staff looks for, most pressing first.
func duties(each: Dictionary) -> Array:
	return roles[each["role"]]["duties"]


## True if anyone on the team has a duty, at work now or not.
func has_duty(duty: String) -> bool:
	return team.any(func(each: Dictionary) -> bool: return duties(each).has(duty))


func save() -> Dictionary:
	return {"team": team, "applicants": applicants, "next_id": _next_id}


## Puts back a saved team, without anyone whose role the game no longer has.
func restore(saved: Dictionary) -> void:
	team.clear()
	applicants.clear()
	for entry: Dictionary in saved["team"]:
		if roles.has(entry["role"]):
			team.append({"id": int(entry["id"]), "name": String(entry["name"]), "role": String(entry["role"]),
				"shift": String(entry["shift"]) if shifts.has(entry["shift"]) else shifts.keys()[0],
				"look": String(entry["look"]), "hired_at": float(entry["hired_at"])})
	for entry: Dictionary in saved["applicants"]:
		if roles.has(entry["role"]):
			applicants.append({"name": String(entry["name"]), "role": String(entry["role"]), "look": String(entry["look"])})
	_next_id = int(saved["next_id"])
