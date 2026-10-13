class_name SaveSlots
extends RefCounted
## The saved games on this computer: one JSON file each in a folder, with a
## small picture beside it. A save carries a `meta` block (business name, day,
## cash, premises, when it was written) so the menu can list them without
## restoring any. Pure file handling, no nodes; every function takes the
## folder so the tests can use one of their own.

const DIR := "user://saves"
## Where the one save lived before there were slots.
const LEGACY := "user://save.json"

## The folder used when a function isn't given one. Dev runs point it
## elsewhere with --saves=<folder>, to keep clear of the real saves.
static var root := DIR


## The header written at the top of a save, from the business as Game.save()
## gives it. `saved_unix` is the real time, for "last played".
static func meta(business: Dictionary, business_name: String, saved_unix: int) -> Dictionary:
	return {
		"name": business_name,
		"minutes": float(business["clock"]["minutes"]),
		"cash_pence": int(business["bank"]["cash"]),
		"premises": String(business.get("premises", "garage")),
		"tier": int(business.get("tier", 1)),
		"saved_unix": saved_unix,
	}


## Every save in the folder that can be read, the most recently played first.
## Each is its meta block plus `path` and `thumbnail`.
static func list(dir := "") -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	dir = _folder(dir)
	if not DirAccess.dir_exists_absolute(dir):
		return found
	for file in DirAccess.get_files_at(dir):
		if file.get_extension() == "json":
			var slot := describe(dir.path_join(file))
			if not slot.is_empty():
				found.append(slot)
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["saved_unix"]) > int(b["saved_unix"]))
	return found


## What one save file holds, or {} if it isn't a save. One from before saves
## had a meta block is described from the business inside it.
static func describe(path: String, fallback_name := "My print shop") -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	# Parsed this way so a file that isn't JSON is passed over without a fuss.
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return {}
	var parsed: Variant = json.data
	if not parsed is Dictionary or not parsed.get("business") is Dictionary:
		return {}
	var slot: Dictionary = {}
	if parsed.get("meta") is Dictionary:
		slot = (parsed["meta"] as Dictionary).duplicate()
	else:
		slot = meta(parsed["business"], fallback_name, int(FileAccess.get_modified_time(path)))
	slot["name"] = String(slot.get("name", fallback_name))
	slot["minutes"] = float(slot.get("minutes", 0.0))
	slot["cash_pence"] = int(slot.get("cash_pence", 0))
	slot["premises"] = String(slot.get("premises", "garage"))
	slot["tier"] = int(slot.get("tier", 1))
	slot["saved_unix"] = int(slot.get("saved_unix", 0))
	slot["version"] = int(parsed.get("version", 0))
	slot["path"] = path
	slot["thumbnail"] = thumbnail_path(path)
	return slot


## The save played last, or {} if there are none.
static func latest(dir := "") -> Dictionary:
	var slots := list(dir)
	return {} if slots.is_empty() else slots[0]


## A path for a new save that no file has yet. Makes the folder if need be.
static func fresh_path(dir := "") -> String:
	dir = _folder(dir)
	DirAccess.make_dir_recursive_absolute(dir)
	var number := 1
	while FileAccess.file_exists(dir.path_join("slot_%d.json" % number)):
		number += 1
	return dir.path_join("slot_%d.json" % number)


## Where the picture of a save goes.
static func thumbnail_path(path: String) -> String:
	return path.get_basename() + ".png"


## Deletes a save and its picture.
static func remove(path: String) -> void:
	for file: String in [path, thumbnail_path(path), path + ".tmp"]:
		if FileAccess.file_exists(file):
			DirAccess.remove_absolute(file)


## Keeps a copy of a save as a slot of its own, picture and all, to go back to
## later. Returns the copy's path, or "" if it couldn't be made.
static func copy(path: String, dir := "") -> String:
	if not FileAccess.file_exists(path):
		return ""
	var target := fresh_path(dir)
	if DirAccess.copy_absolute(path, target) != OK:
		return ""
	if FileAccess.file_exists(thumbnail_path(path)):
		DirAccess.copy_absolute(thumbnail_path(path), thumbnail_path(target))
	return target


## Moves the save from before there were slots into the folder, as a slot of
## its own. Returns its new path, or "" if there was nothing to move.
static func adopt_legacy(dir := "", legacy := LEGACY) -> String:
	if not FileAccess.file_exists(legacy):
		return ""
	var path := fresh_path(dir)
	return path if DirAccess.rename_absolute(legacy, path) == OK else ""


static func _folder(dir: String) -> String:
	return dir if dir != "" else root


## "Day 12" for a save's game minutes.
static func day_label(minutes: float) -> String:
	return "Day %d" % (int(minutes / GameClock.DAY) + 1)


## "13 Oct, 14:02" in local time for when a save was written.
static func when_label(saved_unix: int) -> String:
	if saved_unix <= 0:
		return "Not played yet"
	var zone := Time.get_time_zone_from_system()
	var date := Time.get_datetime_dict_from_unix_time(saved_unix + int(zone.get("bias", 0)) * 60)
	var months := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	return "%d %s, %02d:%02d" % [date["day"], months[int(date["month"]) - 1], date["hour"], date["minute"]]
