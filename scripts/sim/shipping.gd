class_name Shipping
extends RefCounted
## How an order gets to its buyer: the size of parcel a design makes, what
## packaging it fits in, what a courier's service charges for it, and what
## that packaging and service mean for the parcel on the way (the `terms`
## recorded on a Marketplace.Order when it is packed).
##
## Works on rows from data/packaging.json and data/couriers.json (`bands`,
## `couriers`, `services`), and the `shipping` block of data/game.json.
##
## A design falls in the smallest band it fits by size and weight. Packaging
## lists the bands it is made for: a design fits packaging made for its own
## band or a bigger one, and a small thing in a big box goes at the box's
## size, which costs more to post. The buyer pays the going rate for the
## speed of service they are promised; the seller pays the courier whatever
## the chosen service really costs, and keeps or makes up the difference.

var data: GameData


func _init(p_data: GameData) -> void:
	data = p_data


## The bands, smallest first.
func band_ids() -> Array:
	return data.bands.keys()


## Id of the smallest band a design fits by size and weight, or the biggest if
## it is too large for any.
func band_of(product: Dictionary) -> String:
	var size: Array = product["size_mm"].duplicate()
	size.sort()
	size.reverse()
	for band: Dictionary in data.bands.values():
		var limit: Array = band["max_size_mm"].duplicate()
		limit.sort()
		limit.reverse()
		var fits := float(product["filament_grams"]) <= float(band["max_weight_grams"])
		for axis in 3:
			fits = fits and float(size[axis]) <= float(limit[axis])
		if fits:
			return band["id"]
	return band_ids().back()


## The band a parcel goes at when something of `band` is packed in `packaging`:
## the smallest the packaging is made for that is no smaller than the item.
## "" if the item is too big for it.
func parcel_band(packaging: Dictionary, band: String) -> String:
	var order := band_ids()
	for candidate: String in order:
		if order.find(candidate) >= order.find(band) and packaging["fits_bands"].has(candidate):
			return candidate
	return ""


func fits(packaging: Dictionary, band: String) -> bool:
	return parcel_band(packaging, band) != ""


## Ids of the packaging on sale at `tier` that something of `band` fits in.
func packaging_for(band: String, tier: int) -> Array[StringName]:
	var found: Array[StringName] = []
	for row: Dictionary in data.packaging.values():
		if int(row["unlock_tier"]) <= tier and fits(row, band):
			found.append(StringName(row["id"]))
	return found


## What a design goes out in unless the player says otherwise: the cheapest
## box on sale that posts it at its own size. Failing that, the cheapest
## thing it fits in at all. &"" if nothing on sale will take it.
func default_packaging(band: String, tier: int) -> StringName:
	var best: StringName = &""
	var best_score := INF
	for id in packaging_for(band, tier):
		var row: Dictionary = data.packaging[id]
		var score := float(row["price_pence"])
		if row["kind"] != "box":
			score += 100000.0
		if parcel_band(row, band) != band:
			score += 10000.0
		if score < best_score:
			best = id
			best_score = score
	return best


## True if a service takes parcels of a band.
static func carries(service: Dictionary, band: String) -> bool:
	return service["prices"].has(band)


## What a service charges the seller for a parcel of a band, in pence.
static func price(service: Dictionary, band: String) -> int:
	return int(service["prices"].get(band, 0))


## Ids of the services on offer at `tier`, in the table's order.
func services_at(tier: int) -> Array[StringName]:
	var found: Array[StringName] = []
	for row: Dictionary in data.services.values():
		if int(row["unlock_tier"]) <= tier:
			found.append(StringName(row["id"]))
	return found


## The service a parcel of `band` really goes by when `chosen` is the one
## picked: that one if it takes the band, else the usual one, else the
## cheapest on offer that does. &"" if nobody will take it.
func service_for(chosen: StringName, band: String, tier: int) -> StringName:
	var usual := StringName(_config()["default_service"])
	for id: StringName in [chosen, usual]:
		if data.services.has(id) and carries(data.services[id], band) and int(data.services[id]["unlock_tier"]) <= tier:
			return id
	var best: StringName = &""
	for id in services_at(tier):
		if carries(data.services[id], band) and (best == &"" or price(data.services[id], band) < price(data.services[best], band)):
			best = id
	return best


## What the buyer is charged for postage on a parcel of `band` sent by
## `service`: the going rate for that speed. Anything quicker than standard is
## the seller's treat, so the buyer pays the standard rate for it.
func buyer_pays(service: Dictionary, band: String) -> int:
	var rates: Dictionary = _config()["buyer_pays"]
	var reference: String = rates.get(service["speed"], rates["standard"])
	if data.services.has(reference) and carries(data.services[reference], band):
		return price(data.services[reference], band)
	# The usual service doesn't take parcels this big: the cheapest that does sets the rate.
	var lowest := 0
	for row: Dictionary in data.services.values():
		if carries(row, band) and (lowest == 0 or price(row, band) < lowest):
			lowest = price(row, band)
	return lowest


## Stars added to (or, if negative, knocked off) a review for how the parcel
## was wrapped and how quickly it was promised.
func star_bonus(packaging: Dictionary, service: Dictionary) -> float:
	var config := _config()
	var wrapped := (float(packaging["presentation"]) - float(config["neutral_presentation"])) * float(config["stars_per_presentation_point"])
	return wrapped + float(config["speed_stars"].get(service["speed"], 0.0))


## Everything about how a design is sent that matters once it has gone:
## { packaging, service, band, protection, damage_multiplier, lost_chance,
##   late_chance, late_star_penalty, star_bonus, insured_pence, cost, buyer_pays }.
## `band` is the design's own; the parcel may go at a bigger one.
func terms(packaging: Dictionary, service: Dictionary, band: String) -> Dictionary:
	var sent_as := parcel_band(packaging, band)
	return {
		"packaging": packaging["id"], "service": service["id"], "band": sent_as,
		"protection": int(packaging["protection"]),
		"damage_multiplier": float(service["damage_multiplier"]),
		"lost_chance": float(service["lost_chance"]), "late_chance": float(service["late_chance"]),
		"late_star_penalty": float(_config()["late_star_penalty"]),
		"star_bonus": star_bonus(packaging, service),
		"insured_pence": int(service["insured_pence"]) if service["tracked"] else 0,
		"cost": price(service, sent_as), "buyer_pays": buyer_pays(service, band),
	}


## The terms a design goes on with nothing chosen: its usual box, the usual service.
func default_terms(product: Dictionary, tier: int) -> Dictionary:
	var band := band_of(product)
	var box := default_packaging(band, tier)
	if box == &"":
		return {}
	var sent_as := parcel_band(data.packaging[box], band)
	var service := service_for(&"", sent_as, tier)
	return terms(data.packaging[box], data.services[service], band) if service != &"" else {}


## When a parcel collected at `minute` arrives. `late` says whether it was held up.
func arrival(service: Dictionary, minute: float, late: bool, rng: RandomNumberGenerator) -> float:
	var transit: Array = service["delivery_minutes"]
	var at := minute + rng.randf_range(transit[0], transit[1])
	if late:
		var held: Array = _config()["late_minutes"]
		at += rng.randf_range(held[0], held[1])
	return at


func _config() -> Dictionary:
	return data.settings["shipping"]
