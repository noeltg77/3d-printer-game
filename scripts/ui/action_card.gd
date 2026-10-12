class_name ActionCard
extends CanvasLayer
## The card that pops out of an object when it is clicked: what it is, how it
## stands, and everything that can be done with it, each a single click away.
## A submenu is laid out as a headed group of its choices rather than hidden
## behind another click; only what is `tucked` (done rarely, or not to be
## undone) stays folded until opened. The card keeps itself up to date while
## it is open, so a print's progress bar moves.
##
## The InteractionController opens it and is told what was `chosen`.

signal chosen(action: Action)

const WIDTH := 356.0
## Gap kept between the card and the edges of the screen, and the mouse.
const MARGIN := 12.0
const REACH := 18.0
## Most of the screen's height the list may take before it scrolls.
const MAX_LIST := 0.62
const REFRESH_SECONDS := 0.4
const STAGGER_SECONDS := 0.022
## Icons that aren't an app's take their colours from here.
const PLAIN := {"colour": "E8792B", "dark": "B85A17"}

var _target: Interactable = null
var _agent: Agent = null
var _at := Vector2.ZERO
var _card: PanelContainer = null
var _list: VBoxContainer = null
var _scroll: ScrollContainer = null
var _accent := Ui.ORANGE
## Labels of the tucked groups the player has opened on this card.
var _unfolded: Array[String] = []
## What the card last drew, to tell when it needs drawing again.
var _drawn := ""
var _rows: Array[Control] = []
## Cards a newer one is about to take the place of.
var _stale: Array[PanelContainer] = []


func _ready() -> void:
	# Over the HUD, under the PC screen.
	layer = 2
	var tick := Timer.new()
	tick.wait_time = REFRESH_SECONDS
	tick.ignore_time_scale = true
	tick.autostart = true
	tick.timeout.connect(_refresh)
	add_child(tick)
	Game.changed.connect(_refresh)


func _unhandled_key_input(event: InputEvent) -> void:
	if is_open() and event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


## Every enabled task in a list of actions, submenus included.
static func doable(actions: Array[Action]) -> Array[Action]:
	var found: Array[Action] = []
	for action in actions:
		if not action.children.is_empty():
			found.append_array(doable(action.children))
		elif action.enabled and action.run.is_valid():
			found.append(action)
	return found


## The one thing there is to do, if a click on the object can only mean that:
## a single task on offer, and not one that is kept folded away. Otherwise null.
static func sole_action(actions: Array[Action]) -> Action:
	if doable(actions).size() != 1:
		return null
	for action in actions:
		if action.tucked:
			continue
		if action.children.is_empty() and action.enabled and action.run.is_valid():
			return action
		var inside := sole_action(action.children)
		if inside != null:
			return inside
	return null


func is_open() -> bool:
	return _target != null


## Opens the card for `target`, popping out beside `at` on the screen.
func open(target: Interactable, agent: Agent, at: Vector2) -> void:
	close()
	_target = target
	_agent = agent
	_at = at
	_unfolded.clear()
	_draw(true)


func close() -> void:
	_target = null
	_clear_stale()
	if _card != null:
		_dismiss(_card)
		_card = null


## A chip that floats up from `at` and fades: what a click just set going
## when there was no need to show the card.
func flash(text: String, at: Vector2) -> void:
	var chip := Ui.panel(Ui.text(text, 14, Ui.PAPER, 800), Ui.box(Ui.INK, 14, 14, 7, Ui.SHADE, 4))
	chip.theme = Ui.theme()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(chip)
	var room := chip.get_viewport_rect().size - chip.get_combined_minimum_size() - Vector2.ONE * MARGIN
	chip.position = (at + Vector2(REACH, -44)).clamp(Vector2.ONE * MARGIN, room)
	Ui.pop_in(chip, Vector2(0, 30))
	var drift := Ui.tween(chip)
	drift.tween_property(chip, "position:y", chip.position.y - 26.0, 1.1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	drift.parallel().tween_property(chip, "modulate:a", 0.0, 0.35).set_delay(0.75)
	drift.tween_callback(chip.queue_free)


func _refresh() -> void:
	if not is_open() or not is_inside_tree():
		return
	# The object may have gone since (a box unpacked, a printer sold), or the
	# player's attention: sat down at the PC, or the day ended.
	if not is_instance_valid(_target) or not _target.is_inside_tree() or _agent.held or Game.sleeping:
		close()
	elif _signature(_target.get_actions(_agent)) != _drawn:
		_draw(false)


## Builds the card from the object's actions as they are now. The first time
## it pops out; after that the new card quietly takes the old one's place.
func _draw(pop: bool) -> void:
	var actions := _target.get_actions(_agent)
	_drawn = _signature(actions)
	if _card != null:
		_stale.append(_card)
	var scrolled := _scroll.scroll_vertical if is_instance_valid(_scroll) else 0
	var colours: Dictionary = PcScreen.app(_target.card_icon())
	if colours.is_empty():
		colours = PLAIN
	_accent = Color.html(colours["colour"])

	_rows = []
	_list = Ui.vbox([], 8)
	_fill(_list, actions)
	_scroll = Ui.scroll(_list)
	_scroll.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var card := Ui.panel(Ui.vbox([_header(actions, Color.html(colours["dark"])), _scroll], 12), Ui.box(Ui.CREAM, 22, 16, 16, Ui.SHADE, 5))
	card.theme = Ui.theme()
	card.custom_minimum_size.x = WIDTH
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.modulate.a = 0.0
	_card = card
	add_child(card)
	# Wrapped lines only know their height once they have been given a width,
	# so the card is measured a couple of frames after it is built.
	for frame in 2:
		await get_tree().process_frame
		if card != _card:
			return
	_fit()
	# A long line can take a frame or two more to settle on its height.
	_list.minimum_size_changed.connect(_fit)
	_clear_stale()
	if not pop:
		card.modulate.a = 1.0
		_scroll.set_deferred(&"scroll_vertical", scrolled)
		return
	Ui.pop_in(card, (_at - card.position).clamp(Vector2.ZERO, card.size))
	for index in _rows.size():
		var row := _rows[index]
		row.modulate.a = 0.0
		Ui.tween(row).tween_property(row, "modulate:a", 1.0, 0.16).set_delay(0.05 + index * STAGGER_SECONDS)


## Sizes the card to its list, up to where it has to scroll, and stands it
## beside the click: to the right if there is room, and wholly on the screen.
func _fit() -> void:
	if _card == null:
		return
	var view := _card.get_viewport_rect().size
	_scroll.custom_minimum_size.y = minf(_list.get_combined_minimum_size().y, view.y * MAX_LIST)
	_card.reset_size()
	var across := _at.x + REACH if _at.x + REACH + _card.size.x <= view.x - MARGIN else _at.x - REACH - _card.size.x
	_card.position = Vector2(across, _at.y - 40.0).clamp(Vector2.ONE * MARGIN, (view - _card.size - Vector2.ONE * MARGIN).max(Vector2.ONE * MARGIN))


func _clear_stale() -> void:
	for card in _stale:
		card.queue_free()
	_stale.clear()


## Shrinks a card away and frees it.
func _dismiss(card: PanelContainer) -> void:
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var away := Ui.tween(card).set_parallel()
	away.tween_property(card, "scale", Vector2.ONE * 0.94, 0.09)
	away.tween_property(card, "modulate:a", 0.0, 0.09)
	away.chain().tween_callback(card.queue_free)


func _choose(action: Action) -> void:
	close()
	chosen.emit(action)


func _unfold(label: String) -> void:
	if _unfolded.has(label):
		_unfolded.erase(label)
	else:
		_unfolded.append(label)
	_draw(false)


## The top of the card: the object's icon and name, how much there is to do, and a way out.
func _header(actions: Array[Action], dark: Color) -> Control:
	var count := doable(actions).size()
	var summary := "Nothing to do here just now" if count == 0 else "%d thing%s you can do" % [count, "" if count == 1 else "s"]
	var names := Ui.vbox([Ui.title(_target.display_name, 20), Ui.text(summary, 12, Ui.MUTED, 700)], 0)
	(names.get_child(0) as Label).text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	(names.get_child(0) as Label).clip_text = true
	names.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var shut := Ui.button("", close, Ui.SOFT, Ui.INK, 32, 10)
	shut.custom_minimum_size.x = 32
	shut.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	shut.tooltip_text = "Close"
	var cross := Ui.icon("close", 14, Ui.INK)
	cross.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	shut.add_child(cross)
	return Ui.hbox([Ui.icon_tile(_target.card_icon(), 42, 24, _accent, Ui.PAPER, 13, dark), Ui.grow(names), shut], 12)


## Lays a list of actions out in `into`: tasks as rows to click, submenus as
## headed groups, and anything that can't be clicked gathered into notes.
func _fill(into: VBoxContainer, actions: Array[Action]) -> void:
	var notes: VBoxContainer = null
	for action in actions:
		var plain := action.children.is_empty() and not (action.enabled and action.run.is_valid())
		if not plain:
			notes = null
		if plain:
			if notes == null:
				notes = Ui.vbox([], 7)
				into.add_child(_keep(Ui.panel(notes, Ui.box(Ui.INSET, 12, 12, 9))))
			notes.add_child(_note(action))
		elif action.children.is_empty():
			into.add_child(_keep(_row(action.label, _choose.bind(action), action.tucked)))
		elif action.tucked:
			_fold(into, action)
		else:
			into.add_child(_keep(_heading(action)))
			_fill(into, action.children)


## A line that only says something. One with a task behind it that can't be
## done yet is fainter than one that reports how things stand.
func _note(action: Action) -> Control:
	var line := Ui.wrap(Ui.text(action.label, 13, Ui.INK if not action.run.is_valid() else Ui.MUTED, 700))
	if action.progress < 0.0:
		return line
	return Ui.vbox([line, Ui.bar(action.progress, Ui.GREEN, Ui.TRACK, 8)], 6)


func _heading(action: Action) -> Control:
	var rule := ColorRect.new()
	rule.color = Ui.LINE
	rule.custom_minimum_size.y = 2
	rule.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var count := doable(action.children).size()
	var tally := Ui.pill(str(count), Ui.PAPER, _accent if count > 0 else Ui.CHIP_MUTED, 11)
	return Ui.margin(Ui.hbox([Ui.text(action.label, 12, Ui.MUTED, 800), tally, Ui.grow(rule)], 8), 2, 4, 2, 0)


## A tucked submenu: a quiet row that opens in place to show what is inside.
func _fold(into: VBoxContainer, action: Action) -> void:
	var open_now := _unfolded.has(action.label)
	var row := _row(action.label, _unfold.bind(action.label), true, doable(action.children).size(), open_now)
	into.add_child(_keep(row))
	if open_now:
		var inside := Ui.vbox([], 8)
		_fill(inside, action.children)
		into.add_child(Ui.margin(inside, 14, 0, 0, 2))


## A row to click. `quiet` ones sit back for what is done rarely; `count`
## adds a bubble saying how many tasks wait inside; `turned` points the arrow down.
func _row(label: String, on_pressed: Callable, quiet := false, count := 0, turned := false) -> Control:
	var words := Ui.wrap(Ui.text(label, 13 if quiet else 14, Ui.INK, 700 if quiet else 800))
	var arrow := Ui.icon("chevron", 12, Ui.MUTED)
	arrow.pivot_offset = Vector2(6, 6)
	arrow.rotation = PI / 2.0 if turned else 0.0
	var chip_style := Ui.box(Ui.CLEAR if quiet else Ui.SOFT, 12, 6, 6)
	var chip := Ui.panel(arrow, chip_style)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var parts: Array = [words]
	if count > 0:
		parts.append(Ui.pill(str(count), Ui.PAPER, _accent, 11))
	parts.append(chip)
	var rest := Ui.SOFT if quiet else Ui.WHITE
	var style := Ui.box(rest, 12, 12, 8 if quiet else 9, Ui.LINE, 0 if quiet else 3)
	var row := Ui.panel(Ui.hbox(parts, 10), style)
	Ui.clickable(row, on_pressed)
	var lit := _accent.lerp(Ui.WHITE, 0.86)
	row.mouse_entered.connect(func() -> void:
		var glow := Ui.tween(row).set_parallel()
		glow.tween_property(style, "bg_color", lit, 0.1)
		glow.tween_property(style, "border_color", _accent.lerp(Ui.WHITE, 0.55), 0.1)
		glow.tween_property(chip_style, "bg_color", _accent, 0.1)
		glow.tween_property(arrow, "modulate", Ui.PAPER, 0.1))
	row.mouse_exited.connect(func() -> void:
		var fade := Ui.tween(row).set_parallel()
		fade.tween_property(style, "bg_color", rest, 0.14)
		fade.tween_property(style, "border_color", Ui.LINE, 0.14)
		fade.tween_property(chip_style, "bg_color", Ui.CLEAR if quiet else Ui.SOFT, 0.14)
		fade.tween_property(arrow, "modulate", Ui.MUTED, 0.14))
	return row


## Notes a piece of the list so it can fade in with the rest. Returns it.
func _keep(piece: Control) -> Control:
	_rows.append(piece)
	return piece


## Everything about a list of actions that shows on the card, as one string.
func _signature(actions: Array[Action]) -> String:
	var parts: PackedStringArray = []
	for action in actions:
		parts.append("%s|%s|%d|%s{%s}" % [action.label, action.enabled, roundi(action.progress * 200.0), action.tucked, _signature(action.children)])
	return "\n".join(parts)
