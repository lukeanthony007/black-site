extends Area3D
## Lab UX: stand on pad to set checkpoint; optional auto-return zones use fall_reset group.
## Player return_to_checkpoint() on void fall uses the last pad stood on.

@export var zone_id: String = "hub"
@export var prompt_on_enter: String = ""


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 # player
	monitoring = true
	body_entered.connect(_on_body_entered)
	add_to_group("zone_checkpoints")
	add_to_group("checkpoint_%s" % zone_id)


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	if body.has_method("set_checkpoint"):
		var t := body.global_transform
		t.origin = global_position + Vector3(0, 0.05, 0)
		# Keep player facing; only snap position to pad center
		t.basis = body.global_transform.basis
		body.set_checkpoint(t)
	if prompt_on_enter != "":
		ObjectiveTracker.set_prompt(prompt_on_enter)
	else:
		ObjectiveTracker.set_prompt("Checkpoint: %s" % zone_id.to_upper())
