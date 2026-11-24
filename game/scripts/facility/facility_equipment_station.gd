class_name FacilityEquipmentStation
extends StaticBody3D
## Runtime presentation of one authoritative equipment item.

var utility_requirements: Array[String] = []
var service_available: Dictionary = {}
var operational_color: Color = Color(0.3, 0.4, 0.5)


func configure(item: Dictionary, mission_step_ids: Array[String], base_color: Color) -> void:
	utility_requirements.assign(item["utility_requirements"])
	operational_color = base_color
	for requirement in utility_requirements:
		service_available[requirement] = true
	set_meta("equipment_id", item["id"])
	set_meta("room", item["room"])
	set_meta("owner_job", item["owner_job"])
	set_meta("function", item["function"])
	set_meta("utility_requirements", utility_requirements.duplicate())
	set_meta("mission_steps", mission_step_ids.duplicate())
	_update_visual_state()


func set_service_available(service_kind: String, available: bool) -> void:
	if not utility_requirements.has(service_kind):
		return
	service_available[service_kind] = available
	_update_visual_state()


func apply_service_snapshot(snapshot: Dictionary) -> void:
	for requirement in utility_requirements:
		service_available[requirement] = bool(snapshot.get(requirement, false))
	_update_visual_state()


func is_operational() -> bool:
	for requirement in utility_requirements:
		if not bool(service_available.get(requirement, false)):
			return false
	return true


func _update_visual_state() -> void:
	var operational := is_operational()
	set_meta("visual_state", "operational" if operational else "degraded")
	set_meta("unavailable_services", _unavailable_services())
	var mesh_instance := get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh_instance == null:
		return
	var material := mesh_instance.material_override as StandardMaterial3D
	if material == null:
		return
	if operational:
		material.albedo_color = operational_color
		material.emission_enabled = false
	else:
		material.albedo_color = Color(0.42, 0.06, 0.04)
		material.emission_enabled = true
		material.emission = Color(0.9, 0.04, 0.02)
		material.emission_energy_multiplier = 1.8


func _unavailable_services() -> Array[String]:
	var result: Array[String] = []
	for requirement in utility_requirements:
		if not bool(service_available.get(requirement, false)):
			result.append(requirement)
	return result
