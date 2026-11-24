extends Node3D
## Playable Vine Street canyon.
## Continuous road collider (so you can move) + N64 façade blocks set back
## from a clear channel. OSM Vine centerline is the spine only.

const DATA_DIR := "res://data/otr/vine_main"

const ASPHALT := Color(0.11, 0.11, 0.13)
const SIDEWALK := Color(0.62, 0.60, 0.55)
const LINE := Color(0.85, 0.82, 0.55)
const GROUND := Color(0.22, 0.24, 0.20)
const WINDOW := Color(0.15, 0.18, 0.22)
const DOOR := Color(0.12, 0.10, 0.09)
const OBJ_TECH := Color(0.25, 0.55, 0.95)

const BRICK := [
	Color(0.55, 0.30, 0.26),
	Color(0.48, 0.28, 0.24),
	Color(0.60, 0.36, 0.28),
	Color(0.42, 0.34, 0.32),
	Color(0.68, 0.64, 0.56),
]

@export var data_dir: String = DATA_DIR
@export var spawn_player: bool = false
@export var road_width: float = 12.0
@export var sidewalk_width: float = 3.0
@export var bay_width: float = 7.5
@export var building_depth: float = 10.0
@export var corridor_half_length: float = 120.0
## Clear half-width with NO building collision (road + sidewalks).
@export var clear_half_width: float = 9.5

var spawn_position: Vector3 = Vector3.ZERO
var spawn_yaw_deg: float = 0.0
var _ground_y: float = 0.0
var _vine_poly: PackedVector2Array = PackedVector2Array()


func _ready() -> void:
	_build_corridor()
	_spawn_entities()


func _load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("OTR missing: %s" % path)
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	return JSON.parse_string(f.get_as_text())


func _build_corridor() -> void:
	var streets: Array = _load_json("%s/streets.json" % data_dir)
	var entities: Dictionary = _load_json("%s/entities.json" % data_dir)
	if streets == null:
		return

	var spawn: Dictionary = entities.get("spawn", {}) if entities != null else {}
	var focus := Vector2(float(spawn.get("x", 0.0)), float(spawn.get("z", 0.0)))
	_ground_y = 0.0

	_vine_poly = _build_vine_polyline(streets, focus)
	if _vine_poly.size() < 2:
		push_error("OTR: no Vine Street centerline")
		return

	var root := Node3D.new()
	root.name = "VineStreet"
	add_child(root)

	# Soft ground outside the canyon (visual only at edges).
	_box(root, Vector3(focus.x, _ground_y - 0.4, focus.y), Vector3(280, 0.6, 280), GROUND, Vector2(1, 0), Vector2(0, 1), false)

	# Walkable street: overlapping collision boxes (reliable) + visuals.
	_build_walkable_street(root, _vine_poly)
	_build_rowhouses(root, _vine_poly, -1.0)
	_build_rowhouses(root, _vine_poly, 1.0)

	print("OTR Vine canyon ready — clear channel ±%.1fm, %d spine pts" % [clear_half_width, _vine_poly.size()])


func _build_vine_polyline(streets: Array, focus: Vector2) -> PackedVector2Array:
	var segs: Array = []
	for s in streets:
		if "vine" not in String(s.get("name", "")).to_lower():
			continue
		var line: Array = s.get("centerline", [])
		for i in line.size() - 1:
			var a := Vector2(line[i][0], line[i][1])
			var b := Vector2(line[i + 1][0], line[i + 1][1])
			if a.distance_to(b) >= 0.5:
				segs.append([a, b])
	if segs.is_empty():
		return PackedVector2Array()

	var best_i := 0
	var best_d := 1.0e12
	for i in segs.size():
		var mid: Vector2 = (segs[i][0] + segs[i][1]) * 0.5
		var d := mid.distance_squared_to(focus)
		if d < best_d:
			best_d = d
			best_i = i

	var path: Array = [segs[best_i][0], segs[best_i][1]]
	var used := {best_i: true}
	var grew := true
	while grew:
		grew = false
		var head: Vector2 = path[0]
		var tail: Vector2 = path[path.size() - 1]
		for i in segs.size():
			if used.has(i):
				continue
			var a: Vector2 = segs[i][0]
			var b: Vector2 = segs[i][1]
			if a.distance_to(tail) < 4.0:
				path.append(b)
				used[i] = true
				grew = true
			elif b.distance_to(tail) < 4.0:
				path.append(a)
				used[i] = true
				grew = true
			elif a.distance_to(head) < 4.0:
				path.insert(0, b)
				used[i] = true
				grew = true
			elif b.distance_to(head) < 4.0:
				path.insert(0, a)
				used[i] = true
				grew = true

	return _clip_path_around(_densify_path(path, 3.5), focus, corridor_half_length)


func _densify_path(path: Array, step: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	if path.is_empty():
		return out
	out.append(path[0])
	for i in path.size() - 1:
		var a: Vector2 = path[i]
		var b: Vector2 = path[i + 1]
		var n := maxi(1, int(a.distance_to(b) / step))
		for k in range(1, n + 1):
			out.append(a.lerp(b, float(k) / float(n)))
	return out


func _clip_path_around(path: PackedVector2Array, focus: Vector2, half_len: float) -> PackedVector2Array:
	var nearest_i := 0
	var best_d := 1.0e12
	for i in path.size():
		var d := path[i].distance_squared_to(focus)
		if d < best_d:
			best_d = d
			nearest_i = i
	var start_i := nearest_i
	var acc := 0.0
	while start_i > 0 and acc < half_len:
		acc += path[start_i].distance_to(path[start_i - 1])
		start_i -= 1
	var end_i := nearest_i
	acc = 0.0
	while end_i < path.size() - 1 and acc < half_len:
		acc += path[end_i].distance_to(path[end_i + 1])
		end_i += 1
	var out := PackedVector2Array()
	for i in range(start_i, end_i + 1):
		out.append(path[i])
	return out


func _frame_at(path: PackedVector2Array, i: int) -> Dictionary:
	var p := path[i]
	var tangent := Vector2(0, -1)
	if i < path.size() - 1:
		tangent = path[i + 1] - p
	elif i > 0:
		tangent = p - path[i - 1]
	if tangent.length_squared() < 0.0001:
		tangent = Vector2(0, -1)
	else:
		tangent = tangent.normalized()
	return {"p": p, "t": tangent, "n": Vector2(-tangent.y, tangent.x)}


func _build_walkable_street(parent: Node3D, path: PackedVector2Array) -> void:
	## Thick overlapping floor boxes — collision you can actually walk on.
	var total_w := clear_half_width * 2.0
	for i in path.size() - 1:
		var a := path[i]
		var b := path[i + 1]
		var mid := (a + b) * 0.5
		var t := (b - a)
		var length := t.length()
		if length < 0.2:
			continue
		t /= length
		length += 1.0  # overlap so no seams
		var n := Vector2(-t.y, t.x)
		# Asphalt (collider)
		_box(
			parent,
			Vector3(mid.x, _ground_y, mid.y),
			Vector3(length, 0.4, road_width),
			ASPHALT,
			t,
			n,
			true
		)
		# Sidewalks (collider) — outside asphalt, still inside clear channel
		var sw_center_off := road_width * 0.5 + sidewalk_width * 0.5
		for side in [-1.0, 1.0]:
			var c2: Vector2 = mid + n * sw_center_off * side
			_box(
				parent,
				Vector3(c2.x, _ground_y + 0.05, c2.y),
				Vector3(length, 0.35, sidewalk_width),
				SIDEWALK,
				t,
				n,
				true
			)
		# Center line (visual only)
		_box(
			parent,
			Vector3(mid.x, _ground_y + 0.22, mid.y),
			Vector3(length * 0.55, 0.02, 0.18),
			LINE,
			t,
			n,
			false
		)


func _build_rowhouses(parent: Node3D, path: PackedVector2Array, side: float) -> void:
	## Façade face sits just outside the clear channel so the street stays walkable.
	var face_dist := clear_half_width + 0.15
	var i := 0
	while i < path.size() - 1:
		var f := _frame_at(path, i)
		var p: Vector2 = f.p
		var t: Vector2 = f.t
		var n: Vector2 = f.n * side
		var face2 := p + n * face_dist
		var center2 := face2 + n * (building_depth * 0.5)
		var h := _bay_height(center2)
		var col: Color = BRICK[_bay_variant(center2) % BRICK.size()]
		var w := bay_width

		# Main mass — collision on (outside clear channel)
		_box(
			parent,
			Vector3(center2.x, _ground_y + h * 0.5, center2.y),
			Vector3(w + 0.15, h, building_depth),
			col,
			t,
			n,
			true
		)
		# Roof
		_box(
			parent,
			Vector3(center2.x, _ground_y + h + 0.12, center2.y),
			Vector3(w + 0.45, 0.25, building_depth + 0.35),
			col.darkened(0.25),
			t,
			n,
			false
		)
		# Ground-floor storefront recess (visual)
		_box(
			parent,
			Vector3(face2.x + n.x * 0.15, _ground_y + 1.4, face2.y + n.y * 0.15),
			Vector3(w * 0.7, 2.6, 0.35),
			col.lightened(0.1),
			t,
			n,
			false
		)
		# Door
		_box(
			parent,
			Vector3(face2.x + n.x * 0.05, _ground_y + 1.05, face2.y + n.y * 0.05),
			Vector3(1.1, 2.1, 0.2),
			DOOR,
			t,
			n,
			false
		)
		# Window row
		for wi in 3:
			var ox := (float(wi) - 1.0) * (w * 0.28)
			var wp := face2 + t * ox + n * 0.08
			_box(
				parent,
				Vector3(wp.x, _ground_y + 5.2, wp.y),
				Vector3(1.4, 1.6, 0.18),
				WINDOW,
				t,
				n,
				false
			)

		# Advance ~ one bay along the spine
		var need := w * 0.95
		while need > 0.0 and i < path.size() - 1:
			var step_len := path[i].distance_to(path[i + 1])
			if step_len <= 0.001:
				i += 1
				continue
			if step_len >= need:
				need = 0.0
				i += 1
			else:
				need -= step_len
				i += 1


func _bay_height(p: Vector2) -> float:
	return [8.5, 9.5, 10.5, 11.5, 12.0][int(absf(p.x * 17.0 + p.y * 31.0)) % 5]


func _bay_variant(p: Vector2) -> int:
	return int(absf(p.x * 13.0 + p.y * 7.0)) % 97


func _box(
	parent: Node,
	pos: Vector3,
	size: Vector3,
	color: Color,
	along: Vector2,
	into: Vector2,
	with_collision: bool
) -> void:
	var body := StaticBody3D.new()
	if with_collision:
		body.collision_layer = 1
	else:
		body.collision_layer = 0
	body.collision_mask = 0
	var ax := Vector3(along.x, 0.0, along.y)
	if ax.length_squared() < 0.0001:
		ax = Vector3(1, 0, 0)
	ax = ax.normalized()
	var into3 := Vector3(into.x, 0.0, into.y)
	if into3.length_squared() < 0.0001:
		into3 = Vector3(0, 0, 1)
	# Orthonormal Y-up: X along street, Z into lot / across road.
	var az := ax.cross(Vector3.UP).normalized()
	if az.dot(into3) < 0.0:
		az = -az
	var ay := az.cross(ax).normalized()
	body.transform = Transform3D(Basis(ax, ay, az), pos)

	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = N64Look.mat(color)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(mi)

	if with_collision:
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		col.shape = shape
		body.add_child(col)
	parent.add_child(body)


func _spawn_entities() -> void:
	if _vine_poly.size() < 2:
		return
	var mid_i := _vine_poly.size() / 2
	var f := _frame_at(_vine_poly, mid_i)
	var p: Vector2 = f.p
	var t: Vector2 = f.t
	var n: Vector2 = f.n

	# Center of road, feet on asphalt top (box top at ground_y + 0.2).
	spawn_position = Vector3(p.x, _ground_y + 0.45 + 0.9, p.y)
	spawn_yaw_deg = rad_to_deg(atan2(-t.x, -t.y))

	if spawn_player:
		call_deferred("_place_player")

	# Dead drop clearly on sidewalk, not in a wall.
	var drop := p + n * (road_width * 0.5 + sidewalk_width * 0.5)
	_spawn_objective(drop)

	var ex_i := mini(mid_i + 20, _vine_poly.size() - 1)
	var ex := _vine_poly[ex_i]
	var zone := Area3D.new()
	zone.name = "ExtractZone"
	zone.position = Vector3(ex.x, _ground_y + 1.0, ex.y)
	zone.set_script(load("res://scripts/world/extract_zone.gd"))
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(5, 3, 5)
	col.shape = shape
	zone.add_child(col)
	add_child(zone)
	N64Look.cyl(zone, Vector3.ZERO, 1.6, 0.05, Color(0.2, 0.9, 0.35, 0.6), "Glow", 1.2, 12)

	var guard_scene: PackedScene = load("res://scenes/guard.tscn")
	var points := PackedVector3Array()
	for i in range(maxi(0, mid_i - 6), mini(_vine_poly.size(), mid_i + 14), 2):
		var gp := _vine_poly[i]
		points.append(Vector3(gp.x, _ground_y + 1.1, gp.y))
	if points.size() >= 2:
		var guard: Node3D = guard_scene.instantiate()
		guard.position = points[0]
		guard.set("patrol_points", points)
		add_child(guard)


func _place_player() -> void:
	var player := get_parent().get_node_or_null("Player")
	if player == null:
		return
	# Lift then settle so we never spawn inside floor volume.
	player.global_position = spawn_position + Vector3(0, 0.5, 0)
	player.rotation_degrees = Vector3(0, spawn_yaw_deg, 0)
	if player is CharacterBody3D:
		var body := player as CharacterBody3D
		body.velocity = Vector3.ZERO
		body.floor_snap_length = 0.4
	if player.has_method("set_checkpoint"):
		var xform: Transform3D = Transform3D(Basis.from_euler(Vector3(0, deg_to_rad(spawn_yaw_deg), 0)), spawn_position)
		player.set_checkpoint(xform)
	# Second settle after physics exists
	await get_tree().physics_frame
	if is_instance_valid(player):
		player.global_position = spawn_position
		if player is CharacterBody3D:
			(player as CharacterBody3D).velocity = Vector3.ZERO
	print("OTR spawn OK ", spawn_position, " yaw=", spawn_yaw_deg)


func _spawn_objective(drop: Vector2) -> void:
	var body := StaticBody3D.new()
	body.position = Vector3(drop.x, _ground_y + 0.95, drop.y)
	body.collision_layer = 1
	body.set_script(load("res://scripts/world/objective_prop.gd"))
	body.set("objective_id", "scout")
	body.set("prompt_text", "Hold E — mark dead drop")
	body.set("done_text", "Dead drop marked")
	var mi := MeshInstance3D.new()
	mi.name = "MeshInstance3D"
	var box := BoxMesh.new()
	box.size = Vector3(0.9, 1.4, 0.9)
	mi.mesh = box
	mi.material_override = N64Look.mat(OBJ_TECH, 1.2)
	body.add_child(mi)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.9, 1.4, 0.9)
	col.shape = shape
	body.add_child(col)
	var area := Area3D.new()
	area.name = "Area3D"
	area.collision_layer = 0
	area.collision_mask = 2
	var area_col := CollisionShape3D.new()
	var area_shape := SphereShape3D.new()
	area_shape.radius = 2.2
	area_col.shape = area_shape
	area.add_child(area_col)
	body.add_child(area)
	add_child(body)
