class_name WorkDay
extends RefCounted
## The hours the business keeps. On their own the owner works from the start
## minute to the end minute (data/game.json, `work_day`); with staff, the day
## runs on until the last of their shifts is over. Once the day is done the
## night can be skipped, through to the start of the next one.

var start_minute: float
var end_minute: float


func _init(config: Dictionary) -> void:
	start_minute = float(config["start_minute"])
	end_minute = float(config["end_minute"])


## The minute of the day the working day ends, given who is on the team.
func closes_at(staff: Staff) -> float:
	var closes := end_minute
	for member in staff.team:
		closes = maxf(closes, float(staff.shifts[member["shift"]]["end_minute"]))
	return closes


## True if the working day is over at this minute of the day: it has closed, or
## it is the small hours before the next one starts.
func over(minute_of_day: float, closes: float) -> bool:
	return minute_of_day >= closes or minute_of_day < start_minute


## The game minute the next working day starts, counted from `minutes`.
func next_start(minutes: float) -> float:
	var today := floorf(minutes / GameClock.DAY) * GameClock.DAY + start_minute
	return today if today > minutes else today + GameClock.DAY


## "18:00"
static func time_label(minute_of_day: float) -> String:
	var minute := int(minute_of_day)
	return "%02d:%02d" % [minute / 60, minute % 60]
