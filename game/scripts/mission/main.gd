extends Node3D


func _ready() -> void:
	AlertPhase.reset()
	ObjectiveTracker.reset_mission()
	ObjectiveTracker.set_player_vitals(100.0, 100.0, 50.0, 100.0)
	ObjectiveTracker.set_prompt("Infiltrate · complete objectives · extract on roof")

	var briefing_timer := get_tree().create_timer(3.5)
	briefing_timer.timeout.connect(func():
		if not ObjectiveTracker.ended:
			ObjectiveTracker.set_prompt("")
		briefing_timer = null
	, CONNECT_ONE_SHOT)
