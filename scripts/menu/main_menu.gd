extends Node
## The front of the game: the opening, where its name prints itself over a
## dark screen, then the main menu over the player's own shop, really running
## (the Showcase; a busy workshop until there is a saved game). From here a game is carried on, started or loaded; Screens then
## swaps to its premises behind the loading screen.
##
## Dev: `--no-splash` after `--` goes straight to the menu, for screenshots.

const TAGLINE := "From one printer in the garage to a factory floor of them."
const HINT := "That workshop is really running. Hover over a printer, or click one for a closer look."
const OWN_HINT := "That's your shop, ticking over while you're away. None of it counts until you carry on."
const COLUMN_LEFT := 96
const COLUMN_WIDTH := 344
const PANEL_WIDTH := 640
const SPLASH_SECONDS := 2.2
## Real seconds a line of news from the workshop stays up.
const NEWS_SECONDS := 5.0
const MUSIC := &"menu_theme"

var _showcase: Showcase
var _ui: Control
var _column: VBoxContainer
var _buttons: VBoxContainer
var _side: Control
var _panel: PanelContainer = null
var _open := ""
var _splash: Control = null
var _hover: PanelContainer
var _news: Label
var _news_chip: PanelContainer
var _clock: Label
var _news_until := 0.0
var _name_box: LineEdit = null
## The whirr of the name being printed, during the opening.
var _printing: AudioStreamPlayer = null


func _ready() -> void:
	_showcase = Showcase.new()
	add_child(_showcase)
	_showcase.hovered.connect(_on_hovered)

	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	_ui = Control.new()
	_ui.theme = Ui.theme()
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_ui)
	_ui.add_child(_scrim())
	_build_column()
	_build_corner()
	_build_hover()
	Game.notified.connect(_on_news)
	Game.changed.connect(_refresh_buttons)

	if Screens.seen_splash or OS.get_cmdline_user_args().has("--no-splash"):
		_showcase.reveal(0.01 if not Screens.seen_splash else Showcase.CURTAIN_SECONDS)
		Sound.music(MUSIC)
		_arrive(false)
	else:
		_play_splash()
	Screens.seen_splash = true


func _process(_delta: float) -> void:
	var minute := int(Game.clock.minute_of_day)
	_clock.text = "%02d:%02d" % [minute / 60, minute % 60]
	if _news_chip.visible and Time.get_ticks_msec() / 1000.0 > _news_until:
		_news_chip.visible = false
	if _hover.visible:
		_place_hover()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") and _open != "":
		_show_panel("")
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	# Any key or click cuts the opening short.
	var pressed := (event is InputEventKey or event is InputEventMouseButton) and event.is_pressed()
	if _splash != null and pressed:
		_end_splash()
		get_viewport().set_input_as_handled()


## Darkens the left of the picture so the menu reads over whatever is behind.
func _scrim() -> Control:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.3, 0.62])
	gradient.colors = PackedColorArray([Color(Ui.TASKBAR, 0.94), Color(Ui.TASKBAR, 0.72), Color(Ui.TASKBAR, 0.0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 256
	texture.height = 4
	var scrim := TextureRect.new()
	scrim.texture = texture
	scrim.stretch_mode = TextureRect.STRETCH_SCALE
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return scrim


func _build_column() -> void:
	var tagline := Ui.text(TAGLINE, 17, Ui.CHIP_TEXT)
	tagline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tagline.custom_minimum_size.x = COLUMN_WIDTH
	tagline.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_buttons = Ui.vbox([], 12)
	_buttons.custom_minimum_size.x = COLUMN_WIDTH
	_buttons.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_column = Ui.vbox([PrintLogo.new(0.86), tagline, Ui.margin(_buttons, 0, 22, 0, 0)], 6)
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	_column.alignment = BoxContainer.ALIGNMENT_CENTER
	_column.offset_left = COLUMN_LEFT
	_column.offset_right = COLUMN_LEFT + 560
	_ui.add_child(_column)

	# Where the panel a button opens goes: beside the buttons, clear of the logo.
	_side = Control.new()
	_side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_side.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	_side.offset_left = COLUMN_LEFT + COLUMN_WIDTH + 56
	_side.offset_right = _side.offset_left + PANEL_WIDTH
	_ui.add_child(_side)
	_refresh_buttons()


## The buttons, afresh: "Continue" only when there is a game to carry on.
func _refresh_buttons() -> void:
	if _buttons == null or not is_inside_tree():
		return
	Ui.clear(_buttons)
	var latest := SaveSlots.latest()
	if not latest.is_empty() and int(latest["version"]) == Game.SAVE_VERSION:
		_buttons.add_child(_button("Continue", _play.bind(latest), true))
		var about := Ui.text("%s  ·  %s  ·  %s" % [latest["name"], SaveSlots.day_label(latest["minutes"]), Money.format(latest["cash_pence"])],
			14, Ui.CHIP_TEXT, 800)
		about.clip_text = true
		_buttons.add_child(Ui.margin(about, 6, -4, 0, 8))
	_buttons.add_child(_button("New game", _show_panel.bind("new"), latest.is_empty(), _open == "new"))
	var load_game := _button("Load game", _show_panel.bind("load"), false, _open == "load")
	load_game.disabled = latest.is_empty()
	_buttons.add_child(load_game)
	_buttons.add_child(_button("Settings", _show_panel.bind("settings"), false, _open == "settings"))
	_buttons.add_child(_button("Quit", get_tree().quit))


func _button(label: String, on_pressed: Callable, primary := false, chosen := false) -> Button:
	var bg := Ui.ORANGE if primary else (Ui.AMBER_SOFT if chosen else Ui.CREAM)
	var button := Ui.button(label, on_pressed, bg, Ui.WHITE if primary else Ui.INK, 60, 18,
		Ui.ORANGE_DARK if primary else Color("B9AE9C"), 22, true)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return button


## Bottom of the screen: a word on what the picture is, and news from it.
func _build_corner() -> void:
	var hint := Ui.text(OWN_HINT if _showcase.own_shop else HINT, 13, Ui.CHIP_MUTED)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hint.position += Vector2(COLUMN_LEFT, -28)
	hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_ui.add_child(hint)

	_clock = Ui.text("", 14, Ui.PAPER, 800)
	var live := Ui.panel(Ui.hbox([Ui.pips(1, 1, Ui.ORANGE, Ui.ORANGE, 9), Ui.text("%s cam" % Game.premises_row()["name"], 13, Ui.CHIP_TEXT, 800), _clock], 8),
		Ui.box(Ui.TASKBAR, 14, 14, 8))
	live.size_flags_horizontal = Control.SIZE_SHRINK_END
	_news = Ui.text("", 14, Ui.INK, 800)
	_news_chip = Ui.panel(_news, Ui.box(Ui.CREAM, 14, 14, 8, Ui.SHADE, 4))
	_news_chip.size_flags_horizontal = Control.SIZE_SHRINK_END
	_news_chip.visible = false
	var corner := Ui.vbox([_news_chip, live], 8)
	corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	corner.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	corner.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	corner.grow_vertical = Control.GROW_DIRECTION_BEGIN
	corner.position += Vector2(-24, -24)
	_ui.add_child(corner)


func _build_hover() -> void:
	_hover = Ui.panel(Ui.vbox([Ui.text("", 14, Ui.INK, 800), Ui.text("", 12, Ui.MUTED, 700)], 0), Ui.box(Ui.CREAM, 12, 12, 7, Ui.SHADE, 4))
	_hover.visible = false
	_hover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_hover)


func _on_hovered(thing: Interactable) -> void:
	_hover.visible = thing != null and _splash == null
	_hover.set_meta(&"thing", thing)
	if thing != null:
		_place_hover()


## Keeps the label by the mouse and what it says up to date.
func _place_hover() -> void:
	var thing: Interactable = _hover.get_meta(&"thing", null)
	if not is_instance_valid(thing):
		_hover.visible = false
		return
	var lines := _hover.get_child(0)
	(lines.get_child(0) as Label).text = thing.display_name
	var detail := _showcase.describe(thing)
	(lines.get_child(1) as Label).text = detail
	(lines.get_child(1) as Label).visible = detail != ""
	_hover.reset_size()
	_hover.position = _ui.get_local_mouse_position() + Vector2(18, 20)


func _on_news(text: String, _tone: StringName) -> void:
	# Not over the player's own shop: none of it has really happened to them.
	if _splash != null or _showcase.own_shop:
		return
	_news.text = text
	_news_until = Time.get_ticks_msec() / 1000.0 + NEWS_SECONDS
	if not _news_chip.visible:
		_news_chip.visible = true
		Ui.pop_in.call_deferred(_news_chip, Vector2(_news_chip.size.x, _news_chip.size.y / 2.0))


## The opening: the name prints itself on a dark screen, which then lifts to
## show the workshop as the menu comes in.
func _play_splash() -> void:
	_column.modulate.a = 0.0
	_splash = Control.new()
	_splash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_splash.mouse_filter = Control.MOUSE_FILTER_STOP
	var dark := ColorRect.new()
	dark.color = Ui.TASKBAR
	dark.set_anchors_preset(Control.PRESET_FULL_RECT)
	dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_splash.add_child(dark)
	var logo := PrintLogo.new(1.25)
	logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var skip := Ui.text("Click to skip", 13, Ui.CHIP_MUTED)
	skip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centre.add_child(Ui.vbox([logo, Ui.margin(skip, 0, 30, 0, 0)], 0))
	_splash.add_child(centre)
	_ui.add_child(_splash)
	var splash := _splash
	logo.play(SPLASH_SECONDS)
	_printing = Sound.start_loop("printer/motion_a", -10.0)
	await logo.printed
	if _splash == splash:
		_stop_printing()
		Sound.ui(&"chime")
	# Held until the workshop behind is ready to be seen.
	while not _showcase.ready_to_show:
		await get_tree().process_frame
	await get_tree().create_timer(0.6, true, false, true).timeout
	if _splash == splash:
		_end_splash()


## Ends the whirr of the name being printed, if it is still going.
func _stop_printing() -> void:
	if _printing != null:
		Sound.fade_out(_printing, 0.25)
		_printing = null


func _end_splash() -> void:
	var splash := _splash
	_splash = null
	_stop_printing()
	Sound.music(MUSIC, 2.0)
	_showcase.reveal(0.01)
	var lift := Ui.tween(self)
	lift.tween_property(splash, "modulate:a", 0.0, 0.7)
	lift.tween_callback(splash.queue_free)
	_arrive(true)


## Brings the menu in from the left.
func _arrive(after_splash: bool) -> void:
	_column.modulate.a = 0.0
	_column.position.x = COLUMN_LEFT - 48.0
	var slide := Ui.tween(self).set_parallel()
	var wait := 0.35 if after_splash else 0.15
	slide.tween_property(_column, "modulate:a", 1.0, 0.45).set_delay(wait)
	slide.tween_property(_column, "position:x", float(COLUMN_LEFT), 0.55).set_delay(wait).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Opens one of the panels beside the buttons, or shuts it with "" or the
## name of the one already open.
func _show_panel(which: String) -> void:
	_open = "" if which == _open else which
	Sound.ui(&"back" if _open == "" else &"open")
	if _panel != null:
		_panel.queue_free()
		_panel = null
	_name_box = null
	_refresh_buttons()
	if _open == "":
		return
	var content: Control
	match _open:
		"new":
			content = _new_game_panel()
		"load":
			content = _load_panel()
		_:
			content = _settings_panel()
	_panel = Ui.panel(content, Ui.box(Ui.CREAM, 26, 28, 26, Ui.SHADE, 6))
	_panel.custom_minimum_size.x = PANEL_WIDTH
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centre.add_child(_panel)
	_side.add_child(centre)
	_panel.tree_exited.connect(centre.queue_free)
	await get_tree().process_frame
	if _panel != null:
		Ui.pop_in(_panel, Vector2(0.0, _panel.size.y / 2.0))
	if _name_box != null:
		_name_box.grab_focus()


func _heading(title: String) -> Control:
	return Ui.hbox([Ui.title(title, 28), null, Ui.button("Close", _show_panel.bind(""), Ui.SOFT, Ui.INK, 36, 12, Ui.CLEAR, 13)], 8)


func _new_game_panel() -> Control:
	var start: Dictionary = Game.data.settings["start"]
	_name_box = LineEdit.new()
	_name_box.placeholder_text = Game.data.settings["business_name"]
	_name_box.max_length = 28
	_name_box.custom_minimum_size.y = 52
	_name_box.text_submitted.connect(func(_text: String) -> void: _start_new())
	return Ui.vbox([
		_heading("Start a new business"),
		Ui.wrap(Ui.text("You begin in the garage with %s in the bank, one design and room for a printer or two. It saves itself as you go, in a slot of its own."
			% Money.format(int(start["cash_pence"])), 15, Ui.MUTED)),
		Ui.margin(Ui.text("What is it called?", 15, Ui.INK, 800), 0, 8, 0, 0),
		_name_box,
		Ui.margin(Ui.button("Open for business", _start_new, Ui.ORANGE, Ui.WHITE, 56, 16, Ui.ORANGE_DARK, 20, true), 0, 10, 0, 0),
	], 10)


func _load_panel() -> Control:
	var list := SaveList.new()
	list.picked.connect(_play)
	list.child_order_changed.connect(_refresh_buttons, CONNECT_DEFERRED)
	var scroller := Ui.scroll(list)
	scroller.custom_minimum_size.y = 470
	return Ui.vbox([_heading("Saved games"), scroller], 14)


func _settings_panel() -> Control:
	var options := Ui.hbox([], 10)
	for code: String in Money.currencies():
		var spec: Dictionary = Money.currencies()[code]
		var chosen := code == Money.currency
		var option := Ui.button("%s  %s" % [spec["symbol"], code], _set_currency.bind(code), Ui.INK if chosen else Ui.SOFT,
			Ui.PAPER if chosen else Ui.INK, 52, 16, Color("0F171B") if chosen else Ui.TRACK, 18, true)
		Ui.grow(option)
		options.add_child(option)
	return Ui.vbox([
		_heading("Settings"),
		Ui.title("Currency", 20),
		Ui.wrap(Ui.text("The money you think in. The business runs in pounds underneath, so changing this never alters what anything costs.", 14, Ui.MUTED)),
		options,
		Ui.margin(Ui.title("Sound", 20), 0, 8, 0, 0),
		VolumeControls.new(),
	], 12)


func _set_currency(code: String) -> void:
	Game.set_currency(code)
	_reopen_settings()


## Draws the settings panel afresh after one of them has changed.
func _reopen_settings() -> void:
	if _open != "settings" or _panel == null:
		return
	var content := _settings_panel()
	Ui.clear(_panel)
	_panel.add_child(content)


func _start_new() -> void:
	var called := _name_box.text if _name_box != null else ""
	var start: Dictionary = Game.data.settings["start"]
	var scene: String = Game.data.premises[StringName(start["premises"])]["scene"]
	Sound.ui(&"start")
	Screens.go(scene, "Unlocking the garage", _begin.bind(SaveSlots.fresh_path(), called))


## Carries on a saved game: a row from SaveSlots.list().
func _play(slot: Dictionary) -> void:
	Sound.ui(&"start")
	Screens.go(Game.scene_of(slot), "Opening %s" % slot["name"], _begin.bind(slot["path"], ""))


## Run once the loading screen covers the window: the show stops and the
## Game is pointed at the save.
func _begin(path: String, called: String) -> void:
	_showcase.close()
	Sound.music(&"")
	Game.begin(path, called)
