extends VBoxContainer
## PC app: Rota, where the business takes people on. The team on the left,
## with what each does, the shift they work and what they cost; today's
## applicants on the right. No mock-up existed for this one, so it follows the
## shop screens.

const RUST := Color("B5582E")
const RUST_DARK := Color("8A3F1D")
const PAGE := Color("F8F3EF")
const TILE := Color("F1E3DA")
const SHADOW := Color("E8DAD0")
const LOCK_TEXT := Color("5A4A1C")
const LOCK_BG := Color("F4EBCF")

var screen: PcScreen


func refresh() -> void:
	Ui.clear(self)
	add_theme_constant_override(&"separation", 0)
	var banner := Ui.panel(Ui.hbox([
		Ui.title("rota", 32, Ui.PAPER, 700),
		Ui.text("People to do the jobs you no longer have time for.", 15, Ui.PAPER),
	], 24), Ui.box(RUST, 0, 32, 0))
	banner.custom_minimum_size.y = 84
	add_child(banner)

	var staff := Game.staff
	var room := Game.staff_capacity()
	var team := Ui.vbox([Ui.hbox([Ui.title("Your team", 20), null,
		Ui.text("%d of %d places filled · %s a day in wages" % [staff.team.size(), room, Money.format(staff.wages_per_day())] if room > 0 else "", 13, Ui.MUTED)])], 12)
	var applicants := Ui.vbox([Ui.title("Looking for work today", 20)], 12)
	if room == 0:
		team.add_child(Ui.panel(Ui.wrap(Ui.text("There is only room for you here. A small unit has space to take one person on, and by then there is more than one pair of hands can do.", 14, LOCK_TEXT, 800)), Ui.box(LOCK_BG, 14, 16, 12)))
	elif staff.team.is_empty():
		team.add_child(_empty("Nobody yet. Staff come in for their shift, find their own jobs on the floor and are paid at midnight for every day they are on the books."))
	for member in staff.team:
		team.add_child(_member_card(member))
	if room > 0:
		if staff.applicants.is_empty():
			applicants.add_child(_empty("Nobody today. New people apply each morning."))
		for index in staff.applicants.size():
			applicants.add_child(_applicant_card(index))

	var page := Ui.panel(Ui.margin(Ui.hbox([Ui.scroll(team), Ui.scroll(applicants)], 32), 40, 24, 40, 24), Ui.box(PAGE, 0, 0, 0))
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(page)


func _empty(words: String) -> Control:
	return Ui.panel(Ui.wrap(Ui.text(words, 14, Ui.MUTED)), Ui.outlined(Ui.CLEAR, SHADOW, 18, 18, 16))


func _member_card(member: Dictionary) -> Control:
	var role: Dictionary = Game.data.roles[member["role"]]
	var id := int(member["id"])
	var at_work := Game.staff.on_shift(member, fmod(Game.clock.minutes, GameClock.DAY))
	var shifts := Ui.hbox([Ui.width(Ui.text("Shift", 13, Ui.MUTED, 800), 60)], 8)
	for shift_id: String in Game.data.shifts:
		var shift: Dictionary = Game.data.shifts[shift_id]
		var chosen: bool = member["shift"] == shift_id
		shifts.add_child(Ui.button("%s, %s to %s" % [shift["name"], _clock(shift["start_minute"]), _clock(shift["end_minute"])],
			func() -> void: Game.set_staff_shift(id, shift_id), Ui.INK if chosen else Ui.WHITE, Ui.PAPER if chosen else Ui.INK, 36, 12, Ui.CLEAR if chosen else SHADOW, 13))
	var column := Ui.vbox([
		Ui.hbox([Ui.title(member["name"], 20), Ui.pill(role["name"], RUST_DARK, TILE), null,
			Ui.pill("At work" if at_work else "Off shift", Ui.GREEN_DARK if at_work else Ui.MUTED, Ui.GREEN_SOFT if at_work else TILE)], 10),
		Ui.wrap(Ui.text(role["description"], 13, Ui.MUTED)),
		shifts,
		Ui.hbox([
			Ui.title(Money.format(int(role["wage_pence_per_day"])), 22), Ui.text("a day", 13, Ui.MUTED), null,
			Ui.button("Let go", func() -> void: Game.fire_staff(id), Ui.SOFT, Ui.INK, 40, 14, Ui.CLEAR, 14),
		], 8),
	], 10)
	return Ui.card(column, 22, 20, SHADOW)


func _applicant_card(index: int) -> Control:
	var applicant: Dictionary = Game.staff.applicants[index]
	var role: Dictionary = Game.data.roles[applicant["role"]]
	var problem := Game.staff.hire_problem(index, Game.staff_capacity())
	var hire := Ui.button("Take on", func() -> void: Game.hire_staff(index), RUST, Ui.WHITE, 44, 14, RUST_DARK, 15)
	hire.disabled = problem != ""
	var column := Ui.vbox([
		Ui.hbox([Ui.title(applicant["name"], 20), Ui.pill(role["name"], RUST_DARK, TILE)], 10),
		Ui.wrap(Ui.text(role["description"], 13, Ui.MUTED)),
	], 10)
	if problem != "":
		column.add_child(Ui.text(problem, 13, Ui.RED_DARK, 800))
	column.add_child(Ui.hbox([Ui.title(Money.format(int(role["wage_pence_per_day"])), 22), Ui.text("a day", 13, Ui.MUTED), null, hire], 8))
	return Ui.card(column, 22, 20, SHADOW)


## "08:00" for a minute of the day.
func _clock(minute: float) -> String:
	return "%02d:%02d" % [int(minute) / 60, int(minute) % 60]
