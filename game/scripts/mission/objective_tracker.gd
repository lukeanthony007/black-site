extends Node
## Mission checklist, run stats, and end rating. Autoload.

signal objectives_changed
signal prompt_changed(text: String)
signal ammo_changed(mag: int, reserve: int)
signal health_changed(current: float, maximum: float)
signal weapon_changed(weapon_name: String)
signal hurt_flash_changed(amount: float)
signal gadgets_changed(lockpicks: int, loops: int, decoys: int)
signal mission_ended(won: bool, message: String, summary: Dictionary)

var objectives: Dictionary = {}
var prompt: String = ""
var ammo_mag: int = 0
var ammo_reserve: int = 0
var player_health: float = 100.0
var player_max_health: float = 100.0
var player_armor: float = 50.0
var player_max_armor: float = 100.0
var weapon_name: String = "PP7"
var hurt_flash: float = 0.0
var lockpick_count: int = 0
var loop_count: int = 0
var decoy_count: int = 0
var ended: bool = false
var last_rating: String = ""

# Run stats for rating
var kills: int = 0
var stealth_kills: int = 0
var knockouts: int = 0
var shots_fired: int = 0
var alerts_raised: int = 0
var bodies_found: int = 0
var damage_taken: float = 0.0


func _ready() -> void:
	reset_mission()


func _reset_run_stats() -> void:
	ended = false
	last_rating = ""
	kills = 0
	stealth_kills = 0
	knockouts = 0
	shots_fired = 0
	alerts_raised = 0
	bodies_found = 0
	damage_taken = 0.0
	hurt_flash = 0.0
	weapon_name = "PP7"
	lockpick_count = 0
	loop_count = 0
	decoy_count = 0


func reset_mission() -> void:
	_reset_run_stats()
	objectives = {
		"download": {"label": "1. Download research data", "done": false, "required": true},
		"destroy": {"label": "2. Destroy mainframe console", "done": false, "required": true},
		"exit": {"label": "3. Reach extraction", "done": false, "required": true},
		"bunker": {"label": "★ Sabotage bunker relay (optional)", "done": false, "required": false},
		"clean": {"label": "★ No casualties (optional)", "done": false, "required": false},
	}
	prompt = "WASD · aim+1/2/3 · V decoy · F/Q · G pick · C loop · E · P"
	objectives_changed.emit()
	prompt_changed.emit(prompt)
	weapon_changed.emit(weapon_name)
	hurt_flash_changed.emit(0.0)
	gadgets_changed.emit(0, 0, 0)


func setup_otr_mission() -> void:
	_reset_run_stats()
	objectives = {
		"scout": {"label": "1. Mark dead drop on Vine", "done": false, "required": true},
		"exit": {"label": "2. Reach extraction zone", "done": false, "required": true},
		"clean": {"label": "★ No casualties (optional)", "done": false, "required": false},
	}
	prompt = "WASD · parkour · E interact · reach green extract"
	objectives_changed.emit()
	prompt_changed.emit(prompt)
	weapon_changed.emit(weapon_name)
	hurt_flash_changed.emit(0.0)
	gadgets_changed.emit(0, 0, 0)


func setup_parkour_mission() -> void:
	_reset_run_stats()
	objectives = {
		"stride": {"label": "1. Clear STRIDE (slide)", "done": false, "required": true},
		"gaps": {"label": "2. Clear GAPS", "done": false, "required": true},
		"climb": {"label": "3. Clear CLIMB", "done": false, "required": true},
		"walls": {"label": "4. Clear WALLRUN", "done": false, "required": true},
		"summit": {"label": "5. Reach SUMMIT", "done": false, "required": true},
		"exit": {"label": "6. Extract", "done": false, "required": true},
	}
	prompt = "Shift sprint · Ctrl slide/dive · Space jump/mantle/wallkick · follow red · P restart"
	objectives_changed.emit()
	prompt_changed.emit(prompt)
	weapon_changed.emit(weapon_name)
	hurt_flash_changed.emit(0.0)
	gadgets_changed.emit(0, 0, 0)


func complete(id: String) -> void:
	if ended:
		return
	if not objectives.has(id):
		return
	if objectives[id]["done"]:
		return
	objectives[id]["done"] = true
	objectives_changed.emit()
	GameAudio.play_interact()
	set_prompt("Objective complete")


func fail_optional(id: String) -> void:
	if not objectives.has(id):
		return
	if objectives[id].get("required", true):
		return
	# Leave undone; checklist will show as missed at end
	objectives[id]["failed"] = true
	objectives_changed.emit()


func is_complete(id: String) -> bool:
	return objectives.has(id) and objectives[id]["done"]


func required_complete() -> bool:
	for key in objectives:
		var obj: Dictionary = objectives[key]
		if obj["required"] and key != "exit" and not obj["done"]:
			return false
	return true


func try_extract() -> void:
	if ended:
		return
	if not required_complete():
		set_prompt("Complete required gates before extraction")
		return
	if objectives.has("clean"):
		if kills == 0:
			complete("clean")
		else:
			fail_optional("clean")
	complete("exit")
	last_rating = compute_rating()
	var summary := build_summary(last_rating)
	mission_won(summary)


func build_summary(rating: String) -> Dictionary:
	return {
		"rating": rating,
		"kills": kills,
		"stealth_kills": stealth_kills,
		"knockouts": knockouts,
		"alerts": alerts_raised,
		"shots": shots_fired,
		"bodies_found": bodies_found,
		"damage_taken": int(damage_taken),
		"clean": is_complete("clean"),
	}


func compute_rating() -> String:
	if kills == 0 and alerts_raised == 0 and shots_fired == 0:
		return "GHOST"
	if kills == 0 and alerts_raised == 0:
		return "GHOST"
	if stealth_kills == kills and alerts_raised == 0 and kills > 0:
		return "SHADOW"
	if kills == 0 and knockouts > 0 and alerts_raised <= 1:
		return "MERCY"
	if stealth_kills + knockouts >= kills and alerts_raised <= 1:
		return "PANTHER"
	if is_complete("bunker") and kills <= 1 and alerts_raised <= 2:
		return "PANTHER"
	if alerts_raised >= 3 and kills >= 3:
		return "CHAOS"
	return "ASSAULT"


func record_kill(stealth: bool) -> void:
	kills += 1
	if stealth:
		stealth_kills += 1
	fail_optional("clean")


func record_knockout() -> void:
	knockouts += 1


func record_shot() -> void:
	shots_fired += 1


func record_body_found() -> void:
	bodies_found += 1


func record_damage(amount: float) -> void:
	damage_taken += amount


func set_prompt(text: String) -> void:
	prompt = text
	prompt_changed.emit(prompt)


func set_ammo(mag: int, reserve: int) -> void:
	ammo_mag = mag
	ammo_reserve = reserve
	ammo_changed.emit(mag, reserve)


func set_player_health(current: float, maximum: float) -> void:
	set_player_vitals(current, maximum, player_armor, player_max_armor)


func set_player_vitals(hp: float, max_hp: float, arm: float, max_arm: float) -> void:
	player_health = hp
	player_max_health = max_hp
	player_armor = arm
	player_max_armor = max_arm
	health_changed.emit(hp, max_hp)


func set_weapon_name(name: String) -> void:
	weapon_name = name
	weapon_changed.emit(name)


func set_hurt_flash(amount: float) -> void:
	hurt_flash = amount
	hurt_flash_changed.emit(amount)


func set_gadget_counts(picks: int, loops: int, decoys: int = 0) -> void:
	lockpick_count = picks
	loop_count = loops
	decoy_count = decoys
	gadgets_changed.emit(picks, loops, decoys)


func mission_failed(message: String) -> void:
	if ended:
		return
	ended = true
	mission_ended.emit(false, message, {})


func mission_won(summary: Dictionary) -> void:
	if ended:
		return
	ended = true
	var msg := "MISSION COMPLETE — %s" % summary.get("rating", "ASSAULT")
	mission_ended.emit(true, msg, summary)
