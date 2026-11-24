extends Node3D
## PARKOUR GYM — measured lab. Geometry uses MotorConstants only.
## Movement wings (stride/gaps/climb/tights/wall): no live AI.
## Systems (guards/cameras/doors/hide): STEALTH + COMBAT only.

const WALL := Color(0.78, 0.79, 0.82)
const FLOOR := Color(0.55, 0.56, 0.58)
const ACCENT := Color(0.45, 0.5, 0.55)
const DANGER := Color(0.7, 0.25, 0.2)
const TECH := Color(0.25, 0.45, 0.55)
const MATTE := Color(0.28, 0.3, 0.34)
const NAVY := Color(0.16, 0.2, 0.3)
const WOOD := Color(0.55, 0.42, 0.3)
const MULLION := Color(0.12, 0.13, 0.15)
## Muted hub accents — no rainbow lab palette
const BRAND := Color(0.22, 0.24, 0.28)
const SOFT := Color(0.88, 0.88, 0.9)
const PAD := Color(0.58, 0.58, 0.6) ## parkour blocks / steps (neutral)
const CP := Color(0.5, 0.52, 0.55) ## checkpoint markers
const LABEL_MUTE := Color(0.75, 0.78, 0.82)

const GLASS_TINT := Color(0.6, 0.78, 0.85, 0.28)

## Exported for layout verification scripts (edge-to-edge gaps / step rises).
var measured_gaps: Array = [] ## {id, gap, expected}
var measured_steps: Array = [] ## {id, rise, expected}
var movement_wing_guard_count: int = 0
var systems_guard_count: int = 0


func _ready() -> void:
	_build_facility()
	_spawn_entities()


func _build_facility() -> void:
	measured_gaps.clear()
	measured_steps.clear()
	_build_shell()
	_build_hub()
	_build_stride_hall()
	_build_gap_course()
	_build_climb_tower()
	_build_tights()
	_build_wallrun_strip()
	_build_combat_pad()
	_build_stealth_wing()
	_build_upper_links()
	_add_zone_labels()
	_add_legend()
	_add_lights()


func _build_shell() -> void:
	_box(Vector3(0, -0.4, -1), Vector3(80, 0.3, 80), Color(0.08, 0.09, 0.1))
	_box(Vector3(0, -0.15, -1), Vector3(52, 0.3, 50), FLOOR)
	var wall_h := 12.2
	var wall_y := wall_h * 0.5 - 0.15
	_box(Vector3(0, wall_y, -26.1), Vector3(52.4, wall_h, 0.4), WALL)
	_box(Vector3(0, wall_y, 24.1), Vector3(52.4, wall_h, 0.4), WALL)
	_box(Vector3(26.1, wall_y, -1), Vector3(0.4, wall_h, 50.4), WALL)
	_box(Vector3(-26.1, wall_y, -1), Vector3(0.4, wall_h, 50.4), WALL)
	_glass(Vector3(0, 11.2, -26.0), Vector3(51.5, 1.2, 0.12))
	_glass(Vector3(0, 11.2, 24.0), Vector3(51.5, 1.2, 0.12))
	_glass(Vector3(26.0, 11.2, -1), Vector3(0.12, 1.2, 49.5))
	_glass(Vector3(-26.0, 11.2, -1), Vector3(0.12, 1.2, 49.5))
	# Roof ring (skylight over hub)
	_box(Vector3(0, 12.15, -16.5), Vector3(52, 0.3, 19), MATTE)
	_box(Vector3(0, 12.15, 15.5), Vector3(52, 0.3, 17), MATTE)
	_box(Vector3(-16.5, 12.15, 0), Vector3(19, 0.3, 14), MATTE)
	_box(Vector3(16.5, 12.15, 0), Vector3(19, 0.3, 14), MATTE)
	# Wing dividers with openings
	_box(Vector3(-11, 2.0, -8.1), Vector3(14, 4.0, 0.3), WALL)
	_box(Vector3(11, 2.0, -8.1), Vector3(14, 4.0, 0.3), WALL)
	_box(Vector3(0, 5.5, -8.1), Vector3(36, 3.0, 0.3), WALL)
	_box(Vector3(8.1, 2.0, -13), Vector3(0.3, 4.0, 12), WALL)
	_box(Vector3(8.1, 2.0, 11), Vector3(0.3, 4.0, 16), WALL)
	_box(Vector3(8.1, 5.5, -1), Vector3(0.3, 3.0, 36), WALL)
	_box(Vector3(-8.1, 2.0, -13), Vector3(0.3, 4.0, 12), WALL)
	_box(Vector3(-8.1, 2.0, 11), Vector3(0.3, 4.0, 16), WALL)
	_box(Vector3(-8.1, 5.5, -1), Vector3(0.3, 3.0, 36), WALL)
	_box(Vector3(-7, 2.0, 8.1), Vector3(8, 4.0, 0.3), WALL)
	_box(Vector3(7, 2.0, 8.1), Vector3(8, 4.0, 0.3), WALL)
	_box(Vector3(0, 5.5, 8.1), Vector3(36, 3.0, 0.3), WALL)


func _build_hub() -> void:
	_panel(Vector3(0, 0.02, 0), Vector3(10, 0.02, 10), NAVY)
	_panel(Vector3(0, 0.03, 0), Vector3(4, 0.02, 4), BRAND)
	_box(Vector3(0, 0.5, 2.5), Vector3(4.5, 1.0, 0.8), WALL)
	_panel(Vector3(0, 1.03, 2.5), Vector3(4.7, 0.06, 1.0), WOOD)
	_box(Vector3(4.5, 0.4, 3.5), Vector3(3.5, 0.8, 1.2), MATTE)
	# Walkable real stairs to mid balcony (~0.17 × 24 ≈ 4.1m)
	_build_stairs(Vector3(-2.0, 0.0, -0.3), Vector3(0, 0, -1), 24, 1.6)
	# Separate hop pads (parkour, not walkable) — off to the side
	_step_pad(Vector3(3.2, 0, -3), MotorConstants.STEP_EASY, PAD, "hub_hop_e")
	_step_pad(Vector3(5.0, 0, -4.2), MotorConstants.STEP_MED, PAD, "hub_hop_m")
	_step_pad(Vector3(3.5, 0, -5.8), MotorConstants.STEP_HARD, PAD, "hub_hop_h")
	# Mantle ledges on a wall face
	_box(Vector3(6.5, MotorConstants.MANTLE_LEDGE_LOW * 0.5, -2), Vector3(0.4, MotorConstants.MANTLE_LEDGE_LOW, 2.4), MATTE)
	_box(Vector3(6.5, MotorConstants.MANTLE_LEDGE_LOW + 0.12, -2), Vector3(1.6, 0.24, 2.4), PAD)
	_record_step("hub_mantle_low", MotorConstants.MANTLE_LEDGE_LOW, MotorConstants.MANTLE_LEDGE_LOW)
	_box(Vector3(6.5, MotorConstants.MANTLE_LEDGE_HIGH * 0.5, 1.5), Vector3(0.4, MotorConstants.MANTLE_LEDGE_HIGH, 2.4), MATTE)
	_box(Vector3(6.5, MotorConstants.MANTLE_LEDGE_HIGH + 0.12, 1.5), Vector3(1.6, 0.24, 2.4), PAD)
	_record_step("hub_mantle_high", MotorConstants.MANTLE_LEDGE_HIGH, MotorConstants.MANTLE_LEDGE_HIGH)
	# Mid balcony ring
	_box(Vector3(0, 3.85, -6.5), Vector3(14, 0.3, 3), FLOOR)
	_box(Vector3(0, 3.85, 5.5), Vector3(14, 0.3, 3), FLOOR)
	_box(Vector3(-5.5, 3.85, 0), Vector3(3, 0.3, 8), FLOOR)
	_box(Vector3(5.5, 3.85, 0), Vector3(3, 0.3, 8), FLOOR)
	# Solid faces under ring for vertical wall-climb + mantle.
	# Set into the balcony (not into hub floor) so spawn stays clear.
	# North hub lip ≈ z=-5; south ≈ z=4; west/east ≈ x=±4.
	_box(Vector3(0, 1.925, -5.25), Vector3(10.0, 3.85, 0.4), WALL) # north face
	_box(Vector3(0, 1.925, 5.25), Vector3(10.0, 3.85, 0.4), WALL) # south face
	_box(Vector3(-5.25, 1.925, 0), Vector3(0.4, 3.85, 6.0), WALL) # west face
	_box(Vector3(5.25, 1.925, 0), Vector3(0.4, 3.85, 6.0), WALL) # east face
	# Lip pads on top for clear standable grab targets
	_box(Vector3(0, 3.95, -5.35), Vector3(9.5, 0.12, 0.55), PAD)
	_box(Vector3(0, 3.95, 5.35), Vector3(9.5, 0.12, 0.55), PAD)
	_box(Vector3(-5.35, 3.95, 0), Vector3(0.55, 0.12, 5.5), PAD)
	_box(Vector3(5.35, 3.95, 0), Vector3(0.55, 0.12, 5.5), PAD)
	_glass(Vector3(-3.9, 4.25, -2), Vector3(0.08, 0.55, 6))
	_glass(Vector3(3.9, 4.25, -2), Vector3(0.08, 0.55, 6))
	_glass(Vector3(0, 4.25, -4.9), Vector3(6, 0.55, 0.08))
	_glass(Vector3(0, 4.25, 3.9), Vector3(6, 0.55, 0.08))
	for px in [-6.5, 6.5]:
		for pz in [-6.5, 6.5]:
			_box(Vector3(px, 6.0, pz), Vector3(0.55, 12.0, 0.55), WALL)


func _build_stride_hall() -> void:
	_panel(Vector3(0, 0.02, -16), Vector3(6, 0.02, 14), Color(0.48, 0.5, 0.52))
	for i in 6:
		_panel(Vector3(0, 0.025, -10 - i * 2.5), Vector3(0.2, 0.02, 0.9), ACCENT)
	_box(Vector3(-6.2, 2.0, -16), Vector3(0.3, 4.0, 16), WALL)
	_box(Vector3(6.2, 2.0, -16), Vector3(0.3, 4.0, 16), WALL)
	# Slide-under: solid from SLIDE_CLEARANCE up (opening height = clearance)
	var clear := MotorConstants.SLIDE_CLEARANCE
	_box(Vector3(0, clear + 1.5, -14), Vector3(12, 3.0, 0.35), MATTE)
	_box(Vector3(0, clear - 0.04, -14), Vector3(12, 0.08, 0.4), MULLION)
	_panel(Vector3(0, 0.025, -11), Vector3(3, 0.02, 1.5), ACCENT)
	_panel(Vector3(0, 0.025, -18), Vector3(3, 0.02, 1.5), ACCENT)
	# Overhead bridges (visual route, no AI)
	_box(Vector3(-3.5, 3.85, -12), Vector3(3.5, 0.3, 2.2), ACCENT)
	_box(Vector3(3.5, 3.85, -16), Vector3(3.5, 0.3, 2.2), ACCENT)
	_box(Vector3(0, 3.85, -22), Vector3(12, 0.3, 4), FLOOR)


func _build_gap_course() -> void:
	# Edge-to-edge gaps from MotorConstants — pad half-size 1.0 → centers gap+2
	var half := 1.0
	var start_x := -10.0
	var gaps: Array = [
		["gap_easy", MotorConstants.GAP_EASY, PAD],
		["gap_med", MotorConstants.GAP_MED, PAD],
		["gap_hard", MotorConstants.GAP_HARD, PAD],
		["gap_extreme", MotorConstants.GAP_EXTREME, PAD],
	]
	var x := start_x
	var z := 0.0
	_pad(Vector3(x, 0.4, z), Vector3(half * 2.0, 0.8, half * 2.0), PAD)
	for g: Array in gaps:
		var edge_gap: float = g[1]
		var next_x := x - (half + edge_gap + half)
		_pad(Vector3(next_x, 0.4, z), Vector3(half * 2.0, 0.8, half * 2.0), g[2])
		_record_gap(g[0], absf(x - next_x) - half * 2.0, edge_gap)
		x = next_x
	# Mid catwalk same gaps
	x = start_x
	_pad(Vector3(x, 4.0, -3), Vector3(2.0, 0.3, 1.8), PAD)
	for g: Array in gaps:
		var edge_gap: float = g[1]
		var next_x := x - (1.0 + edge_gap + 1.0)
		_pad(Vector3(next_x, 4.0, -3), Vector3(2.0, 0.3, 1.8), g[2])
		_record_gap(str(g[0]) + "_mid", absf(x - next_x) - 2.0, edge_gap)
		x = next_x
	_box(Vector3(-22, 3.85, 4), Vector3(5, 0.3, 6), FLOOR)


func _build_climb_tower() -> void:
	# Real collidable stair flights: G → F2 → F3 → roof (auto-step, no ramp)
	_build_stairs(Vector3(10.5, 0.0, 1.0), Vector3(1, 0, 0), 24, 1.6) # east to F2
	_box(Vector3(15.5, 3.95, 1.0), Vector3(3.5, 0.3, 3.5), FLOOR) # F2 landing
	_build_stairs(Vector3(15.5, 4.0, -0.5), Vector3(0, 0, -1), 24, 1.6) # north to F3
	_box(Vector3(15.5, 7.95, -5.5), Vector3(4.0, 0.3, 3.5), FLOOR) # F3 landing
	_build_stairs(Vector3(16.5, 8.0, -5.5), Vector3(1, 0, 0), 24, 1.6) # east to roof
	_box(Vector3(20, 11.85, 0), Vector3(5.0, 0.3, 6.0), ACCENT) # roof / extract pad
	# Optional hop pads beside stairs (parkour, jump required)
	_step_pad(Vector3(11.5, 0, 3.5), MotorConstants.STEP_EASY, PAD, "climb_hop_e")
	_step_pad(Vector3(13.0, 0, 4.5), MotorConstants.STEP_MED, PAD, "climb_hop_m")
	_step_pad(Vector3(14.5, 0, 3.5), MotorConstants.STEP_HARD, PAD, "climb_hop_h")
	# Mantle ledges mid tower
	var m_low := MotorConstants.MANTLE_LEDGE_LOW
	_box(Vector3(18, m_low * 0.5, -3), Vector3(0.4, m_low, 2.2), MATTE)
	_pad(Vector3(18.7, m_low + 0.12, -3), Vector3(1.6, 0.24, 2.2), PAD)
	_record_step("climb_mantle_low", m_low, m_low)
	var m_hi := MotorConstants.MANTLE_LEDGE_HIGH
	_box(Vector3(18, 2.0 + m_hi * 0.5, 2), Vector3(0.4, m_hi, 2.2), MATTE)
	_pad(Vector3(18.7, 2.0 + m_hi + 0.12, 2), Vector3(1.6, 0.24, 2.2), PAD)
	_record_step("climb_mantle_high", m_hi, m_hi)
	# Extra landings + gentle ramp alt
	_box(Vector3(18, 4.0, 3), Vector3(3.5, 0.3, 3.5), ACCENT)
	_box(Vector3(16, 7.85, 0), Vector3(4.5, 0.3, 5.0), ACCENT)
	_ramp(Vector3(11, 1.9, -5.5), Vector3(2.4, 0.3, 12.5), 17.5, WALL)
	_box(Vector3(11, 3.85, -12), Vector3(3.5, 0.3, 3), FLOOR)


func _build_tights() -> void:
	var clear := MotorConstants.SLIDE_CLEARANCE
	# Crawl ceiling at SLIDE_CLEARANCE
	_box(Vector3(0, clear + 0.12, 13), Vector3(5, 0.25, 8), MATTE)
	_box(Vector3(-2.7, clear * 0.5, 13), Vector3(0.3, clear, 8), WALL)
	_box(Vector3(2.7, clear * 0.5, 13), Vector3(0.3, clear, 8), WALL)
	# Slide choke
	_box(Vector3(0, clear + 1.4, 17.5), Vector3(5.5, 2.5, 0.35), MATTE)
	_box(Vector3(0, clear - 0.04, 17.5), Vector3(5.5, 0.08, 0.4), MULLION)
	_box(Vector3(-5, 1.5, 19), Vector3(0.3, 3.0, 6), WALL)
	_box(Vector3(5, 1.5, 19), Vector3(0.3, 3.0, 6), WALL)
	_box(Vector3(-1.5, 1.5, 20), Vector3(0.3, 3.0, 4), WALL)
	_box(Vector3(1.5, 1.5, 18), Vector3(0.3, 3.0, 4), WALL)
	_step_pad(Vector3(-3.5, 0, 19), MotorConstants.STEP_EASY, PAD, "tights_e")
	_step_pad(Vector3(3.5, 0, 20), MotorConstants.STEP_MED, PAD, "tights_m")
	_box(Vector3(0, 3.85, 11), Vector3(8, 0.3, 3), FLOOR)


func _build_wallrun_strip() -> void:
	## NE pocket: sprint → jump → cling parallel walls → wallkick to exit pads.
	## Inner faces ~1.7 m apart so WALLRUN_ATTACH_DIST reaches from lane center.
	var mid_x := 12.0
	var mid_z := -16.0
	var half_gap := 0.85 ## clear width between inner faces
	var wall_t := 0.3
	var wall_h := 4.2
	var run_len := 14.0
	var left_x := mid_x - half_gap - wall_t * 0.5
	var right_x := mid_x + half_gap + wall_t * 0.5

	# Lane paint + approach
	_panel(Vector3(mid_x, 0.02, -10.5), Vector3(4.0, 0.02, 4.0), Color(0.4, 0.42, 0.48))
	_panel(Vector3(mid_x, 0.02, mid_z), Vector3(half_gap * 2.0 + 0.5, 0.02, run_len), Color(0.38, 0.4, 0.45))
	# Entry curb — sprint-jump onto / along a wall
	_pad(Vector3(mid_x, 0.22, -10.0), Vector3(2.2, 0.44, 1.4), PAD)

	# Parallel walls (long enough for full WALLRUN_MAX_TIME at WALLRUN_SPEED)
	_box(Vector3(left_x, wall_h * 0.5, mid_z), Vector3(wall_t, wall_h, run_len), WALL)
	_box(Vector3(right_x, wall_h * 0.5, mid_z), Vector3(wall_t, wall_h, run_len), WALL)

	# Mid trench: raised shoulders + sunken center so airtime is natural
	# (still lands on facility floor if you miss the wall — soft fail)
	_box(Vector3(left_x + 0.15, 0.35, mid_z), Vector3(0.55, 0.7, 4.5), MATTE)
	_box(Vector3(right_x - 0.15, 0.35, mid_z), Vector3(0.55, 0.7, 4.5), MATTE)

	# Exit pads (north / -Z) — wallkick target
	_panel(Vector3(mid_x, 0.025, -9.5), Vector3(2.2, 0.02, 1.0), ACCENT)
	_pad(Vector3(mid_x, 0.45, -22.2), Vector3(2.6, 0.9, 2.2), PAD)
	_pad(Vector3(mid_x, 1.35, -23.6), Vector3(2.2, 0.35, 1.6), PAD)
	_pad(Vector3(mid_x, 2.1, -24.6), Vector3(2.0, 0.3, 1.4), PAD)


func _build_combat_pad() -> void:
	_panel(Vector3(16, 0.02, 15), Vector3(14, 0.02, 12), Color(0.42, 0.35, 0.32))
	for c: Vector3 in [
		Vector3(13, 0.55, 13), Vector3(17, 0.55, 13), Vector3(15, 0.55, 17),
		Vector3(19, 0.9, 16), Vector3(12, 0.9, 18), Vector3(20, 0.4, 19),
	]:
		_box(c, Vector3(1.3, c.y * 2.0, 1.3), Color(0.5, 0.38, 0.25))
	_box(Vector3(21, 2.0, 13), Vector3(3, 0.3, 3), ACCENT)
	_box(Vector3(21, 1.0, 13), Vector3(0.8, 2.0, 0.8), WALL)
	_box(Vector3(11, 1.5, 15), Vector3(0.3, 3.0, 6), WALL)
	_box(Vector3(17, 1.5, 21), Vector3(8, 3.0, 0.3), WALL)


func _build_stealth_wing() -> void:
	_box(Vector3(-20.5, 1.6, 10), Vector3(5, 3.2, 0.3), WALL)
	_box(Vector3(-10.5, 1.6, 10), Vector3(7, 3.2, 0.3), WALL)
	_box(Vector3(-15, 2.85, 10), Vector3(2.4, 0.7, 0.3), WALL)
	_box(Vector3(-18.5, 1.6, 12.5), Vector3(0.3, 3.2, 3.5), WALL)
	_box(Vector3(-21, 1.6, 14.2), Vector3(5, 3.2, 0.3), WALL)
	_box(Vector3(-12, 1.6, 15), Vector3(0.3, 3.2, 2.5), WALL)
	_box(Vector3(-12, 1.6, 20), Vector3(0.3, 3.2, 2.5), WALL)
	_box(Vector3(-12, 2.85, 17.5), Vector3(0.3, 0.7, 2.4), WALL)
	_box(Vector3(-15, 1.6, 16), Vector3(6, 3.2, 0.3), WALL)
	_box(Vector3(-15, 1.6, 21), Vector3(6, 3.2, 0.3), WALL)
	_panel(Vector3(-18.5, 0.02, 18.5), Vector3(7, 0.02, 5), NAVY)
	_box(Vector3(-14, 1.6, 15.5), Vector3(0.3, 3.2, 2.5), WALL)
	_box(Vector3(-14, 1.6, 20.5), Vector3(0.3, 3.2, 2.5), WALL)
	_box(Vector3(-14, 2.85, 18), Vector3(0.3, 0.7, 2.4), WALL)
	_box(Vector3(-18, 1.6, 16), Vector3(8, 3.2, 0.3), WALL)
	for rx in [-20.5, -17.0]:
		_box(Vector3(rx, 0.9, 19.8), Vector3(1.0, 1.8, 0.7), NAVY)
		_panel(Vector3(rx, 0.9, 19.4), Vector3(0.8, 1.5, 0.05), Color(0.2, 0.9, 0.8), 1.4)
	_box(Vector3(-16, 3.85, 12), Vector3(12, 0.3, 5), FLOOR)
	_box(Vector3(-20, 3.85, 18), Vector3(4, 0.3, 6), FLOOR)
	_box(Vector3(-12, 3.85, 18), Vector3(4, 0.3, 6), FLOOR)


func _build_upper_links() -> void:
	_box(Vector3(0, 7.85, -6), Vector3(14, 0.3, 3), FLOOR)
	_box(Vector3(6, 7.85, 0), Vector3(3, 0.3, 10), FLOOR)
	_box(Vector3(-6, 7.85, 0), Vector3(3, 0.3, 10), FLOOR)
	_box(Vector3(0, 7.85, 6), Vector3(10, 0.3, 3), FLOOR)
	# High bridge gap = GAP_MED
	var half := 1.5
	var g := MotorConstants.GAP_MED
	_pad(Vector3(-half - g * 0.5, 7.85, 0), Vector3(half * 2.0, 0.3, 1.4), PAD)
	_pad(Vector3(half + g * 0.5, 7.85, 0), Vector3(half * 2.0, 0.3, 1.4), PAD)
	_record_gap("high_ring", g, MotorConstants.GAP_MED)
	_pad(Vector3(-4, 12.0, -4), Vector3(2.5, 0.3, 2.5), PAD)
	_pad(Vector3(4, 12.0, 4), Vector3(2.5, 0.3, 2.5), PAD)
	_pad(Vector3(0, 12.0, 0), Vector3(2.0, 0.3, 2.0), PAD)


func _add_zone_labels() -> void:
	pass


func _add_legend() -> void:
	pass

func _add_lights() -> void:
	for p: Vector3 in [
		Vector3(0, 3.6, 0), Vector3(0, 7.5, 0), Vector3(0, 3.5, -16),
		Vector3(-16, 3.5, 0), Vector3(16, 3.5, 0), Vector3(0, 2.5, 14),
		Vector3(16, 3.5, 15), Vector3(-16, 3.5, 15), Vector3(20, 11.5, 0),
		Vector3(12, 3.5, -16), Vector3(14, 6.5, 0),
	]:
		_ceiling_lamp(p, Color(0.95, 0.95, 1.0), 2.2, 12.0, 48.0)
	_omni_fill(Vector3(0, 2.0, 1), Color(0.95, 0.9, 0.8), 0.8, 8.0)
	_omni_fill(Vector3(0, 2.0, -16), Color(0.4, 0.7, 1.0), 0.7, 9.0)
	_omni_fill(Vector3(-16, 2.5, 0), Color(1.0, 0.7, 0.35), 0.75, 9.0)
	_omni_fill(Vector3(16, 3.0, 0), Color(1.0, 0.5, 0.35), 0.8, 9.0)
	_omni_fill(Vector3(0, 1.5, 14), Color(0.55, 0.85, 0.45), 0.6, 7.0)
	_omni_fill(Vector3(16, 2.0, 15), Color(1.0, 0.35, 0.25), 0.7, 8.0)
	_omni_fill(Vector3(-16, 2.0, 16), Color(0.35, 0.9, 0.7), 0.7, 8.0)
	_omni_fill(Vector3(20, 12.5, 0), Color(0.3, 1.0, 0.45), 1.5, 8.0)
	_omni_fill(Vector3(12, 2.0, -16), Color(0.95, 0.8, 0.3), 0.7, 8.0)


# --- Measured helpers ---------------------------------------------------------

func _record_gap(id: String, actual: float, expected: float) -> void:
	measured_gaps.append({"id": id, "gap": actual, "expected": expected})


func _record_step(id: String, actual: float, expected: float) -> void:
	measured_steps.append({"id": id, "rise": actual, "expected": expected})


func _step_pad(pos: Vector3, rise: float, color: Color, id: String) -> void:
	_pad(Vector3(pos.x, rise * 0.5, pos.z), Vector3(1.4, rise, 1.4), color)
	_record_step(id, rise, rise)


## Stairs: visible treads (no collision) + invisible walk slab under them.
## Looks like real steps; walks smooth up and down (no per-riser snap jitter).
func _build_stairs(start: Vector3, forward: Vector3, step_count: int, width: float = -1.0) -> void:
	var rise := MotorConstants.STAIR_RISE
	var tread := MotorConstants.STAIR_TREAD
	if width < 0.0:
		width = MotorConstants.STAIR_WIDTH
	forward.y = 0.0
	if forward.length() < 0.01:
		return
	forward = forward.normalized()
	var along_x := absf(forward.x) >= absf(forward.z)
	# Visual treads only
	for i in step_count:
		var along := tread * (float(i) + 0.5)
		var up := rise * (float(i) + 0.5)
		var pos := start + forward * along + Vector3(0.0, up, 0.0)
		var depth := tread * 0.98
		var size := Vector3(depth, rise * 0.95, width) if along_x else Vector3(width, rise * 0.95, depth)
		_deco_box(pos, size, PAD)
	_record_step("stairs_r%.2f" % rise, rise, rise)

	var run := tread * float(step_count)
	var rise_total := rise * float(step_count)
	var hyp := sqrt(run * run + rise_total * rise_total)
	var tilt_deg := rad_to_deg(atan(rise_total / maxf(run, 0.001)))
	# Invisible collidable walk surface (no mesh — not visible "cheat ramp")
	var mid := start + forward * (run * 0.5) + Vector3(0.0, rise_total * 0.5, 0.0)
	# Thicker walk slab so downhill stay-on-floor is stable
	var ramp_size := Vector3(hyp, 0.28, width * 0.98) if along_x else Vector3(width * 0.98, 0.28, hyp)
	var walk := _collision_box(mid, ramp_size)
	if along_x:
		walk.rotation_degrees.z = tilt_deg * signf(forward.x)
	else:
		walk.rotation_degrees.x = -tilt_deg * signf(forward.z)

	var top_along := run + tread * 0.45
	var top_pos := start + forward * top_along + Vector3(0.0, rise_total + 0.08, 0.0)
	var top_size := Vector3(tread * 1.5, 0.16, width) if along_x else Vector3(width, 0.16, tread * 1.5)
	_box(top_pos, top_size, FLOOR)


## Collision-only box (no mesh) for smooth stair walk surfaces.
func _collision_box(pos: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = pos
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	add_child(body)
	return body


## Visual-only box (stair treads).
func _deco_box(pos: Vector3, size: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mi.material_override = mat
	mi.position = pos
	add_child(mi)


func _pad(pos: Vector3, size: Vector3, color: Color) -> void:
	_box(pos, size, color)


func _make_checkpoint(pos: Vector3, zone_id: String, prompt: String) -> void:
	var area := Area3D.new()
	area.position = pos
	area.set_script(load("res://scripts/world/zone_checkpoint.gd"))
	area.set("zone_id", zone_id)
	area.set("prompt_on_enter", prompt)
	N64Look.cyl(area, Vector3(0, 0.02, 0), 0.9, 0.06, CP, "Pad", 0.0, 10)
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 1.0
	shape.height = 0.4
	col.shape = shape
	col.position.y = 0.15
	area.add_child(col)
	var label := Label3D.new()
	label.text = "CP"
	label.position = Vector3(0, 0.5, 0)
	label.font_size = 36
	label.modulate = LABEL_MUTE
	area.add_child(label)
	add_child(area)


# --- Lights / primitives (shared) ---------------------------------------------

func _ceiling_lamp(pos: Vector3, color: Color, energy: float, range_m: float, spot_deg: float) -> void:
	var fixture := MeshInstance3D.new()
	var plate := BoxMesh.new()
	plate.size = Vector3(0.7, 0.06, 0.7)
	fixture.mesh = plate
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = color.lightened(0.2)
	fmat.emission_enabled = true
	fmat.emission = color
	fmat.emission_energy_multiplier = 1.8
	fmat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	fmat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	fixture.material_override = fmat
	fixture.position = pos + Vector3(0, 0.12, 0)
	add_child(fixture)
	var spot := SpotLight3D.new()
	spot.light_color = color
	spot.light_energy = energy * 0.55
	spot.spot_range = range_m
	spot.spot_angle = spot_deg
	spot.spot_attenuation = 0.6
	spot.shadow_enabled = false
	spot.position = pos
	spot.rotation_degrees = Vector3(-90, 0, 0)
	add_child(spot)
	_omni_fill(pos + Vector3(0, -1.2, 0), color, energy * 0.28, range_m * 0.65)


func _omni_fill(pos: Vector3, color: Color, energy: float, range_m: float) -> void:
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy * 0.5
	light.omni_range = range_m
	light.omni_attenuation = 1.2
	light.shadow_enabled = false
	light.position = pos
	add_child(light)


func _glass(pos: Vector3, size: Vector3) -> void:
	var body := _box(pos, size, Color(1, 1, 1))
	var mi := body.get_child(0) as MeshInstance3D
	var m := StandardMaterial3D.new()
	m.albedo_color = GLASS_TINT
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.15
	m.metallic = 0.1
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m


func _panel(pos: Vector3, size: Vector3, color: Color, emission := 0.0, rot := Vector3.ZERO) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.85
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = Color(color.r, color.g, color.b)
		m.emission_energy_multiplier = emission
	mi.material_override = m
	mi.position = pos
	mi.rotation_degrees = rot
	add_child(mi)


func _ramp(pos: Vector3, size: Vector3, tilt_x_deg: float, color: Color) -> void:
	var body := _box(pos, size, color)
	body.rotation_degrees.x = tilt_x_deg


func _label(pos: Vector3, text: String, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = pos
	label.font_size = 48
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)


func _box(pos: Vector3, size: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = pos
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	mat.metallic = 0.0
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mesh_instance.material_override = mat
	body.add_child(mesh_instance)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	add_child(body)
	return body


# --- Entities: systems only in STEALTH + COMBAT -------------------------------

func _spawn_entities() -> void:
	movement_wing_guard_count = 0
	systems_guard_count = 0

	# Hub armory
	_make_pickup(Vector3(3.5, 0.9, 3.2), Pickup.PickupType.WEAPON_SILENCED, 1.0, Color(0.15, 0.15, 0.18))
	_make_pickup(Vector3(4.5, 0.9, 3.2), Pickup.PickupType.WEAPON_SMG, 1.0, Color(0.4, 0.55, 0.3))
	_make_pickup(Vector3(5.5, 0.9, 3.2), Pickup.PickupType.WEAPON_RIFLE, 1.0, Color(0.35, 0.4, 0.28))
	_make_pickup(Vector3(3.5, 0.85, 4.2), Pickup.PickupType.AMMO, 60.0, Color(0.2, 0.5, 0.9))
	_make_pickup(Vector3(4.5, 0.85, 4.2), Pickup.PickupType.ARMOR, 50.0, Color(0.55, 0.55, 0.65))
	_make_pickup(Vector3(5.5, 0.85, 4.2), Pickup.PickupType.HEALTH, 40.0, Color(0.2, 0.8, 0.3))
	_make_pickup(Vector3(3.5, 0.85, 2.4), Pickup.PickupType.LOCKPICK, 3.0, Color(0.85, 0.7, 0.3))
	_make_pickup(Vector3(4.5, 0.85, 2.4), Pickup.PickupType.CAMERA_LOOP, 3.0, Color(0.3, 0.9, 0.5))
	_make_pickup(Vector3(5.5, 0.85, 2.4), Pickup.PickupType.DECOY, 4.0, Color(0.2, 0.55, 0.85))

	_make_pickup(Vector3(5.5, 4.3, 0), Pickup.PickupType.KEYCARD, 1.0, Color(0.9, 0.85, 0.2))
	_make_pickup(Vector3(-20, 0.5, 13), Pickup.PickupType.KEYCARD_SERVER, 1.0, Color(0.3, 0.75, 0.95))
	_make_pickup(Vector3(-21, 0.5, 12), Pickup.PickupType.LOCKPICK, 2.0, Color(0.85, 0.7, 0.3))
	_make_pickup(Vector3(-21, 0.5, 14), Pickup.PickupType.CAMERA_LOOP, 1.0, Color(0.3, 0.9, 0.5))

	_make_door(Vector3(-15, 1.5, 10), true, 1, 0.0)
	_make_door(Vector3(-12, 1.5, 17.5), true, 1, 90.0)
	_make_door(Vector3(-14, 1.5, 18), true, 2, 90.0)

	_make_objective(Vector3(-15, 0.9, 19.5), "bunker", "Hold E — sabotage bunker relay", "Bunker relay sabotaged", DANGER, Vector3(1.4, 1.6, 1.0))
	_make_objective(Vector3(14, 4.5, -3), "destroy", "Hold E — destroy mainframe console", "Mainframe destroyed", DANGER, Vector3(1.4, 1.0, 1.0))
	_make_objective(Vector3(-18, 0.9, 19), "download", "Hold E — download research data", "Data downloaded", TECH, Vector3(1.2, 1.2, 0.8))
	_make_extract(Vector3(20, 12.2, 0))

	_make_pickup(Vector3(15, 0.5, 18), Pickup.PickupType.AMMO, 30.0, Color(0.2, 0.5, 0.9))
	_make_pickup(Vector3(18, 4.4, 3), Pickup.PickupType.ARMOR, 40.0, Color(0.55, 0.55, 0.65))
	_make_pickup(Vector3(-21, 0.5, 4), Pickup.PickupType.AMMO, 40.0, Color(0.2, 0.5, 0.9))

	# SYSTEMS GUARDS — combat + stealth only (movement wings empty)
	_make_guard(Vector3(15, 0.1, 14), PackedVector3Array([
		Vector3(12, 0.1, 12), Vector3(18, 0.1, 17)
	]), 0.75, true)
	_make_guard(Vector3(17, 0.1, 17), PackedVector3Array([
		Vector3(13, 0.1, 16), Vector3(19, 0.1, 14)
	]), 0.8, true)
	_make_guard(Vector3(-16, 0.1, 13), PackedVector3Array([
		Vector3(-12, 0.1, 12), Vector3(-20, 0.1, 15)
	]), -1.0, true)
	_make_guard(Vector3(-18, 0.1, 18), PackedVector3Array([
		Vector3(-16, 0.1, 17), Vector3(-20, 0.1, 19)
	]), 0.9, true)

	_make_camera(Vector3(-12, 3.2, 12), Vector3(-0.5, -0.25, 1))
	_make_camera(Vector3(-16, 3.2, 17), Vector3(0.5, -0.2, 0.8))
	_make_camera(Vector3(14, 3.0, 12), Vector3(0.5, -0.25, 0.8))
	_make_hide_spot(Vector3(-22, 0.5, 14), "Drag body into security locker")
	_make_hide_spot(Vector3(-10, 0.5, 19), "Drag body into cage locker")
	_make_damageable_crate(Vector3(13, 0.6, 13), 50.0)
	_make_damageable_crate(Vector3(17, 0.6, 16), 40.0)


func _make_objective(pos: Vector3, id: String, prompt: String, done: String, color: Color, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	body.collision_layer = 1
	body.set_script(load("res://scripts/world/objective_prop.gd"))
	body.set("objective_id", id)
	body.set("prompt_text", prompt)
	body.set("done_text", done)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "MeshInstance3D"
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	mesh_instance.material_override = N64Look.mat(color, 0.9)
	body.add_child(mesh_instance)
	N64Look.box(body, Vector3(0, -size.y * 0.35, 0.05), Vector3(size.x * 1.15, size.y * 0.35, size.z * 1.1), Color(0.2, 0.22, 0.24), "Base")
	N64Look.box(body, Vector3(0, size.y * 0.15, -size.z * 0.35), Vector3(size.x * 0.7, size.y * 0.15, 0.08), Color(0.12, 0.12, 0.14), "Screen")
	N64Look.box(body, Vector3(size.x * 0.35, 0.0, size.z * 0.4), Vector3(0.08, 0.08, 0.08), Color(0.9, 0.2, 0.15), "LED", 1.5)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	var area := Area3D.new()
	area.name = "Area3D"
	area.collision_layer = 0
	area.collision_mask = 2
	var area_col := CollisionShape3D.new()
	var area_shape := SphereShape3D.new()
	area_shape.radius = 2.0
	area_col.shape = area_shape
	area.add_child(area_col)
	body.add_child(area)
	add_child(body)


func _make_door(pos: Vector3, needs_card: bool, tier: int = 1, yaw_deg: float = 0.0) -> void:
	var door := StaticBody3D.new()
	door.position = pos
	door.rotation_degrees.y = yaw_deg
	door.collision_layer = 1
	door.set_script(load("res://scripts/world/door.gd"))
	door.set("requires_keycard", needs_card)
	door.set("required_tier", tier)
	door.set("bashable", true)
	door.set("lockpickable", tier < 2)
	var panel_color := Color(0.6, 0.15, 0.1)
	if tier >= 2:
		panel_color = Color(0.15, 0.35, 0.55)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "MeshInstance3D"
	var box := BoxMesh.new()
	box.size = Vector3(0.28, 2.9, 2.2)
	mesh_instance.mesh = box
	mesh_instance.material_override = N64Look.mat(panel_color)
	door.add_child(mesh_instance)
	N64Look.box(door, Vector3(0, 0, 0), Vector3(0.4, 3.05, 2.45), panel_color.darkened(0.25), "Frame")
	N64Look.box(door, Vector3(0.18, 0.1, 0.7), Vector3(0.08, 0.35, 0.12), Color(0.55, 0.55, 0.5), "Handle")
	var reader_col := Color(0.9, 0.85, 0.2) if tier < 2 else Color(0.3, 0.75, 0.95)
	N64Look.box(door, Vector3(0.22, 0.4, -0.7), Vector3(0.1, 0.25, 0.2), reader_col, "Reader", 0.8)
	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.4, 3.0, 2.4)
	col.shape = shape
	door.add_child(col)
	var area := Area3D.new()
	area.collision_mask = 2
	area.monitoring = true
	var area_col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.8
	area_col.shape = sphere
	area.add_child(area_col)
	door.add_child(area)
	add_child(door)


func _make_pickup(pos: Vector3, type: int, amount: float, color: Color) -> void:
	var area := Area3D.new()
	area.position = pos
	area.collision_layer = 0
	area.collision_mask = 2
	area.monitoring = true
	area.monitorable = false
	area.set_script(load("res://scripts/world/pickup.gd"))
	area.set("pickup_type", type)
	area.set("amount", amount)
	match type:
		Pickup.PickupType.AMMO:
			N64Look.box(area, Vector3(0, 0.08, 0), Vector3(0.28, 0.16, 0.4), color, "AmmoBox", 0.6)
		Pickup.PickupType.HEALTH:
			N64Look.box(area, Vector3(0, 0.1, 0), Vector3(0.3, 0.22, 0.22), color, "Medkit", 0.7)
			N64Look.box(area, Vector3(0, 0.1, 0), Vector3(0.32, 0.06, 0.08), Color(0.95, 0.95, 0.95), "CrossH")
			N64Look.box(area, Vector3(0, 0.1, 0), Vector3(0.08, 0.06, 0.32), Color(0.95, 0.95, 0.95), "CrossV")
		Pickup.PickupType.KEYCARD, Pickup.PickupType.KEYCARD_SERVER:
			N64Look.box(area, Vector3(0, 0.06, 0), Vector3(0.28, 0.04, 0.18), color, "Card", 1.0)
			N64Look.box(area, Vector3(0.08, 0.07, 0), Vector3(0.06, 0.02, 0.1), Color(0.1, 0.1, 0.1), "Chip")
		Pickup.PickupType.WEAPON_SMG, Pickup.PickupType.WEAPON_RIFLE, Pickup.PickupType.WEAPON_SILENCED:
			N64Look.box(area, Vector3(0, 0.1, 0), Vector3(0.12, 0.12, 0.55), color, "Gun", 0.4)
			N64Look.box(area, Vector3(0, 0.0, 0.1), Vector3(0.1, 0.16, 0.12), color.darkened(0.2), "Grip")
		Pickup.PickupType.ARMOR:
			N64Look.box(area, Vector3(0, 0.12, 0), Vector3(0.4, 0.35, 0.2), color, "Vest", 0.3)
		Pickup.PickupType.LOCKPICK:
			N64Look.box(area, Vector3(0, 0.08, 0), Vector3(0.08, 0.08, 0.35), color, "Pick", 0.5)
		Pickup.PickupType.CAMERA_LOOP:
			N64Look.box(area, Vector3(0, 0.08, 0), Vector3(0.22, 0.16, 0.12), color, "Loop", 0.8)
			N64Look.cyl(area, Vector3(0, 0.08, -0.1), 0.05, 0.08, Color(0.1, 0.1, 0.1), "Lens")
		Pickup.PickupType.DECOY:
			N64Look.cyl(area, Vector3(0, 0.1, 0), 0.1, 0.2, color, "Decoy", 0.7)
		_:
			N64Look.box(area, Vector3(0, 0.1, 0), Vector3(0.25, 0.25, 0.25), color, "Item", 0.5)
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.65
	col.shape = shape
	area.add_child(col)
	add_child(area)


func _make_damageable_crate(pos: Vector3, hp: float) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	body.collision_layer = 1
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.15, 1.15, 1.15)
	mesh_instance.mesh = box
	mesh_instance.material_override = N64Look.mat(Color(0.55, 0.4, 0.25))
	body.add_child(mesh_instance)
	N64Look.box(body, Vector3(0, 0.58, 0), Vector3(1.2, 0.08, 1.2), Color(0.35, 0.28, 0.18), "Lid")
	N64Look.box(body, Vector3(0, 0, 0.58), Vector3(0.9, 0.08, 0.08), Color(0.25, 0.2, 0.12), "Band")
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.2, 1.2, 1.2)
	col.shape = shape
	body.add_child(col)
	var dmg := Damageable.new()
	dmg.name = "Damageable"
	dmg.max_health = hp
	body.add_child(dmg)
	add_child(body)


func _make_guard(pos: Vector3, points: PackedVector3Array, bravery: float = -1.0, systems_wing: bool = false) -> void:
	var guard_scene: PackedScene = load("res://scenes/guard.tscn")
	var guard: Node3D = guard_scene.instantiate()
	guard.position = pos
	guard.set("patrol_points", points)
	if bravery >= 0.0:
		guard.set("bravery", bravery)
	add_child(guard)
	if systems_wing:
		systems_guard_count += 1
	else:
		movement_wing_guard_count += 1


func _make_extract(pos: Vector3) -> void:
	var area := Area3D.new()
	area.position = pos
	area.collision_layer = 0
	area.collision_mask = 2
	area.set_script(load("res://scripts/world/extract_zone.gd"))
	N64Look.cyl(area, Vector3(0, 0.05, 0), 1.7, 0.1, Color(0.15, 0.55, 0.3), "Pad", 0.6, 8)
	N64Look.box(area, Vector3(0, 0.08, 1.2), Vector3(0.5, 0.04, 0.35), Color(0.3, 1.0, 0.45), "ChevronN", 1.2)
	N64Look.box(area, Vector3(0, 0.08, -1.2), Vector3(0.5, 0.04, 0.35), Color(0.3, 1.0, 0.45), "ChevronS", 1.2)
	N64Look.box(area, Vector3(1.2, 0.08, 0), Vector3(0.35, 0.04, 0.5), Color(0.3, 1.0, 0.45), "ChevronE", 1.2)
	N64Look.box(area, Vector3(-1.2, 0.08, 0), Vector3(0.35, 0.04, 0.5), Color(0.3, 1.0, 0.45), "ChevronW", 1.2)
	N64Look.box(area, Vector3(0, 1.1, 0), Vector3(0.15, 2.0, 0.15), Color(0.2, 0.7, 0.35), "Beacon", 1.4)
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 1.8
	shape.height = 2.0
	col.shape = shape
	col.position.y = 1.0
	area.add_child(col)
	add_child(area)


func _make_hide_spot(pos: Vector3, prompt: String) -> void:
	var area := Area3D.new()
	area.position = pos
	area.collision_layer = 0
	area.collision_mask = 2
	area.set_script(load("res://scripts/world/hide_spot.gd"))
	area.set("prompt_text", prompt)
	N64Look.box(area, Vector3(0, 0.0, 0), Vector3(1.15, 2.0, 0.95), Color(0.28, 0.3, 0.32), "Locker")
	N64Look.box(area, Vector3(0, 0.15, 0.48), Vector3(1.0, 1.7, 0.06), Color(0.22, 0.24, 0.26), "Door")
	N64Look.box(area, Vector3(0.35, 0.1, 0.52), Vector3(0.08, 0.2, 0.06), Color(0.55, 0.55, 0.45), "Handle")
	N64Look.box(area, Vector3(0, 1.05, 0), Vector3(1.2, 0.08, 1.0), Color(0.2, 0.22, 0.24), "Top")
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.8, 2.2, 1.6)
	col.shape = shape
	area.add_child(col)
	add_child(area)


func _make_camera(pos: Vector3, forward: Vector3) -> void:
	var cam := Node3D.new()
	cam.position = pos
	add_child(cam)
	if forward.length() > 0.01:
		cam.look_at(pos + forward.normalized(), Vector3.UP)
	N64Look.box(cam, Vector3(0, 0.15, 0.1), Vector3(0.12, 0.35, 0.12), Color(0.2, 0.2, 0.22), "Mount")
	N64Look.box(cam, Vector3(0, 0, 0), Vector3(0.32, 0.22, 0.4), Color(0.12, 0.12, 0.14), "Housing")
	var lens := N64Look.cyl(cam, Vector3(0, 0, -0.28), 0.08, 0.12, Color(0.08, 0.08, 0.1), "Lens", 0.0, 6)
	lens.rotation_degrees.x = 90.0
	N64Look.box(cam, Vector3(0.12, 0.08, -0.05), Vector3(0.06, 0.06, 0.06), Color(0.9, 0.15, 0.1), "LED", 2.0)
	var sensor := Area3D.new()
	sensor.set_script(load("res://scripts/world/security_camera.gd"))
	sensor.set("boot_grace", 2.5)
	var ray := RayCast3D.new()
	ray.name = "RayCast3D"
	ray.target_position = Vector3(0, 0, -14)
	ray.collision_mask = 3
	sensor.add_child(ray)
	cam.add_child(sensor)
