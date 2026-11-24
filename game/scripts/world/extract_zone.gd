extends Area3D
## Extraction zone — win if required objectives done.


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		ObjectiveTracker.try_extract()
