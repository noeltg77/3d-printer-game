class_name DesignStudio
extends RefCounted
## The business's own designs: its own versions of items from the catalogue,
## made at the PC instead of bought. An own design costs time rather than a
## fee, owes no royalty, and sells better or worse than the bought one
## according to its quality. Iterating (V2, V3) raises the quality; making
## designs builds skill. A new or changed design may hide a fault that only a
## test print shows up. Rules come from the `design` settings in data/game.json.
##
## Designing takes time at the PC, and can be left and come back to: the
## minutes put in so far are kept (`progress`) until the piece of work is done.

## Product rows from data/products.json, by id.
var products: Dictionary
## The `design` block of data/game.json.
var rules: Dictionary
## Product id -> { version, quality, faulty, fault_known, tested }.
var designs: Dictionary[StringName, Dictionary] = {}
## Designs and iterations finished so far. Builds skill.
var completed := 0
## Work at the PC part way through: product id -> game minutes put in so far,
## for the next version of a design and for fixing a fault, kept apart.
var progress: Dictionary[StringName, float] = {}
var fix_progress: Dictionary[StringName, float] = {}
## The piece of work that would be carried on with next, or &"" if there is
## none: the product, and whether it is a fix.
var current: StringName = &""
var current_is_fix := false


func _init(p_products: Dictionary, p_rules: Dictionary) -> void:
	products = p_products
	rules = p_rules


func has(product: StringName) -> bool:
	return designs.has(product)


func version(product: StringName) -> int:
	return int(designs[product]["version"]) if has(product) else 0


## Design skill, 0 upwards: a level for every few designs finished.
func skill() -> int:
	return mini(completed / int(rules["designs_per_skill_level"]), int(rules["max_skill"]))


## True if a design can be iterated again.
func can_improve(product: StringName) -> bool:
	return has(product) and version(product) < int(rules["max_version"])


## Game minutes at the PC to make the next version of a design: the first for a
## design not yet made. Harder items take longer; iterations are quicker.
func minutes_for(product: StringName) -> float:
	var first := float(rules["base_minutes"]) * (1.0 + float(products[product]["difficulty"]))
	return first if not has(product) else first * float(rules["iteration_time"])


func fix_minutes() -> float:
	return float(rules["fix_minutes"])


## Sits down to a piece of work: the next version of a design, or a fix to
## it. What was already put into it still counts.
func start(product: StringName, fix := false) -> void:
	var store := fix_progress if fix else progress
	if not store.has(product):
		store[product] = 0.0
	current = product
	current_is_fix = fix


## True if a piece of work has been started and not finished.
func in_progress(product: StringName, fix := false) -> bool:
	return (fix_progress if fix else progress).has(product)


## Game minutes a piece of work takes from start to finish.
func minutes_needed(product: StringName, fix := false) -> float:
	return fix_minutes() if fix else minutes_for(product)


## How far through a piece of work is, 0 to 1.
func fraction(product: StringName, fix := false) -> float:
	var store := fix_progress if fix else progress
	return clampf(float(store.get(product, 0.0)) / minutes_needed(product, fix), 0.0, 1.0)


## Adds game minutes at the PC to a piece of work that has been started.
## Returns true when that finishes it: it is then cleared away, and the caller
## completes the design or the fix.
func work(product: StringName, fix: bool, minutes: float) -> bool:
	var store := fix_progress if fix else progress
	if not store.has(product):
		return false
	store[product] += minutes
	if store[product] < minutes_needed(product, fix):
		return false
	store.erase(product)
	if current == product and current_is_fix == fix:
		current = &""
	return true


## Quality (1 to 5) the next version of a design will have.
func next_quality(product: StringName) -> int:
	var quality := int(designs[product]["quality"]) + 1 if has(product) else int(rules["base_quality"]) + skill()
	return mini(quality, int(rules["max_quality"]))


## Chance (0 to 1) that a new version hides a fault. Falls with skill.
func fault_chance() -> float:
	return clampf(float(rules["fault_chance"]) - skill() * float(rules["fault_chance_per_skill"]), 0.0, 1.0)


## Finishes the next version of a design: V1 if it is new. Returns its record.
func complete(product: StringName, rng: RandomNumberGenerator) -> Dictionary:
	var record := {
		"version": version(product) + 1,
		"quality": next_quality(product),
		"faulty": rng.randf() < fault_chance(),
		"fault_known": false,
		"tested": false,
	}
	designs[product] = record
	completed += 1
	return record


## How an own design sells against the bought one: a multiplier on demand, 1.0
## at the middle quality. 1.0 for anything that isn't an own design.
func appeal(product: StringName) -> float:
	if not has(product):
		return 1.0
	return float(rules["appeal_base"]) + float(rules["appeal_per_quality"]) * int(designs[product]["quality"])


## True if prints of this design come out flawed: it has a fault not yet fixed.
func is_faulty(product: StringName) -> bool:
	return has(product) and designs[product]["faulty"]


## Call when a print of a design comes off the printer. The first print is its
## test: returns "fault" if it shows one up, "sound" if it proves the design,
## or "" if there was nothing new to learn.
func printed(product: StringName) -> String:
	if not has(product):
		return ""
	var record := designs[product]
	if record["faulty"]:
		var news := "" if record["fault_known"] else "fault"
		record["fault_known"] = true
		return news
	var first: bool = not record["tested"]
	record["tested"] = true
	return "sound" if first else ""


## True if a fault has been found and is waiting to be fixed at the PC.
func needs_fix(product: StringName) -> bool:
	return has(product) and designs[product]["faulty"] and designs[product]["fault_known"]


## Puts right a fault a test print found.
func fix(product: StringName) -> void:
	if needs_fix(product):
		designs[product]["faulty"] = false
		designs[product]["fault_known"] = false
		designs[product]["tested"] = true


func save() -> Dictionary:
	return {"designs": designs, "completed": completed, "progress": progress, "fix_progress": fix_progress,
		"current": current, "current_is_fix": current_is_fix}


## Puts back saved designs, leaving out any for items the game no longer has.
func restore(data: Dictionary) -> void:
	designs.clear()
	for product: String in data["designs"]:
		if products.has(product):
			var saved: Dictionary = data["designs"][product]
			designs[StringName(product)] = {
				"version": int(saved["version"]), "quality": int(saved["quality"]), "faulty": bool(saved["faulty"]),
				"fault_known": bool(saved["fault_known"]), "tested": bool(saved["tested"]),
			}
	completed = int(data["completed"])
	progress.clear()
	fix_progress.clear()
	for product: String in data.get("progress", {}):
		if products.has(product):
			progress[StringName(product)] = float(data["progress"][product])
	for product: String in data.get("fix_progress", {}):
		if needs_fix(StringName(product)):
			fix_progress[StringName(product)] = float(data["fix_progress"][product])
	current = StringName(data.get("current", ""))
	current_is_fix = bool(data.get("current_is_fix", false))
	if not in_progress(current, current_is_fix):
		current = &""
