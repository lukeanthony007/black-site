extends Node3D
## Mirror's Edge–style rooftop freerun. Connected buildings, street void below.
## Geometry driven by MotorConstants. No AI. Fall = last checkpoint.

const CONCRETE := Color(0.88, 0.88, 0.86)
const CONCRETE_DARK := Color(0.62, 0.63, 0.64)
const PARAPET := Color(0.78, 0.78, 0.76)
const GLASS := Color(0.55, 0.72, 0.82, 0.45)
const METAL := Color(0.45, 0.48, 0.52)
const METAL_DARK := Color(0.28, 0.3, 0.33)
const RUNNER := Color(0.92, 0.18, 0.2) ## ME red — path / hard marks
const SAFE := Color(0.2, 0.72, 0.45)
const ASPHALT := Color(0.22, 0.24, 0.26)
const BRICK := Color(0.55, 0.42, 0.36)
const STREET := Color(0.18, 0.19, 0.21)
const LABEL_C := Color(0.95, 0.95, 0.97)

## Roof deck Y for the main run (building tops). Street sits far below.
const ROOF_Y := 24.0

var measured_gaps: Array = []
var measured_steps: Array = []


func _ready() -> void:
	_build_course()


func _build_course() -> void:
	measured_gaps.clear()
	measured_steps.clear()
	_build_city_shell()
	_build_spawn_roof()
	_build_stride_roof()
	_build_gap_roofs()
	_build_climb_building()
	_build_wallrun_alley()
	_build_dive_skylight()
	_build_drop_roofs()
	_build_finale_tower()
	_build_skyline_backdrop()
	_add_lights()


# --- City shell: street + distant blocks --------------------------------------

func _build_city_shell() -> void:
	# Street plane far below — visual only (fall resets before you hit it)
	_panel(Vector3(20, -2.0, 70), Vector3(200, 0.4, 220), STREET)
	# Road stripes
	for i in 18:
		_panel(Vector3(2.0, -1.75, float(i) * 12.0 - 10.0), Vector3(0.35, 0.05, 4.0), Color(0.85, 0.8, 0.35))
	# Sidewalk bands
	_panel(Vector3(-18, -1.7, 70), Vector3(12, 0.3, 200), Color(0.35, 0.36, 0.38))
	_panel(Vector3(38, -1.7, 70), Vector3(12, 0.3, 200), Color(0.35, 0.36, 0.38))


func _building_volume(roof_center: Vector3, roof_size: Vector2, stories: float, facade: Color = BRICK) -> void:
	## Solid mass under a roof pad so the run feels like real buildings.
	var h := stories
	var mid_y := roof_center.y - h * 0.5
	_box(Vector3(roof_center.x, mid_y, roof_center.z), Vector3(roof_size.x * 0.96, h, roof_size.y * 0.96), facade)
	# Window grid on long faces
	var rows := int(clampf(h / 3.2, 2.0, 8.0))
	var cols := int(clampf(roof_size.x / 3.0, 2.0, 6.0))
	for r in rows:
		for c in cols:
			var wx := roof_center.x - roof_size.x * 0.35 + float(c) * (roof_size.x * 0.7 / maxf(float(cols - 1), 1.0))
			var wy := roof_center.y - h + 2.5 + float(r) * 3.0
			_panel(Vector3(wx, wy, roof_center.z - roof_size.y * 0.48), Vector3(1.1, 1.4, 0.08), GLASS, 0.15)
			_panel(Vector3(wx, wy, roof_center.z + roof_size.y * 0.48), Vector3(1.1, 1.4, 0.08), GLASS, 0.15)


func _roof_deck(center: Vector3, size: Vector2, color: Color = CONCRETE, open_run: bool = true) -> void:
	_platform(center, Vector3(size.x, 0.4, size.y), color)
	_parapet(center, size, open_run)


func _parapet(center: Vector3, size: Vector2, open_run: bool = true) -> void:
	## Side walls always. ±Z ends open when open_run so jumps can land/leave.
	var t := 0.28
	var h := 0.85
	var y := center.y + 0.55
	_box(Vector3(center.x - size.x * 0.5 + t * 0.5, y, center.z), Vector3(t, h, size.y - 0.3), PARAPET)
	_box(Vector3(center.x + size.x * 0.5 - t * 0.5, y, center.z), Vector3(t, h, size.y - 0.3), PARAPET)
	var gap := mini(3.6, size.x * 0.55)
	var side := (size.x - gap) * 0.5
	if open_run:
		if side > 0.35:
			# Partial ±Z parapets with center exit/entry
			for sign_i in 2:
				var sign_z: float = -1.0 if sign_i == 0 else 1.0
				var z_edge: float = center.z + sign_z * (size.y * 0.5 - t * 0.5)
				_box(Vector3(center.x - gap * 0.5 - side * 0.5, y, z_edge), Vector3(side, h, t), PARAPET)
				_box(Vector3(center.x + gap * 0.5 + side * 0.5, y, z_edge), Vector3(side, h, t), PARAPET)
		_panel(Vector3(center.x, center.y + 0.25, center.z + size.y * 0.5 - 0.1), Vector3(gap, 0.06, 0.2), RUNNER, 0.9)
		_panel(Vector3(center.x, center.y + 0.25, center.z - size.y * 0.5 + 0.1), Vector3(gap, 0.06, 0.2), RUNNER, 0.7)
	else:
		_box(Vector3(center.x, y, center.z - size.y * 0.5 + t * 0.5), Vector3(size.x, h, t), PARAPET)
		_box(Vector3(center.x, y, center.z + size.y * 0.5 - t * 0.5), Vector3(size.x, h, t), PARAPET)


func _ac_unit(pos: Vector3) -> void:
	_box(pos + Vector3(0, 0.55, 0), Vector3(1.6, 1.1, 1.2), METAL)
	_box(pos + Vector3(0, 1.2, 0), Vector3(1.4, 0.2, 1.0), METAL_DARK)
	_panel(pos + Vector3(0.85, 0.55, 0), Vector3(0.08, 0.7, 0.9), METAL_DARK)
	_panel(pos + Vector3(-0.85, 0.55, 0), Vector3(0.08, 0.7, 0.9), METAL_DARK)


func _vent(pos: Vector3) -> void:
	_box(pos + Vector3(0, 0.35, 0), Vector3(0.9, 0.7, 0.9), METAL_DARK)
	_box(pos + Vector3(0, 0.85, 0), Vector3(1.1, 0.12, 1.1), METAL)


func _pipe_run(from: Vector3, to: Vector3, red: bool = true) -> void:
	var mid := (from + to) * 0.5
	var delta := to - from
	var length := delta.length()
	if length < 0.05:
		return
	var col := RUNNER if red else METAL
	if absf(delta.x) >= absf(delta.z) and absf(delta.x) >= absf(delta.y):
		_box(mid, Vector3(length, 0.18, 0.18), col)
	elif absf(delta.y) >= absf(delta.z):
		_box(mid, Vector3(0.18, length, 0.18), col)
	else:
		_box(mid, Vector3(0.18, 0.18, length), col)


func _duct(pos: Vector3, size: Vector3) -> void:
	_box(pos, size, METAL)
	_panel(pos + Vector3(0, size.y * 0.5 + 0.02, 0), Vector3(size.x * 0.95, 0.04, size.z * 0.95), METAL_DARK)


# --- 0. Spawn roof ------------------------------------------------------------

func _build_spawn_roof() -> void:
	var c := Vector3(0, ROOF_Y, 0)
	_building_volume(c, Vector2(16, 14), ROOF_Y - 0.5, Color(0.72, 0.72, 0.7))
	_roof_deck(c, Vector2(16, 14))
	_ac_unit(c + Vector3(-5, 0.2, -3))
	_ac_unit(c + Vector3(5, 0.2, -2.5))
	_vent(c + Vector3(-3, 0.2, 3))
	_vent(c + Vector3(4, 0.2, 2))
	_pipe_run(c + Vector3(-6, 0.55, -4), c + Vector3(-6, 0.55, 4), true)
	_pipe_run(c + Vector3(6, 0.55, -4), c + Vector3(6, 0.55, 4), true)
	_label(c + Vector3(0, 3.2, -4), "ROOFTOPS", LABEL_C, 64)
	_label(c + Vector3(0, 2.5, -2.8), "FREERUN", RUNNER, 40)
	_make_checkpoint(c + Vector3(0, 0.35, 0), "spawn", "Checkpoint · START — sprint the roof line")
	# Exit bridge pad toward stride building
	_platform(c + Vector3(0, 0, 8.5), Vector3(4.5, 0.35, 3.5), CONCRETE)


# --- 1. Stride roof: long deck + HVAC slide -----------------------------------

func _build_stride_roof() -> void:
	var c := Vector3(0, ROOF_Y, 22)
	_building_volume(c, Vector2(12, 22), ROOF_Y - 0.5, Color(0.68, 0.7, 0.72))
	_roof_deck(c, Vector2(12, 22))
	# Red lane paint
	for i in 8:
		_panel(c + Vector3(0, 0.25, -8.0 + float(i) * 2.2), Vector3(0.25, 0.03, 1.0), RUNNER, 0.7)
	# HVAC duct to slide under
	var clear := MotorConstants.SLIDE_CLEARANCE
	var gate_z := c.z + 2.0
	_duct(Vector3(0, ROOF_Y + clear + 0.85, gate_z), Vector3(10.0, 1.7, 2.4))
	_panel(Vector3(0, ROOF_Y + clear - 0.02, gate_z), Vector3(10.0, 0.05, 2.5), RUNNER, 1.1)
	_label(c + Vector3(0, 3.5, -8), "SPRINT", LABEL_C, 44)
	_label(Vector3(0, ROOF_Y + 3.0, gate_z - 3), "SLIDE", RUNNER, 36)
	_ac_unit(c + Vector3(-3.5, 0.2, -6))
	_vent(c + Vector3(3.5, 0.2, 6))
	_make_checkpoint(c + Vector3(0, 0.35, 8), "stride", "Checkpoint · HVAC clear")
	_make_gate(c + Vector3(0, 1.0, 8.5), "stride", "Stride roof")


# --- 2. Gap roofs: building-to-building jumps ---------------------------------

func _build_gap_roofs() -> void:
	var half := 2.2 ## half-depth of each roof pad along Z
	var pad_w := 7.0
	var z := 38.0
	var y := ROOF_Y
	var gaps: Array = [
		["gap_easy", MotorConstants.GAP_EASY],
		["gap_med", MotorConstants.GAP_MED],
		["gap_hard", MotorConstants.GAP_HARD],
		["gap_extreme", MotorConstants.GAP_EXTREME],
	]
	_label(Vector3(0, y + 3.5, z - 2), "CROSSINGS", LABEL_C, 44)

	# First roof
	_building_volume(Vector3(0, y, z), Vector2(pad_w, half * 2.0), y - 1.0, BRICK)
	_roof_deck(Vector3(0, y, z), Vector2(pad_w, half * 2.0))
	_make_checkpoint(Vector3(0, y + 0.35, z), "gaps_start", "Checkpoint · CROSSINGS — rooftop gaps ahead")
	_vent(Vector3(-2, y + 0.2, z))

	var prev_edge := z + half
	for g: Array in gaps:
		var edge_gap: float = g[1]
		var next_center := prev_edge + edge_gap + half
		y += 0.4 ## slight rise across the block
		var color := CONCRETE if edge_gap < MotorConstants.GAP_HARD else Color(0.9, 0.85, 0.82)
		_building_volume(Vector3(0, y, next_center), Vector2(pad_w, half * 2.0), y - 1.0, Color(0.5, 0.45, 0.42))
		_roof_deck(Vector3(0, y, next_center), Vector2(pad_w, half * 2.0), color)
		# Red edge marks on both lips
		_panel(Vector3(0, y + 0.25, prev_edge - 0.05), Vector3(3.5, 0.05, 0.18), RUNNER, 1.0)
		_panel(Vector3(0, y + 0.25, next_center - half + 0.05), Vector3(3.5, 0.05, 0.18), RUNNER, 1.0)
		_record_gap(g[0], edge_gap, edge_gap)
		prev_edge = next_center + half
		z = next_center

	# Landing roof
	z += 4.0
	_building_volume(Vector3(0, y, z), Vector2(10, 8), y - 1.0, Color(0.65, 0.66, 0.68))
	_roof_deck(Vector3(0, y, z), Vector2(10, 8))
	_ac_unit(Vector3(-3, y + 0.2, z + 1))
	_make_checkpoint(Vector3(0, y + 0.35, z), "gaps", "Checkpoint · CROSSINGS clear")
	_make_gate(Vector3(0, y + 1.0, z + 2.5), "gaps", "Gap roofs")


# --- 3. Climb: fire-escape hops + ledge + facade climb ------------------------

func _build_climb_building() -> void:
	var base_y := ROOF_Y + 1.6
	var c := Vector3(0, base_y, 72)
	_building_volume(c, Vector2(14, 12), base_y - 0.5, Color(0.58, 0.6, 0.63))
	_roof_deck(c, Vector2(14, 12))
	_label(c + Vector3(0, 3.2, -4), "ASCENT", LABEL_C, 44)
	_make_checkpoint(c + Vector3(0, 0.35, 0), "climb", "Checkpoint · ASCENT — mantle, then wall-climb the face")

	# Crates / AC as hop pads
	_step_pad(c + Vector3(-3, 0.2, 2), MotorConstants.STEP_EASY, "climb_hop_e")
	_step_pad(c + Vector3(0, 0.2, 3), MotorConstants.STEP_MED, "climb_hop_m")
	_step_pad(c + Vector3(3, 0.2, 2), MotorConstants.STEP_HARD, "climb_hop_h")

	# Scaffold ledge wall (mantle)
	var wall_z := c.z + 5.2
	var m_low := MotorConstants.MANTLE_LEDGE_LOW
	var m_hi := MotorConstants.MANTLE_LEDGE_HIGH
	_box(Vector3(c.x - 1.5, c.y + m_low * 0.5, wall_z), Vector3(4.0, m_low, 0.4), METAL)
	_platform(Vector3(c.x - 1.5, c.y + m_low + 0.12, wall_z + 0.8), Vector3(3.4, 0.24, 1.8), CONCRETE)
	_panel(Vector3(c.x - 1.5, c.y + m_low + 0.28, wall_z + 0.1), Vector3(3.0, 0.05, 0.2), RUNNER, 1.0)
	_record_step("mantle_low", m_low, m_low)

	_box(Vector3(c.x + 2.5, c.y + 1.0 + m_hi * 0.5, wall_z), Vector3(2.4, m_hi, 0.4), METAL)
	_platform(Vector3(c.x + 2.5, c.y + 1.0 + m_hi + 0.12, wall_z + 0.8), Vector3(2.2, 0.24, 1.8), CONCRETE)
	_record_step("mantle_high", m_hi, m_hi)

	# Mid terrace
	var mid_y := c.y + 3.5
	_platform(Vector3(c.x, mid_y, wall_z + 2.8), Vector3(8.0, 0.35, 4.5), CONCRETE)
	_parapet(Vector3(c.x, mid_y, wall_z + 2.8), Vector2(8.0, 4.5))
	_duct(Vector3(c.x - 2.5, mid_y + 0.7, wall_z + 2.8), Vector3(2.0, 1.2, 2.5))

	# Vertical facade climb into penthouse lip
	var climb_face_z := wall_z + 4.9
	var climb_h := 4.4
	_box(Vector3(c.x, mid_y + climb_h * 0.5, climb_face_z), Vector3(6.0, climb_h, 0.5), CONCRETE_DARK)
	# Window bands on climb face
	for i in 3:
		_panel(Vector3(c.x, mid_y + 1.0 + float(i) * 1.2, climb_face_z - 0.28), Vector3(4.5, 0.7, 0.08), GLASS, 0.2)
	var lip_y := mid_y + climb_h
	_roof_deck(Vector3(c.x, lip_y, climb_face_z + 1.6), Vector2(8.0, 5.0))
	_panel(Vector3(c.x, lip_y + 0.25, climb_face_z + 0.15), Vector3(5.0, 0.05, 0.22), RUNNER, 1.2)
	_label(Vector3(c.x, lip_y + 2.4, climb_face_z + 1.6), "WALL CLIMB", RUNNER, 36)
	_ac_unit(Vector3(c.x + 2.5, lip_y + 0.2, climb_face_z + 1.8))
	_make_checkpoint(Vector3(c.x, lip_y + 0.35, climb_face_z + 1.6), "mantle", "Checkpoint · ASCENT clear")
	_make_gate(Vector3(c.x, lip_y + 1.0, climb_face_z + 2.8), "climb", "Climb building")


# --- 4. Wallrun: alley between towers -----------------------------------------

func _build_wallrun_alley() -> void:
	var mid_x := 0.0
	var mid_z := 92.0
	var half_gap := 0.85
	var wall_t := 0.45
	var wall_h := 5.0
	var run_len := 14.0
	var floor_y := ROOF_Y + 5.2
	var left_x := mid_x - half_gap - wall_t * 0.5
	var right_x := mid_x + half_gap + wall_t * 0.5

	# Approach terraces down from penthouse (~ROOF_Y+9.5)
	_platform(Vector3(0, ROOF_Y + 8.2, 84), Vector3(5.0, 0.35, 3.5), CONCRETE)
	_platform(Vector3(0, ROOF_Y + 6.8, 87), Vector3(4.5, 0.35, 3.0), CONCRETE)
	_platform(Vector3(mid_x, floor_y, mid_z - 6.5), Vector3(4.0, 0.35, 3.5), CONCRETE)
	_make_checkpoint(Vector3(mid_x, floor_y + 0.35, mid_z - 6.5), "wall_entry", "Checkpoint · ALLEY — sprint-jump, wallrun the facade")

	_label(Vector3(mid_x, floor_y + 3.8, mid_z - 5), "ALLEY", LABEL_C, 44)
	# Building masses on both sides of alley
	_box(Vector3(left_x - 3.5, floor_y - 8.0, mid_z), Vector3(7.0, 18.0, run_len + 4.0), BRICK)
	_box(Vector3(right_x + 3.5, floor_y - 8.0, mid_z), Vector3(7.0, 18.0, run_len + 4.0), Color(0.6, 0.58, 0.55))
	# Runnable inner faces
	_box(Vector3(left_x, floor_y + wall_h * 0.5, mid_z), Vector3(wall_t, wall_h, run_len), CONCRETE_DARK)
	_box(Vector3(right_x, floor_y + wall_h * 0.5, mid_z), Vector3(wall_t, wall_h, run_len), CONCRETE_DARK)
	# Red pipes along walls (runner vision)
	_box(Vector3(left_x + wall_t * 0.55, floor_y + 2.2, mid_z), Vector3(0.12, 0.12, run_len - 0.5), RUNNER)
	_box(Vector3(right_x - wall_t * 0.55, floor_y + 2.2, mid_z), Vector3(0.12, 0.12, run_len - 0.5), RUNNER)
	_panel(Vector3(mid_x, floor_y + 0.22, mid_z), Vector3(half_gap * 2.0, 0.03, run_len), Color(0.3, 0.32, 0.34))

	var exit_z := mid_z + run_len * 0.5 + 1.8
	_platform(Vector3(mid_x, floor_y + 0.5, exit_z), Vector3(3.5, 0.35, 2.5), CONCRETE)
	_platform(Vector3(mid_x, floor_y + 1.4, exit_z + 2.0), Vector3(3.2, 0.3, 2.2), CONCRETE)
	_roof_deck(Vector3(mid_x, floor_y + 2.3, exit_z + 4.2), Vector2(6.0, 4.5))
	_make_checkpoint(Vector3(mid_x, floor_y + 2.65, exit_z + 4.2), "walls", "Checkpoint · ALLEY clear")
	_make_gate(Vector3(mid_x, floor_y + 3.3, exit_z + 5.0), "walls", "Wallrun alley")


# --- 5. Dive through broken skylight ------------------------------------------

func _build_dive_skylight() -> void:
	var y := ROOF_Y + 7.5
	var z := 108.0
	_building_volume(Vector3(0, y, z), Vector2(10, 8), y - 2.0, Color(0.7, 0.71, 0.73))
	_roof_deck(Vector3(0, y, z), Vector2(10, 8))
	_label(Vector3(0, y + 3.0, z - 2), "SKYLIGHT", LABEL_C, 44)
	_make_checkpoint(Vector3(0, y + 0.35, z), "dive", "Checkpoint · SKYLIGHT — dive the low frame")

	var win_z := z + 5.0
	var dive_clear := MotorConstants.DIVE_HEIGHT + 0.12
	# Skylight frame
	_box(Vector3(-2.6, y + 1.5, win_z), Vector3(0.45, 3.0, 0.45), METAL)
	_box(Vector3(2.6, y + 1.5, win_z), Vector3(0.45, 3.0, 0.45), METAL)
	_box(Vector3(0, y + dive_clear + 1.2, win_z), Vector3(5.6, 2.2, 0.45), METAL)
	_panel(Vector3(0, y + dive_clear - 0.02, win_z), Vector3(4.6, 0.05, 0.5), RUNNER, 1.2)
	# Glass shards (deco)
	_panel(Vector3(-1.2, y + dive_clear + 0.4, win_z + 0.3), Vector3(1.0, 0.8, 0.06), GLASS, 0.2)
	_panel(Vector3(1.4, y + dive_clear + 0.6, win_z - 0.2), Vector3(0.8, 0.6, 0.06), GLASS, 0.2)

	_platform(Vector3(0, y - 0.4, win_z + 4.5), Vector3(6.0, 0.35, 4.5), CONCRETE)
	# Ascent toward drop tower
	var land_z := win_z + 7.5
	_step_pad(Vector3(-1.5, y - 0.4, land_z), MotorConstants.STEP_MED, "dive_hop_m")
	_step_pad(Vector3(1.5, y - 0.4, land_z + 1.2), MotorConstants.STEP_HARD, "dive_hop_h")
	var m_low := MotorConstants.MANTLE_LEDGE_LOW
	_box(Vector3(0, y - 0.4 + m_low * 0.5, land_z + 3.0), Vector3(3.5, m_low, 0.4), METAL)
	_platform(Vector3(0, y - 0.4 + m_low + 0.12, land_z + 3.7), Vector3(3.2, 0.24, 1.8), CONCRETE)
	_platform(Vector3(0, y + 1.4, land_z + 5.5), Vector3(4.5, 0.35, 2.5), CONCRETE)
	_platform(Vector3(0, y + 2.5, land_z + 7.5), Vector3(5.0, 0.35, 2.5), CONCRETE)


# --- 6. Drop roofs: soft / hard landings --------------------------------------

func _build_drop_roofs() -> void:
	var high_y := ROOF_Y + 10.6
	var z := 124.0
	_building_volume(Vector3(0, high_y, z), Vector2(9, 7), high_y - 2.0, Color(0.55, 0.52, 0.5))
	_roof_deck(Vector3(0, high_y, z), Vector2(9, 7))
	_label(Vector3(0, high_y + 2.8, z), "DROP", LABEL_C, 44)
	_make_checkpoint(Vector3(0, high_y + 0.35, z), "land_high", "Checkpoint · DROP — soft left · hard right")

	var soft_y := high_y - 1.8
	_building_volume(Vector3(-4.0, soft_y, z + 6), Vector2(5, 5), soft_y - 1.0, Color(0.5, 0.55, 0.5))
	_roof_deck(Vector3(-4.0, soft_y, z + 6), Vector2(5, 5), Color(0.82, 0.88, 0.82))
	_panel(Vector3(-4.0, soft_y + 0.28, z + 6), Vector3(3.5, 0.04, 3.5), SAFE, 0.6)
	_label(Vector3(-4.0, soft_y + 2.0, z + 6), "SOFT", SAFE, 32)

	var hard_y := high_y - 3.2
	_building_volume(Vector3(4.0, hard_y, z + 6), Vector2(5, 5), hard_y - 1.0, Color(0.55, 0.45, 0.42))
	_roof_deck(Vector3(4.0, hard_y, z + 6), Vector2(5, 5), Color(0.9, 0.8, 0.78))
	_panel(Vector3(4.0, hard_y + 0.28, z + 6), Vector3(3.5, 0.04, 3.5), RUNNER, 0.8)
	_label(Vector3(4.0, hard_y + 2.0, z + 6), "HARD", RUNNER, 32)

	_building_volume(Vector3(0, hard_y, z + 11), Vector2(12, 6), hard_y - 1.0, Color(0.6, 0.6, 0.62))
	_roof_deck(Vector3(0, hard_y, z + 11), Vector2(12, 6))
	_make_checkpoint(Vector3(0, hard_y + 0.35, z + 11), "land", "Checkpoint · DROP clear")


# --- 7. Finale: crane beam + tower extract ------------------------------------

func _build_finale_tower() -> void:
	var y := ROOF_Y + 7.4
	var z := 140.0
	_building_volume(Vector3(0, y, z), Vector2(8, 6), y - 1.0, Color(0.66, 0.67, 0.7))
	_roof_deck(Vector3(0, y, z), Vector2(8, 6))
	_label(Vector3(0, y + 3.0, z), "CRANE", LABEL_C, 44)
	_make_checkpoint(Vector3(0, y + 0.35, z), "finale", "Checkpoint · CRANE — beam, jump, extract")

	# Narrow crane/scaffold beam
	_box(Vector3(0, y + 0.35, z + 5.5), Vector3(0.5, 0.35, 7.0), METAL)
	_panel(Vector3(0, y + 0.58, z + 5.5), Vector3(0.55, 0.04, 7.0), RUNNER, 1.0)
	# Support posts
	_box(Vector3(0, y - 2.0, z + 3.5), Vector3(0.25, 4.0, 0.25), METAL_DARK)
	_box(Vector3(0, y - 2.0, z + 7.5), Vector3(0.25, 4.0, 0.25), METAL_DARK)

	var half := 1.4
	var g := MotorConstants.GAP_EXTREME
	var pad_a_z := z + 10.5
	var pad_b_z := pad_a_z + half + g + half
	_platform(Vector3(0, y + 0.9, pad_a_z), Vector3(half * 2.0, 0.35, half * 2.0), CONCRETE)
	_panel(Vector3(0, y + 1.15, pad_a_z + half - 0.05), Vector3(2.0, 0.05, 0.18), RUNNER, 1.0)
	_platform(Vector3(0, y + 1.8, pad_b_z), Vector3(half * 2.0, 0.35, half * 2.0), Color(0.9, 0.82, 0.8))
	_panel(Vector3(0, y + 2.05, pad_b_z - half + 0.05), Vector3(2.0, 0.05, 0.18), RUNNER, 1.0)
	_record_gap("finale_extreme", g, MotorConstants.GAP_EXTREME)

	var summit_z := pad_b_z + 4.5
	var summit_y := y + 2.8
	_building_volume(Vector3(0, summit_y, summit_z), Vector2(10, 10), summit_y - 1.0, Color(0.75, 0.75, 0.74))
	_roof_deck(Vector3(0, summit_y, summit_z), Vector2(10, 10))
	_ac_unit(Vector3(-3, summit_y + 0.2, summit_z - 2))
	_vent(Vector3(3, summit_y + 0.2, summit_z + 2))
	# Helipad / extract mark
	_panel(Vector3(0, summit_y + 0.28, summit_z + 1.2), Vector3(4.5, 0.05, 4.5), SAFE, 0.5)
	_panel(Vector3(0, summit_y + 0.3, summit_z + 1.2), Vector3(3.2, 0.04, 0.35), Color(0.95, 0.95, 0.95), 0.3)
	_panel(Vector3(0, summit_y + 0.3, summit_z + 1.2), Vector3(0.35, 0.04, 3.2), Color(0.95, 0.95, 0.95), 0.3)
	_label(Vector3(0, summit_y + 3.4, summit_z), "EXTRACT", SAFE, 52)
	_make_checkpoint(Vector3(0, summit_y + 0.35, summit_z), "summit", "Checkpoint · EXTRACT ROOF")
	_make_gate(Vector3(0, summit_y + 1.0, summit_z - 2.5), "summit", "Summit")
	_make_extract(Vector3(0, summit_y + 0.4, summit_z + 1.5))


func _build_skyline_backdrop() -> void:
	## Distant non-collidable towers for ME city read.
	var towers: Array = [
		Vector3(-28, 18, 30), Vector3(-35, 28, 80), Vector3(-22, 22, 120),
		Vector3(32, 20, 25), Vector3(40, 32, 70), Vector3(30, 26, 115),
		Vector3(-40, 14, 150), Vector3(45, 16, 155), Vector3(0, 12, 175),
	]
	for t: Vector3 in towers:
		var w := 6.0 + fmod(absf(t.x), 5.0)
		var d := 6.0 + fmod(absf(t.z), 4.0)
		var h := t.y * 2.0
		_panel(Vector3(t.x, h * 0.5 - 2.0, t.z), Vector3(w, h, d), Color(0.55, 0.58, 0.62, 0.85))
		# Roof cap
		_panel(Vector3(t.x, h - 2.0, t.z), Vector3(w * 1.05, 0.4, d * 1.05), Color(0.7, 0.7, 0.72, 0.9))


func _add_lights() -> void:
	for p: Vector3 in [
		Vector3(0, ROOF_Y + 8, 0), Vector3(0, ROOF_Y + 8, 22),
		Vector3(0, ROOF_Y + 10, 50), Vector3(0, ROOF_Y + 14, 75),
		Vector3(0, ROOF_Y + 12, 95), Vector3(0, ROOF_Y + 14, 110),
		Vector3(0, ROOF_Y + 16, 130), Vector3(0, ROOF_Y + 14, 155),
	]:
		var light := OmniLight3D.new()
		light.position = p
		light.light_color = Color(1.0, 0.97, 0.92)
		light.light_energy = 1.2
		light.omni_range = 18.0
		light.shadow_enabled = false
		add_child(light)


# --- Helpers ------------------------------------------------------------------

func _record_gap(id: String, actual: float, expected: float) -> void:
	measured_gaps.append({"id": id, "gap": actual, "expected": expected})


func _record_step(id: String, actual: float, expected: float) -> void:
	measured_steps.append({"id": id, "rise": actual, "expected": expected})


func _step_pad(pos: Vector3, rise: float, id: String) -> void:
	_box(Vector3(pos.x, pos.y + rise * 0.5, pos.z), Vector3(1.5, rise, 1.5), METAL)
	_panel(Vector3(pos.x, pos.y + rise + 0.02, pos.z), Vector3(1.4, 0.04, 1.4), RUNNER, 0.6)
	_record_step(id, rise, rise)


func _platform(pos: Vector3, size: Vector3, color: Color) -> StaticBody3D:
	return _box(pos, size, color)


func _box(pos: Vector3, size: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = pos
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	mesh_instance.material_override = N64Look.mat(color)
	body.add_child(mesh_instance)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	add_child(body)
	return body


func _panel(pos: Vector3, size: Vector3, color: Color, emission := 0.0) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = N64Look.mat(color, emission)
	mi.position = pos
	add_child(mi)


func _label(pos: Vector3, text: String, color: Color, font_size: int = 48) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = pos
	label.font_size = font_size
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	add_child(label)


func _make_checkpoint(pos: Vector3, zone_id: String, prompt: String) -> void:
	var area := Area3D.new()
	area.position = pos
	area.set_script(load("res://scripts/world/zone_checkpoint.gd"))
	area.set("zone_id", zone_id)
	area.set("prompt_on_enter", prompt)
	N64Look.cyl(area, Vector3(0, 0.02, 0), 0.8, 0.05, RUNNER, "Pad", 0.9, 12)
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 1.05
	shape.height = 0.45
	col.shape = shape
	col.position.y = 0.15
	area.add_child(col)
	var label := Label3D.new()
	label.text = "CP"
	label.position = Vector3(0, 0.45, 0)
	label.font_size = 26
	label.modulate = RUNNER
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	area.add_child(label)
	add_child(area)


func _make_gate(pos: Vector3, objective_id: String, _label_text: String) -> void:
	var area := Area3D.new()
	area.position = pos
	area.collision_layer = 0
	area.collision_mask = 2
	area.monitoring = true
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(4.5, 3.0, 2.2)
	col.shape = shape
	area.add_child(col)
	var id := objective_id
	area.body_entered.connect(func(body: Node3D) -> void:
		if body.is_in_group("player"):
			ObjectiveTracker.complete(id)
	)
	# Doorframe-style gate
	N64Look.box(area, Vector3(-1.9, 0.9, 0), Vector3(0.15, 2.0, 0.15), RUNNER, "L", 0.7)
	N64Look.box(area, Vector3(1.9, 0.9, 0), Vector3(0.15, 2.0, 0.15), RUNNER, "R", 0.7)
	N64Look.box(area, Vector3(0, 1.95, 0), Vector3(4.0, 0.12, 0.15), RUNNER, "Bar", 0.9)
	add_child(area)


func _make_extract(pos: Vector3) -> void:
	var area := Area3D.new()
	area.position = pos
	area.collision_layer = 0
	area.collision_mask = 2
	area.set_script(load("res://scripts/world/extract_zone.gd"))
	N64Look.cyl(area, Vector3(0, 0.06, 0), 1.9, 0.1, SAFE, "Pad", 0.8, 12)
	N64Look.box(area, Vector3(0, 1.3, 0), Vector3(0.2, 2.4, 0.2), SAFE, "Beacon", 1.4)
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 2.0
	shape.height = 2.4
	col.shape = shape
	col.position.y = 1.0
	area.add_child(col)
	add_child(area)
