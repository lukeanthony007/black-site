extends Area3D
## CCTV — detects standing players. Can be camera-looped.

@export var view_range: float = 14.0
@export var view_angle_deg: float = 40.0
@export var boot_grace: float = 2.0

var _cooldown: float = 0.0
var _loop_timer: float = 0.0
var _mesh: MeshInstance3D
var _grace: float = 0.0

@onready var ray: RayCast3D = $RayCast3D


func _ready() -> void:
	add_to_group("cameras")
	if ray == null:
		ray = RayCast3D.new()
		ray.name = "RayCast3D"
		add_child(ray)
	ray.collision_mask = 2
	_grace = boot_grace
	_find_mesh()


func _find_mesh() -> void:
	var parent := get_parent()
	if parent == null:
		return
	_mesh = parent.get_node_or_null("LED") as MeshInstance3D
	if _mesh:
		return
	for child in parent.get_children():
		if child is MeshInstance3D:
			_mesh = child
			break


func is_looped() -> bool:
	return _loop_timer > 0.0


func apply_loop(duration: float = 12.0) -> void:
	_loop_timer = maxf(_loop_timer, duration)
	_set_loop_visual(true)


func _physics_process(delta: float) -> void:
	_grace = maxf(0.0, _grace - delta)
	if _loop_timer > 0.0:
		_loop_timer -= delta
		if _loop_timer <= 0.0:
			_set_loop_visual(false)
		return

	_cooldown = maxf(0.0, _cooldown - delta)
	if _cooldown > 0.0 or _grace > 0.0:
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return
	var eye := global_position
	var target := player.global_position + Vector3.UP * 1.0
	var to := target - eye
	if to.length() > view_range:
		return
	var forward := -global_transform.basis.z
	if forward.normalized().angle_to(to.normalized()) > deg_to_rad(view_angle_deg):
		return
	if player.has_method("is_crouching") and player.is_crouching():
		return
	ray.global_position = eye
	ray.target_position = ray.to_local(target)
	ray.force_raycast_update()
	if ray.is_colliding():
		var col := ray.get_collider()
		if col != player and col.get_parent() != player:
			return
	_cooldown = 2.5
	NoiseBus.emit_noise(player.global_position, 0.65, self)
	ObjectiveTracker.set_prompt("Camera spotted you")
	GameAudio.play_interact()


func _set_loop_visual(active: bool) -> void:
	if _mesh == null:
		_find_mesh()
	if _mesh == null:
		return
	var color := Color(0.2, 0.9, 0.4) if active else Color(0.9, 0.15, 0.1)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.2 if active else 1.8
	_mesh.material_override = mat
