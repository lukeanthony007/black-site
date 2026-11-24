class_name N64Look
extends RefCounted
## Flat nearest-filter materials. World props are lit; emissives still pop.


static func mat(color: Color, emit: float = 0.0, alpha: float = 1.0, lit: bool = true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	m.metallic = 0.0
	m.roughness = 0.92
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	# Vertex lighting keeps the N64 faceted read while reacting to lamps
	m.shading_mode = (
		BaseMaterial3D.SHADING_MODE_PER_VERTEX if lit
		else BaseMaterial3D.SHADING_MODE_UNSHADED
	)
	if alpha < 0.99:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emit
	return m


static func box(parent: Node, pos: Vector3, size: Vector3, color: Color, part_name: String = "Part", emit: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = part_name
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat(color, emit)
	mi.position = pos
	parent.add_child(mi)
	return mi


static func cyl(parent: Node, pos: Vector3, radius: float, height: float, color: Color, part_name: String = "Cyl", emit: float = 0.0, segments: int = 6) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = part_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	mi.mesh = mesh
	mi.material_override = mat(color, emit)
	mi.position = pos
	parent.add_child(mi)
	return mi
