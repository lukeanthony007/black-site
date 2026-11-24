extends Node
## Headless: drive shipped WeaponData / WeaponController gunfeel APIs.
## Run: godot --path game --headless res://scenes/dev_gunfeel_selftest.tscn

var _fails: int = 0


func _ready() -> void:
	print("=== gunfeel_selftest ===")
	_test_hip_vs_ads_spread()
	_test_recovery_vs_baseline()
	_test_controller_api()
	_test_fire_rate_cooldown_math()
	print("=== gunfeel_selftest done fails=%d ===" % _fails)
	await get_tree().process_frame
	get_tree().quit(0 if _fails == 0 else 1)


func _fail(msg: String) -> void:
	_fails += 1
	print("FAIL: ", msg)


func _ok(msg: String) -> void:
	print("OK: ", msg)


func _test_hip_vs_ads_spread() -> void:
	var pistol := WeaponData.make_pistol()
	var hip := WeaponData.compute_spread_deg(pistol, 0.0, false)
	var ads := WeaponData.compute_spread_deg(pistol, 0.0, true)
	if ads >= hip:
		_fail("ADS spread (%.3f) should be < hip (%.3f)" % [ads, hip])
	else:
		_ok("ADS %.3f < hip %.3f deg" % [ads, hip])
	var hip_move := WeaponData.compute_spread_deg(pistol, 8.0, false)
	if hip_move <= hip:
		_fail("moving hip should widen spread")
	else:
		_ok("move spreads hip %.3f → %.3f" % [hip, hip_move])
	# ADS must still be meaningfully tighter than pre-tighten static base alone
	if ads >= WeaponData.PRE_TIGHTEN_BASE_SPREAD_PISTOL:
		_fail("ADS should beat old base spread baseline")
	else:
		_ok("ADS tighter than PRE_TIGHTEN_BASE_SPREAD_PISTOL")


func _test_recovery_vs_baseline() -> void:
	var pistol := WeaponData.make_pistol()
	if pistol.recovery_speed <= WeaponData.PRE_TIGHTEN_RECOVERY:
		_fail("recovery_speed %.1f should exceed pre-tighten %.1f" % [
			pistol.recovery_speed, WeaponData.PRE_TIGHTEN_RECOVERY
		])
	else:
		_ok("recovery %.1f > baseline %.1f" % [
			pistol.recovery_speed, WeaponData.PRE_TIGHTEN_RECOVERY
		])
	if pistol.recoil_pitch <= WeaponData.PRE_TIGHTEN_RECOIL_PITCH_PISTOL:
		_fail("recoil_pitch should be snappier than pre-tighten")
	else:
		_ok("recoil_pitch %.2f > pre %.2f" % [
			pistol.recoil_pitch, WeaponData.PRE_TIGHTEN_RECOIL_PITCH_PISTOL
		])


func _test_controller_api() -> void:
	# Real player scene weapon path (shipped hierarchy)
	var player_scene: PackedScene = load("res://scenes/player.tscn")
	var player: Node = player_scene.instantiate()
	add_child(player)
	var wc: WeaponController = player.get_node("CameraPivot/Camera3D/Weapon") as WeaponController
	if wc == null:
		_fail("player weapon path missing")
		player.queue_free()
		return
	wc.weapon_data = WeaponData.make_pistol()
	wc.mag = wc.weapon_data.magazine_size
	wc.reserve = wc.weapon_data.reserve_ammo
	var hip: float = wc.compute_spread_deg(0.0, 0)
	var ads: float = wc.compute_spread_deg(0.0, 1)
	if ads >= hip:
		_fail("controller ADS not tighter than hip")
	else:
		_ok("controller compute_spread_deg ADS < hip")
	if absf(wc.get_recovery_speed() - wc.weapon_data.recovery_speed) > 0.01:
		_fail("get_recovery_speed mismatch")
	else:
		_ok("get_recovery_speed matches weapon_data")
	var mag_before := wc.mag
	wc.try_fire()
	if wc.mag != mag_before - 1:
		_fail("try_fire did not consume mag")
	else:
		_ok("try_fire consumes magazine")
	if wc.get_recoil_pitch() <= 0.0:
		_fail("try_fire should set recoil_pitch residual")
	else:
		_ok("recoil residual after fire %.2f" % wc.get_recoil_pitch())
	player.queue_free()


func _test_fire_rate_cooldown_math() -> void:
	var pistol := WeaponData.make_pistol()
	var cd := 1.0 / pistol.fire_rate
	if cd <= 0.0 or cd > 1.0:
		_fail("fire cooldown out of range")
	else:
		_ok("fire cooldown %.3fs at rate %.1f" % [cd, pistol.fire_rate])
