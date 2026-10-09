extends VBoxContainer
## PC app: the bank. Balance and today's totals on the left, the ledger on the
## right. No mock-up existed for this one, so it follows the other apps.

const SHADOW := Color("D6E8DF")
const ROW := Color("F3F8F5")
const SHOWN_ENTRIES := 40

var screen: PcScreen


func refresh() -> void:
	Ui.clear(self)
	add_theme_constant_override(&"separation", 0)
	var bank := Game.bank
	var banner := Ui.panel(Ui.hbox([
		Ui.title(String(Game.data.settings["bank_name"]).to_lower(), 32, Ui.PAPER, 700),
		Ui.text("%s · Business account" % Game.data.settings["business_name"], 15, Ui.PAPER),
	], 24), Ui.box(Ui.GREEN, 0, 32, 0))
	banner.custom_minimum_size.y = 84
	add_child(banner)

	var today := bank.totals_since(float(Game.clock.day - 1) * GameClock.DAY)
	var all_time := bank.totals_since(0.0)
	var balance := Ui.card(Ui.vbox([
		Ui.text("Balance", 13, Ui.MUTED, 800),
		Ui.title(Money.format(bank.cash), 44, Ui.RED if bank.cash < 0 else Ui.INK),
	], 0), 22, 20, SHADOW)
	var summary := Ui.vbox([
		balance,
		_totals("Today", today["income"], today["expenses"]),
		_totals("All time", all_time["income"], all_time["expenses"]),
	], 16)
	summary.custom_minimum_size.x = 360
	summary.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	var rows := Ui.vbox([], 8)
	var newest_first := bank.entries.slice(-SHOWN_ENTRIES)
	newest_first.reverse()
	for entry in newest_first:
		var when := GameClock.new()
		when.minutes = entry["minute"]
		var amount: int = entry["amount"]
		rows.add_child(Ui.panel(Ui.hbox([
			Ui.width(Ui.text(when.label(), 13, Ui.MUTED), 120),
			Ui.grow(Ui.text(entry["text"], 15, Ui.INK, 800)),
			Ui.text(("+" if amount >= 0 else "") + Money.format(amount), 15, Ui.GREEN_DARK if amount >= 0 else Ui.RED_DARK, 800),
		], 12), Ui.box(ROW, 14, 14, 10)))
	if rows.get_child_count() == 0:
		rows.add_child(Ui.text("Nothing yet.", 14, Ui.MUTED))
	var ledger := Ui.card(Ui.vbox([Ui.title("Transactions", 20), Ui.scroll(rows)], 12), 22, 20, SHADOW)
	ledger.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var page := Ui.margin(Ui.hbox([summary, ledger], 24), 32, 24, 32, 24)
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(page)


func _totals(label: String, income: int, expenses: int) -> Control:
	return Ui.card(Ui.vbox([
		Ui.text(label, 13, Ui.MUTED, 800),
		Ui.hbox([Ui.text("In", 14, Ui.MUTED), null, Ui.text(Money.format(income), 16, Ui.GREEN_DARK, 800)]),
		Ui.hbox([Ui.text("Out", 14, Ui.MUTED), null, Ui.text(Money.format(expenses), 16, Ui.RED_DARK, 800)]),
	], 6), 22, 20, SHADOW)
