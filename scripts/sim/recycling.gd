class_name Recycling
extends RefCounted
## The rules of the filament recycler, and the state of one: what has been
## ground up into its hopper, the spool it is winding and the one waiting to
## be taken off. The ends of spools and failed prints go in by weight, less
## what the shredder loses; a spool's worth of one family of filament comes
## out as a new spool of the plain filament, in whatever colour is asked for.
## The machine is a row of data/fittings.json; what counts as a leftover and
## what recycled filament does to a print are the `recycling` settings.

## Row of data/fittings.json for the machine.
var spec: Dictionary
## Ground up filament waiting to be used, filament family -> grams.
var hopper: Dictionary[String, float] = {}
## The spool being wound, as { material, colour, left } with game minutes to
## go. Empty while nothing is.
var job: Dictionary = {}
## The spool wound and waiting to be taken off, as { material, colour }. Empty if none.
var ready: Dictionary = {}


func _init(p_spec: Dictionary) -> void:
	spec = p_spec


## The family a filament is recycled as, or "" if this machine can't take it:
## resin, and anything it doesn't melt.
static func family_of(machine: Dictionary, filament: Dictionary) -> String:
	if filament.get("process", FilamentRules.DEFAULT_PROCESS) != FilamentRules.DEFAULT_PROCESS:
		return ""
	return String(filament["family"]) if (machine["recycles"] as Array).has(filament["family"]) else ""


## True if what is left on a spool is little enough to be called a leftover.
static func is_leftover(grams: float, rules: Dictionary) -> bool:
	return grams < float(rules["leftover_grams"])


## What printing with a recycled spool adds to the chance of a failure.
static func extra_fail_chance(recycled: bool, rules: Dictionary) -> float:
	return float(rules["extra_fail"]) if recycled else 0.0


## Grams of regrind that `grams` of scrap comes to, once the shredder has had its share.
func yield_of(grams: float) -> float:
	return maxf(grams, 0.0) * (1.0 - float(spec["loss"]))


## Shreds `grams` of a filament into the hopper. Returns what was added, 0 if
## the machine can't take it.
func feed(filament: Dictionary, grams: float) -> float:
	var family := Recycling.family_of(spec, filament)
	if family == "":
		return 0.0
	var added := yield_of(grams)
	hopper[family] = float(hopper.get(family, 0.0)) + added
	return added


## Grams one new spool takes.
func spool_grams() -> float:
	return float(spec["spool_grams"])


## How much of a family is in the hopper.
func grams_of(family: String) -> float:
	return float(hopper.get(family, 0.0))


## Why a spool of a family can't be started, or "" if it can.
func problem(family: String) -> String:
	if not job.is_empty():
		return "it is busy winding a spool"
	if not ready.is_empty():
		return "take the finished spool off first"
	var short := spool_grams() - grams_of(family)
	if short > 0.0:
		return "it needs %d g more" % ceili(short)
	return ""


## Sets a spool of `family` winding in `colour`, out of the hopper. False if it can't.
func start(family: String, colour: StringName) -> bool:
	if problem(family) != "":
		return false
	hopper[family] = grams_of(family) - spool_grams()
	if hopper[family] < 1.0:
		hopper.erase(family)
	job = {"material": family, "colour": String(colour), "left": float(spec["extrude_minutes"])}
	return true


## Moves the winding on by game minutes. True as the spool is finished.
func advance(minutes: float) -> bool:
	if job.is_empty():
		return false
	job["left"] = float(job["left"]) - minutes
	if float(job["left"]) > 0.0:
		return false
	ready = {"material": job["material"], "colour": job["colour"]}
	job = {}
	return true


## How far through the spool being wound it is, 0 to 1.
func progress() -> float:
	if job.is_empty():
		return 0.0
	return clampf(1.0 - float(job["left"]) / float(spec["extrude_minutes"]), 0.0, 1.0)


## Hands over the finished spool, as { material, colour }. Empty if there is none.
func take() -> Dictionary:
	var taken := ready
	ready = {}
	return taken


## True while there is anything in it or on it.
func in_use() -> bool:
	return not hopper.is_empty() or not job.is_empty() or not ready.is_empty()


func save() -> Dictionary:
	return {"hopper": hopper, "job": job, "ready": ready}


## Skips anything the data tables no longer have.
func restore(data: Dictionary, filaments: Dictionary) -> void:
	hopper.clear()
	for family: String in data.get("hopper", {}):
		if filaments.has(family):
			hopper[family] = float(data["hopper"][family])
	job = {}
	var saved_job: Dictionary = data.get("job", {})
	if filaments.has(saved_job.get("material", "")):
		job = {"material": String(saved_job["material"]), "colour": String(saved_job["colour"]), "left": float(saved_job["left"])}
	ready = {}
	var saved_ready: Dictionary = data.get("ready", {})
	if filaments.has(saved_ready.get("material", "")):
		ready = {"material": String(saved_ready["material"]), "colour": String(saved_ready["colour"])}
