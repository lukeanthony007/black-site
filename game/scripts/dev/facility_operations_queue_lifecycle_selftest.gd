extends Node
## Queue lifecycle, reservation, retryability, and direct completion contract.
var fails := 0
func _ready() -> void:
	var script: Script = load("res://scripts/facility/facility_operations_queue_runtime.gd")
	var runtime: RefCounted = script.new()
	_check(runtime.has_method("record_task_outcome"), "queue lacks direct task outcome closure")
	_check(runtime.has_method("record_dispatch_failure"), "queue lacks retryable/terminal dispatch classification")
	var state: Dictionary = runtime.start_queue()
	_check(state.has("reservations"), "queue lacks explicit resource reservations")
	if fails == 0:
		var candidates: Array[Dictionary] = [
			{"entry_id":"a", "panel_id":"p:a", "domain":"custody", "action":"contain", "actor_job":"records_officer", "station":"archive_processing", "base_priority":10, "deadline_ticks":2, "retry_backoff_ticks":1, "max_wait_ticks":8, "abandonment_action":"mission_safe_hold"},
			{"entry_id":"b", "panel_id":"p:b", "domain":"infrastructure", "action":"repair", "actor_job":"facilities_engineer", "station":"archive_processing", "base_priority":20, "deadline_ticks":3, "retry_backoff_ticks":2, "max_wait_ticks":9, "abandonment_action":"mobilize_qualified_relief"},
		]
		var first: Dictionary = runtime.advance(state, candidates)
		runtime.record_dispatch(state, "a", "task-a", "person-a", "archive_processing")
		var blocked: Dictionary = runtime.advance(state, candidates)
		_check(blocked["selected"].is_empty(), "station reservation admitted conflicting dispatch")
		runtime.record_task_outcome(state, "task-a", "committed", "")
		var remaining: Array[Dictionary] = [candidates[1]]
		var released: Dictionary = runtime.advance(state, remaining)
		_check(released["selected"].get("entry_id", "") == "b", "completion did not release station reservation")
		runtime.record_dispatch_failure(state, "b", "no named active-watch actor can reach procedure station", true)
		_check(state["entries"]["b"]["status"] == "waiting" and state["entries"]["b"]["attempts"] == 1, "retryable blocker did not preserve waiting authority")
		var backoff: Dictionary = runtime.advance(state, remaining)
		_check(backoff["selected"].is_empty() and state["entries"]["b"]["next_attempt_clock"] == 5, "retry backoff admitted an early attempt")
		runtime.record_dispatch_failure(state, "b", "panel phase is stale", false)
		_check(state["entries"]["b"]["status"] == "terminal_failed", "terminal failure remained retryable")
		var continuity_state: Dictionary = runtime.start_queue()
		var safe_candidates: Array[Dictionary] = [{"entry_id":"safe", "panel_id":"p:safe", "domain":"custody", "action":"contain", "actor_job":"records_officer", "station":"archive_processing", "base_priority":10, "deadline_ticks":1, "retry_backoff_ticks":1, "max_wait_ticks":2, "abandonment_action":"mission_safe_hold"}]
		runtime.advance(continuity_state, safe_candidates)
		runtime.advance(continuity_state, safe_candidates)
		var abandoned: Dictionary = runtime.advance(continuity_state, safe_candidates)
		_check(abandoned["abandoned"].size() == 1, "continuity limit did not abandon waiting work")
		var held: Dictionary = runtime.record_continuity_decision(continuity_state, "safe", true, {"mode":"mission_safe_hold"})
		_check(held.get("status", "") == "safe_hold" and continuity_state["continuity_decisions"].size() == 1, "custody abandonment did not enter audited safe hold")
		_check(not runtime.record_continuity_decision(continuity_state, "safe", true, {}).get("accepted", false), "continuity decision replay was accepted")
		var reassign_state: Dictionary = runtime.start_queue()
		var reassign_candidates: Array[Dictionary] = [{"entry_id":"reassign", "panel_id":"p:repair", "domain":"infrastructure", "action":"repair", "actor_job":"facilities_engineer", "station":"plant", "base_priority":20, "deadline_ticks":1, "retry_backoff_ticks":1, "max_wait_ticks":2, "abandonment_action":"mobilize_qualified_relief"}]
		runtime.advance(reassign_state, reassign_candidates)
		runtime.advance(reassign_state, reassign_candidates)
		runtime.advance(reassign_state, reassign_candidates)
		var reassigned: Dictionary = runtime.record_continuity_decision(reassign_state, "reassign", true, {"mobilized_staff":["facilities_engineer-relief-1"]})
		_check(reassigned.get("status", "") == "waiting" and reassign_state["entries"]["reassign"]["reassignments"] == 1, "accepted qualified-relief mobilization did not create a fresh retry window")
		var shutdown_state: Dictionary = runtime.start_queue()
		var shutdown_candidates: Array[Dictionary] = [{"entry_id":"shutdown", "panel_id":"p:shutdown", "domain":"infrastructure", "action":"repair", "actor_job":"facilities_engineer", "station":"plant", "base_priority":20, "deadline_ticks":1, "retry_backoff_ticks":1, "max_wait_ticks":2, "abandonment_action":"mobilize_qualified_relief", "relief_failure_action":"mission_shutdown"}]
		runtime.advance(shutdown_state, shutdown_candidates); runtime.advance(shutdown_state, shutdown_candidates); runtime.advance(shutdown_state, shutdown_candidates)
		var shutdown: Dictionary = runtime.record_continuity_decision(shutdown_state, "shutdown", false, {"reason":"qualified relief unavailable"})
		_check(shutdown.get("status", "") == "mission_shutdown" and shutdown_state["continuity_decisions"].size() == 2, "failed relief did not produce a separate mission-shutdown command decision")
	print("=== facility_operations_queue_lifecycle_selftest done fails=%d ===" % fails)
	get_tree().quit(0 if fails == 0 else 1)
func _check(value: bool, message: String) -> void:
	if not value:
		fails += 1
		push_error("FAIL: %s" % message)
