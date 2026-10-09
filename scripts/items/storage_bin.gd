class_name StorageBin
extends Node3D
## A printed storage bin in use on the shelving: one space that holds several
## prints. It is the print it was made from (kept inside it as `shell`, so it
## can go back to being stock) with the prints stored in it out of sight, bar
## the last one in, which shows over the rim.
##
## How much fits is in units (StorageRules): the bin's design says how many
## it has, and each print takes up some by its size.

## How big the print on show is drawn, against the bin.
const SHOWN_SCALE := 0.55

## The print the bin is.
var shell: PrintedItem
var items: Array[PrintedItem] = []


static func create(p_shell: PrintedItem) -> StorageBin:
	var bin := StorageBin.new()
	bin.name = "Bin_%s" % p_shell.product
	bin.shell = p_shell
	Interactable.attach(p_shell, bin)
	return bin


func units() -> int:
	return Game.storage.bin_units(shell.product)


## Units still free.
func free_units() -> int:
	var used := 0
	for item in items:
		used += Game.storage.cost(item.product)
	return units() - used


## How many more prints of a design it has room for.
func room_for(product: StringName) -> int:
	return Game.storage.fits(product, free_units())


## Puts a print in. False if there is no room for it.
func add(item: PrintedItem) -> bool:
	if room_for(item.product) <= 0:
		return false
	Interactable.attach(item, self)
	items.append(item)
	_show_top()
	return true


## Takes a print out and returns it.
func remove(item: PrintedItem) -> PrintedItem:
	items.erase(item)
	remove_child(item)
	item.scale = Vector3.ONE
	item.visible = true
	_show_top()
	return item


## Takes the bin out of use: the print it was made from, to go back on the shelf.
func empty_shell() -> PrintedItem:
	remove_child(shell)
	return shell


## "Stackable storage bin: 3 prints, room for 9 small"
func describe() -> String:
	var smallest: Dictionary = Game.data.settings["storage_bins"]["sizes"][0]
	return "%s: %d print%s, room for %d %s" % [Game.product_name(shell.product), items.size(), "" if items.size() == 1 else "s",
		free_units() / int(smallest["cost"]), String(smallest["name"]).to_lower()]


func _show_top() -> void:
	for index in items.size():
		var item := items[index]
		item.visible = index == items.size() - 1
		var fit := minf(1.0, SHOWN_SCALE * maxf(shell.footprint.x, shell.footprint.y) / maxf(maxf(item.footprint.x, item.footprint.y), 0.01))
		item.scale = Vector3.ONE * fit
		item.position = Vector3(0.0, shell.height * 0.6, 0.0)


func save() -> Dictionary:
	return {"shell": shell.save(), "items": items.map(func(item: PrintedItem) -> Dictionary: return item.save())}


## Null if the bin's design is no longer in the game. Prints whose design has
## gone are left out.
static func restored(data: Dictionary) -> StorageBin:
	var saved_shell := PrintedItem.restored(data["shell"])
	if saved_shell == null or not Game.storage.is_bin(saved_shell.product):
		return null
	var bin := StorageBin.create(saved_shell)
	for entry: Dictionary in data["items"]:
		var item := PrintedItem.restored(entry)
		if item != null:
			bin.add(item)
	return bin
