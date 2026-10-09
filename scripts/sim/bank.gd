class_name Bank
extends RefCounted
## Cash and a ledger of every movement. Amounts are integer pence.

var cash := 0
## Newest last. Each entry: { minute, text, amount } with expenses negative.
var entries: Array[Dictionary] = []


func _init(starting_cash := 0) -> void:
	cash = starting_cash


func can_afford(amount: int) -> bool:
	return cash >= amount


## Pays for something the player chose to buy. False, and nothing happens, if short.
func spend(amount: int, text: String, minute: float) -> bool:
	if not can_afford(amount):
		return false
	_record(-amount, text, minute)
	return true


## A cost that happens regardless (fees, electricity). Can take cash below zero.
func charge(amount: int, text: String, minute: float) -> void:
	if amount > 0:
		_record(-amount, text, minute)


func earn(amount: int, text: String, minute: float) -> void:
	_record(amount, text, minute)


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


func _record(amount: int, text: String, minute: float) -> void:
	cash += amount
	entries.append({"minute": minute, "text": text, "amount": amount})
