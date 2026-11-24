class_name Pickup
extends Area3D
## Ammo, health, keycard, or weapon touch-pickups.

enum PickupType {
	AMMO, HEALTH, KEYCARD, KEYCARD_SERVER,
	WEAPON_SMG, WEAPON_RIFLE, WEAPON_SILENCED, ARMOR,
	LOCKPICK, CAMERA_LOOP, DECOY
}


@export var pickup_type: PickupType = PickupType.AMMO
@export var amount: float = 24.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	match pickup_type:
		PickupType.AMMO:
			if body.has_node("CameraPivot/Camera3D/Weapon"):
				var weapon: WeaponController = body.get_node("CameraPivot/Camera3D/Weapon")
				weapon.add_ammo(int(amount))
			ObjectiveTracker.set_prompt("Ammo +%d" % int(amount))
			GameAudio.play_pickup()
		PickupType.HEALTH:
			if body.has_method("heal"):
				body.heal(amount)
			ObjectiveTracker.set_prompt("Health restored")
			GameAudio.play_pickup()
		PickupType.KEYCARD:
			if body.has_method("give_keycard"):
				body.give_keycard(1)
			GameAudio.play_pickup()
		PickupType.KEYCARD_SERVER:
			if body.has_method("give_keycard"):
				body.give_keycard(2)
			GameAudio.play_pickup()
		PickupType.WEAPON_SMG:
			if body.has_node("CameraPivot/Camera3D/Weapon"):
				var weapon: WeaponController = body.get_node("CameraPivot/Camera3D/Weapon")
				weapon.equip(WeaponData.make_smg())
		PickupType.WEAPON_RIFLE:
			if body.has_node("CameraPivot/Camera3D/Weapon"):
				var weapon: WeaponController = body.get_node("CameraPivot/Camera3D/Weapon")
				weapon.equip(WeaponData.make_rifle())
		PickupType.WEAPON_SILENCED:
			if body.has_node("CameraPivot/Camera3D/Weapon"):
				var weapon: WeaponController = body.get_node("CameraPivot/Camera3D/Weapon")
				weapon.equip(WeaponData.make_silenced())
		PickupType.ARMOR:
			if body.has_method("add_armor"):
				body.add_armor(amount)
			GameAudio.play_pickup()
		PickupType.LOCKPICK:
			if body.has_method("add_lockpicks"):
				body.add_lockpicks(int(amount))
			GameAudio.play_pickup()
		PickupType.CAMERA_LOOP:
			if body.has_method("add_camera_loops"):
				body.add_camera_loops(int(amount))
			GameAudio.play_pickup()
		PickupType.DECOY:
			if body.has_method("add_decoys"):
				body.add_decoys(int(amount))
			GameAudio.play_pickup()
	queue_free()
