extends StaticBody3D
## Hold E to complete an objective (download / destroy).

@export var objective_id: String = "download"
@export var hold_seconds: float = 1.25
@export var prompt_text: String = "Hold E to interact"
@export var done_text: String = "Objective complete"

var _holding: float = 0.0
var _player_near: bool = false
var _done: bool = false

@onready var area: Area3D = $Area3D


func _ready() -> void:
	area.body_entered.connect(func(body: Node3D) -> void:
		if body.is_in_group("player"):
			_player_near = true
			if not _done:
				ObjectiveTracker.set_prompt(prompt_text)
	)
	area.body_exited.connect(func(body: Node3D) -> void:
		if body.is_in_group("player"):
			_player_near = false
			_holding = 0.0
	)


func _process(delta: float) -> void:
	if _done or not _player_near:
		return
	if Input.is_action_pressed("interact"):
		_holding += delta
		ObjectiveTracker.set_prompt("%s… %.0f%%" % [prompt_text, (_holding / hold_seconds) * 100.0])
		if _holding >= hold_seconds:
			_finish()
	else:
		_holding = 0.0


func interact(_player: Node) -> void:
	# Instant path if ray-interacted; hold still works via Area.
	if _done:
		return
	_finish()


func _finish() -> void:
	_done = true
	ObjectiveTracker.complete(objective_id)
	ObjectiveTracker.set_prompt(done_text)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.6, 0.3)
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.8, 0.3)
	mat.emission_energy_multiplier = 1.5
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.roughness = 0.9
	if has_node("MeshInstance3D"):
		$MeshInstance3D.material_override = mat
