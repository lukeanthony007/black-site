class_name FacilityProcedurePanel
extends StaticBody3D
## Physical interaction boundary for one graph-derived infrastructure response action.

var controller: Node
var panel_id: String = ""
var last_result: Dictionary = {}
var _action_label := ""
var _required_phase := ""


func configure(
	facility_controller: Node,
	configured_panel_id: String,
	service_id: String,
	action: String,
	station: String,
	actor_job: String,
	required_phase: String,
	duration_ticks: int,
	required_services: Array,
	control_mode: String = "primary_control"
) -> void:
	controller = facility_controller
	panel_id = configured_panel_id
	_action_label = action.replace("_", " ").to_upper()
	if control_mode != "primary_control":
		_action_label += " · HARDWIRED"
	_required_phase = required_phase
	set_meta("panel_id", panel_id)
	set_meta("service", service_id)
	set_meta("action", action)
	set_meta("station", station)
	set_meta("actor_job", actor_job)
	set_meta("required_phase", required_phase)
	set_meta("duration_ticks", duration_ticks)
	set_meta("required_services", required_services.duplicate())
	set_meta("control_mode", control_mode)
	_build_physical_panel(action, required_phase, control_mode)


func interact(interactor: Node) -> void:
	if controller == null or not controller.has_method("activate_procedure_panel"):
		last_result = {"accepted": false, "reason": "procedure controller unavailable"}
		return
	last_result = controller.activate_procedure_panel(panel_id, interactor)
	set_meta("last_result", last_result.duplicate(true))


func set_available(available: bool) -> void:
	set_meta("available", available)
	var face := get_node_or_null("PanelFace") as MeshInstance3D
	if face != null:
		var material := face.material_override as StandardMaterial3D
		if material != null:
			material.emission = Color(0.04, 0.72, 0.28) if available else Color(0.18, 0.08, 0.04)
			material.albedo_color = Color(0.08, 0.24, 0.14) if available else Color(0.13, 0.10, 0.09)
	var label := get_node_or_null("ProcedureLabel") as Label3D
	if label != null:
		label.modulate = Color(0.55, 1.0, 0.66) if available else Color(0.6, 0.42, 0.32)


func set_work_state(status: String, remaining_ticks: int, handoff_count: int = 0, reason: String = "") -> void:
	set_meta("work_status", status)
	set_meta("remaining_ticks", remaining_ticks)
	set_meta("handoff_count", handoff_count)
	set_meta("work_reason", reason)
	var label := get_node_or_null("ProcedureLabel") as Label3D
	if label == null:
		return
	label.text = "%s\n[%s]" % [_action_label, _required_phase]
	if not status.is_empty():
		label.text += "\n%s  %dt" % [status.to_upper(), remaining_ticks]
		if handoff_count > 0:
			label.text += "  H%d" % handoff_count
		if not reason.is_empty():
			var short_reason := reason.get_slice(":", 1).to_upper() if reason.contains(":") else reason.replace("station_access_revoked", "ACCESS").replace("restart_reconciliation_required", "RECONCILE").to_upper()
			label.text += "\n%s" % short_reason


func _build_physical_panel(action: String, required_phase: String, control_mode: String) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "PanelFace"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.72, 0.58, 0.16)
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.08, 0.16, 0.19)
	material.emission_enabled = true
	material.emission = Color(0.03, 0.22, 0.18)
	material.emission_energy_multiplier = 0.7
	mesh_instance.material_override = material
	add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	collision.name = "InteractionCollider"
	var shape := BoxShape3D.new()
	shape.size = mesh.size
	collision.shape = shape
	add_child(collision)

	var label := Label3D.new()
	label.name = "ProcedureLabel"
	label.text = "%s\n[%s]" % [action.replace("_", " ").to_upper(), required_phase]
	label.font_size = 24
	label.outline_size = 6
	label.pixel_size = 0.004
	label.no_depth_test = true
	label.position = Vector3(0.0, 0.0, 0.09)
	add_child(label)
