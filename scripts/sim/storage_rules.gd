class_name StorageRules
extends RefCounted
## The rules of storage: the shelving and racks that can be bought and stood
## about the premises (data/fittings.json, and each premises' limits), and
## the printed storage bins that let one space on the shelving hold several
## prints (the `storage_bins` rules in data/game.json).
##
## A bin has room measured in units. A print takes up units by its size: the
## longest side of its design puts it in a size class, and each class has a
## cost. So a bin of 12 units holds 12 small prints, 6 medium or 2 large, or
## a mixture.

## The unit a thing is marked as having stood on once its shelving has come down for a move.
const MOVED_UNIT := 9999

var data: GameData


func _init(p_data: GameData) -> void:
	data = p_data


## True if a design, once printed, can be used as a storage bin.
func is_bin(product: StringName) -> bool:
	return _bins()["designs"].has(String(product))


## Units of room in a bin printed from a design. 0 if it is not a bin.
func bin_units(product: StringName) -> int:
	return int(_bins()["designs"].get(String(product), 0))


## The size class of a design, a row of the rules' `sizes`: { id, name, cost }.
func size_of(product: StringName) -> Dictionary:
	var longest := 0.0
	for side: float in data.products[product]["size_mm"]:
		longest = maxf(longest, side)
	var sizes: Array = _bins()["sizes"]
	for size: Dictionary in sizes:
		if longest <= float(size.get("max_mm", INF)):
			return size
	return sizes.back()


## Units of a bin's room that one print of a design takes up.
func cost(product: StringName) -> int:
	return int(size_of(product)["cost"])


## How many more prints of a design fit in a bin with `free` units left.
func fits(product: StringName, free: int) -> int:
	return free / cost(product)


## "12 small, 6 medium or 2 large prints": what a bin of a design holds.
func bin_summary(product: StringName) -> String:
	var parts: PackedStringArray = []
	for size: Dictionary in _bins()["sizes"]:
		parts.append("%d %s" % [bin_units(product) / int(size["cost"]), String(size["name"]).to_lower()])
	return "%s prints" % (", ".join(parts.slice(0, -1)) + " or " + parts[-1] if parts.size() > 1 else parts[0])


## What a printer fetches second hand, in pence: its price new, less the most
## for one with every part worn out (the `resale` rules in data/game.json).
## `health` is how much life its parts have left on average, 0 to 1.
func resale_value(printer: Dictionary, health: float) -> int:
	var rules: Dictionary = data.settings["resale"]
	return roundi(float(printer["price_pence"]) * lerpf(float(rules["worn_out"]), float(rules["as_new"]), clampf(health, 0.0, 1.0)))


## How many units of a kind of fitting ("shelf" or "rack") the premises may
## have in all, counting the one built in. Benches and printer racks are
## limited another way: by the places for printers they add up to.
func limit(premises: Dictionary, kind: String) -> int:
	return int(premises.get("%s_units" % kind, 1))


## How many places for printers a bench or printer rack adds. 0 for anything else.
func places(fitting: StringName) -> int:
	return (data.fittings.get(String(fitting), {}).get("printer_spots", []) as Array).size()


## How many places for printers the premises has room for, on benches and racks together.
static func max_printers(premises: Dictionary) -> int:
	return int(premises["max_printers"])


## Readies a saved shelf or rack (StorageShelf.save, FilamentRack.save) to be
## handed to other premises: the bought units come down, to be stood again
## there, and what was on them is left to find new places. Returns the
## fitting ids of the units taken down.
static func pack_for_move(saved: Dictionary) -> Array[StringName]:
	var taken_down: Array[StringName] = []
	for entry: Dictionary in saved.get("units", []):
		taken_down.append(StringName(entry["fitting"]))
	saved["units"] = []
	# The benches taken out were the old place's own. The new one has its own.
	saved.erase("removed")
	for entry: Dictionary in saved.get("slots", []):
		if int(entry.get("unit", 0)) > 0:
			entry["unit"] = MOVED_UNIT
	return taken_down


func _bins() -> Dictionary:
	return data.settings["storage_bins"]
