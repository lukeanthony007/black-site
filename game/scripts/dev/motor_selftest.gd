extends Node
## Headless self-test: drives shipped MotorConstants + Player motor APIs.
## Run: godot --path game --headless res://scenes/dev_motor_selftest.tscn
## Exit 0 = pass.

var _fails: int = 0
var _noise_events: Array = []


func _ready() -> void:
	print("=== motor_selftest ===")
	_test_mantle_band()
	_test_landing_noise()
	_test_player_api_wrappers()
	await _test_mantle_probe_world()
	_test_gap_constants_sanity()
	print("=== motor_selftest done fails=%d ===" % _fails)
	await get_tree().process_frame
	get_tree().quit(0 if _fails == 0 else 1)


func _fail(msg: String) -> void:
	_fails += 1
	print("FAIL: ", msg)


func _ok(msg: String) -> void:
	print("OK: ", msg)


func _test_mantle_band() -> void:
	# Below band (pure jump territory) must fail
	if MotorConstants.is_mantleable_height(MotorConstants.MANTLE_MIN - 0.1):
		_fail("mantle should reject below MANTLE_MIN")
	else:
		_ok("reject below band")
	# Mid band must pass
	var mid := (MotorConstants.MANTLE_MIN + MotorConstants.MANTLE_MAX) * 0.5
	if not MotorConstants.is_mantleable_height(mid):
		_fail("mantle should accept mid band %.2f" % mid)
	else:
		_ok("accept mid band %.2f" % mid)
	# Above band must fail
	if MotorConstants.is_mantleable_height(MotorConstants.MANTLE_MAX + 0.2):
		_fail("mantle should reject above MANTLE_MAX")
	else:
		_ok("reject above band")
	# Edges inclusive
	if not MotorConstants.is_mantleable_height(MotorConstants.MANTLE_MIN):
		_fail("MANTLE_MIN should be inclusive")
	if not MotorConstants.is_mantleable_height(MotorConstants.MANTLE_MAX):
		_fail("MANTLE_MAX should be inclusive")
	else:
		_ok("band edges inclusive")


func _test_landing_noise() -> void:
	var soft_h := MotorConstants.LANDING_SOFT_MAX * 0.5
	var hard_h := MotorConstants.LANDING_HARD_MIN + 0.5
	var soft_n := MotorConstants.landing_noise_for_fall(soft_h)
	var hard_n := MotorConstants.landing_noise_for_fall(hard_h)
	if soft_n >= hard_n:
		_fail("soft noise (%.2f) should be < hard noise (%.2f)" % [soft_n, hard_n])
	else:
		_ok("soft noise %.2f < hard noise %.2f" % [soft_n, hard_n])
	if MotorConstants.classify_landing(soft_h) != MotorConstants.LandingKind.SOFT:
		_fail("soft_h not classified SOFT")
	if MotorConstants.classify_landing(hard_h) != MotorConstants.LandingKind.HARD:
		_fail("hard_h not classified HARD")
	if absf(soft_n - MotorConstants.LANDING_SOFT_NOISE) > 0.001:
		_fail("soft noise mismatch shipped constant")
	if absf(hard_n - MotorConstants.LANDING_HARD_NOISE) > 0.001:
		_fail("hard noise mismatch shipped constant")
	else:
		_ok("landing kinds + noise match MotorConstants")


func _test_player_api_wrappers() -> void:
	# Instantiate real player script without full scene tree children for pure methods
	var p: Node = load("res://scripts/player/player.gd").new()
	if not p.has_method("is_mantleable_height"):
		_fail("player missing is_mantleable_height")
		return
	var mid := (MotorConstants.MANTLE_MIN + MotorConstants.MANTLE_MAX) * 0.5
	if not p.is_mantleable_height(mid):
		_fail("player.is_mantleable_height mid failed")
	else:
		_ok("player.is_mantleable_height mid")
	if p.is_mantleable_height(MotorConstants.MANTLE_MAX + 1.0):
		_fail("player should reject tall ledge")
	else:
		_ok("player rejects tall ledge")
	var sn: float = p.landing_noise_for_fall(1.2)
	var hn: float = p.landing_noise_for_fall(3.5)
	if sn >= hn:
		_fail("player landing_noise soft>=hard")
	else:
		_ok("player landing_noise soft < hard (%.2f < %.2f)" % [sn, hn])
	p.free()


func _test_mantle_probe_world() -> void:
	# Minimal physics world: floor + mantle-height ledge; call real probe_mantle_target
	var root := Node3D.new()
	add_child(root)
	var floor_body := _static_box(root, Vector3(0, -0.1, 0), Vector3(10, 0.2, 10))
	var ledge_h: float = (MotorConstants.MANTLE_MIN + MotorConstants.MANTLE_MAX) * 0.5
	# Wall face at z≈-0.6 so chest probe (reach 0.85) hits from player z=0
	var wall := _static_box(root, Vector3(0, ledge_h * 0.5, -0.8), Vector3(2.0, ledge_h, 0.4))
	var top := _static_box(root, Vector3(0, ledge_h + 0.1, -1.3), Vector3(2.0, 0.2, 1.4))

	var player_scene: PackedScene = load("res://scenes/player.tscn")
	var player: CharacterBody3D = player_scene.instantiate()
	player.position = Vector3(0, 0.0, 0.0)
	player.rotation.y = 0.0 # -Z forward
	root.add_child(player)
	await get_tree().physics_frame
	await get_tree().physics_frame

	if not player.has_method("probe_mantle_target"):
		_fail("player missing probe_mantle_target")
		root.queue_free()
		return
	var hit: Dictionary = player.probe_mantle_target()
	if hit.is_empty():
		_fail("probe_mantle_target empty against mid-band ledge")
	else:
		var lh: float = float(hit.get("ledge_height", -1.0))
		if not player.is_mantleable_height(lh):
			_fail("probe height %.2f outside band" % lh)
		else:
			_ok("probe_mantle_target found ledge_height=%.2f" % lh)
		# Drive real try_mantle / begin path when probe works
		if player.has_method("try_mantle"):
			var started: bool = player.try_mantle()
			if not started:
				_fail("try_mantle returned false after successful probe")
			else:
				_ok("try_mantle started from real probe")

	if player.is_mantleable_height(MotorConstants.MANTLE_MAX + 0.5):
		_fail("band still broken after probe")
	else:
		_ok("post-probe band still rejects oversize")

	if player.is_mantleable_height(MotorConstants.MANTLE_MIN - 0.05):
		_fail("should reject short ledge height")
	else:
		_ok("rejects short ledge height")

	floor_body.name = "Floor"
	wall.name = "Wall"
	top.name = "Top"
	root.queue_free()


func _test_gap_constants_sanity() -> void:
	if not (MotorConstants.GAP_EASY < MotorConstants.GAP_MED
			and MotorConstants.GAP_MED < MotorConstants.GAP_HARD
			and MotorConstants.GAP_HARD < MotorConstants.GAP_EXTREME):
		_fail("gap distances not strictly increasing")
	else:
		_ok("gap ladder E<M<H<X")
	if MotorConstants.MAX_JUMP_HEIGHT >= MotorConstants.MANTLE_MIN:
		if MotorConstants.MAX_JUMP_HEIGHT > MotorConstants.MANTLE_MIN + 0.01:
			_fail("MANTLE_MIN should be >= MAX_JUMP_HEIGHT (beyond pure jump)")
		else:
			_ok("mantle starts at/above jump apex (%.3f vs %.3f)" % [
				MotorConstants.MAX_JUMP_HEIGHT, MotorConstants.MANTLE_MIN
			])
	else:
		_ok("mantle beyond jump apex")
	# Wallrun pure eligibility
	if not MotorConstants.can_start_wallrun(8.0, 0.2, true):
		_fail("lateral wallrun should allow sprint along wall")
	else:
		_ok("lateral wallrun allows sprint along wall")
	if MotorConstants.can_start_wallrun(8.0, 0.95, true):
		_fail("lateral wallrun should reject head-on into wall")
	else:
		_ok("lateral wallrun rejects head-on (use vertical instead)")
	if MotorConstants.can_start_wallrun(2.0, 0.1, true):
		_fail("wallrun should reject low speed")
	else:
		_ok("wallrun rejects low speed")
	# Vertical climb: into-wall (negative into_dot)
	if not MotorConstants.can_start_vertical_wallrun(8.0, -0.7, true):
		_fail("vertical wallrun should allow sprint into wall")
	else:
		_ok("vertical wallrun allows sprint into wall")
	if MotorConstants.can_start_vertical_wallrun(8.0, 0.1, true):
		_fail("vertical wallrun should reject parallel run")
	else:
		_ok("vertical wallrun rejects parallel (lateral only)")
	# Stair / ledge constants: auto-step covers stair rise, not tall hop pads
	if MotorConstants.MAX_STEP_HEIGHT < MotorConstants.STAIR_RISE:
		_fail("MAX_STEP_HEIGHT must cover STAIR_RISE")
	else:
		_ok("auto-step covers stair rise (%.2f >= %.2f)" % [
			MotorConstants.MAX_STEP_HEIGHT, MotorConstants.STAIR_RISE
		])
	if MotorConstants.MAX_STEP_HEIGHT >= MotorConstants.STEP_HARD:
		_fail("auto-step should not trivialize hard hop pads")
	else:
		_ok("hard hop pads still need jump")


func _static_box(parent: Node, pos: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 0
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	body.add_child(mi)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	parent.add_child(body)
	return body
