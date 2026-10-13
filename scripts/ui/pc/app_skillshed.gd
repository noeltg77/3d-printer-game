extends VBoxContainer
## PC app: Skillshed, the course site where the owner learns to run the
## business better. The courses of data/research.json are a `SkillTree`, a
## bough for each branch; beside it the card of the course that is picked, with
## the button to study it, and what everything learned so far adds up to.
## Starting a course leaves the desk's screen so the character can get on with
## it. No mock-up existed for this one, so it follows the shop screens.

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

var _tree: SkillTree = null
var _side: VBoxContainer = null
var _tally: Label = null
## The course whose card is open beside the tree.
var _selected: StringName = &""


func refresh() -> void:
	if _tree == null:
		_build()
	if _selected == &"":
		_selected = _first_pick()
	_tree.selected = _selected
	_tree.queue_redraw()
	_tally.text = "%d of %d learned" % [Game.research.learned.size(), Game.data.courses.size()]
	Ui.clear(_side)
	_side.add_child(_course_card(Game.data.courses[String(_selected)]))
	_side.add_child(_learned_card())


func _build() -> void:
	add_theme_constant_override(&"separation", 0)
	var banner := Ui.panel(Ui.hbox([
		Ui.title("skillshed", 32, Ui.PAPER, 700),
		Ui.text("Courses for people who make things. Study at your desk, a bit at a time.", 15, Ui.PAPER),
	], 24), Ui.box(INDIGO, 0, 32, 0))
	banner.custom_minimum_size.y = 84
	add_child(banner)

	_tree = SkillTree.new()
	_tree.picked.connect(func(course: StringName) -> void:
		_selected = course
		refresh())
	_tally = Ui.text("", 14, Ui.MUTED, 800)
	var tree_card := Ui.card(Ui.vbox([
		Ui.hbox([Ui.title("Your skill tree", 22), null, _tally], 12),
		Ui.text("Each course opens the next along its branch. Pick one to see what it teaches.", 13, Ui.MUTED),
		_tree,
	], 4), 20, 20, SHADOW)
	tree_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_side = Ui.vbox([], 20)
	var side := Ui.scroll(_side)
	side.custom_minimum_size.x = 380
	side.size_flags_horizontal = Control.SIZE_FILL
	var page := Ui.panel(Ui.margin(Ui.hbox([tree_card, side], 24), 40, 24, 40, 24), Ui.box(PAGE, 0, 0, 0))
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(page)


## The course to show first: the one on the go, or the first that can be taken.
func _first_pick() -> StringName:
	if Game.research.current != &"":
		return Game.research.current
	for id: String in Game.data.courses:
		if SkillTree.state_of(StringName(id)) == SkillTree.State.OPEN:
			return StringName(id)
	return StringName(Game.data.courses.keys()[0])


## "8% fewer failed prints": what a multiplier does to the rule it scales.
static func effect_label(key: String, scale: float) -> String:
	return String(EFFECT_WORDS.get(key, key + " %d%%")) % roundi((1.0 - scale) * 100.0)


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
	return card


## Everything about the picked course, and the button that starts it.
func _course_card(row: Dictionary) -> Control:
	var id := StringName(row["id"])
	var research := Game.research
	var branch: Dictionary = Game.data.branches[row["branch"]]
	var colour := Color.html(branch["colour"])
	var state := SkillTree.state_of(id)
	var locked := state == SkillTree.State.LOCKED
	var column := Ui.vbox([
		Ui.hbox([
			Ui.icon_tile(row["icon"], 56, 30, colour if not locked else SkillTree.LOCKED_ICON, Ui.WHITE, 16),
			Ui.vbox([Ui.text(branch["name"], 13, colour, 800), Ui.title(row["name"], 22)], 0),
		], 14),
		Ui.wrap(Ui.text(row["description"], 14, Ui.MUTED)),
	], 12)
	var gains := Ui.vbox([], 4)
	for key: String in row["effects"]:
		gains.add_child(Ui.hbox([
			Ui.icon("tick", 16, Ui.GREEN_DARK),
			Ui.text(effect_label(key, float(row["effects"][key])), 14, Ui.GREEN_DARK, 800),
		], 8))
	column.add_child(Ui.panel(gains, Ui.box(Ui.GREEN_SOFT, 14, 14, 12)))

	match state:
		SkillTree.State.LEARNED:
			column.add_child(Ui.hbox([Ui.pill("Learned", Ui.GREEN_DARK, Ui.GREEN_SOFT, 13), null,
				Ui.text("Yours for good", 13, Ui.MUTED, 800)], 10))
		SkillTree.State.LOCKED:
			var problem := Game.study_problem(id)
			column.add_child(Ui.hbox([Ui.text(_cost(row), 13, Ui.MUTED, 800), null,
				Ui.pill("Needs a %s" % String(Game.data.settings["tier_names"][int(row["unlock_tier"]) - 1]).to_lower()
					if int(row["unlock_tier"]) > Game.tier else problem, LOCK_TEXT, LOCK_BG, 13)], 10))
		_:
			if state == SkillTree.State.STARTED:
				column.add_child(Ui.bar(research.fraction(id), colour, TILE, 12))
				column.add_child(Ui.hbox([Ui.text("%s to go" % GameClock.duration_label(research.minutes_left(id)), 13, Ui.MUTED, 800), null,
					_study_button(id)], 10))
			else:
				column.add_child(Ui.hbox([Ui.text(_cost(row), 13, Ui.MUTED, 800), null, _study_button(id)], 10))
			column.add_child(Ui.wrap(Ui.text("You pay once, then study at this desk. Stop whenever something needs doing and carry on from where you left off.", 12, Ui.MUTED)))
	return Ui.card(column, 20, 20, SHADOW)


## "1h 30m of study · £15.00"
func _cost(row: Dictionary) -> String:
	return "%s of study · %s" % [GameClock.duration_label(float(row["minutes"])), Money.format(int(row["fee_pence"]))]


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
