extends VBoxContainer
## PC tab: cash, today's income and costs, and the recent ledger.

const SHOWN_ENTRIES := 40


func refresh() -> void:
	Ui.clear(self)
	add_theme_constant_override(&"separation", 8)
	var bank := Game.bank
	var today := bank.totals_since(float(Game.clock.day - 1) * GameClock.DAY)
	var all_time := bank.totals_since(0.0)
	add_child(Ui.label(Money.text(bank.cash), 34, Ui.BAD if bank.cash < 0 else Color.WHITE))
	add_child(Ui.label("Today: %s in, %s out   |   All time: %s in, %s out" % [
		Money.text(today["income"]), Money.text(today["expenses"]),
		Money.text(all_time["income"]), Money.text(all_time["expenses"])], 16, Ui.MUTED))
	add_child(HSeparator.new())
	add_child(Ui.heading("Recent transactions"))
	if bank.entries.is_empty():
		add_child(Ui.label("Nothing yet.", 16, Ui.MUTED))
	var newest_first := bank.entries.slice(-SHOWN_ENTRIES)
	newest_first.reverse()
	for entry in newest_first:
		var when := GameClock.new()
		when.minutes = entry["minute"]
		var amount: int = entry["amount"]
		add_child(Ui.row([
			Ui.cell(when.label(), 130, Ui.MUTED),
			Ui.label(entry["text"]),
			null,
			Ui.label(("+" if amount >= 0 else "") + Money.text(amount), 16, Ui.GOOD if amount >= 0 else Ui.BAD),
		]))
