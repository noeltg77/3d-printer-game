class_name PauseMenu
extends Control
## The menu Escape opens over a game: carry on, save, keep a copy, load
## another game, or leave for the main menu or the desktop. The game is paused
## while it is open. A save can only be written between tasks, so when the
## character is in the middle of one the game is let run until it is done.

var _card: PanelContainer
var _body: VBoxContainer
var _status: Label
## The speed the game was running at when the menu opened.
var _speed_before := 1
## True while waiting for a job to finish so the game can be saved.
var _waiting := false
var _listing := false


func _init() -> void:
	theme = Ui.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(Ui.TASKBAR, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_body = Ui.vbox([], 12)
	_card = Ui.panel(_body, Ui.box(Ui.CREAM, 26, 28, 26, Ui.SHADE, 6))
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centre.add_child(_card)
	add_child(centre)


func toggle() -> void:
	if not visible:
		open()
	elif _listing:
		_show_list(false)
	else:
		close()


func open() -> void:
	if visible:
		return
	_speed_before = Game.speed
	if not Game.sleeping:
		Game.set_speed(0)
	_listing = false
	visible = true
	_build()
	await get_tree().process_frame
	Ui.pop_in(_card, _card.size / 2.0)


## Puts the menu away. `resume` sets the game going as it was.
func close(resume := true) -> void:
	if not visible:
		return
	visible = false
	_waiting = false
	if resume and not Game.sleeping:
		Game.set_speed(_speed_before)


func _build(status := "") -> void:
	Ui.clear(_body)
	if _listing:
		_card.custom_minimum_size = Vector2(680, 0)
		var list := SaveList.new()
		list.current = Game.save_path
		list.picked.connect(_load)
		var scroller := Ui.scroll(list)
		scroller.custom_minimum_size.y = 440
		_body.add_child(Ui.hbox([Ui.title("Load a game", 26), null,
			Ui.button("Back", _show_list.bind(false), Ui.SOFT, Ui.INK, 38, 12, Ui.CLEAR, 14)], 8))
		_body.add_child(Ui.wrap(Ui.text("This game is saved first, if the job in hand allows.", 13, Ui.MUTED)))
		_body.add_child(scroller)
		return
	_card.custom_minimum_size = Vector2(380, 0)
	var saving := Game.save_path != ""
	_body.add_child(Ui.vbox([
		Ui.title("Paused", 30),
		Ui.text("%s  ·  %s" % [Game.business_name, Game.clock.label()], 14, Ui.MUTED),
	], 0))
	_body.add_child(_button("Carry on", close, true))
	var save := _button("Save game", _save)
	var copy := _button("Keep a copy", _keep_copy)
	copy.tooltip_text = "Saves this moment as a game of its own, to come back to. You carry on in this one."
	save.disabled = not saving
	copy.disabled = not saving
	_body.add_child(save)
	_body.add_child(copy)
	_body.add_child(_button("Load a game", _show_list.bind(true)))
	_body.add_child(_button("Main menu", _leave.bind(true)))
	_body.add_child(_button("Quit to desktop", _leave.bind(false)))
	if status == "" and not saving:
		status = "Saving is switched off for this run."
	_status = Ui.wrap(Ui.text(status, 13, Ui.MUTED))
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.custom_minimum_size.y = 36
	_body.add_child(_status)


func _button(label: String, on_pressed: Callable, primary := false) -> Button:
	var button := Ui.button(label, on_pressed, Ui.ORANGE if primary else Ui.WHITE, Ui.WHITE if primary else Ui.INK,
		52, 16, Ui.ORANGE_DARK if primary else Ui.LINE, 18, true)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# "Carry on" always works: it calls off a save that is being waited for.
	button.disabled = _waiting and not primary
	return button


func _show_list(on: bool) -> void:
	_listing = on
	_build()


## Writes the game to its file, letting it run until the character is between
## tasks if need be. True once it is saved; false if it can't be, or the menu
## was closed while waiting.
func _saved() -> bool:
	var world: WorldSave = get_tree().get_first_node_in_group(&"world_save")
	if world == null or Game.save_path == "":
		return false
	if world.save_now():
		return true
	_waiting = true
	_build("Saving as soon as the job in hand is done...")
	if not Game.sleeping:
		Game.set_speed(maxi(_speed_before, 1))
	await world.saved_now
	if not _waiting:
		return false
	_waiting = false
	if not Game.sleeping:
		Game.set_speed(0)
	return true


func _save() -> void:
	if await _saved():
		_build("Saved.")


func _keep_copy() -> void:
	if await _saved():
		_build("Copy kept. Find it under Load a game." if SaveSlots.copy(Game.save_path) != "" else "The copy couldn't be made.")


func _load(slot: Dictionary) -> void:
	var world: WorldSave = get_tree().get_first_node_in_group(&"world_save")
	if world != null:
		world.save_now()
	Screens.go(Game.scene_of(slot), "Opening %s" % slot["name"], Game.begin.bind(slot["path"]))


## Saves, then goes to the main menu or closes the game.
func _leave(to_menu: bool) -> void:
	if Game.save_path != "" and not await _saved():
		return
	if to_menu:
		Screens.go(Screens.MENU, "Shutting up shop")
	else:
		get_tree().quit()
