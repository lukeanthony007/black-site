extends Node3D
## Outdoor OTR slice — mission bootstrap (parallel to indoor gym main.gd).


func _ready() -> void:
	AlertPhase.reset()
	ObjectiveTracker.setup_otr_mission()
	ObjectiveTracker.set_player_vitals(100.0, 100.0, 50.0, 100.0)
	ObjectiveTracker.set_prompt("OTR district · reach extract marker · avoid patrols")

	var briefing_timer := get_tree().create_timer(3.5)
	briefing_timer.timeout.connect(func():
		if not ObjectiveTracker.ended:
			ObjectiveTracker.set_prompt("")
		briefing_timer = null
	, CONNECT_ONE_SHOT)
