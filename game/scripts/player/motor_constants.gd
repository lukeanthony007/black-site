class_name MotorConstants
extends RefCounted
## Single source of truth for parkour numbers.
## Gym geometry and motor tests MUST read these — do not duplicate magic numbers.

# --- Locomotion (mirrored on player for runtime speed) ---
const WALK_SPEED := 5.0
const SPRINT_SPEED := 8.0
const CROUCH_SPEED := 2.5
const JUMP_VELOCITY := 4.5
## Godot default gravity magnitude used for jump-apex math (project may differ slightly).
const GRAVITY_ASSUMED := 9.8
## Peak jump height from rest: v² / (2g)
const MAX_JUMP_HEIGHT := (JUMP_VELOCITY * JUMP_VELOCITY) / (2.0 * GRAVITY_ASSUMED)

const STAND_HEIGHT := 1.8
const CROUCH_HEIGHT := 0.95
## Mid-air dive (Ctrl held, or 2nd Space) — shorter capsule for windows / low gaps.
const DIVE_HEIGHT := 0.72
## Horizontal air speed while diving (clearly above sprint for distance).
const DIVE_AIR_SPEED := 11.0
## Extra upward kick when leaving the ground already diving (Ctrl+jump).
const DIVE_JUMP_BOOST := 0.65
## Clear opening height for a crouch/slide (capsule + small margin).
const SLIDE_CLEARANCE := 1.05

## Min horizontal speed to enter slide without sprint held (between walk and sprint).
const SLIDE_START_SPEED := 5.5
const SLIDE_BOOST := 9.5
## After releasing sprint, crouch still counts as sprint-slide for this long.
const SLIDE_SPRINT_GRACE := 0.32
## Deceleration while sliding (m/s²) — lower = longer coast
const SLIDE_FRICTION := 5.5
## End slide below this speed and settle into crouch walk
const SLIDE_MIN_SPEED := 1.4
## Hard cap so a slide can never last forever even on slopes
const SLIDE_MAX_TIME := 2.8

# --- Ledge grab / mantle (heights above feet) ---
## Ground vault band starts at/above pure jump apex (no free double-jump from stand).
const MANTLE_MIN := 1.05
## Tall grab window — wallrun tops, second-story lips, climb pads.
const MANTLE_MAX := 2.45
const MANTLE_FORWARD_REACH := 1.15
const MANTLE_PROBE_UP := 0.55
## Pull-up: hang → climb onto surface (seconds). Scales slightly with ledge height.
const MANTLE_DURATION := 0.52
const MANTLE_EXIT_SPEED := 3.5
## Vertical speed window for a grab (free air). Wall-climb uses a higher cap.
const MANTLE_MAX_UP_VEL := 5.5
const MANTLE_MAX_DOWN_VEL := -7.5
## Allow grab while still climbing (vert speed is ~WALLRUN_VERT_SPEED).
const MANTLE_WALLCLIMB_MAX_UP_VEL := 9.0
## Auto-grab when this close to a valid lip (meters to wall).
const MANTLE_AUTO_DIST := 0.72
## How far past the wall face to search for a standable top (balcony depth).
const MANTLE_TOP_INSET := 0.65

# --- Landings (fall distance from peak air Y to feet on land) ---
const LANDING_SOFT_MAX := 2.4
const LANDING_HARD_MIN := 2.4
const LANDING_SOFT_NOISE := 0.18
const LANDING_HARD_NOISE := 0.78
const LANDING_HARD_ACCURACY_SEC := 0.65 ## slightly longer recovery after hard land
const LANDING_SOFT_MIN := 0.85

# --- Sprint gap distances (edge-to-edge, horizontal) ---
const GAP_EASY := 1.5
const GAP_MED := 2.2
const GAP_HARD := 2.8
const GAP_EXTREME := 3.4

# --- Climb step / pad rises (intentional hop/parkour pads, not walkable stairs) ---
const STEP_EASY := 0.50
const STEP_MED := 0.75
const STEP_HARD := 0.95
const MANTLE_LEDGE_LOW := 1.20
const MANTLE_LEDGE_HIGH := 1.45

# --- Walkable stairs / ledges (real collision steps; motor auto-steps, no ramps) ---
const STAIR_RISE := 0.17
const STAIR_TREAD := 0.45 ## wider than capsule radius so a tread is standable
const STAIR_WIDTH := 1.6
## Max ledge height auto-stepped with W (no jump). Covers stairs + small gaps.
const MAX_STEP_HEIGHT := 0.5

# --- Wallrun ---
## Lateral arc duration (along wall, up then down).
const WALLRUN_MAX_TIME := 1.55
const WALLRUN_MIN_SPEED := 4.5 ## jump-sprint entry (walk is too slow)
const WALLRUN_SPEED := 8.5
const WALLRUN_ATTACH_DIST := 0.95 ## reach wall from ~center of gym lane
## Lateral: reject if |forward·normal| above this (too head-on / away).
const WALLRUN_MAX_INTO_DOT := 0.78
const WALLRUN_KICK_SPEED := 9.0
const WALLRUN_MIN_HEIGHT := 0.28 ## feet clear of floor before attach
const WALLRUN_COOLDOWN := 0.2 ## brief peel-off only; re-run needs floor (see _wallrun_used_air)
## Peak of the lateral wall-arc above attach height.
const WALLRUN_ARC_PEAK := 2.6
const WALLRUN_ARC_APEX_FRAC := 0.52
const WALLRUN_CAM_ROLL_DEG := 9.0 ## lean toward wall (lateral)
const WALLRUN_STICK := 2.2 ## pull into wall so capsule stays glued
# Vertical climb (sprint-jump straight into a wall, then mantle the lip)
const WALLRUN_VERT_MAX_TIME := 1.05
const WALLRUN_VERT_SPEED := 7.2 ## upward climb m/s
const WALLRUN_VERT_MIN_INTO := 0.42 ## must face into wall ( -forward·normal )
const WALLRUN_VERT_STICK := 3.0
## Mirror's Edge-style 180° turn (Ctrl) while climbing — face away for kick.
const WALLRUN_TURN_TIME := 0.18

# Difficulty colors removed — gym uses neutral facility materials (see facility_builder PAD/CP).


enum LandingKind { NONE, SOFT, HARD }


static func is_mantleable_height(height_above_feet: float) -> bool:
	return height_above_feet >= MANTLE_MIN and height_above_feet <= MANTLE_MAX


static func classify_landing(fall_height: float) -> LandingKind:
	if fall_height < LANDING_SOFT_MIN:
		return LandingKind.NONE
	if fall_height < LANDING_HARD_MIN:
		return LandingKind.SOFT
	return LandingKind.HARD


static func landing_noise(kind: LandingKind) -> float:
	match kind:
		LandingKind.SOFT:
			return LANDING_SOFT_NOISE
		LandingKind.HARD:
			return LANDING_HARD_NOISE
		_:
			return 0.0


static func landing_noise_for_fall(fall_height: float) -> float:
	return landing_noise(classify_landing(fall_height))


## Lateral wallrun: run along wall. into_wall_dot = forward · normal (0 = parallel).
static func can_start_wallrun(planar_speed: float, into_wall_dot: float, sprinting: bool) -> bool:
	if planar_speed < WALLRUN_MIN_SPEED:
		return false
	if not sprinting and planar_speed < SPRINT_SPEED * 0.85:
		return false
	if absf(into_wall_dot) > WALLRUN_MAX_INTO_DOT:
		return false
	return true


## Vertical wallrun: sprint-jump into wall and climb. into = forward · normal (negative = into).
static func can_start_vertical_wallrun(planar_speed: float, into_wall_dot: float, sprinting: bool) -> bool:
	if planar_speed < WALLRUN_MIN_SPEED * 0.9:
		return false
	if not sprinting and planar_speed < SPRINT_SPEED * 0.8:
		return false
	# Must be driving into the wall (normal points out → into is negative)
	if into_wall_dot > -WALLRUN_VERT_MIN_INTO:
		return false
	return true
