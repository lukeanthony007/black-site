extends Node
var fails := 0
func _ready() -> void:
	var script: Script=load("res://scripts/facility/facility_control_network_runtime.gd")
	_check(script != null and script.can_instantiate(),"control-network runtime missing")
	if script:
		var runtime=script.new(); var state: Dictionary=runtime.start_state()
		var compromised: Dictionary=runtime.declare_compromise(state,"control-network:1","ids-7")
		_check(compromised.get("accepted",false) and state["posture"]=="isolated","compromise did not isolate automation")
		_check(runtime.validate_state(state).get("accepted",false),"valid isolated control-network state rejected")
		var forged: Dictionary=state.duplicate(true); forged["active_incident"]["occurrence_id"]="control-network:forged"
		_check(not runtime.validate_state(forged).get("accepted",true),"control-network incident/history disagreement accepted")
		_check(not runtime.authorize_control(state,"remote_automation","duty-1","cyber_ops").get("accepted",true),"isolated network admitted remote automation")
		_check(runtime.authorize_control(state,"hardwired_local","guard-1","security_control").get("accepted",false),"isolated network rejected hardwired local control")
		_check(not runtime.reconstitute(state,"control-network:1","ids-7",true).get("accepted",true),"incident owner self-approved reconstitution")
		_check(runtime.record_functional_test(state,"control-network:1","network-tech-2",true).get("accepted",false),"independent functional test rejected")
		_check(state["history"][-1].get("kind","")=="functional_test_passed" and state["history"][-1].get("actor","")=="network-tech-2","functional test lacked immutable history evidence")
		_check(runtime.validate_state(state).get("accepted",false),"valid tested control-network state rejected")
		var forged_test: Dictionary=state.duplicate(true); forged_test["functional_test"]["occurrence_id"]="control-network:forged-test"
		_check(not runtime.validate_state(forged_test).get("accepted",true),"cross-occurrence functional test provenance accepted")
		_check(runtime.reconstitute(state,"control-network:1","duty-1",true).get("accepted",false) and state["posture"]=="normal","independent reconstitution rejected")
		_check(runtime.validate_state(state).get("accepted",false),"valid reconstituted control-network state rejected")
		var missing_test_event: Dictionary=state.duplicate(true); missing_test_event["history"].remove_at(1)
		_check(not runtime.validate_state(missing_test_event).get("accepted",true),"reconstituted state accepted without functional-test history")
		_check(runtime.declare_compromise(state,"control-network:2","ids-8").get("accepted",false) and state["functional_test"].is_empty(),"second compromise retained prior test authority")
		_check(runtime.validate_state(state).get("accepted",false),"second isolated occurrence was not recoverable")
		_check(runtime.record_functional_test(state,"control-network:2","network-tech-3",true).get("accepted",false),"second occurrence functional test rejected")
		_check(runtime.reconstitute(state,"control-network:2","duty-2",true).get("accepted",false) and runtime.validate_state(state).get("accepted",false) and state["history"].size()==6,"second lifecycle mixed or lost historical evidence")
	print("=== facility_control_network_selftest done fails=%d ===" % fails); get_tree().quit(0 if fails==0 else 1)
func _check(v: bool,m: String)->void:
	if not v: fails+=1; push_error("FAIL: %s"%m)
