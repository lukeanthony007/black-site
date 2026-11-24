extends Node
## Rendered proof for graph-derived local procedure panels at the plant station.

const SHOT_PATH := "/tmp/blacksite_shots/generated_procedure_panels.png"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("/tmp/blacksite_shots")
	var packed: PackedScene = load("res://scenes/dev_generated_facility.tscn")
	var facility: Node3D = packed.instantiate()
	add_child(facility)
	for _frame in 12:
		await get_tree().process_frame
	var panels: Node = facility.get_node("ProcedurePanels")
	var command_panel := _panel_for(panels, "cooling", "enter_controlled_shutdown")
	var isolate_panel := _panel_for(panels, "cooling", "isolate_for_repair")
	var begin_panel := _panel_for(panels, "cooling", "begin_repair")
	var repair_panel := _panel_for(panels, "cooling", "record_repair")
	var player: Node = facility.get_node("Player")
	facility.set_service_available("cooling", false)
	facility.request_personnel_transition("staff_control")
	facility.request_personnel_transition("cyber_ops")
	command_panel.interact(player)
	_complete_panel_work(facility)
	facility.request_personnel_transition("staff_control")
	facility.request_personnel_transition("plant")
	isolate_panel.interact(player)
	_complete_panel_work(facility)
	begin_panel.interact(player)
	_complete_panel_work(facility)
	repair_panel.interact(player)
	facility.tick_procedure_work()
	var repair_task_id: String = repair_panel.last_result.get("task_id", "")
	var outgoing_actor: String = facility.procedure_work_state["tasks"][repair_task_id]["actor_person_id"]
	var turnover: Dictionary = facility.turnover_shift("swing")
	var handed_task: Dictionary = facility.procedure_work_state["tasks"].get(repair_task_id, {})
	if facility.infrastructure_runtime.service_phase(facility.infrastructure_state, "cooling") != "repair_pending":
		push_error("procedure-panel shot could not reach plant repair phase")
		get_tree().quit(1)
		return
	if not turnover.get("accepted", false) or handed_task.get("actor_person_id", "") == outgoing_actor or handed_task.get("handoffs", []).size() != 1 or bool(begin_panel.get_meta("available", true)) or bool(repair_panel.get_meta("available", true)) or repair_panel.get_meta("work_status", "") != "working" or int(repair_panel.get_meta("remaining_ticks", -1)) != 2 or int(repair_panel.get_meta("handoff_count", 0)) != 1:
		push_error("procedure-panel shot has false shift-handoff work presentation")
		get_tree().quit(1)
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		push_error("procedure-panel shot has no camera")
		get_tree().quit(1)
		return
	var target: Vector3 = begin_panel.global_position + Vector3(0.9, 0.15, 0.0)
	camera.global_position = target + Vector3(0.0, 0.15, 3.25)
	camera.look_at(target, Vector3.UP)
	for _frame in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(SHOT_PATH)
	if error != OK:
		push_error("procedure-panel screenshot save failed: %s" % error_string(error))
		get_tree().quit(1)
		return
	print("PROCEDURE_PANEL_SHOT path=%s phase=repair_pending repair_status=working remaining_ticks=2 handoffs=1 shift=swing" % SHOT_PATH)
	get_tree().quit()


func _complete_panel_work(facility: Node) -> void:
	for _tick in 16:
		var result: Dictionary = facility.tick_procedure_work()
		if not (result["commits"] as Array).is_empty() or not (result["failures"] as Array).is_empty():
			return


func _panel_for(group: Node, service_id: String, action: String) -> Node:
	for panel in group.get_children():
		if panel.get_meta("service", "") == service_id and panel.get_meta("action", "") == action:
			return panel
	return null
