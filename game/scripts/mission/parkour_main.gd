extends Node3D
## Animus freerun course — mission bootstrap.


func _ready() -> void:
	AlertPhase.reset()
	ObjectiveTracker.setup_parkour_mission()
	ObjectiveTracker.set_player_vitals(100.0, 100.0, 0.0, 100.0)
	ObjectiveTracker.set_prompt("ROOFTOPS · follow the red · clear each gate · extract on the helipad")

	var player := get_node_or_null("Player")
	if player and player.has_method("set_checkpoint"):
		player.set_checkpoint(player.global_transform)

	var briefing_timer := get_tree().create_timer(4.0)
	briefing_timer.timeout.connect(func():
		if not ObjectiveTracker.ended:
			ObjectiveTracker.set_prompt("")
		briefing_timer = null
	, CONNECT_ONE_SHOT)
