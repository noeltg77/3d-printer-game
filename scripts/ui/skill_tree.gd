class_name SkillTree
extends Control
## The courses of data/research.json drawn as a skill tree: the owner on the
## left, a bough for each branch, and a round badge for every course, joined to
## the one it follows. A badge shows where its course stands (learned, being
## studied, open or locked) and clicking one picks it. It reads `Game.research`
## each time it draws, so a redraw is all it needs to stay up to date.

signal picked(course: StringName)

enum State { LOCKED, OPEN, STARTED, LEARNED }

const TRACK := Color("E6E7F5")
const SHADOW := Color("DCDDEE")
const LOCKED_FILL := Color("EEEEF6")
const LOCKED_ICON := Color("A4A7C2")
const LOCK_TEXT := Color("5A4A1C")
## Room kept for the owner's badge and the branch names before the first course.
const TRUNK := 250.0
const EDGE := 84.0
const LABEL_ROOM := 46.0
const CURVE_STEPS := 28

## The course with the ring round it.
var selected: StringName = &"":
	set(value):
		selected = value
		queue_redraw()

var _hover: StringName = &""
## Where each course's badge is centred, by id.
var _spots: Dictionary[StringName, Vector2] = {}
var _icons: Dictionary[String, Texture2D] = {}
var _root := Vector2.ZERO
var _radius := 40.0
var _column := 200.0


func _init() -> void:
	custom_minimum_size = Vector2(720, 460)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_exited.connect(func() -> void: _set_hover(&""))


## Where a course stands for the owner.
static func state_of(course: StringName) -> State:
	var research := Game.research
	if research.is_learned(course):
		return State.LEARNED
	if research.is_started(course):
		return State.STARTED
	var problem := Game.study_problem(course)
	return State.OPEN if problem == "" or problem == "Not enough cash" else State.LOCKED


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_lay_out()
		queue_redraw()


func _process(_delta: float) -> void:
	# Only the badges that can be studied move, so only they need the redraws.
	if not is_visible_in_tree():
		return
	for id: String in Game.data.courses:
		if state_of(StringName(id)) == State.OPEN:
			queue_redraw()
			return


## How many courses come before this one in its branch.
func _depth(row: Dictionary) -> int:
	var depth := 0
	var before := String(row.get("requires", ""))
	while before != "" and depth < 32:
		depth += 1
		before = String(Game.data.courses[before].get("requires", ""))
	return depth


func _lay_out() -> void:
	_spots.clear()
	var branches: Array = Game.data.branches.keys()
	if branches.is_empty() or size.x <= 0.0:
		return
	var deepest := 1
	# Courses sharing a branch and a depth sit one above the other.
	var groups: Dictionary[Vector2i, Array] = {}
	for row: Dictionary in Game.data.courses.values():
		var depth := _depth(row)
		deepest = maxi(deepest, depth)
		var key := Vector2i(branches.find(row["branch"]), depth)
		if not groups.has(key):
			groups[key] = []
		groups[key].append(row["id"])
	var band := size.y / branches.size()
	_column = (size.x - TRUNK - EDGE) / deepest
	_radius = clampf(minf((band - LABEL_ROOM) * 0.42, _column * 0.24), 24.0, 46.0)
	_root = Vector2(EDGE * 0.6, size.y / 2.0)
	for key in groups:
		var ids: Array = groups[key]
		# A gentle zigzag along the bough, so it reads as a branch and not a row.
		var sway := (-0.06 if key.y % 2 == 0 else 0.06) * band
		for index in ids.size():
			var spread := (index - (ids.size() - 1) / 2.0) * band / ids.size()
			_spots[StringName(ids[index])] = Vector2(TRUNK + _column * key.y,
				band * (key.x + 0.5) - LABEL_ROOM * 0.55 + sway + spread)


func _draw() -> void:
	if _spots.is_empty():
		_lay_out()
	var research := Game.research
	var heading := Ui.font(Ui.HEADING, 600)
	var body := Ui.font(Ui.BODY, 800)
	var beat := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 2.6)

	# The boughs first, so every badge sits on top of its joins.
	for row: Dictionary in Game.data.courses.values():
		var id := StringName(row["id"])
		var colour := Color.html(Game.data.branches[row["branch"]]["colour"])
		var before := StringName(row.get("requires", ""))
		var from := _root if before == &"" else _spots[before]
		var path := _curve(from, _spots[id])
		match state_of(id):
			State.LEARNED:
				draw_polyline(path, colour, 7.0, true)
			State.LOCKED:
				_draw_dashes(path, SHADOW, 5.0)
			_:
				draw_polyline(path, colour.lerp(Color.WHITE, 0.45), 7.0, true)
		if before == &"":
			_draw_pill(path[CURVE_STEPS / 2], Game.data.branches[row["branch"]]["name"], colour, heading)

	# The owner, where every branch starts.
	draw_circle(_root + Vector2(0, 4), _radius * 0.8, SHADOW, true, -1.0, true)
	draw_circle(_root, _radius * 0.8, Ui.INK, true, -1.0, true)
	_draw_icon("skillshed", _root, _radius * 0.85, Ui.PAPER)

	for row: Dictionary in Game.data.courses.values():
		var id := StringName(row["id"])
		var colour := Color.html(Game.data.branches[row["branch"]]["colour"])
		var at := _spots[id]
		var state := state_of(id)
		var radius := _radius * (1.07 if id == _hover else 1.0)
		if state == State.OPEN:
			draw_circle(at, radius + 5.0 + 9.0 * beat, Color(colour, 0.22 * (1.0 - beat)), true, -1.0, true)
		draw_circle(at + Vector2(0, 4), radius, SHADOW, true, -1.0, true)
		match state:
			State.LEARNED:
				draw_circle(at, radius, colour, true, -1.0, true)
				_draw_icon(row["icon"], at, radius, Ui.WHITE)
				_draw_mark(at, radius, "tick", Ui.GREEN, Ui.WHITE)
			State.STARTED:
				draw_circle(at, radius, Ui.WHITE, true, -1.0, true)
				draw_arc(at, radius - 4.0, 0.0, TAU, 64, TRACK, 8.0, true)
				draw_arc(at, radius - 4.0, -PI / 2.0, -PI / 2.0 + TAU * research.fraction(id), 64, colour, 8.0, true)
				_draw_icon(row["icon"], at, radius * 0.9, colour)
			State.OPEN:
				draw_circle(at, radius, Ui.WHITE, true, -1.0, true)
				draw_arc(at, radius - 2.0, 0.0, TAU, 64, colour, 4.0, true)
				_draw_icon(row["icon"], at, radius, colour)
			State.LOCKED:
				draw_circle(at, radius, LOCKED_FILL, true, -1.0, true)
				draw_arc(at, radius - 1.5, 0.0, TAU, 64, SHADOW, 3.0, true)
				_draw_icon(row["icon"], at, radius, LOCKED_ICON)
				_draw_mark(at, radius, "lock", Ui.WHITE, LOCKED_ICON)
		if id == selected:
			draw_arc(at, radius + 8.0, 0.0, TAU, 72, Ui.INK, 3.0, true)

		var wide := _column - 12.0
		var left := at.x - wide / 2.0
		var below := at.y + _radius + 26.0
		draw_string(heading, Vector2(left, below), row["name"], HORIZONTAL_ALIGNMENT_CENTER, wide, 16,
			Ui.MUTED if state == State.LOCKED else Ui.INK)
		var note := _note(row, state)
		draw_string(body, Vector2(left, below + 18.0), note[0], HORIZONTAL_ALIGNMENT_CENTER, wide, 12, note[1])


## The line under a course's name and the colour it is written in.
func _note(row: Dictionary, state: State) -> Array:
	var id := StringName(row["id"])
	match state:
		State.LEARNED:
			return ["Learned", Ui.GREEN_DARK]
		State.STARTED:
			return ["%s to go" % GameClock.duration_label(Game.research.minutes_left(id)), Ui.INK]
	if int(row["unlock_tier"]) > Game.tier:
		return ["Needs a %s" % String(Game.data.settings["tier_names"][int(row["unlock_tier"]) - 1]).to_lower(), LOCK_TEXT]
	return ["%s · %s" % [GameClock.duration_label(float(row["minutes"])), Money.format(int(row["fee_pence"]))], Ui.MUTED]


## A bough from one badge to the next: level where it leaves and where it lands.
func _curve(from: Vector2, to: Vector2) -> PackedVector2Array:
	var reach := Vector2((to.x - from.x) * 0.5, 0)
	var path := PackedVector2Array()
	for step in CURVE_STEPS + 1:
		path.append(from.bezier_interpolate(from + reach, to - reach, to, float(step) / CURVE_STEPS))
	return path


func _draw_dashes(path: PackedVector2Array, colour: Color, thickness: float) -> void:
	for index in range(0, path.size() - 1, 2):
		draw_line(path[index], path[index + 1], colour, thickness, true)


func _draw_icon(icon_name: String, at: Vector2, radius: float, colour: Color) -> void:
	var side := radius * 1.05
	# Kept here, because a texture nothing holds on to is gone before it is drawn.
	if not _icons.has(icon_name):
		_icons[icon_name] = load("res://assets/ui/icons/%s.svg" % icon_name)
	draw_texture_rect(_icons[icon_name], Rect2(at - Vector2(side, side) / 2.0, Vector2(side, side)), false, colour)


## The little tick or padlock on a badge's shoulder.
func _draw_mark(at: Vector2, radius: float, icon_name: String, fill: Color, ink: Color) -> void:
	var centre := at + Vector2(radius, -radius) * 0.72
	var small := radius * 0.34
	draw_circle(centre, small + 2.5, Ui.WHITE, true, -1.0, true)
	draw_circle(centre, small, fill, true, -1.0, true)
	if fill == Ui.WHITE:
		draw_arc(centre, small, 0.0, TAU, 32, SHADOW, 2.0, true)
	_draw_icon(icon_name, centre, small * 1.3, ink)


func _draw_pill(centre: Vector2, label: String, colour: Color, font: Font) -> void:
	var wide := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 24.0
	var rect := Rect2(centre - Vector2(wide, 28.0) / 2.0, Vector2(wide, 28.0))
	draw_style_box(Ui.box(Ui.WHITE, 16, 0, 0), rect.grow(3.0))
	draw_style_box(Ui.box(colour, 14, 0, 0), rect)
	draw_string(font, Vector2(rect.position.x, rect.position.y + 19.0), label, HORIZONTAL_ALIGNMENT_CENTER, wide, 14, Ui.WHITE)


## The course whose badge is under a point, or &"".
func _at(point: Vector2) -> StringName:
	for id in _spots:
		if point.distance_to(_spots[id]) <= _radius + 6.0:
			return id
	return &""


func _set_hover(course: StringName) -> void:
	if course == _hover:
		return
	_hover = course
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if course != &"" else Control.CURSOR_ARROW
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_set_hover(_at(event.position))
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var course := _at(event.position)
		if course != &"":
			selected = course
			picked.emit(course)
			accept_event()
