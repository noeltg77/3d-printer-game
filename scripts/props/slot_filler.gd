extends Node3D
## Placeholder set dressing: fills this model's slot markers with random items,
## e.g. spools on a filament rack. Real stock replaces this in Phase 3.

@export var items: Array[PackedScene] = []
@export_range(0.0, 1.0) var fill := 0.9
@export var slot_prefix := "spool_slot_"
@export var random_seed := 1
## The same item repeats for up to this many slots in a row, like colours bought in batches.
@export var max_run := 3


func _ready() -> void:
	if items.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed
	var item: PackedScene = null
	var run := 0
	for slot in find_children(slot_prefix + "*", "Node3D", true, false):
		if run == 0:
			item = items[rng.randi() % items.size()]
			run = rng.randi_range(1, max_run)
		run -= 1
		if rng.randf() <= fill:
			slot.add_child(item.instantiate())
