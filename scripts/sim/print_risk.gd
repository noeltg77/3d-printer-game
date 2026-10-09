class_name PrintRisk
extends RefCounted
## The rules for prints going wrong: how likely a print is to fail, which
## failure it is and when in the print it strikes. Works on rows from
## data/printers.json, presets.json, filaments.json, products.json and
## failures.json, so it can be tested without a scene.

## No print is ever more likely than this to fail.
const MAX_CHANCE := 0.85
## Risk meter bands: the chance at or above which each label applies.
const BANDS: Array[Dictionary] = [
	{"from": 0.0, "label": "Low"},
	{"from": 0.06, "label": "Medium"},
	{"from": 0.12, "label": "High"},
	{"from": 0.25, "label": "Very high"},
]
## A part counts as large when it covers this share of the bed in either direction.
const LARGE_PART_SHARE := 0.6
## Taller than this multiple of its narrowest side counts as tall and thin.
const TALL_THIN_RATIO := 2.0
## A bed slinger shakes prints taller than this (mm).
const BEDSLINGER_TALL_MM := 150.0
## Where in the print each `happens` value strikes, as a range of progress.
const WHEN := {"start": [0.01, 0.05], "mid": [0.1, 0.9], "end": [1.0, 1.0]}


## True if a design fits a printer's build volume, turned either way round on the bed.
static func fits(printer: Dictionary, product: Dictionary) -> bool:
	var size: Array = product["size_mm"]
	var bed: Array = printer["build_volume_mm"]
	if float(size[2]) > float(bed[2]):
		return false
	var straight: bool = float(size[0]) <= float(bed[0]) and float(size[1]) <= float(bed[1])
	var turned: bool = float(size[1]) <= float(bed[0]) and float(size[0]) <= float(bed[1])
	return straight or turned


## How many copies of a design fit on a printer's bed at once, `gap_mm` apart
## and all turned the same way. 0 if it doesn't fit at all.
static func copies(printer: Dictionary, product: Dictionary, gap_mm := 5.0) -> int:
	if not fits(printer, product):
		return 0
	var size: Array = product["size_mm"]
	var bed: Array = printer["build_volume_mm"]
	var straight := _in_a_row(bed[0], size[0], gap_mm) * _in_a_row(bed[1], size[1], gap_mm)
	var turned := _in_a_row(bed[0], size[1], gap_mm) * _in_a_row(bed[1], size[0], gap_mm)
	return maxi(straight, turned)


static func _in_a_row(bed: float, size: float, gap: float) -> int:
	return floori((bed + gap) / (size + gap))


## Chance (0 to 1) that a print goes wrong in any way. `extra` is added on top
## for things outside the print itself, such as worn parts.
static func fail_chance(printer: Dictionary, preset: Dictionary, filament: Dictionary, product: Dictionary, extra := 0.0) -> float:
	var base := 1.0 - float(printer["reliability"])
	var material := (6.0 - float(filament["ease_of_printing"])) / 3.0
	var design := 0.8 + 0.8 * float(product["difficulty"])
	return clampf(base * float(preset["failure_multiplier"]) * material * design + extra, 0.0, MAX_CHANCE)


## "Low", "Medium", "High" or "Very high" for a chance from fail_chance().
static func band(chance: float) -> String:
	var label := ""
	for entry in BANDS:
		if chance >= float(entry["from"]):
			label = entry["label"]
	return label


## The condition flags that are true for this print. They are the keys used in
## each failure's `causes`.
static func conditions(printer: Dictionary, preset: Dictionary, product: Dictionary) -> Array[StringName]:
	var flags: Array[StringName] = []
	var size: Array = product["size_mm"]
	var bed: Array = printer["build_volume_mm"]
	if preset["id"] == "draft":
		flags.append(&"draft_preset")
	if not printer["auto_bed_levelling"]:
		flags.append(&"no_auto_level")
	if float(size[0]) >= float(bed[0]) * LARGE_PART_SHARE or float(size[1]) >= float(bed[1]) * LARGE_PART_SHARE:
		flags.append(&"large_part")
	if float(size[2]) >= minf(size[0], size[1]) * TALL_THIN_RATIO:
		flags.append(&"tall_thin_part")
	if printer["motion"] == "bed_slinger" and float(size[2]) >= BEDSLINGER_TALL_MM:
		flags.append(&"bedslinger_tall_part")
	return flags


## How heavily a failure counts when choosing which one happens: its weight,
## times every cause that applies, times the filament's own modifier for it,
## times what the printer's upgrades do to it (`multipliers`, by failure id).
## A failure that `requires` a condition counts for nothing without it.
static func weight_of(failure: Dictionary, flags: Array[StringName], filament: Dictionary, multipliers := {}) -> float:
	if failure.has("requires") and not flags.has(StringName(failure["requires"])):
		return 0.0
	var weight := float(failure["weight"])
	for cause: String in failure["causes"]:
		if flags.has(StringName(cause)):
			weight *= float(failure["causes"][cause])
	return weight * float(filament["failure_modifiers"].get(failure["id"], 1.0)) * float(multipliers.get(failure["id"], 1.0))


## How much upgrades cut the chance of a print failing at all: the share of
## the failures that are left once each is scaled by its multiplier.
static func upgrade_scale(failures: Dictionary, flags: Array[StringName], filament: Dictionary, multipliers: Dictionary) -> float:
	var before := 0.0
	var after := 0.0
	for failure: Dictionary in failures.values():
		before += weight_of(failure, flags, filament)
		after += weight_of(failure, flags, filament, multipliers)
	return after / before if before > 0.0 else 1.0


## Picks which failure happens, given that one does. `failures` is the table by id.
static func pick(failures: Dictionary, flags: Array[StringName], filament: Dictionary, rng: RandomNumberGenerator, multipliers := {}) -> Dictionary:
	var total := 0.0
	for failure: Dictionary in failures.values():
		total += weight_of(failure, flags, filament, multipliers)
	var roll := rng.randf() * total
	var last := {}
	for failure: Dictionary in failures.values():
		var weight := weight_of(failure, flags, filament, multipliers)
		# Weightless failures are never rolled: something else sets them off.
		if weight <= 0.0:
			continue
		roll -= weight
		last = failure
		if roll < 0.0:
			break
	return last


## The point in the print (0 to 1) at which a failure strikes.
static func strike_point(failure: Dictionary, rng: RandomNumberGenerator) -> float:
	var span: Array = WHEN[failure["happens"]]
	return rng.randf_range(span[0], span[1])


## Rolls one print. Returns {} if it goes well, or { failure, at } with the
## failure's row and the progress at which it strikes.
static func roll(chance: float, failures: Dictionary, flags: Array[StringName], filament: Dictionary, rng: RandomNumberGenerator, multipliers := {}) -> Dictionary:
	if failures.is_empty() or rng.randf() >= chance:
		return {}
	var failure := pick(failures, flags, filament, rng, multipliers)
	return {"failure": failure, "at": strike_point(failure, rng)}
