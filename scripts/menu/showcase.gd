class_name Showcase
extends Node3D
## The moving picture behind the main menu: a real premises scene with the
## game running in it. It is the player's own shop, from the game they played
## last, carrying on where they left it; with no saved game yet it is a
## workshop set up busy for the purpose. Printers print, staff do their
## rounds, the owner mucks in, orders arrive and are packed, the courier calls
## and the day turns to evening. Nothing in it is saved: the real game is as
## it was left.
##
## It is the game's own scene with the player's controls taken out, so it
## shows whatever the game can do with no upkeep. The camera drifts, leans a
## little with the mouse, and moves in on whatever is clicked.

## A thing in the room came under the mouse, or null when it left.
signal hovered(thing: Interactable)

const PLACE := &"workshop"
const CASH_PENCE := 5000000
## The day shown runs between these minutes, then starts again.
const START_MINUTE := 475.0
const END_MINUTE := 1260.0
## A saved game left later in the day than this, or before the start, is
## shown from the morning of that day, so the menu isn't a dark, empty room.
const LATEST_MINUTE := 1110.0
const MORNING_MINUTE := 540.0
## Nodes of a premises scene that are the player's way in, and so not wanted.
const CONTROLS: Array[String] = ["InteractionController", "Hud", "WorldSave", "PrintDialog", "PcScreen"]
const PRINTERS := 9
const DESIGNS := 7
const RACK_SPOOLS := 16
const SHELF_PRINTS := 10
const OWNER_DUTIES: Array[String] = ["clear", "collect", "reprint", "pack", "finish"]
## How far to the left of the room the camera looks at the least, as a share
## of the view's width, so the room sits clear of the menu.
const SHIFT := 0.17
## How near the right of the view a small room's far corner may come, as a
## share of the view's width.
const EDGE := 0.02
## The view's height as a share of the premises camera's own, and when close in.
const WIDE_SHARE := 0.88
const CLOSE_SIZE := 4.6
## Real seconds the camera stays on something that was clicked.
const CLOSE_SECONDS := 8.0
const CURTAIN_SECONDS := 0.7

var camera := Camera3D.new()
## True once the room is built and fitted out.
var ready_to_show := false
## True when the room is the player's own, from their latest saved game.
var own_shop := false

var _room: Node3D = null
var _curtain := ColorRect.new()
var _home := Transform3D.IDENTITY
var _wide_size := 11.5
var _lean := Vector2.ZERO
## The middle of the floor, and half its width across the screen in metres,
## as the premises camera sees them.
var _centre := Vector2.ZERO
var _half_width := 0.0
var _focus := Vector2.ZERO
var _close_until := 0.0
var _hovered: Interactable = null
var _restaging := false
var _closed := false


func _ready() -> void:
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.current = true
	add_child(camera)
	var layer := CanvasLayer.new()
	layer.layer = 0
	_curtain.color = Ui.TASKBAR
	_curtain.set_anchors_preset(Control.PRESET_FULL_RECT)
	_curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_curtain)
	add_child(layer)
	_stage()


func _process(delta: float) -> void:
	if _room == null or _closed or not _room.is_inside_tree():
		return
	_move_camera(delta)
	if not _restaging and Game.clock.minute_of_day >= END_MINUTE:
		_start_again()


func _unhandled_input(event: InputEvent) -> void:
	if _room == null or _closed or _restaging:
		return
	if event is InputEventMouseMotion:
		_set_hovered(Interactable.under(camera, event.position))
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var thing := Interactable.under(camera, event.position)
		if thing != null:
			look_at_thing(thing)
		else:
			_close_until = 0.0


## Stops the show and clears the room, as a real game is about to start.
func close() -> void:
	_closed = true
	_set_hovered(null)
	if _room != null:
		_room.queue_free()
		_room = null


## Fades the room in from behind its curtain.
func reveal(seconds := CURTAIN_SECONDS) -> void:
	Ui.tween(self).tween_property(_curtain, "color:a", 0.0, seconds)


## Moves the camera in on something in the room for a few seconds.
func look_at_thing(thing: Node3D) -> void:
	var seen := _home.affine_inverse() * (thing.global_position + Vector3.UP * 0.4)
	_focus = Vector2(seen.x, seen.y)
	_close_until = Time.get_ticks_msec() / 1000.0 + CLOSE_SECONDS


## One line on what a thing in the room is up to, for the label by the mouse.
func describe(thing: Interactable) -> String:
	var station := thing as PrinterStation
	if station == null:
		return ""
	match station.status:
		PrinterStation.Status.PRINTING:
			return "Printing %s  ·  %d%%" % [Game.product_name(station.item.product).to_lower(), int(station.job.progress * 100.0)]
		PrinterStation.Status.DONE:
			return "Finished. Waiting to be collected"
		PrinterStation.Status.FAILED:
			return "That one went wrong"
	return "Standing by"


func _stage() -> void:
	var latest := SaveSlots.latest()
	var world: Dictionary = {} if latest.is_empty() else Game.begin_showcase_of(latest["path"])
	own_shop = not world.is_empty()
	if own_shop:
		var minute := Game.clock.minute_of_day
		if minute < START_MINUTE or minute > LATEST_MINUTE:
			Game.clock.minutes += MORNING_MINUTE - minute
	else:
		Game.begin_showcase(PLACE, CASH_PENCE)
		Game.clock.minutes = START_MINUTE
	# Loaded on a thread, so the opening over it keeps moving.
	var path: String = Game.premises_row()["scene"]
	ResourceLoader.load_threaded_request(path)
	while ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
	if _closed:
		return
	_room = (ResourceLoader.load_threaded_get(path) as PackedScene).instantiate()
	for control in CONTROLS:
		var node := _room.get_node_or_null(control)
		if node != null:
			_room.remove_child(node)
			node.free()
	# The view is the game's own, from the scene's camera, but ours to move.
	var theirs: Camera3D = _room.get_node(^"Camera")
	_home = theirs.transform
	camera.far = theirs.far
	_wide_size = theirs.size * WIDE_SHARE
	_measure_floor()
	camera.size = _wide_size
	_room.remove_child(theirs)
	theirs.free()
	add_child(_room)
	camera.transform = _home
	camera.make_current()
	# A frame for everything to be ready, and another for the click boxes.
	await get_tree().process_frame
	await get_tree().process_frame
	if _room == null:
		return
	if own_shop:
		_restore(world)
	else:
		_fill()
	# The owner mucks in with whatever wants doing.
	var owner: Agent = get_tree().get_first_node_in_group(&"player")
	var mind := Worker.new()
	mind.name = "Worker"
	mind.own_duties = OWNER_DUTIES
	owner.add_child(mind)
	Game.changed.emit()
	ready_to_show = true


## Puts the player's own shop back as their save has it, the way WorldSave does.
func _restore(world: Dictionary) -> void:
	for key: String in WorldSave.PARTS:
		var node := get_tree().get_first_node_in_group(WorldSave.PARTS[key])
		if node != null and world.has(key):
			node.call(&"restore", world[key])


## Finds where the floor is in the camera's view. The room is framed by its
## floor, not by where the premises camera happens to point.
func _measure_floor() -> void:
	var grid := _room.get_node_or_null(^"FloorGrid")
	if grid == null:
		_centre = Vector2.ZERO
		_half_width = 0.0
		return
	var area: Rect2 = grid.get(&"area")
	var to_view := _home.affine_inverse()
	var middle := to_view * Vector3(area.get_center().x, 0.0, area.get_center().y)
	_centre = Vector2(middle.x, middle.y)
	_half_width = 0.0
	for corner: Vector2 in [area.position, area.end, Vector2(area.end.x, area.position.y), Vector2(area.position.x, area.end.y)]:
		_half_width = maxf(_half_width, absf((to_view * Vector3(corner.x, 0.0, corner.y)).x - middle.x))


## Fits the room out as a going concern: designs on sale, printers part way
## through jobs, stock on the shelf, orders waiting and staff on the books.
func _fill() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var bench: Workbench = get_tree().get_first_node_in_group(&"workbench")
	var rack: FilamentRack = get_tree().get_first_node_in_group(&"filament_rack")
	var shelf: StorageShelf = get_tree().get_first_node_in_group(&"print_storage")
	var colours: Array = Game.data.filaments[&"pla"]["colours"]
	var preset := StringName(Game.data.settings["default_preset"])

	var designs := _pick_designs(rng)
	for product in designs:
		if not Game.owned_designs.has(product):
			Game.owned_designs.append(product)
		for shop: Marketplace in Game.markets.values():
			if Game.unlocked(shop.config):
				shop.set_listing(product, true, shop.typical_price(product))
	for kind: StringName in Game.data.packaging:
		Game.packaging[kind] = 12

	var models := _pick_printers()
	for index in mini(PRINTERS, bench.free_spots()):
		var station := bench.install_printer(models[index % models.size()])
		if station == null:
			break
		station.load_spool(Spool.create(StringName(colours[rng.randi() % colours.size()])))
		station.repeat = true
		for attempt in designs.size():
			var product := designs[(index + attempt) % designs.size()]
			if station.print_problem(product, preset) == "":
				station.start_print(product, preset)
				# Each at a different point, the first about to finish.
				station.job.elapsed = station.job.duration * (0.97 if index == 0 else rng.randf_range(0.08, 0.9))
				break

	for index in mini(RACK_SPOOLS, rack.free_slots()):
		rack.store(Spool.create(StringName(colours[index % colours.size()])))
	for index in SHELF_PRINTS:
		var product := designs[index % designs.size()]
		if shelf.room_for(product) <= 0:
			break
		var colour: Array[StringName] = [StringName(colours[rng.randi() % colours.size()])]
		shelf.store(PrintedItem.create(product, colour, preset))
	# A day's orders already in, so there is packing to do from the off.
	for shop: Marketplace in Game.markets.values():
		if Game.unlocked(shop.config):
			for round in 3:
				shop.tick(Game.clock.minutes - GameClock.DAY, Game.clock.minutes, rng)

	Game.staff.refresh_applicants(rng, Game.tier)
	while not Game.staff.applicants.is_empty() and Game.staff.hire_problem(0, Game.staff_capacity()) == "":
		Game.staff.hire(0, Game.clock.minutes, Game.staff_capacity())


## Designs that print in plain PLA in an hour or two, a mix of them.
func _pick_designs(rng: RandomNumberGenerator) -> Array[StringName]:
	var pool: Array[StringName] = []
	for id: StringName in Game.data.products:
		var row: Dictionary = Game.data.products[id]
		var minutes := float(row["print_minutes"])
		if int(row["unlock_tier"]) <= Game.tier and int(row["colour_count"]) == 1 and row["allowed_filaments"] == ["pla"] \
				and minutes >= 50.0 and minutes <= 170.0 and not row.get("contract_only", false):
			pool.append(id)
	var picked: Array[StringName] = []
	while picked.size() < DESIGNS and not pool.is_empty():
		picked.append(pool.pop_at(rng.randi() % pool.size()))
	return picked


## The filament printers a business of this size could have, dearest last.
func _pick_printers() -> Array[StringName]:
	var found: Array[StringName] = []
	for id: StringName in Game.data.printers:
		var row: Dictionary = Game.data.printers[id]
		if row.get("kind", "fdm") == "fdm" and int(row["unlock_tier"]) <= Game.tier:
			found.append(id)
	return found


## The day is over: draws the curtain, builds the room afresh and opens again.
func _start_again() -> void:
	_restaging = true
	_set_hovered(null)
	var draw := Ui.tween(self)
	draw.tween_property(_curtain, "color:a", 1.0, CURTAIN_SECONDS)
	await draw.finished
	if _closed:
		return
	_room.queue_free()
	_room = null
	await get_tree().process_frame
	await _stage()
	_restaging = false
	reveal()


func _set_hovered(thing: Interactable) -> void:
	if not is_instance_valid(_hovered):
		_hovered = null
	if thing == _hovered:
		return
	if _hovered != null:
		_hovered.set_highlighted(false)
	_hovered = thing
	if _hovered != null:
		_hovered.set_highlighted(true)
	hovered.emit(_hovered)


## A slow drift, a lean away from the mouse, and a move in on what was clicked.
func _move_camera(delta: float) -> void:
	var view := get_viewport().get_visible_rect().size
	var now := Time.get_ticks_msec() / 1000.0
	var close := now < _close_until
	var size := minf(CLOSE_SIZE, _wide_size * 0.6) if close else _wide_size * (1.0 + 0.025 * sin(now * 0.13))
	camera.size = lerpf(camera.size, size, 1.0 - exp(-2.2 * delta))
	# Clamped: the mouse may be well outside the window.
	var mouse := (get_viewport().get_mouse_position() / view - Vector2(0.5, 0.5)).clampf(-0.5, 0.5)
	_lean = _lean.lerp(Vector2(-mouse.x, mouse.y) * (0.15 if close else 0.5), 1.0 - exp(-3.0 * delta))
	var drift := Vector2(sin(now * 0.11) * 0.45, sin(now * 0.07 + 1.0) * 0.2)
	var centre := _focus if close else _centre + drift
	# Looking to the left of the subject puts it to the right of the menu. A
	# small room goes as far over as it can with its far corner still in view.
	var width := camera.size * view.aspect()
	var shift := width * SHIFT
	if not close:
		shift = maxf(shift, width * (0.5 - EDGE) - _half_width)
	var target := centre + _lean - Vector2(shift, 0.0)
	var seen := _home.affine_inverse() * camera.position
	var at := Vector2(seen.x, seen.y).lerp(target, 1.0 - exp(-2.2 * delta))
	camera.position = _home.origin + _home.basis.x * at.x + _home.basis.y * at.y
