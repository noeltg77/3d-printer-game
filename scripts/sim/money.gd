class_name Money
extends RefCounted
## The one place money is turned into text. All game data, simulation and save
## files hold amounts in GBP as integer pence; the player's display currency
## (data/currencies.json) is applied only here, at the moment of showing it.
## Never write a currency symbol anywhere else.
##
## Every amount is converted the same way, to the penny, so the price on a
## shop card is exactly what appears on the bank statement. Prices are not
## rounded to tidy endings in other currencies, because that would break it.

const SOURCE := "res://data/currencies.json"
const BASE := "GBP"
## Countries that use the euro, for picking a default from the OS locale.
const EUROZONE: PackedStringArray = [
	"AT", "BE", "BG", "CY", "DE", "EE", "ES", "FI", "FR", "GR", "HR", "IE", "IT",
	"LT", "LU", "LV", "MT", "NL", "PT", "SI", "SK",
]

## Code of the currency amounts are shown in.
static var currency := BASE

static var _table: Dictionary = {}


## Every currency on offer: code -> { name, rate, symbol, symbol_after, decimal, thousands }.
static func currencies() -> Dictionary:
	if _table.is_empty():
		_table = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	return _table


## Switches the display currency. Unknown codes are ignored.
static func set_currency(code: String) -> void:
	if currencies().has(code):
		currency = code


## The currency to start a new player on, from an OS locale such as "en_GB".
static func currency_for_locale(locale: String) -> String:
	var country := locale.get_slice(".", 0).replace("-", "_").get_slice("_", 1).to_upper()
	if country == "US":
		return "USD"
	if EUROZONE.has(country):
		return "EUR"
	return BASE


## An amount of GBP pence as text in the display currency:
## "£1,234.50", "-$3.00", "12,99 €".
static func format(pence: int) -> String:
	var spec: Dictionary = currencies()[currency]
	var amount := to_display(pence)
	var whole := str(absi(amount) / 100)
	var grouped := ""
	for index in whole.length():
		if index > 0 and (whole.length() - index) % 3 == 0:
			grouped += String(spec["thousands"])
		grouped += whole[index]
	var number := "%s%s%02d" % [grouped, spec["decimal"], absi(amount) % 100]
	var sign := "-" if amount < 0 else ""
	if spec["symbol_after"]:
		return "%s%s %s" % [sign, number, spec["symbol"]]
	return "%s%s%s" % [sign, spec["symbol"], number]


## GBP pence converted to hundredths of the display currency.
static func to_display(pence: int) -> int:
	return roundi(pence * float(currencies()[currency]["rate"]))
