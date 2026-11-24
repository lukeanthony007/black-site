class_name Damageable
extends Node
## Attach to any body that can take damage.

signal died
signal damaged(amount: float, remaining: float)

@export var max_health: float = 100.0
@export var destroy_owner_on_death: bool = true

var health: float


func _ready() -> void:
	health = max_health


func is_alive() -> bool:
	return health > 0.0


func apply_damage(amount: float, _from: Node = null) -> void:
	if health <= 0.0:
		return
	health = maxf(0.0, health - amount)
	damaged.emit(amount, health)
	if health <= 0.0:
		died.emit()
		if destroy_owner_on_death:
			owner.queue_free()
