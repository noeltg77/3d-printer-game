class_name Trends
extends RefCounted
## What buyers are after this week. One category of product is in fashion and
## sells faster, another has gone quiet and sells slower; every few days both
## move on. Rules come from the `trends` settings in data/game.json.

## Product rows from data/products.json, by id.
var products: Dictionary
## The `trends` block of data/game.json.
var rules: Dictionary
## Category in fashion and the one gone quiet, or empty before the first tick.
var hot := ""
var cool := ""
## Game minute at which the current pair moves on.
var until := 0.0


func _init(p_products: Dictionary, p_rules: Dictionary) -> void:
	products = p_products
	rules = p_rules


## Categories with enough designs in them to be worth a trend, in catalogue
## order. Seasonal ones are left out: they belong to a time of year, not a whim.
func candidates() -> Array[String]:
	var counts := {}
	for row: Dictionary in products.values():
		counts[row["category"]] = int(counts.get(row["category"], 0)) + 1
	var found: Array[String] = []
	for category: String in counts:
		if counts[category] >= int(rules["min_designs"]) and not (rules.get("seasonal", []) as Array).has(category):
			found.append(category)
	return found


## Moves the trends on if their time is up. Returns true if they changed.
func tick(minute: float, rng: RandomNumberGenerator) -> bool:
	if minute < until and hot != "":
		return false
	var choices := candidates()
	if choices.size() < 2:
		return false
	# Something new each time: neither category carries straight over.
	var fresh := choices.filter(func(category: String) -> bool: return category != hot and category != cool)
	if fresh.size() >= 2:
		choices = fresh
	hot = choices[rng.randi() % choices.size()]
	choices.erase(hot)
	cool = choices[rng.randi() % choices.size()]
	var days: Array = rules["days"]
	until = minute + rng.randf_range(days[0], days[1]) * GameClock.DAY
	return true


## How demand for a category is scaled right now: 1.0 unless it is trending.
func multiplier(category: String) -> float:
	if category == hot:
		return float(rules["hot_multiplier"])
	if category == cool:
		return float(rules["cool_multiplier"])
	return 1.0


## Category -> demand multiplier, for the ones that are trending either way.
func multipliers() -> Dictionary:
	return {hot: multiplier(hot), cool: multiplier(cool)} if hot != "" else {}


## A category as shown to the player, from any design in it.
func category_name(category: String) -> String:
	for row: Dictionary in products.values():
		if row["category"] == category:
			return row.get("category_name", String(category).capitalize())
	return String(category).capitalize()


func save() -> Dictionary:
	return {"hot": hot, "cool": cool, "until": until}


func restore(data: Dictionary) -> void:
	hot = String(data["hot"])
	cool = String(data["cool"])
	until = float(data["until"])
