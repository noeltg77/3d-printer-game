extends VBoxContainer
## PC app: Stats. How the business is doing in a few figures, and the
## milestones it has reached and has still to reach. No mock-up existed for
## this one, so it follows the shop screens.

const GOLD := Color("D9A23A")
const GOLD_DARK := Color("A87A22")
const PAGE := Color("FAF6EC")
const TILE := Color("F4E9CC")
const SHADOW := Color("EADFC4")

var screen: PcScreen


func refresh() -> void:
	Ui.clear(self)
	add_theme_constant_override(&"separation", 0)
	var banner := Ui.panel(Ui.hbox([
		Ui.title("stats", 32, Ui.PAPER, 700),
		Ui.text("How far the business has come, and what is next.", 15, Ui.PAPER),
	], 24), Ui.box(GOLD, 0, 32, 0))
	banner.custom_minimum_size.y = 84
	add_child(banner)

	var stats := Game.stats
	var figures := Ui.vbox([
		Ui.title("So far", 20),
		_figure("Parcels sold", str(stats["sales"])),
		_figure("Taken so far this month", Money.format(stats["month_pence"])),
		_figure("Best thirty days", Money.format(stats["best_month_pence"])),
		_figure("Five-star reviews in a row", "%d (best %d)" % [stats["streak"], stats["best_streak"]]),
		_figure("Contracts finished", str(stats["contracts_done"])),
		_figure("Biggest contract", "%d items" % stats["largest_contract"] if stats["largest_contract"] > 0 else "None yet"),
		_figure("People taken on", str(stats["staff_hired"])),
		_figure("Premises", Game.premises_row()["name"]),
	], 10)
	figures.custom_minimum_size.x = 420
	figures.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	var view := Game.stat_view()
	var reached := 0
	var rows := Ui.vbox([], 10)
	for id: String in Game.data.milestones:
		reached += 1 if Game.milestones.is_reached(id) else 0
		rows.add_child(_milestone(id, view))
	var list := Ui.vbox([Ui.hbox([Ui.title("Milestones", 20), null,
		Ui.text("%d of %d reached" % [reached, Game.data.milestones.size()], 13, Ui.MUTED)]), Ui.scroll(rows)], 12)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var page := Ui.panel(Ui.margin(Ui.hbox([Ui.card(figures, 22, 22, SHADOW), list], 32), 40, 24, 40, 24), Ui.box(PAGE, 0, 0, 0))
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(page)


func _figure(label: String, value: String) -> Control:
	return Ui.hbox([Ui.text(label, 14, Ui.MUTED), null, Ui.text(value, 15, Ui.INK, 800)])


func _milestone(id: String, view: Dictionary) -> Control:
	var row: Dictionary = Game.data.milestones[id]
	var done := Game.milestones.is_reached(id)
	var words := Ui.vbox([
		Ui.text(row["name"], 16, Ui.INK if done else Ui.MUTED, 800),
		Ui.wrap(Ui.text(Game.milestone_text(row), 13, Ui.MUTED)),
	], 2)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cells: Array = [Ui.icon_tile("stats", 44, 24, GOLD if done else TILE, Ui.PAPER if done else GOLD_DARK, 12), words]
	if done:
		var when := GameClock.new()
		when.minutes = Game.milestones.reached[id]
		cells.append(Ui.pill("Day %d" % when.day, Ui.GREEN_DARK, Ui.GREEN_SOFT))
	else:
		cells.append(Ui.width(Ui.bar(Game.milestones.progress(id, view), GOLD, TILE, 10), 140))
	return Ui.panel(Ui.hbox(cells, 16), Ui.box(Ui.WHITE, 16, 18, 12, SHADOW, 3))
