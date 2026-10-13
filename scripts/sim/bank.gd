class_name Bank
extends RefCounted
## Cash and a ledger of every movement. Amounts are integer pence.

## What a movement was for, so the bank can show where money comes from and
## goes. An entry with none given is OTHER.
const SALES := &"sales"
const CONTRACTS := &"contracts"
const RESALE := &"resale"
const SUPPLIES := &"supplies"
const EQUIPMENT := &"equipment"
const DESIGNS := &"designs"
const FEES := &"fees"
const POSTAGE := &"postage"
const REFUNDS := &"refunds"
const RENT := &"rent"
const WAGES := &"wages"
const ELECTRICITY := &"electricity"
const PREMISES := &"premises"
const MOULDING := &"moulding"
const TRAINING := &"training"
const OTHER := &"other"

var cash := 0
## Newest last. Each entry: { minute, text, amount, category } with expenses negative.
var entries: Array[Dictionary] = []


func _init(starting_cash := 0) -> void:
	cash = starting_cash


func can_afford(amount: int) -> bool:
	return cash >= amount


## Pays for something the player chose to buy. False, and nothing happens, if short.
func spend(amount: int, text: String, minute: float, category := OTHER) -> bool:
	if not can_afford(amount):
		return false
	_record(-amount, text, minute, category)
	return true


## A cost that happens regardless (fees, electricity). Can take cash below zero.
func charge(amount: int, text: String, minute: float, category := OTHER) -> void:
	if amount > 0:
		_record(-amount, text, minute, category)


func earn(amount: int, text: String, minute: float, category := OTHER) -> void:
	_record(amount, text, minute, category)


## Income and expenses since `minute`, both as positive numbers.
func totals_since(minute: float) -> Dictionary:
	var totals := {"income": 0, "expenses": 0}
	for entry in entries:
		if entry["minute"] >= minute:
			if entry["amount"] >= 0:
				totals["income"] += entry["amount"]
			else:
				totals["expenses"] -= entry["amount"]
	return totals


## One row for each game day from `first_day` to `last_day`: { day, income,
## expenses, net, closing }, with income and expenses positive and `closing` the
## balance as the day ended (or now, for a day still going).
func by_day(first_day: int, last_day: int) -> Array[Dictionary]:
	var days: Array[Dictionary] = []
	for day in range(first_day, last_day + 1):
		days.append({"day": day, "income": 0, "expenses": 0, "net": 0, "closing": 0})
	# Everything after the last day asked for, to work back from the cash in hand.
	var later := 0
	for entry in entries:
		var day := int(float(entry["minute"]) / GameClock.DAY) + 1
		var amount: int = entry["amount"]
		if day > last_day:
			later += amount
		elif day >= first_day:
			var row := days[day - first_day]
			row["income" if amount >= 0 else "expenses"] += absi(amount)
			row["net"] += amount
	var closing := cash - later
	for index in range(days.size() - 1, -1, -1):
		days[index]["closing"] = closing
		closing -= int(days[index]["net"])
	return days


## What came in and went out since `minute`, by category: { income: { category:
## pence }, expenses: { category: pence } }, all positive.
func by_category(minute: float) -> Dictionary:
	var found := {"income": {}, "expenses": {}}
	for entry in entries:
		if entry["minute"] < minute:
			continue
		var amount: int = entry["amount"]
		var side: Dictionary = found["income" if amount >= 0 else "expenses"]
		side[entry["category"]] = int(side.get(entry["category"], 0)) + absi(amount)
	return found


func _record(amount: int, text: String, minute: float, category: StringName) -> void:
	cash += amount
	entries.append({"minute": minute, "text": text, "amount": amount, "category": category})


func save() -> Dictionary:
	return {"cash": cash, "entries": entries}


## Entries saved before movements had a category come back as OTHER.
func restore(data: Dictionary) -> void:
	cash = int(data["cash"])
	entries.clear()
	for entry: Dictionary in data["entries"]:
		entries.append({"minute": float(entry["minute"]), "text": String(entry["text"]), "amount": int(entry["amount"]),
			"category": StringName(entry.get("category", OTHER))})
