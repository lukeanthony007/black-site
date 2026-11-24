class_name N64Geo
extends RefCounted
## Low-poly triangular primitives (Rare / GoldenEye language — not Roblox AABBs).


## Material for vertex-colored lofts — albedo multiplies the vertex color,
## so alert tints just swap albedo_color and keep the painted zones.
static func mat_vc(albedo: Color = Color.WHITE) -> StandardMaterial3D:
	var m := mat(albedo)
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	return m


static func mat(color: Color, tex: Texture2D = null) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.95
	m.metallic = 0.0
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	m.cull_mode = BaseMaterial3D.CULL_BACK
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	if tex:
		m.albedo_texture = tex
	return m


static func add_mesh(parent: Node, mesh: ArrayMesh, pos: Vector3, color: Color, part_name: String, is_uniform: bool, tex: Texture2D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = part_name
	mi.mesh = mesh
	# Textured parts must not tint: albedo multiplies the texture, and the face
	# texture already carries its color — a skin albedo would square it darker.
	mi.material_override = mat(Color.WHITE if tex else color, tex)
	mi.position = pos
	if is_uniform:
		mi.add_to_group("n64_uniform")
	parent.add_child(mi)
	return mi


## GE-style loft: stacked chamfered-box cross-sections skinned with smooth-
## shaded quads and vertex colors (pair with mat_vc). Sections run bottom→top,
## each a Dictionary:
##   y: ring height    w / d: full width / depth    x / z: ring center offset
##   color: ring color    back: optional color for all but the front facet
static func loft(sections: Array, chamfer: float = 0.55, smooth: bool = true) -> ArrayMesh:
	var pos := PackedVector3Array()
	var col := PackedColorArray()
	var idx := PackedInt32Array()
	for s: Dictionary in sections:
		var hw: float = s.w * 0.5
		var hd: float = s.d * 0.5
		var cx: float = s.get("x", 0.0)
		var cz: float = s.get("z", 0.0)
		var ring: Array = [
			Vector2(hw, hd * chamfer), Vector2(hw * chamfer, hd),
			Vector2(-hw * chamfer, hd), Vector2(-hw, hd * chamfer),
			Vector2(-hw, -hd * chamfer), Vector2(-hw * chamfer, -hd),
			Vector2(hw * chamfer, -hd), Vector2(hw, -hd * chamfer),
		]
		for k in 8:
			pos.append(Vector3(cx + ring[k].x, s.y, cz + ring[k].y))
			# verts 1 and 2 form the front facet; the rest may take the back color
			col.append(s.back if s.has("back") and k != 1 and k != 2 else s.color)
	for r in sections.size() - 1:
		var b := r * 8
		var t := b + 8
		for k in 8:
			var k1 := (k + 1) % 8
			idx.append_array(PackedInt32Array([b + k, b + k1, t + k1, b + k, t + k1, t + k]))
	# Smooth normals: accumulate outward face normals per shared vertex
	var nrm := PackedVector3Array()
	nrm.resize(pos.size())
	for i in range(0, idx.size(), 3):
		var n := (pos[idx[i + 2]] - pos[idx[i]]).cross(pos[idx[i + 1]] - pos[idx[i]])
		nrm[idx[i]] += n
		nrm[idx[i + 1]] += n
		nrm[idx[i + 2]] += n
	for i in nrm.size():
		nrm[i] = nrm[i].normalized()
	# Flat end caps with their own verts so the rim shading stays smooth
	for cap: Array in [[0, false], [sections.size() - 1, true]]:
		var s: Dictionary = sections[cap[0]]
		var base := pos.size()
		var ring_base: int = cap[0] * 8
		var c: Color = s.get("back", s.color)
		for k in 8:
			pos.append(pos[ring_base + k])
			col.append(c)
			nrm.append(Vector3(0, 1.0 if cap[1] else -1.0, 0))
		for k in range(1, 7):
			if cap[1]:
				idx.append_array(PackedInt32Array([base, base + k, base + k + 1]))
			else:
				idx.append_array(PackedInt32Array([base, base + k + 1, base + k]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	if smooth:
		arrays[Mesh.ARRAY_VERTEX] = pos
		arrays[Mesh.ARRAY_NORMAL] = nrm
		arrays[Mesh.ARRAY_COLOR] = col
		arrays[Mesh.ARRAY_INDEX] = idx
	else:
		# Hard facets: unshared verts with face normals, so each bevel lights
		# as its own plane (machined-metal look)
		var fpos := PackedVector3Array()
		var fnrm := PackedVector3Array()
		var fcol := PackedColorArray()
		for i in range(0, idx.size(), 3):
			var n := ((pos[idx[i + 2]] - pos[idx[i]]).cross(pos[idx[i + 1]] - pos[idx[i]])).normalized()
			for j in 3:
				fpos.append(pos[idx[i + j]])
				fnrm.append(n)
				fcol.append(col[idx[i + j]])
		arrays[Mesh.ARRAY_VERTEX] = fpos
		arrays[Mesh.ARRAY_NORMAL] = fnrm
		arrays[Mesh.ARRAY_COLOR] = fcol
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Tapered box — top face smaller than bottom (classic N64 limb/torso).
static func tapered_box(bottom: Vector2, top: Vector2, height: float) -> ArrayMesh:
	var y0 := -height * 0.5
	var y1 := height * 0.5
	var bx := bottom.x * 0.5
	var bz := bottom.y * 0.5
	var tx := top.x * 0.5
	var tz := top.y * 0.5
	# 0-3 bottom, 4-7 top
	var v: PackedVector3Array = PackedVector3Array([
		Vector3(-bx, y0, -bz), Vector3(bx, y0, -bz), Vector3(bx, y0, bz), Vector3(-bx, y0, bz),
		Vector3(-tx, y1, -tz), Vector3(tx, y1, -tz), Vector3(tx, y1, tz), Vector3(-tx, y1, tz),
	])
	var faces: Array = [
		[0, 1, 2, 3], # bottom
		[7, 6, 5, 4], # top
		[4, 5, 1, 0], # back
		[6, 7, 3, 2], # front
		[7, 4, 0, 3], # left
		[5, 6, 2, 1], # right
	]
	return _mesh_from_quads(v, faces)


## Triangular wedge (boot toe / shoulder).
static func wedge(width: float, height: float, depth: float) -> ArrayMesh:
	var w := width * 0.5
	var h := height * 0.5
	var d := depth
	# Prism pointing +Z
	var v: PackedVector3Array = PackedVector3Array([
		Vector3(-w, -h, 0), Vector3(w, -h, 0), Vector3(w, h, 0), Vector3(-w, h, 0), # back quad
		Vector3(0, -h * 0.3, d), Vector3(0, h * 0.3, d), # tip edge
	])
	var tris: Array = [
		[0, 2, 1], [0, 3, 2], # back
		[0, 1, 4], # bottom
		[3, 5, 2], # top
		[0, 5, 3], [0, 4, 5], # left
		[1, 5, 4], [1, 2, 5], # right
	]
	return _mesh_from_tris(v, tris)


## 6-sided tube — hexagonal limb (reads as tripoint, not a cube).
static func hex_limb(radius: float, height: float, taper: float = 1.0) -> ArrayMesh:
	var y0 := -height * 0.5
	var y1 := height * 0.5
	var r0 := radius
	var r1 := radius * taper
	var v: PackedVector3Array = PackedVector3Array()
	for i in 6:
		var a := TAU * float(i) / 6.0 + PI / 6.0
		v.append(Vector3(cos(a) * r0, y0, sin(a) * r0))
	for i in 6:
		var a := TAU * float(i) / 6.0 + PI / 6.0
		v.append(Vector3(cos(a) * r1, y1, sin(a) * r1))
	var tris: Array = []
	# sides
	for i in 6:
		var n := (i + 1) % 6
		tris.append([i, n + 6, n])
		tris.append([i, i + 6, n + 6])
	# caps (fan)
	for i in range(1, 5):
		tris.append([0, i, i + 1])
		tris.append([6, 6 + i + 1, 6 + i])
	return _mesh_from_tris(v, tris)


## Rare-style diamond / wedge head — flat face plane in front.
static func diamond_head(w: float, h: float, d: float) -> ArrayMesh:
	var hw := w * 0.5
	var hh := h * 0.5
	var hd := d * 0.5
	# Vertices: crown, chin, L/R temples, back, face-center front
	var v: PackedVector3Array = PackedVector3Array([
		Vector3(0, hh, 0),           # 0 crown
		Vector3(0, -hh, 0.05),       # 1 chin
		Vector3(-hw, 0.05, 0),       # 2 left
		Vector3(hw, 0.05, 0),        # 3 right
		Vector3(0, 0.05, -hd),       # 4 back
		Vector3(-hw * 0.55, 0.08, hd * 0.85), # 5 face L
		Vector3(hw * 0.55, 0.08, hd * 0.85),  # 6 face R
		Vector3(0, -hh * 0.35, hd * 0.9),     # 7 face chin
		Vector3(0, hh * 0.55, hd * 0.7),      # 8 brow
	])
	var tris: Array = [
		# back / sides
		[0, 2, 4], [0, 4, 3], [1, 4, 2], [1, 3, 4],
		[0, 3, 6], [0, 6, 8], [0, 8, 5], [0, 5, 2],
		[1, 2, 5], [1, 5, 7], [1, 7, 6], [1, 6, 3],
		# face card (two tris) — UV mapped later via same verts
		[8, 6, 7], [8, 7, 5],
	]
	return _mesh_from_tris(v, tris)


## Flat face card quad for texture (parented on head front).
static func face_card(width: float, height: float) -> ArrayMesh:
	var w := width * 0.5
	var h := height * 0.5
	var v: PackedVector3Array = PackedVector3Array([
		Vector3(-w, -h, 0), Vector3(w, -h, 0), Vector3(w, h, 0), Vector3(-w, h, 0),
	])
	var uvs: PackedVector2Array = PackedVector2Array([
		Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0),
	])
	var tris: Array = [[0, 1, 2], [0, 2, 3]]
	return _mesh_from_tris(v, tris, uvs)


static func _mesh_from_quads(verts: PackedVector3Array, quads: Array) -> ArrayMesh:
	var tris: Array = []
	for q in quads:
		tris.append([q[0], q[1], q[2]])
		tris.append([q[0], q[2], q[3]])
	return _mesh_from_tris(verts, tris)


static func _mesh_from_tris(verts: PackedVector3Array, tris: Array, uvs: PackedVector2Array = PackedVector2Array()) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var has_uv := uvs.size() == verts.size()
	for tri in tris:
		var a: Vector3 = verts[tri[0]]
		var b: Vector3 = verts[tri[1]]
		var c: Vector3 = verts[tri[2]]
		var n: Vector3 = (b - a).cross(c - a).normalized()
		if n.length() < 0.001:
			n = Vector3.UP
		# Godot front faces are CLOCKWISE — emit reversed so outward normals face out
		for idx in [tri[0], tri[2], tri[1]]:
			st.set_normal(n)
			if has_uv:
				st.set_uv(uvs[idx])
			else:
				# Planar-ish UV from position so vertex lighting still reads facets
				st.set_uv(Vector2(verts[idx].x * 2.0 + 0.5, -verts[idx].y * 2.0 + 0.5))
			st.add_vertex(verts[idx])
	st.generate_normals()
	return st.commit()
