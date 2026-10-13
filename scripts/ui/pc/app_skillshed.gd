extends VBoxContainer
## PC app: Skillshed, the course site where the owner learns to run the
## business better. A column for each branch of data/research.json, its
## courses in the order they are taken; above them what is being studied and
## what everything learned so far adds up to. Starting a course leaves the
## desk's screen so the character can get on with it. No mock-up existed for
## this one, so it follows the shop screens.

const INDIGO := Color("5B5FC7")
const INDIGO_DARK := Color("3F428F")
const PAGE := Color("F4F4FB")
const TILE := Color("E6E7F5")
const SHADOW := Color("DCDDEE")
const LOCK_TEXT := Color("5A4A1C")
const LOCK_BG := Color("F4EBCF")
## How each effect reads, given the share it takes off (or, for speed, adds).
const EFFECT_WORDS := {
	"fail_chance": "%d%% fewer failed prints", "print_time": "Prints take %d%% less time",
	"clear_time": "Failed prints cleared %d%% quicker", "wear": "Parts wear %d%% slower",
	"replace_time": "Parts fitted %d%% quicker", "worn_risk": "Worn parts spoil %d%% fewer prints",
	"spool_price": "Spools %d%% cheaper", "parts_price": "Spare parts %d%% cheaper",
	"packaging_price": "Packaging %d%% cheaper", "lead_time": "Supplies arrive %d%% sooner",
}

var screen: PcScreen

var _scroll: ScrollContainer = null


func refresh() -> void:
	var scrolled := _scroll.scroll_vertical if _scroll != null else 0
	Ui.clear(self)
	add_theme_constant_override(&"separation", 0)
	var banner := Ui.panel(Ui.hbox([
		Ui.title("skillshed", 32, Ui.PAPER, 700),
		Ui.text("Courses for people who make things. Study at your desk, a bit at a time.", 15, Ui.PAPER),
	], 24), Ui.box(INDIGO, 0, 32, 0))
	banner.custom_minimum_size.y = 84
	add_child(banner)

	var columns := Ui.hbox([], 20)
	for branch: Dictionary in Game.data.branches.values():
		columns.add_child(_branch(branch))
	_scroll = Ui.scroll(Ui.vbox([Ui.hbox([_now_card(), _learned_card()], 20), columns], 20))
	var page := Ui.panel(Ui.margin(_scroll, 40, 24, 40, 24), Ui.box(PAGE, 0, 0, 0))
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(page)
	_restore_scroll.call_deferred(scrolled)


func _restore_scroll(at: int) -> void:
	if at == 0:
		return
	await get_tree().process_frame
	if is_instance_valid(_scroll):
		_scroll.scroll_vertical = at


## "8% fewer failed prints": what a multiplier does to the rule it scales.
static func effect_label(key: String, scale: float) -> String:
	return String(EFFECT_WORDS.get(key, key + " %d%%")) % roundi((1.0 - scale) * 100.0)


## The course being worked through, with how far along it is.
func _now_card() -> Control:
	var research := Game.research
	var content: Control
	if research.current == &"":
		content = Ui.vbox([
			Ui.title("Nothing on the go", 20),
			Ui.wrap(Ui.text("Pick a course below. You pay for it once, then study it at this desk: stop whenever something needs doing, and carry on from where you left off.", 14, Ui.MUTED)),
		], 6)
	else:
		var row: Dictionary = Game.data.courses[research.current]
		content = Ui.vbox([
			Ui.hbox([Ui.title("Studying: %s" % row["name"], 20), null,
				Ui.text("%s to go" % GameClock.duration_label(research.minutes_left(research.current)), 14, Ui.MUTED, 800)], 12),
			Ui.bar(research.fraction(research.current), INDIGO, TILE, 12),
			Ui.hbox([Ui.wrap(Ui.text("It only moves on while you are sat here studying.", 13, Ui.MUTED)), _study_button(research.current)], 12),
		], 10)
	var card := Ui.card(content, 20, 18, SHADOW)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_stretch_ratio = 1.4
	return card


## Everything learned so far, added up.
func _learned_card() -> Control:
	var lines := Ui.vbox([Ui.title("What you know", 20)], 6)
	var any := false
	for key in Research.EFFECTS:
		var scale := Game.research.effect(key)
		if not is_equal_approx(scale, 1.0):
			any = true
			lines.add_child(Ui.text(effect_label(key, scale), 14, Ui.GREEN_DARK, 800))
	if not any:
		lines.add_child(Ui.wrap(Ui.text("Nothing yet. What each course teaches is yours for good.", 14, Ui.MUTED)))
	var card := Ui.card(lines, 20, 18, SHADOW)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return card


func _branch(branch: Dictionary) -> Control:
	var colour := Color.html(branch["colour"])
	var column := Ui.vbox([
		Ui.hbox([Ui.panel(null, Ui.box(colour, 7, 7, 7)), Ui.title(branch["name"], 22)], 10),
		Ui.wrap(Ui.text(branch["about"], 13, Ui.MUTED)),
	], 10)
	var first := true
	for row: Dictionary in Game.data.courses.values():
		if row["branch"] != branch["id"]:
			continue
		if not first:
			# The line that says this one follows from the last.
			var link := ColorRect.new()
			link.color = SHADOW
			link.custom_minimum_size = Vector2(4, 14)
			link.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			column.add_child(link)
		first = false
		column.add_child(_course(row, colour))
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return column


func _course(row: Dictionary, colour: Color) -> Control:
	var id := StringName(row["id"])
	var research := Game.research
	var learned := research.is_learned(id)
	var problem := Game.study_problem(id)
	var locked := not learned and problem != "" and problem != "Not enough cash"
	var gains := Ui.vbox([], 2)
	for key: String in row["effects"]:
		gains.add_child(Ui.text(effect_label(key, float(row["effects"][key])), 13, Ui.GREEN_DARK if not locked else Ui.MUTED, 800))
	var foot: Control
	if learned:
		foot = Ui.pill("Learned", Ui.GREEN_DARK, Ui.GREEN_SOFT, 13)
	elif locked:
		foot = Ui.pill("Needs a %s" % String(Game.data.settings["tier_names"][int(row["unlock_tier"]) - 1]).to_lower()
			if int(row["unlock_tier"]) > Game.tier else problem, LOCK_TEXT, LOCK_BG, 13)
	else:
		foot = _study_button(id)
	var cost := "%s of study" % GameClock.duration_label(float(row["minutes"]))
	if research.is_started(id):
		cost = "%s to go" % GameClock.duration_label(research.minutes_left(id))
	elif not learned:
		cost += " · %s" % Money.format(int(row["fee_pence"]))
	var column := Ui.vbox([
		Ui.title(row["name"], 18, Ui.INK if not locked else Ui.MUTED),
		Ui.wrap(Ui.text(row["description"], 13, Ui.MUTED)),
		gains,
	], 8)
	if research.is_started(id):
		column.add_child(Ui.bar(research.fraction(id), colour, TILE, 8))
	column.add_child(Ui.hbox([Ui.text(cost, 13, Ui.MUTED, 800), null, foot], 10))
	var card := Ui.panel(column, Ui.box(Ui.WHITE if not locked else PAGE, 18, 16, 14, colour.lerp(Ui.WHITE, 0.55) if learned else SHADOW, 3))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return card


## A button that sets the character studying a course and leaves the PC so they can start.
func _study_button(course: StringName) -> Button:
	var computer: Computer = get_tree().get_first_node_in_group(&"computer")
	var action := computer.study_action(course)
	var started := Game.research.is_started(course)
	var button := Ui.button("Carry on" if started else "Study", func() -> void:
		(get_tree().get_first_node_in_group(&"player") as Agent).enqueue(action)
		screen.close(), INDIGO, Ui.WHITE, 38, 12, INDIGO_DARK, 14)
	button.disabled = not action.enabled
	button.tooltip_text = Game.study_problem(course) if not action.enabled else (
		"Sit down and carry on with it" if started else "Pay %s and start studying" % Money.format(int(Game.data.courses[course]["fee_pence"])))
	return button
