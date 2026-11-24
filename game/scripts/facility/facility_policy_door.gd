class_name FacilityPolicyDoor
extends StaticBody3D
## Runtime policy boundary compiled from an authoritative typed route.

signal navigation_state_changed(door: Node, open: bool)

var door_mode: String = "open_internal"
var required_clearance_tier: int = 0
var is_open: bool = false
var required_roles: Array[String] = []


func _ready() -> void:
	add_to_group("facility_policy_doors")


func configure(route_item: Dictionary, clearance_tier: int, destination_roles: Array[String] = []) -> void:
	door_mode = route_item["door_mode"]
	required_clearance_tier = clearance_tier
	required_roles = destination_roles.duplicate()
	set_meta("route_id", route_item["id"])
	set_meta("from_room", route_item["from"])
	set_meta("to_room", route_item["to"])
	set_meta("flow", route_item["flow"])
	set_meta("door_mode", door_mode)
	set_meta("ordinary_access", route_item["ordinary_access"])
	set_meta("emergency_only", route_item["emergency_only"])
	set_meta("required_clearance_tier", required_clearance_tier)
	set_meta("required_roles", required_roles.duplicate())


func request_open(credentials: Dictionary, emergency_mode: bool = false) -> bool:
	var allowed := false
	match door_mode:
		"open_internal":
			allowed = true
		"alarmed_emergency_egress":
			allowed = emergency_mode
		"credentialed_interlock":
			allowed = (
				int(credentials.get("clearance_tier", -1)) >= required_clearance_tier
				and (_has_required_role(credentials) or _has_role(credentials, "security_officer"))
			)
		"custody_transfer_interlock":
			allowed = _has_required_role(credentials)
		"evidence_transfer_interlock":
			allowed = _has_required_role(credentials)
		"authorized_service":
			allowed = _has_role(credentials, "facilities_engineer") or _has_role(credentials, "systems_administrator")
	if allowed:
		_set_open(true)
	return allowed


func close_door() -> void:
	_set_open(false)


func is_navigation_open() -> bool:
	return is_open


func interact(player: Node) -> void:
	var facility_owner: Node = get_parent()
	while facility_owner != null:
		if facility_owner.has_method("handle_policy_door_interact"):
			facility_owner.handle_policy_door_interact(self, player)
			return
		facility_owner = facility_owner.get_parent()
	var clearance_tier := 0
	if "keycard_tier" in player:
		clearance_tier = int(player.keycard_tier)
	elif "has_keycard" in player and bool(player.has_keycard):
		clearance_tier = 1
	var credentials := {
		"clearance_tier": clearance_tier,
		"roles": player.get_meta("facility_roles", []),
	}
	var emergency_mode: bool = bool(player.get_meta("facility_emergency_mode", false))
	if request_open(credentials, emergency_mode):
		ObjectiveTracker.set_prompt("Access granted — %s" % door_mode.replace("_", " "))
	else:
		ObjectiveTracker.set_prompt("Access denied — %s" % door_mode.replace("_", " "))


func _set_open(value: bool) -> void:
	if is_open == value:
		return
	is_open = value
	var collision := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision != null:
		collision.set_deferred("disabled", value)
	var marker := get_node_or_null("Marker") as MeshInstance3D
	if marker != null:
		if not has_meta("leaf_closed_x"):
			set_meta("leaf_closed_x", marker.position.x)
			set_meta("leaf_closed_rot_y", marker.rotation.y)
		marker.visible = true
		if value:
			# Swing the leaf aside so the doorway is visibly open, not a teleport.
			marker.position.x = float(get_meta("leaf_closed_x")) + 0.95
			marker.rotation.y = float(get_meta("leaf_closed_rot_y")) - PI * 0.55
		else:
			marker.position.x = float(get_meta("leaf_closed_x"))
			marker.rotation.y = float(get_meta("leaf_closed_rot_y"))
	navigation_state_changed.emit(self, is_open)


func _has_required_role(credentials: Dictionary) -> bool:
	var roles: Array = credentials.get("roles", [])
	for required_role in required_roles:
		if roles.has(required_role):
			return true
	return false


func _has_role(credentials: Dictionary, role: String) -> bool:
	var roles: Array = credentials.get("roles", [])
	return roles.has(role)
