extends CanvasLayer
## GoldenEye / N64 mission HUD.

@onready var checklist: Label = $Root/Checklist
@onready var prompt: Label = $Root/Prompt
@onready var status: Label = $Root/Status
@onready var vitals: Label = $Root/Vitals
@onready var weapon_label: Label = $Root/Weapon
@onready var vignette: ColorRect = $Root/Vignette
@onready var alert_label: Label = $Root/AlertPhase
@onready var gadgets_label: Label = $Root/Gadgets
@onready var ammo_label: Label = $Root/Ammo
@onready var end_panel: ColorRect = $Root/EndPanel
@onready var end_title: Label = $Root/EndPanel/Title
@onready var end_body: Label = $Root/EndPanel/Body
@onready var end_hint: Label = $Root/EndPanel/Hint


func _ready() -> void:
	ObjectiveTracker.objectives_changed.connect(_refresh_objectives)
	ObjectiveTracker.prompt_changed.connect(_on_prompt)
	ObjectiveTracker.ammo_changed.connect(_on_ammo)
	ObjectiveTracker.health_changed.connect(_on_health)
	ObjectiveTracker.weapon_changed.connect(_on_weapon)
	ObjectiveTracker.hurt_flash_changed.connect(_on_hurt)
	ObjectiveTracker.gadgets_changed.connect(_on_gadgets)
	ObjectiveTracker.mission_ended.connect(_on_mission_ended)
	AlertPhase.phase_changed.connect(_on_alert_phase)
	end_panel.visible = false
	_refresh_objectives()
	_on_prompt(ObjectiveTracker.prompt)
	_on_ammo(ObjectiveTracker.ammo_mag, ObjectiveTracker.ammo_reserve)
	_on_health(ObjectiveTracker.player_health, ObjectiveTracker.player_max_health)
	_on_weapon(ObjectiveTracker.weapon_name)
	_on_hurt(0.0)
	_on_gadgets(ObjectiveTracker.lockpick_count, ObjectiveTracker.loop_count, ObjectiveTracker.decoy_count)
	_on_alert_phase(AlertPhase.phase, AlertPhase.phase_label())
	status.text = ""


func _refresh_objectives() -> void:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("MISSION OBJECTIVES")
	for key in ObjectiveTracker.objectives:
		var obj: Dictionary = ObjectiveTracker.objectives[key]
		var mark := "·"
		if obj["done"]:
			mark = "✓"
		elif obj.get("failed", false):
			mark = "×"
		lines.append("%s %s" % [mark, obj["label"]])
	checklist.text = "\n".join(lines)
	checklist.modulate = Color(1.35, 1.35, 0.55)
	var tw := create_tween()
	tw.tween_property(checklist, "modulate", Color(0.95, 1.0, 0.55), 0.4)


func _on_prompt(text: String) -> void:
	prompt.text = text.to_upper() if text != "" else ""


func _on_ammo(mag: int, reserve: int) -> void:
	ammo_label.text = "%02d\n%03d" % [mag, reserve]
	_update_vitals(ObjectiveTracker.player_health, ObjectiveTracker.player_max_health)


func _on_health(current: float, maximum: float) -> void:
	_update_vitals(current, maximum)


func _on_weapon(weapon_name: String) -> void:
	weapon_label.text = weapon_name.to_upper()


func _on_gadgets(picks: int, loops: int, decoys: int = 0) -> void:
	gadgets_label.text = "G %d   C %d   V %d" % [picks, loops, decoys]


func _on_hurt(amount: float) -> void:
	vignette.color = Color(0.75, 0.05, 0.05, clampf(amount * 0.7, 0.0, 0.6))


func _on_alert_phase(phase: Variant, label: String) -> void:
	alert_label.text = label
	match phase:
		AlertPhase.Phase.ALERT:
			alert_label.modulate = Color(1.0, 0.3, 0.2)
			alert_label.text = "!! ALERT !!"
		AlertPhase.Phase.CAUTION:
			alert_label.modulate = Color(1.0, 0.9, 0.25)
			alert_label.text = "CAUTION"
		_:
			alert_label.modulate = Color(0.45, 0.95, 0.45)
			alert_label.text = "CLEAR"


func _bar(ratio: float, width: int = 10) -> String:
	var filled := clampi(int(round(ratio * float(width))), 0, width)
	return "█".repeat(filled) + "░".repeat(width - filled)


func _update_vitals(hp: float, max_hp: float) -> void:
	var armor := ObjectiveTracker.player_armor
	var max_armor := ObjectiveTracker.player_max_armor
	var hp_r := 0.0 if max_hp <= 0.0 else hp / max_hp
	var ar_r := 0.0 if max_armor <= 0.0 else armor / max_armor
	vitals.text = "ARMOR  %s\nHEALTH %s" % [_bar(ar_r), _bar(hp_r)]


func _on_mission_ended(won: bool, message: String, summary: Dictionary) -> void:
	status.text = message
	status.modulate = Color(0.45, 1.0, 0.5) if won else Color(1.0, 0.35, 0.3)
	prompt.text = "PRESS P TO RESTART"
	end_panel.visible = true
	if won and not summary.is_empty():
		end_title.text = str(summary.get("rating", "COMPLETE"))
		end_title.modulate = Color(0.85, 1.0, 0.45)
		var clean_line := "NO CASUALTIES: YES" if summary.get("clean", false) else "NO CASUALTIES: FAILED"
		end_body.text = "\n".join([
			"KILLS %d   STEALTH %d" % [summary.get("kills", 0), summary.get("stealth_kills", 0)],
			"KNOCKOUTS %d" % summary.get("knockouts", 0),
			"ALERTS %d   SHOTS %d" % [summary.get("alerts", 0), summary.get("shots", 0)],
			"BODIES FOUND %d   DAMAGE %d" % [summary.get("bodies_found", 0), summary.get("damage_taken", 0)],
			clean_line,
		])
	else:
		end_title.text = "FAILED"
		end_title.modulate = Color(1.0, 0.35, 0.3)
		end_body.text = message
	end_hint.text = "PRESS P TO RESTART"
