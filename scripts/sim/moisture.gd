class_name Moisture
extends RefCounted
## The rules for damp filament. A spool left in the open soaks up moisture, as
## a share from 0 (dry) to 1 (soaked), at a rate set by its filament. Past a
## threshold it is wet: prints fail more often and come out stringy. A dryer
## takes the moisture back out. Works on rows from data/filaments.json and
## data/dryers.json and the `moisture` settings in data/game.json.

## Share of the way to wet at which a spool is worth mentioning as damp.
const DAMP_SHARE := 0.5


## Moisture a spool of this filament gains in a game day in the open.
static func gain_per_day(filament: Dictionary, settings: Dictionary) -> float:
	return float(filament["moisture_sensitivity"]) * float(settings["gain_per_day"])


## The spool's moisture after `game_minutes` more in the open.
static func after(moisture: float, game_minutes: float, filament: Dictionary, settings: Dictionary) -> float:
	return clampf(moisture + gain_per_day(filament, settings) * game_minutes / GameClock.DAY, 0.0, 1.0)


static func is_wet(moisture: float, settings: Dictionary) -> bool:
	return moisture >= float(settings["wet_at"])


## "dry", "damp" or "wet".
static func label(moisture: float, settings: Dictionary) -> String:
	if is_wet(moisture, settings):
		return "wet"
	return "damp" if moisture >= float(settings["wet_at"]) * DAMP_SHARE else "dry"


## Chance of failure (0 to 1) a wet spool adds to a print: nothing up to the
## threshold, then `extra_fail_per_step` for every `step` beyond it.
static func extra_fail_chance(moisture: float, settings: Dictionary) -> float:
	var over := maxf(moisture - float(settings["wet_at"]), 0.0)
	return over / float(settings["step"]) * float(settings["extra_fail_per_step"])


## True if a dryer (a row from data/dryers.json) can dry this filament.
static func can_dry(dryer: Dictionary, filament: Dictionary) -> bool:
	return (dryer["dries"] as Array).has(filament["family"])


## Game hours a dryer takes to bring a spool from this moisture down to dry.
static func hours_to_dry(moisture: float, dryer: Dictionary, filament: Dictionary) -> float:
	return moisture * float(dryer["hours_to_dry"]) * float(filament["drying_multiplier"])


## The spool's moisture after `game_minutes` in a dryer.
static func dried(moisture: float, game_minutes: float, dryer: Dictionary, filament: Dictionary) -> float:
	var full := float(dryer["hours_to_dry"]) * float(filament["drying_multiplier"]) * 60.0
	return clampf(moisture - game_minutes / full, 0.0, 1.0)
