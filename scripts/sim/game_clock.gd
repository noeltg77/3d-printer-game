class_name GameClock
extends RefCounted
## Game time, counted in game minutes since midnight on day 1.
## Speed (pause, 1x, 2x, 4x) is handled by Engine.time_scale, so the seconds
## passed to advance() are already scaled.

## One game day takes 10 real minutes at 1x.
const MINUTES_PER_SECOND := 2.4
const DAY := 1440.0

var minutes := 0.0

var day: int:
	get:
		return int(minutes / DAY) + 1

var minute_of_day: float:
	get:
		return fmod(minutes, DAY)


func advance(seconds: float) -> void:
	minutes += seconds * MINUTES_PER_SECOND


## "Day 2, 14:05"
func label() -> String:
	var now := int(minute_of_day)
	return "Day %d, %02d:%02d" % [day, now / 60, now % 60]


## True if the clock passed `minute_of_day` going from `before` to now.
func crossed(before: float, target_minute_of_day: float) -> bool:
	var next := floorf(before / DAY) * DAY + target_minute_of_day
	if next <= before:
		next += DAY
	return minutes >= next


## Real seconds (at 1x) that a span of game minutes lasts.
static func to_seconds(game_minutes: float) -> float:
	return game_minutes / MINUTES_PER_SECOND


## "3h 20m", "2h", "45m" or "1d 4h"
static func duration_label(game_minutes: float) -> String:
	var total := maxi(int(ceilf(game_minutes)), 0)
	if total >= int(DAY):
		return "%dd %dh" % [total / int(DAY), total % int(DAY) / 60]
	if total >= 60:
		return "%dh" % (total / 60) if total % 60 == 0 else "%dh %02dm" % [total / 60, total % 60]
	return "%dm" % total


func save() -> Dictionary:
	return {"minutes": minutes}


func restore(data: Dictionary) -> void:
	minutes = float(data["minutes"])
