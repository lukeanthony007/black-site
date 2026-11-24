extends Area3D
## Closet / dumpster / vent hatch — hide dragged corpses.

@export var prompt_text: String = "Hold E near body, drag here to hide"


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	monitoring = true
	monitorable = false
	collision_mask = 2 # player; corpses checked manually


func _physics_process(_delta: float) -> void:
	# Also accept corpses dragged into the volume
	for node in get_tree().get_nodes_in_group("corpses"):
		if not is_instance_valid(node):
			continue
		var corpse := node as Node3D
		if corpse == null or corpse.get("hidden"):
			continue
		if global_position.distance_to(corpse.global_position) < 1.6:
			if corpse.has_method("hide_body"):
				corpse.hide_body()


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		ObjectiveTracker.set_prompt(prompt_text)
