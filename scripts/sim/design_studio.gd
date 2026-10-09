class_name DesignStudio
extends RefCounted
## The business's own designs: its own versions of items from the catalogue,
## made at the PC instead of bought. An own design costs time rather than a
## fee, owes no royalty, and sells better or worse than the bought one
## according to its quality. Iterating (V2, V3) raises the quality; making
## designs builds skill. A new or changed design may hide a fault that only a
## test print shows up. Rules come from the `design` settings in data/game.json.

## Product rows from data/products.json, by id.
var products: Dictionary
## The `design` block of data/game.json.
var rules: Dictionary
## Product id -> { version, quality, faulty, fault_known, tested }.
var designs: Dictionary[StringName, Dictionary] = {}
## Designs and iterations finished so far. Builds skill.
var completed := 0


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
	return {"designs": designs, "completed": completed}


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
