class_name WeaponData
extends Resource
## Weapon stats. Gunfeel numbers live here so tests and controller share one source.
## PRE_TIGHTEN_* document the old defaults for measurable regression tests.

## Documented pre-tighten baselines (do not use at runtime — tests compare against these).
const PRE_TIGHTEN_RECOVERY := 12.0
const PRE_TIGHTEN_BASE_SPREAD_PISTOL := 0.3
const PRE_TIGHTEN_MOVE_SPREAD_PISTOL := 1.6
const PRE_TIGHTEN_RECOIL_PITCH_PISTOL := 2.4

@export var display_name: String = "Pistol"
@export var damage: float = 34.0
@export var fire_rate: float = 4.0
@export var automatic: bool = false
@export var magazine_size: int = 12
@export var reserve_ammo: int = 48
@export var range_distance: float = 80.0
@export var recoil_pitch: float = 2.8 ## snappier kick vs pre-tighten 2.4
@export var recoil_yaw_jitter: float = 0.32
@export var recovery_speed: float = 18.0 ## faster settle vs pre-tighten 12
@export var base_spread_deg: float = 0.55 ## hip is looser
@export var move_spread_deg: float = 2.2
@export var ads_spread_mul: float = 0.32 ## ADS much tighter than hip
@export var hip_spread_mul: float = 1.0
@export var noise: float = 0.85
@export var view_kind: int = 0 ## Viewmodel.Kind
@export var view_scale: Vector3 = Vector3(0.12, 0.14, 0.4)
@export var view_color: Color = Color(0.12, 0.12, 0.14)


## Pure spread in degrees from shipped fields (tests call this / WeaponController wrapper).
static func compute_spread_deg(
	data: WeaponData,
	move_speed: float,
	is_ads: bool,
	sprint_ref: float = 8.0
) -> float:
	var move_factor := clampf(move_speed / maxf(sprint_ref, 0.01), 0.0, 1.0)
	var total := data.base_spread_deg + data.move_spread_deg * move_factor
	if is_ads:
		total *= data.ads_spread_mul
	else:
		total *= data.hip_spread_mul
	return total


static func make_pistol() -> WeaponData:
	var w := WeaponData.new()
	w.display_name = "PP7"
	w.damage = 34.0
	w.fire_rate = 4.2
	w.automatic = false
	w.magazine_size = 12
	w.reserve_ammo = 48
	w.recoil_pitch = 2.8
	w.recoil_yaw_jitter = 0.32
	w.recovery_speed = 18.0
	w.base_spread_deg = 0.55
	w.move_spread_deg = 2.2
	w.ads_spread_mul = 0.32
	w.hip_spread_mul = 1.0
	w.noise = 0.8
	w.view_kind = 0
	w.view_scale = Vector3(0.12, 0.14, 0.4)
	w.view_color = Color(0.12, 0.12, 0.14)
	return w


static func make_smg() -> WeaponData:
	var w := WeaponData.new()
	w.display_name = "KF7 Soviet"
	w.damage = 18.0
	w.fire_rate = 10.5
	w.automatic = true
	w.magazine_size = 30
	w.reserve_ammo = 90
	w.recoil_pitch = 1.55
	w.recoil_yaw_jitter = 0.5
	w.recovery_speed = 20.0
	w.base_spread_deg = 1.0
	w.move_spread_deg = 2.8
	w.ads_spread_mul = 0.4
	w.hip_spread_mul = 1.0
	w.noise = 0.95
	w.view_kind = 2
	w.view_scale = Vector3(0.14, 0.16, 0.55)
	w.view_color = Color(0.25, 0.28, 0.22)
	return w


static func make_silenced() -> WeaponData:
	var w := WeaponData.new()
	w.display_name = "PP7 (Silenced)"
	w.damage = 30.0
	w.fire_rate = 3.6
	w.automatic = false
	w.magazine_size = 12
	w.reserve_ammo = 36
	w.recoil_pitch = 2.0
	w.recoil_yaw_jitter = 0.22
	w.recovery_speed = 17.0
	w.base_spread_deg = 0.4
	w.move_spread_deg = 1.5
	w.ads_spread_mul = 0.28
	w.hip_spread_mul = 1.0
	w.noise = 0.25
	w.view_kind = 1
	w.view_scale = Vector3(0.12, 0.14, 0.55)
	w.view_color = Color(0.1, 0.1, 0.12)
	return w


static func make_rifle() -> WeaponData:
	var w := WeaponData.new()
	w.display_name = "AR33"
	w.damage = 42.0
	w.fire_rate = 6.8
	w.automatic = true
	w.magazine_size = 20
	w.reserve_ammo = 60
	w.recoil_pitch = 2.35
	w.recoil_yaw_jitter = 0.38
	w.recovery_speed = 16.0
	w.base_spread_deg = 0.6
	w.move_spread_deg = 2.4
	w.ads_spread_mul = 0.3
	w.hip_spread_mul = 1.0
	w.range_distance = 100.0
	w.noise = 1.0
	w.view_kind = 3
	w.view_scale = Vector3(0.13, 0.15, 0.7)
	w.view_color = Color(0.18, 0.2, 0.16)
	return w
