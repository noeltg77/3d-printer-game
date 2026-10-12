extends VBoxContainer
## PC app: the bank. The balance and how the business is doing across the top,
## then money in and out and the balance day by day as charts, where it came
## from and went by kind, and the ledger. No mock-up existed for this one, so
## it follows the other apps.

const SHADOW := Color("D6E8DF")
const ROW := Color("F3F8F5")
const SHOWN_ENTRIES := 60
## How many days the charts and the breakdown can look back over.
const PERIODS: Array[int] = [7, 14, 30]
## What each kind of movement is called, coming in and going out.
const INCOME_NAMES := {
	Bank.SALES: "Sales", Bank.CONTRACTS: "Contracts", Bank.RESALE: "Second-hand sales", Bank.POSTAGE: "Postage paid by buyers",
	Bank.FEES: "Fees and royalties returned", Bank.REFUNDS: "Insurance payouts", Bank.OTHER: "Other",
}
const EXPENSE_NAMES := {
	Bank.SUPPLIES: "Filament, parts and packaging", Bank.EQUIPMENT: "Printers and fittings", Bank.DESIGNS: "Design licences",
	Bank.FEES: "Marketplace fees and royalties", Bank.POSTAGE: "Postage", Bank.REFUNDS: "Refunds", Bank.RENT: "Rent",
	Bank.WAGES: "Wages", Bank.ELECTRICITY: "Electricity", Bank.PREMISES: "Moving premises", Bank.MOULDING: "Moulds and pellets",
	Bank.OTHER: "Other",
}

var screen: PcScreen

## How many days back the charts and breakdown go.
var _period := PERIODS[0]
var _scroll: ScrollContainer = null


func refresh() -> void:
	var scrolled := _scroll.scroll_vertical if _scroll != null else 0
	Ui.clear(self)
	add_theme_constant_override(&"separation", 0)
	var bank := Game.bank
	var banner := Ui.panel(Ui.hbox([
		Ui.title(String(Game.data.settings["bank_name"]).to_lower(), 32, Ui.PAPER, 700),
		Ui.text("%s · Business account" % Game.data.settings["business_name"], 15, Ui.PAPER),
	], 24), Ui.box(Ui.GREEN, 0, 32, 0))
	banner.custom_minimum_size.y = 84
	add_child(banner)

	var today := Game.clock.day
	var days := bank.by_day(maxi(1, today - _period + 1), today)
	var since := float(days[0]["day"] - 1) * GameClock.DAY
	var kinds := bank.by_category(since)

	var content := Ui.vbox([
		_headlines(days),
		Ui.hbox([
			_section("Money in and out", "Each day's takings beside what was spent.", Ui.vbox([
				Chart.bars(_bar_points(days), [Ui.GREEN, Ui.RED]),
				Ui.hbox([_key("In", Ui.GREEN), _key("Out", Ui.RED)], 18),
			], 8), _period_buttons()),
			_section("Balance", "What was in the account as each day ended.", Chart.line(_line_points(days), Ui.GREEN_DARK)),
		], 24),
		Ui.hbox([
			_section("Where it came from", _period_text(days), _breakdown(kinds["income"], INCOME_NAMES, Ui.GREEN, Ui.GREEN_DARK)),
			_section("Where it went", _period_text(days), _breakdown(kinds["expenses"], EXPENSE_NAMES, Ui.RED, Ui.RED_DARK)),
		], 24),
		_section("Day by day", "", _day_table(days)),
		_section("Transactions", "The latest %d." % SHOWN_ENTRIES if bank.entries.size() > SHOWN_ENTRIES else "", _ledger()),
	], 24)
	_scroll = Ui.scroll(Ui.margin(content, 32, 24, 32, 24))
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_scroll)
	if scrolled > 0:
		_restore_scroll.call_deferred(scrolled)


func _restore_scroll(at: int) -> void:
	# The page has no height to scroll through until it has been laid out.
	await get_tree().process_frame
	if is_instance_valid(_scroll):
		_scroll.scroll_vertical = at


## The four figures across the top: what there is, how today and the period
## are going, and what the business costs before it sells anything.
func _headlines(days: Array[Dictionary]) -> Control:
	var bank := Game.bank
	var today: Dictionary = days[-1]
	var income := 0
	var expenses := 0
	for day in days:
		income += int(day["income"])
		expenses += int(day["expenses"])
	var profit := income - expenses
	var best: Dictionary = days[0]
	for day in days:
		if int(day["net"]) > int(best["net"]):
			best = day
	var rent := int(Game.premises_row()["rent_pence_per_day"])
	var wages := Game.staff.wages_per_day()
	var standing := "Nothing yet. Rent and wages come with bigger premises."
	if rent + wages > 0:
		standing = "Rent %s, wages %s. Paid at midnight." % [Money.format(rent), Money.format(wages)]
	var row := Ui.hbox([
		_headline("Balance", Money.format(bank.cash), Ui.RED if bank.cash < 0 else Ui.INK,
			"Overdrawn. Sales will bring it back." if bank.cash < 0 else "Ready to spend."),
		_headline("Today", _signed(int(today["net"])), _tone(int(today["net"])),
			"In %s, out %s." % [Money.format(int(today["income"])), Money.format(int(today["expenses"]))]),
		_headline("Last %d days" % days.size() if days.size() > 1 else "So far", _signed(profit), _tone(profit),
			"About %s a day. Best: day %d, %s." % [_signed(roundi(float(profit) / days.size())), int(best["day"]), _signed(int(best["net"]))]),
		_headline("Costs every day", Money.format(rent + wages), Ui.INK, standing),
	], 24)
	return row


func _headline(label: String, figure: String, colour: Color, note: String) -> Control:
	var card := Ui.card(Ui.vbox([
		Ui.text(label, 13, Ui.MUTED, 800),
		Ui.title(figure, 32, colour),
		Ui.wrap(Ui.text(note, 13, Ui.MUTED)),
	], 2), 22, 20, SHADOW)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return card


func _section(heading: String, note: String, body: Control, extra: Control = null) -> Control:
	var top := Ui.hbox([Ui.title(heading, 20)], 12)
	if note != "":
		var words := Ui.text(note, 13, Ui.MUTED)
		words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top.add_child(words)
	if extra != null:
		top.add_child(Ui.spacer())
		top.add_child(extra)
	var card := Ui.card(Ui.vbox([top, body], 14), 22, 20, SHADOW)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return card


func _period_buttons() -> Control:
	var row := Ui.hbox([], 6)
	for days in PERIODS:
		var chosen := days == _period
		var pick := func() -> void:
			_period = days
			refresh()
		row.add_child(Ui.button("%d days" % days, pick, Ui.GREEN if chosen else Ui.WHITE, Ui.PAPER if chosen else Ui.INK, 34, 12,
			Ui.GREEN_DARK if chosen else SHADOW, 13))
	return row


func _period_text(days: Array[Dictionary]) -> String:
	return "Today so far." if days.size() == 1 else "Days %d to %d." % [int(days[0]["day"]), int(days[-1]["day"])]


func _key(label: String, colour: Color) -> Control:
	var dot := Ui.panel(Control.new(), Ui.box(colour, 5, 6, 6))
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return Ui.hbox([dot, Ui.text(label, 13, Ui.MUTED, 800)], 6)


func _bar_points(days: Array[Dictionary]) -> Array[Dictionary]:
	var points: Array[Dictionary] = []
	for day in days:
		points.append({"label": str(int(day["day"])), "values": [float(day["income"]), float(day["expenses"])],
			"tip": "Day %d\nIn %s\nOut %s\n%s" % [int(day["day"]), Money.format(int(day["income"])), Money.format(int(day["expenses"])), _result(int(day["net"]))]})
	return points


func _line_points(days: Array[Dictionary]) -> Array[Dictionary]:
	var points: Array[Dictionary] = []
	for day in days:
		points.append({"label": str(int(day["day"])), "value": float(day["closing"]),
			"tip": "Day %d\nEnded on %s" % [int(day["day"]), Money.format(int(day["closing"]))]})
	return points


## One bar for each kind of movement, biggest first, with its share of the whole.
func _breakdown(amounts: Dictionary, names: Dictionary, colour: Color, text_colour: Color) -> Control:
	var rows := Ui.vbox([], 10)
	var total := 0
	for amount: int in amounts.values():
		total += amount
	if total == 0:
		rows.add_child(Ui.text("Nothing in these days.", 14, Ui.MUTED))
		return rows
	var kinds := amounts.keys()
	kinds.sort_custom(func(a: StringName, b: StringName) -> bool: return int(amounts[a]) > int(amounts[b]))
	var most := int(amounts[kinds[0]])
	for kind: StringName in kinds:
		var amount := int(amounts[kind])
		var bar := Ui.bar(float(amount) / most, colour, Ui.TRACK, 10)
		rows.add_child(Ui.vbox([
			Ui.hbox([
				Ui.text(names.get(kind, names[Bank.OTHER]), 14, Ui.INK, 800), null,
				Ui.text("%d%%" % roundi(100.0 * amount / total), 13, Ui.MUTED),
				Ui.width(_right(Ui.text(Money.format(amount), 14, text_colour, 800)), 96),
			], 10),
			bar,
		], 4))
	rows.add_child(Ui.hbox([Ui.text("Total", 14, Ui.MUTED, 800), null, Ui.text(Money.format(total), 15, text_colour, 800)]))
	return rows


## The same days as the charts, as figures, newest first.
func _day_table(days: Array[Dictionary]) -> Control:
	var rows := Ui.vbox([_day_row(["Day", "In", "Out", "Profit or loss", "Balance at the end"], Ui.MUTED, Ui.MUTED, Ui.MUTED, Ui.CLEAR)], 6)
	for index in range(days.size() - 1, -1, -1):
		var day := days[index]
		var net := int(day["net"])
		rows.add_child(_day_row([
			"Day %d%s" % [int(day["day"]), " (today)" if index == days.size() - 1 else ""],
			Money.format(int(day["income"])), Money.format(int(day["expenses"])), _signed(net), Money.format(int(day["closing"])),
		], Ui.INK, _tone(net), Ui.RED_DARK if int(day["closing"]) < 0 else Ui.INK, ROW))
	return rows


func _day_row(cells: Array, colour: Color, net_colour: Color, balance_colour: Color, bg: Color) -> Control:
	var row := Ui.hbox([Ui.grow(Ui.text(cells[0], 14, colour, 800), 1.4)], 12)
	var colours: Array[Color] = [Ui.GREEN_DARK if bg != Ui.CLEAR else colour, Ui.RED_DARK if bg != Ui.CLEAR else colour, net_colour, balance_colour]
	for index in 4:
		row.add_child(Ui.grow(_right(Ui.text(cells[index + 1], 14, colours[index], 800))))
	return Ui.panel(row, Ui.box(bg, 12, 14, 8))


func _ledger() -> Control:
	var rows := Ui.vbox([], 8)
	var newest_first := Game.bank.entries.slice(-SHOWN_ENTRIES)
	newest_first.reverse()
	for entry in newest_first:
		var when := GameClock.new()
		when.minutes = entry["minute"]
		var amount: int = entry["amount"]
		var names := INCOME_NAMES if amount >= 0 else EXPENSE_NAMES
		rows.add_child(Ui.panel(Ui.hbox([
			Ui.width(Ui.text(when.label(), 13, Ui.MUTED), 120),
			Ui.grow(Ui.text(entry["text"], 15, Ui.INK, 800)),
			Ui.text(names.get(entry["category"], names[Bank.OTHER]), 13, Ui.MUTED),
			Ui.width(_right(Ui.text(_signed(amount), 15, Ui.GREEN_DARK if amount >= 0 else Ui.RED_DARK, 800)), 110),
		], 12), Ui.box(ROW, 14, 14, 10)))
	if rows.get_child_count() == 0:
		rows.add_child(Ui.text("Nothing yet.", 14, Ui.MUTED))
	return rows


func _right(label: Label) -> Label:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return label


## "+£12.50" or "-£3.00": an amount that is a gain or a loss.
func _signed(pence: int) -> String:
	return ("+" if pence > 0 else "") + Money.format(pence)


func _result(net: int) -> String:
	return "%s %s" % ["Profit" if net >= 0 else "Loss", Money.format(absi(net))]


func _tone(pence: int) -> Color:
	return Ui.GREEN_DARK if pence > 0 else (Ui.RED_DARK if pence < 0 else Ui.INK)
