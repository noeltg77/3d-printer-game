class_name Events
extends RefCounted
## Things that happen to the business from outside: a design going viral, a
## rival undercutting it, a filament running short, a power cut, a client going
## bust. One comes along every few days (data/events.json). Some last a while,
## scaling a product's demand or a filament's price until they end; some are
## over at once.
##
## This picks what happens, to what, and for how long. Carrying it out is the
## caller's job: it reads multiplier() for the lasting kinds, and acts on the
## others as tick() hands them over.

## Event rows by id, and the `events` block of data/game.json.
var rows: Dictionary
var rules: Dictionary
## Events going on now. Each: { id, target, started, until }.
var active: Array[Dictionary] = []
## Game minute the next event is due, or -1 before the first is scheduled.
var next_at := -1.0


func _init(p_rows: Dictionary, p_rules: Dictionary) -> void:
	rows = p_rows
	rules = p_rules


## Starts an event if one is due. `candidates` is what each kind of event
## could happen to, by the row's `target`: e.g. { product: [ids], filament:
## [ids], contract: [ids], printing: [anything, if a print is running] }.
## Returns the event started, as { id, target, started, until }, or {} if none.
func tick(minute: float, rng: RandomNumberGenerator, tier: int, candidates: Dictionary) -> Dictionary:
	if next_at < 0.0:
		_schedule(minute, rng)
		return {}
	if minute < next_at:
		return {}
	_schedule(minute, rng)
	var possible: Array[Dictionary] = []
	var total := 0.0
	for row: Dictionary in rows.values():
		if int(row["unlock_tier"]) <= tier and not candidates.get(row["target"], []).is_empty() and not is_active(row["id"]):
			possible.append(row)
			total += float(row["weight"])
	if possible.is_empty():
		return {}
	var roll := rng.randf() * total
	var chosen: Dictionary = possible[-1]
	for row in possible:
		roll -= float(row["weight"])
		if roll < 0.0:
			chosen = row
			break
	return start(chosen["id"], minute, rng, candidates)


## Starts a particular event now, on a target picked from the candidates.
func start(id: String, minute: float, rng: RandomNumberGenerator, candidates: Dictionary) -> Dictionary:
	var row: Dictionary = rows[id]
	var targets: Array = candidates.get(row["target"], [])
	if targets.is_empty():
		return {}
	var days: Array = row["days"]
	var event := {"id": id, "target": targets[rng.randi() % targets.size()], "started": minute,
		"until": minute + rng.randf_range(days[0], days[1]) * GameClock.DAY}
	if float(event["until"]) > minute:
		active.append(event)
	return event


## Ends the events whose time is up. Returns them.
func expire(minute: float) -> Array[Dictionary]:
	var over: Array[Dictionary] = []
	for event in active.duplicate():
		if minute >= float(event["until"]):
			active.erase(event)
			over.append(event)
	return over


func is_active(id: String) -> bool:
	return active.any(func(event: Dictionary) -> bool: return event["id"] == id)


## What the events going on do to something: the product of the multipliers of
## every active event of `kind` ("demand" or "price") whose target it is.
func multiplier(kind: String, target: Variant) -> float:
	var result := 1.0
	for event in active:
		var row: Dictionary = rows[event["id"]]
		if row["kind"] == kind and str(event["target"]) == str(target):
			result *= float(row["multiplier"])
	return result


func _schedule(minute: float, rng: RandomNumberGenerator) -> void:
	var gap: Array = rules["days"]
	next_at = minute + rng.randf_range(gap[0], gap[1]) * GameClock.DAY


func save() -> Dictionary:
	return {"active": active, "next_at": next_at}


## Puts back what was going on, leaving out events the game no longer has.
func restore(saved: Dictionary) -> void:
	active.clear()
	for event: Dictionary in saved["active"]:
		if rows.has(event["id"]):
			# Ids of contracts come back from a save as fractions.
			var target: Variant = int(event["target"]) if event["target"] is float else event["target"]
			active.append({"id": String(event["id"]), "target": target, "started": float(event["started"]), "until": float(event["until"])})
	next_at = float(saved["next_at"])
