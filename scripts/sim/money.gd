class_name Money
extends RefCounted
## Formatting for amounts held as integer cents.


## "$12.50", "-$3.00"
static func text(cents: int) -> String:
	var whole := absi(cents)
	return "%s$%d.%02d" % ["-" if cents < 0 else "", whole / 100, whole % 100]
