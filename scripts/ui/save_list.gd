class_name SaveList
extends VBoxContainer
## The saved games as a list of cards: a picture of the room, the business,
## how far it has got and when it was last played, with buttons to load one or
## delete it. Used on the main menu and in the pause menu.

## A save was chosen to be loaded: its row from SaveSlots.list().
signal picked(slot: Dictionary)

const PICTURE := Vector2(176, 99)

## Path of the save being played, which is marked and can't be deleted.
var current := ""
## Path of the save "Delete" has been pressed on, waiting to be confirmed.
var _doomed := ""


func _ready() -> void:
	add_theme_constant_override(&"separation", 12)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	refresh()


func refresh() -> void:
	Ui.clear(self)
	var slots := SaveSlots.list()
	if slots.is_empty():
		add_child(Ui.wrap(Ui.text("No saved games yet. Start a new business and it will save itself as you go.", 15, Ui.MUTED)))
		return
	for slot in slots:
		add_child(_card(slot))


func _card(slot: Dictionary) -> Control:
	var readable := int(slot["version"]) == Game.SAVE_VERSION
	var place: Dictionary = Game.data.premises.get(StringName(slot["premises"]), {})
	var title := Ui.hbox([Ui.title(slot["name"], 19)], 8)
	if slot["path"] == current:
		title.add_child(Ui.pill("Playing now", Ui.GREEN_DARK, Ui.GREEN_SOFT))
	var details := Ui.vbox([
		title,
		Ui.text("%s  ·  %s  ·  %s" % [SaveSlots.day_label(slot["minutes"]), place.get("name", "Somewhere"), Money.format(slot["cash_pence"])], 14, Ui.INK, 800),
		Ui.text("Last played %s" % SaveSlots.when_label(slot["saved_unix"]), 13, Ui.MUTED),
	], 3)
	details.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	Ui.grow(details)

	var buttons: Control
	if _doomed == slot["path"]:
		buttons = Ui.vbox([
			Ui.button("Delete for good", _delete.bind(slot["path"]), Ui.RED, Ui.WHITE, 38, 12, Ui.RED_DARK, 13),
			Ui.button("Keep it", _doom.bind(""), Ui.SOFT, Ui.INK, 38, 12, Ui.CLEAR, 13),
		], 6)
	else:
		var load_button := Ui.button("Load" if readable else "Too old", picked.emit.bind(slot), Ui.GREEN, Ui.WHITE, 38, 12, Ui.GREEN_DARK, 14)
		load_button.disabled = not readable or slot["path"] == current
		var delete := Ui.button("Delete", _doom.bind(slot["path"]), Ui.CLEAR, Ui.MUTED, 30, 10, Ui.CLEAR, 13)
		delete.disabled = slot["path"] == current
		buttons = Ui.vbox([load_button, delete], 4)
	buttons.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	buttons.custom_minimum_size.x = 132
	return Ui.card(Ui.hbox([_picture(slot["thumbnail"]), details, buttons], 14), 18, 12, Ui.LINE)


## The picture taken when the save was written, or a plain tile if it has none.
func _picture(path: String) -> Control:
	var frame := Ui.panel(null, Ui.box(Ui.INSET, 12, 0, 0))
	frame.custom_minimum_size = PICTURE
	frame.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var image := Image.load_from_file(path) if FileAccess.file_exists(path) else null
	if image == null:
		frame.add_child(Ui.icon("home", 36, Ui.TRACK))
		return frame
	var picture := TextureRect.new()
	picture.texture = ImageTexture.create_from_image(image)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(picture)
	return frame


func _doom(path: String) -> void:
	_doomed = path
	refresh()


func _delete(path: String) -> void:
	SaveSlots.remove(path)
	_doomed = ""
	refresh()
