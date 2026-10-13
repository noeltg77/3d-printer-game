class_name ResinFinish
extends RefCounted
## What a resin print needs once it is off the plate: the sticky resin washed
## off and the print hardened under a lamp. By hand that is the character's
## time at the printer (a filament's `post_minutes`, times the
## `resin_finishing` settings' `hand_multiplier`). A wash and cure station (a
## row of data/fittings.json of kind "wash") does it by itself, a plate at a
## time, washing for the first half of its time and curing for the second.

const WASHING := "Washing"
const CURING := "Curing"
const READY := "Ready"


## True if prints in a filament have to be washed and cured.
static func needed(filament: Dictionary) -> bool:
	return float(filament.get("post_minutes", 0)) > 0.0


## Game minutes of the character's time to do a plate by hand.
static func hand_minutes(filament: Dictionary, rules: Dictionary) -> float:
	return float(filament.get("post_minutes", 0)) * float(rules["hand_multiplier"])


## Game minutes a station takes over a plate.
static func machine_minutes(filament: Dictionary, station: Dictionary) -> float:
	return float(filament.get("post_minutes", 0)) * float(station["time_multiplier"])


## What a station is doing to a plate with `left` of `total` minutes to go.
static func stage(left: float, total: float) -> String:
	if left <= 0.0:
		return READY
	return WASHING if left > total / 2.0 else CURING
