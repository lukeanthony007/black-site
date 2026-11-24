extends Node
## Headless launch proof for the dedicated generated facility scene.

var _fails: int = 0


func _ready() -> void:
	print("=== generated_facility_scene_selftest ===")
	var scene_path := "res://scenes/dev_generated_facility.tscn"
	if not ResourceLoader.exists(scene_path):
		_fail("dedicated generated facility scene is missing")
		_finish()
		return
	var packed: PackedScene = load(scene_path)
	var instance: Node3D = packed.instantiate()
	instance.operator_run = false
	add_child(instance)
	await get_tree().process_frame
	await get_tree().physics_frame
	var facility := instance.get_node_or_null("GeneratedCyberArchivesFacility") as Node3D
	var player := instance.get_node_or_null("Player") as CharacterBody3D
	if facility == null or player == null:
		_fail("generated scene lacks facility or player")
		_finish()
		return
	var entry_room: Node3D = null
	for room_node in facility.get_node("Rooms").get_children():
		if room_node.get_meta("room_id", "") == "screened_entry":
			entry_room = room_node
			break
	if entry_room == null:
		_fail("generated scene lacks screened entry")
	elif player.global_position.distance_to(entry_room.global_position) > 2.0:
		_fail("player did not spawn at screened entry")
	elif not instance.has_method("set_service_available") or not instance.has_method("execute_service_recovery"):
		_fail("generated scene exposes no authoritative degraded-operation recovery")
	elif not instance.has_method("transfer_material"):
		_fail("generated scene exposes no custody transfer control")
	elif not instance.has_method("request_personnel_transition"):
		_fail("generated scene exposes no personnel security control")
	elif not instance.has_method("exhaust_job_staffing"):
		_fail("generated scene exposes no staffing continuity control")
	elif not instance.has_method("turnover_shift"):
		_fail("generated scene exposes no shift turnover control")
	elif not instance.has_method("acknowledge_condition"):
		_fail("generated scene exposes no control-room acknowledgement boundary")
	else:
		instance.set_service_available("cooling", false)
		var bench: Node = null
		var preserved_console: Node = null
		for equipment_node in facility.get_node("Equipment").get_children():
			if equipment_node.get_meta("equipment_id", "") == "contained_analysis_bench":
				bench = equipment_node
			elif equipment_node.get_meta("equipment_id", "") == "baseline_admin_console":
				preserved_console = equipment_node
		var control_snapshot: Dictionary = instance.get("control_snapshot")
		if bench == null or preserved_console == null or bench.is_operational() or not preserved_console.is_operational() or _condition_phase(control_snapshot, "cooling") != "safe_hold":
			_fail("generated safe hold did not preserve consumers and phase observability")
		else:
			var initial_recovery: Dictionary = instance.execute_service_recovery("cooling")
			if not initial_recovery.get("accepted", false) or not bench.is_operational():
				_fail("generated scene did not execute staffed cooling recovery")
			else:
				var bypass: Dictionary = instance.transfer_material("archive_stack", ["archive_custodian"])
				var custody_marker := instance.get_node_or_null("CustodyMaterial")
				if bypass.get("accepted", true) or custody_marker == null or custody_marker.get_meta("current_room", "") != "loading":
					_fail("rejected custody bypass moved live material")
				else:
					var screened: Dictionary = instance.transfer_material("material_screening", ["security_officer"])
					if not screened.get("accepted", false) or custody_marker.get_meta("current_room", "") != "material_screening":
						_fail("accepted custody transfer did not move live material")
					else:
						var staffing_group := instance.get_node_or_null("Staffing")
						instance.set_service_available("cooling", false)
						var command_definition: Dictionary = instance.get("procedure_panel_definitions")["cooling:enter_controlled_shutdown"]
						var queued_work: Dictionary = instance.call("_request_procedure_work", command_definition, "scheduled_watch")
						var work_task_id: String = queued_work.get("task_id", "")
						var outgoing_actor: String = queued_work.get("actor_person_id", "")
						var turnover: Dictionary = instance.turnover_shift("swing")
						var handed_task: Dictionary = instance.get("procedure_work_state").get("tasks", {}).get(work_task_id, {})
						var incoming_actor: String = handed_task.get("actor_person_id", "")
						var remaining_after_handoff: int = int(handed_task.get("remaining_ticks", 0))
						var handoff_tick: Dictionary = instance.tick_procedure_work()
						if staffing_group == null or staffing_group.get_child_count() == 0:
							_fail("generated scene instantiated no on-duty staffing")
						elif not queued_work.get("accepted", false) or not turnover.get("accepted", false) or turnover.get("work_handoffs", []).size() != 1 or incoming_actor.is_empty() or incoming_actor == outgoing_actor or remaining_after_handoff != 1 or staffing_group.get_child(0).get_meta("shift", "") != "swing":
							_fail("generated shift turnover did not transfer exact active work to incoming watch")
						elif handoff_tick.get("commits", []).size() != 1 or instance.infrastructure_runtime.service_phase(instance.infrastructure_state, "cooling") != "controlled_shutdown":
							_fail("incoming watch did not commit handed-off work exactly once")
						else:
							var shortage: Dictionary = instance.exhaust_job_staffing("cyber_researcher")
							instance.set_service_available("cooling", false)
							var combined_block: Dictionary = instance.advance_mission()
							if shortage.get("procedure", "") != "staffing_shortage" or combined_block.get("failed_step", "") != "conduct_research" or combined_block.get("active_blockers", []).size() != 2:
								_fail("generated combined failure did not block owned mission work")
							else:
								var board := instance.get_node_or_null("ControlStatusBoard")
								var board_snapshot: Dictionary = {} if board == null else board.get_meta("snapshot", {})
								var cooling_occurrence := ""
								for condition in board_snapshot.get("conditions", []):
									if condition.get("key", "") == "service:cooling":
										cooling_occurrence = condition["occurrence_id"]
								var acknowledgement: Dictionary = instance.acknowledge_condition(cooling_occurrence, ["facilities_engineer"])
								var acknowledged_snapshot: Dictionary = {} if board == null else board.get_meta("snapshot", {})
								if board == null or not acknowledgement.get("accepted", false) or acknowledged_snapshot.get("severity", "") != "alarm" or not _condition_acknowledged(acknowledged_snapshot, "service:cooling"):
									_fail("generated control board acknowledgement erased or missed live alarm")
								else:
									var verified_recovery: Dictionary = instance.execute_service_recovery("cooling")
									var staffing_block: Dictionary = instance.advance_mission()
									var repair_actor_is_on_duty := _staff_marker_matches_job(staffing_group, verified_recovery.get("repair_actor", ""), "facilities_engineer")
									if not verified_recovery.get("accepted", false) or not repair_actor_is_on_duty or staffing_block.get("active_procedure", "") != "staffing_shortage":
										_fail("generated recovery contradiction accepted=%s repair=%s on_duty=%s remaining=%s" % [verified_recovery.get("accepted", false), verified_recovery.get("repair_actor", ""), repair_actor_is_on_duty, staffing_block.get("active_procedure", "")])
									else:
										var personnel_origin: Vector3 = player.global_position
										var ordinary_egress: Dictionary = instance.request_personnel_transition("emergency_exit", false)
										if ordinary_egress.get("accepted", true) or player.global_position != personnel_origin:
											_fail("ordinary request used emergency egress or moved player")
										else:
											var emergency_egress: Dictionary = instance.request_personnel_transition("emergency_exit", true)
											if not emergency_egress.get("accepted", false) or player.get_meta("authoritative_room", "") != "emergency_exit":
												_fail("accepted emergency receipt did not move player to exit")
											else:
												_ok("generated facility preserves active procedure work through shift handoff and combined failures")
	_finish()


func _condition_phase(snapshot: Dictionary, condition_id: String) -> String:
	for condition in snapshot.get("conditions", []):
		if condition.get("id", "") == condition_id:
			return condition.get("phase", "")
	return ""


func _staff_marker_matches_job(staffing_group: Node, staff_id: String, job_id: String) -> bool:
	for marker in staffing_group.get_children():
		if marker.get_meta("staff_id", "") == staff_id:
			return marker.get_meta("job_id", "") == job_id and marker.get_meta("shift", "") == "swing"
	return false


func _condition_acknowledged(snapshot: Dictionary, key: String) -> bool:
	for condition in snapshot.get("conditions", []):
		if condition.get("key", "") == key:
			return bool(condition.get("active", false)) and bool(condition.get("acknowledged", false))
	return false


func _finish() -> void:
	print("=== generated_facility_scene_selftest done fails=%d ===" % _fails)
	await get_tree().process_frame
	get_tree().quit(0 if _fails == 0 else 1)


func _fail(msg: String) -> void:
	_fails += 1
	print("FAIL: ", msg)


func _ok(msg: String) -> void:
	print("OK: ", msg)
