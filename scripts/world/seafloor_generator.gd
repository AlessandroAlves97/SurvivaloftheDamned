extends StaticBody3D

const SEAFLOOR_SHADER := preload("res://shaders/seafloor.gdshader")
const KELP_SHADER := preload("res://shaders/kelp.gdshader")

@export var terrain_size: float = 260.0
@export var terrain_subdivisions: int = 110

## Definição das 4 cavernas submarinas exploráveis ao redor da área inicial
const CAVE_DEFINITIONS: Array[Dictionary] = [
	{
		"name": "Gruta do Recife Luminoso",
		"pos": Vector2(-18.0, -20.0),
		"yaw_deg": 42.0,
		"length": 15.0,
		"width": 6.4,
		"height": 5.2,
		"floor_y": -21.5,
		"glow_color": Color(0.15, 0.92, 0.85),
		"crystal_color": Color(0.20, 0.98, 0.90)
	},
	{
		"name": "Caverna Abissal Cristalina",
		"pos": Vector2(25.0, -16.0),
		"yaw_deg": -50.0,
		"length": 17.5,
		"width": 6.8,
		"height": 5.6,
		"floor_y": -24.5,
		"glow_color": Color(0.68, 0.28, 0.98),
		"crystal_color": Color(0.78, 0.42, 1.0)
	},
	{
		"name": "Túnel Submerso das Algas",
		"pos": Vector2(14.0, 22.0),
		"yaw_deg": 145.0,
		"length": 16.0,
		"width": 6.2,
		"height": 5.0,
		"floor_y": -20.0,
		"glow_color": Color(0.25, 0.95, 0.55),
		"crystal_color": Color(0.35, 1.0, 0.65)
	},
	{
		"name": "Santuário das Anêmonas",
		"pos": Vector2(-26.0, 18.0),
		"yaw_deg": -125.0,
		"length": 15.5,
		"width": 6.6,
		"height": 5.4,
		"floor_y": -22.5,
		"glow_color": Color(1.0, 0.52, 0.22),
		"crystal_color": Color(1.0, 0.65, 0.30)
	}
]

var _rock_mat: StandardMaterial3D
var _dark_cave_mat: StandardMaterial3D
var _kelp_mat: ShaderMaterial
var _seagrass_mat: ShaderMaterial


func _ready() -> void:
	add_to_group("seafloor")
	# Posiciona o nó SeaFloor na origem global (y = 0) para que as alturas reais sejam diretas
	global_position = Vector3.ZERO
	_init_shared_materials()
	_clear_legacy_children()
	_generate_terrain_mesh_and_collision()
	_build_all_caves_and_arches()
	_populate_vegetation_and_corals()


func _init_shared_materials() -> void:
	_rock_mat = StandardMaterial3D.new()
	_rock_mat.albedo_color = Color(0.22, 0.26, 0.29)
	_rock_mat.roughness = 0.90

	_dark_cave_mat = StandardMaterial3D.new()
	_dark_cave_mat.albedo_color = Color(0.15, 0.19, 0.22)
	_dark_cave_mat.roughness = 0.94

	_kelp_mat = ShaderMaterial.new()
	_kelp_mat.shader = KELP_SHADER
	_kelp_mat.set_shader_parameter("base_color", Color(0.07, 0.32, 0.18))
	_kelp_mat.set_shader_parameter("tip_color", Color(0.26, 0.64, 0.30))
	_kelp_mat.set_shader_parameter("sway_speed", 1.55)
	_kelp_mat.set_shader_parameter("sway_strength", 0.32)
	_kelp_mat.set_shader_parameter("plant_height", 5.5)

	_seagrass_mat = ShaderMaterial.new()
	_seagrass_mat.shader = KELP_SHADER
	_seagrass_mat.set_shader_parameter("base_color", Color(0.10, 0.38, 0.22))
	_seagrass_mat.set_shader_parameter("tip_color", Color(0.32, 0.72, 0.38))
	_seagrass_mat.set_shader_parameter("sway_speed", 1.9)
	_seagrass_mat.set_shader_parameter("sway_strength", 0.16)
	_seagrass_mat.set_shader_parameter("plant_height", 1.2)


func _clear_legacy_children() -> void:
	for child in get_children():
		child.queue_free()


## Função matemática determinística da altura do relevo submarino em (x, z)
func get_seafloor_height(x: float, z: float) -> float:
	# Relevo orgânico em múltiplas escalas (colinas, recifes, vales e trincheiras)
	var hills: float = sin(x * 0.042) * cos(z * 0.038) * 4.2
	var ridges: float = sin((x * 0.075 - z * 0.065) + 1.2) * 2.6
	var dunes: float = cos(x * 0.16 + sin(z * 0.14) * 1.8) * 1.15
	var micro: float = sin(x * 0.35 + z * 0.31) * 0.38

	# Elevação central suave perto do naufrágio com vales ao redor
	var dist_center: float = Vector2(x, z).length()
	var reef_ring: float = exp(-pow((dist_center - 28.0) / 16.0, 2.0)) * 3.2
	var deep_trench: float = -exp(-pow((x - z * 0.7 - 36.0) / 14.0, 2.0)) * 6.5

	var h: float = -21.0 + hills + ridges + dunes + micro + reef_ring + deep_trench

	# Nivela suavemente o piso onde as cavernas submarinas estão assentadas
	var p := Vector2(x, z)
	for cave: Dictionary in CAVE_DEFINITIONS:
		var c_pos: Vector2 = cave["pos"]
		var c_radius: float = float(cave["length"]) * 0.65
		var d: float = p.distance_to(c_pos)
		if d < c_radius * 1.4:
			var weight: float = 1.0 - smoothstep(c_radius * 0.45, c_radius * 1.4, d)
			h = lerpf(h, float(cave["floor_y"]), weight)

	return clampf(h, -34.0, -7.5)


func _generate_terrain_mesh_and_collision() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var step: float = terrain_size / float(terrain_subdivisions)
	var half: float = terrain_size * 0.5

	var heights: PackedFloat32Array = PackedFloat32Array()
	heights.resize((terrain_subdivisions + 1) * (terrain_subdivisions + 1))

	for iz in range(terrain_subdivisions + 1):
		var wz: float = -half + float(iz) * step
		for ix in range(terrain_subdivisions + 1):
			var wx: float = -half + float(ix) * step
			heights[iz * (terrain_subdivisions + 1) + ix] = get_seafloor_height(wx, wz)

	for iz in range(terrain_subdivisions):
		var z0: float = -half + float(iz) * step
		var z1: float = z0 + step
		for ix in range(terrain_subdivisions):
			var x0: float = -half + float(ix) * step
			var x1: float = x0 + step

			var h00: float = heights[iz * (terrain_subdivisions + 1) + ix]
			var h10: float = heights[iz * (terrain_subdivisions + 1) + (ix + 1)]
			var h01: float = heights[(iz + 1) * (terrain_subdivisions + 1) + ix]
			var h11: float = heights[(iz + 1) * (terrain_subdivisions + 1) + (ix + 1)]

			var v00 := Vector3(x0, h00, z0)
			var v10 := Vector3(x1, h10, z0)
			var v01 := Vector3(x0, h01, z1)
			var v11 := Vector3(x1, h11, z1)

			st.set_uv(Vector2(float(ix) / terrain_subdivisions, float(iz) / terrain_subdivisions))
			st.add_vertex(v00)
			st.set_uv(Vector2(float(ix + 1) / terrain_subdivisions, float(iz) / terrain_subdivisions))
			st.add_vertex(v10)
			st.set_uv(Vector2(float(ix) / terrain_subdivisions, float(iz + 1) / terrain_subdivisions))
			st.add_vertex(v01)

			st.set_uv(Vector2(float(ix + 1) / terrain_subdivisions, float(iz) / terrain_subdivisions))
			st.add_vertex(v10)
			st.set_uv(Vector2(float(ix + 1) / terrain_subdivisions, float(iz + 1) / terrain_subdivisions))
			st.add_vertex(v11)
			st.set_uv(Vector2(float(ix) / terrain_subdivisions, float(iz + 1) / terrain_subdivisions))
			st.add_vertex(v01)

	st.generate_normals()
	var array_mesh: ArrayMesh = st.commit()

	var shader_mat := ShaderMaterial.new()
	shader_mat.shader = SEAFLOOR_SHADER

	var terrain_mesh_inst := MeshInstance3D.new()
	terrain_mesh_inst.name = "SculptedSeaFloorMesh"
	terrain_mesh_inst.mesh = array_mesh
	terrain_mesh_inst.material_override = shader_mat
	add_child(terrain_mesh_inst)

	var trimesh_shape: ConcavePolygonShape3D = array_mesh.create_trimesh_shape()
	var terrain_col := CollisionShape3D.new()
	terrain_col.name = "SculptedSeaFloorCollision"
	terrain_col.shape = trimesh_shape
	add_child(terrain_col)

	# Plano de segurança infinito abaixo da região esculpida
	var boundary_col := CollisionShape3D.new()
	boundary_col.name = "AbyssSafetyBoundary"
	boundary_col.position = Vector3(0.0, -35.0, 0.0)
	var wb := WorldBoundaryShape3D.new()
	boundary_col.shape = wb
	add_child(boundary_col)


func _build_all_caves_and_arches() -> void:
	var caves_container := Node3D.new()
	caves_container.name = "UnderwaterCaves"
	add_child(caves_container)

	for cave_def: Dictionary in CAVE_DEFINITIONS:
		_build_explorable_cave(caves_container, cave_def)

	# Adiciona arcos rochosos naturais onde o jogador pode nadar por baixo
	_build_natural_arch(caves_container, Vector3(-8.0, get_seafloor_height(-8.0, 12.0), 12.0), 25.0, 8.5, 6.5)
	_build_natural_arch(caves_container, Vector3(16.0, get_seafloor_height(16.0, -4.0), -4.0), -65.0, 9.5, 7.2)


func _build_explorable_cave(parent: Node3D, cave_def: Dictionary) -> void:
	var cave_root := Node3D.new()
	cave_root.name = str(cave_def["name"]).validate_node_name()
	var pos2d: Vector2 = cave_def["pos"]
	var floor_y: float = float(cave_def["floor_y"])
	cave_root.position = Vector3(pos2d.x, floor_y, pos2d.y)
	cave_root.rotation_degrees.y = float(cave_def["yaw_deg"])
	parent.add_child(cave_root)

	var length: float = float(cave_def["length"])
	var width: float = float(cave_def["width"])
	var height: float = float(cave_def["height"])
	var glow_col: Color = cave_def["glow_color"]
	var crystal_col: Color = cave_def["crystal_color"]

	var rib_count: int = 7
	var rib_spacing: float = length / float(rib_count - 1)
	var wall_thickness: float = 2.4
	var roof_thickness: float = 2.2

	var rng := RandomNumberGenerator.new()
	rng.seed = hash(cave_def["name"])

	# Constrói as costelas rochosas (paredes laterais + abóbada superior) formando um túnel oco amplo
	for i in range(rib_count):
		var z_off: float = -length * 0.5 + float(i) * rib_spacing
		var arch_w: float = width + sin(float(i) * 0.9) * 0.8
		var arch_h: float = height + sin(float(i) * 0.7) * 0.6

		# Parede esquerda
		var left_pos := Vector3(-arch_w * 0.5 - wall_thickness * 0.4, arch_h * 0.48, z_off)
		var left_size := Vector3(wall_thickness, arch_h + 1.4, rib_spacing * 1.28)
		_add_rock_block(cave_root, left_pos, left_size, Vector3(rng.randf_range(-6, 6), rng.randf_range(-8, 8), rng.randf_range(-8, 8)), _dark_cave_mat, true)

		# Parede direita
		var right_pos := Vector3(arch_w * 0.5 + wall_thickness * 0.4, arch_h * 0.48, z_off)
		var right_size := Vector3(wall_thickness, arch_h + 1.4, rib_spacing * 1.28)
		_add_rock_block(cave_root, right_pos, right_size, Vector3(rng.randf_range(-6, 6), rng.randf_range(-8, 8), rng.randf_range(-8, 8)), _dark_cave_mat, true)

		# Teto abobadado (deixa uma claraboia natural no anel central i == 3 para luz dramática)
		if i != 3:
			var roof_pos := Vector3(0.0, arch_h + roof_thickness * 0.35, z_off)
			var roof_size := Vector3(arch_w + wall_thickness * 1.6, roof_thickness, rib_spacing * 1.32)
			_add_rock_block(cave_root, roof_pos, roof_size, Vector3(rng.randf_range(-5, 5), rng.randf_range(-6, 6), rng.randf_range(-5, 5)), _rock_mat, true)

			# Ombreiras inclinadas para arredondar o interior da caverna
			var shoulder_l := Vector3(-arch_w * 0.42, arch_h * 0.88, z_off)
			var shoulder_r := Vector3(arch_w * 0.42, arch_h * 0.88, z_off)
			var sh_size := Vector3(2.2, 1.8, rib_spacing * 1.15)
			_add_rock_block(cave_root, shoulder_l, sh_size, Vector3(0, 0, -32), _dark_cave_mat, false)
			_add_rock_block(cave_root, shoulder_r, sh_size, Vector3(0, 0, 32), _dark_cave_mat, false)

		# Estalactites no teto e estalagmites nas bordas internas
		if i > 0 and i < rib_count - 1:
			for s in range(2):
				var sx: float = rng.randf_range(-arch_w * 0.34, arch_w * 0.34)
				var stal_h: float = rng.randf_range(0.9, 1.65)
				_add_stalactite(cave_root, Vector3(sx, arch_h - stal_h * 0.45, z_off + rng.randf_range(-0.6, 0.6)), stal_h, true)

			var stalg_side: float = (-1.0 if (i % 2 == 0) else 1.0) * (arch_w * 0.36)
			var stalg_h: float = rng.randf_range(0.85, 1.45)
			_add_stalactite(cave_root, Vector3(stalg_side, stalg_h * 0.45, z_off), stalg_h, false)

	# Cristais bioluminescentes e iluminação interna para guiar e recompensar a exploração
	var crystal_mat := StandardMaterial3D.new()
	crystal_mat.albedo_color = crystal_col
	crystal_mat.roughness = 0.15
	crystal_mat.emission_enabled = true
	crystal_mat.emission = glow_col
	crystal_mat.emission_energy_multiplier = 2.4

	for c_idx in range(6):
		var cz: float = -length * 0.38 + float(c_idx) * (length * 0.76 / 5.0)
		var side_sign: float = -1.0 if (c_idx % 2 == 0) else 1.0
		var cx: float = side_sign * (width * 0.42)
		var cy: float = rng.randf_range(1.1, height * 0.72)
		_add_crystal_cluster(cave_root, Vector3(cx, cy, cz), side_sign, crystal_mat)

	# Luzes OmniLight3D suaves dentro da caverna para atmosfera realista
	for l_idx in range(2):
		var lz: float = -length * 0.22 + float(l_idx) * (length * 0.44)
		var omni := OmniLight3D.new()
		omni.position = Vector3(0.0, height * 0.62, lz)
		omni.light_color = glow_col
		omni.light_energy = 1.65
		omni.omni_range = 12.0
		omni.omni_attenuation = 1.2
		cave_root.add_child(omni)

	# Sinalizadores naturais (cristais luminosos nas duas entradas da caverna)
	_add_crystal_cluster(cave_root, Vector3(-width * 0.48, 1.2, -length * 0.52), -1.0, crystal_mat)
	_add_crystal_cluster(cave_root, Vector3(width * 0.48, 1.2, length * 0.52), 1.0, crystal_mat)


func _build_natural_arch(parent: Node3D, base_pos: Vector3, yaw_deg: float, span: float, arch_height: float) -> void:
	var arch_root := Node3D.new()
	arch_root.position = base_pos
	arch_root.rotation_degrees.y = yaw_deg
	parent.add_child(arch_root)

	# Pilares laterais e topo do arco
	_add_rock_block(arch_root, Vector3(-span * 0.42, arch_height * 0.5, 0.0), Vector3(2.8, arch_height + 1.5, 3.2), Vector3(0, 0, -10), _rock_mat, true)
	_add_rock_block(arch_root, Vector3(span * 0.42, arch_height * 0.5, 0.0), Vector3(2.8, arch_height + 1.5, 3.2), Vector3(0, 0, 10), _rock_mat, true)
	_add_rock_block(arch_root, Vector3(0.0, arch_height + 0.6, 0.0), Vector3(span + 1.8, 2.2, 3.0), Vector3(4, 0, 0), _rock_mat, true)


func _add_rock_block(parent: Node3D, pos: Vector3, size: Vector3, rot_deg: Vector3, mat: Material, with_collision: bool) -> void:
	var mesh_inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	box.material = mat
	mesh_inst.mesh = box
	mesh_inst.position = pos
	mesh_inst.rotation_degrees = rot_deg
	parent.add_child(mesh_inst)

	if with_collision:
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		col.shape = shape
		col.transform = parent.transform * mesh_inst.transform
		add_child(col)


func _add_stalactite(parent: Node3D, pos: Vector3, h: float, hanging: bool) -> void:
	var mesh_inst := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.height = h
	cyl.top_radius = 0.36 if hanging else 0.06
	cyl.bottom_radius = 0.06 if hanging else 0.40
	cyl.radial_segments = 10
	cyl.material = _dark_cave_mat
	mesh_inst.mesh = cyl
	mesh_inst.position = pos
	parent.add_child(mesh_inst)


func _add_crystal_cluster(parent: Node3D, pos: Vector3, side_sign: float, mat: Material) -> void:
	var cluster := Node3D.new()
	cluster.position = pos
	parent.add_child(cluster)

	for i in range(3):
		var shard := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.02
		cyl.bottom_radius = 0.14 - float(i) * 0.025
		cyl.height = 0.72 - float(i) * 0.12
		cyl.radial_segments = 6
		cyl.material = mat
		shard.mesh = cyl
		shard.position = Vector3(0.0, float(i) * 0.12, float(i - 1) * 0.16)
		shard.rotation_degrees = Vector3((i - 1) * 18.0, i * 25.0, -side_sign * (38.0 + i * 12.0))
		cluster.add_child(shard)


func _populate_vegetation_and_corals() -> void:
	var flora_container := Node3D.new()
	flora_container.name = "UnderwaterFloraAndBenthos"
	add_child(flora_container)

	var rng := RandomNumberGenerator.new()
	rng.seed = 420891

	# 1. Florestas de Algas Gigantes (Kelp) em torno dos recifes e entradas de cavernas
	for i in range(60):
		var angle: float = rng.randf() * TAU
		var radius: float = rng.randf_range(6.0, 82.0)
		var x: float = cos(angle) * radius
		var z: float = sin(angle) * radius
		var y: float = get_seafloor_height(x, z)
		if y > -28.0 and y < -8.5:
			var kelp_h: float = rng.randf_range(3.2, 6.8)
			_spawn_kelp_plant(flora_container, Vector3(x, y, z), kelp_h, rng)

	# 2. Bancos de Grama Marinha (Seagrass) nas dunas e encostas arenosas
	for i in range(95):
		var angle: float = rng.randf() * TAU
		var radius: float = rng.randf_range(4.0, 75.0)
		var x: float = cos(angle) * radius
		var z: float = sin(angle) * radius
		var y: float = get_seafloor_height(x, z)
		if y > -26.5:
			_spawn_seagrass_patch(flora_container, Vector3(x, y, z), rng)

	# 3. Corais coloridos (Corais Tubulares, Corais-Cérebro e Anêmonas Bioluminescentes)
	var coral_colors: Array[Color] = [
		Color(0.95, 0.36, 0.28),
		Color(0.98, 0.62, 0.18),
		Color(0.75, 0.28, 0.85),
		Color(0.18, 0.82, 0.76),
		Color(0.95, 0.45, 0.68)
	]
	var coral_mats: Array[StandardMaterial3D] = []
	for col in coral_colors:
		var m := StandardMaterial3D.new()
		m.albedo_color = col
		m.roughness = 0.55
		m.emission_enabled = true
		m.emission = col * 0.28
		coral_mats.append(m)

	for i in range(65):
		var angle: float = rng.randf() * TAU
		var radius: float = rng.randf_range(5.0, 70.0)
		var x: float = cos(angle) * radius
		var z: float = sin(angle) * radius
		var y: float = get_seafloor_height(x, z)
		var mat: StandardMaterial3D = coral_mats[i % coral_mats.size()]
		if i % 2 == 0:
			_spawn_tube_coral(flora_container, Vector3(x, y, z), mat, rng)
		else:
			_spawn_brain_coral(flora_container, Vector3(x, y, z), mat, rng)

	# 4. Pequenos animais bentônicos no fundo (Estrelas-do-mar e Ouriços-do-mar)
	var star_mat_orange := StandardMaterial3D.new()
	star_mat_orange.albedo_color = Color(0.96, 0.38, 0.16)
	star_mat_orange.roughness = 0.65

	var star_mat_red := StandardMaterial3D.new()
	star_mat_red.albedo_color = Color(0.86, 0.18, 0.26)
	star_mat_red.roughness = 0.65

	var urchin_mat := StandardMaterial3D.new()
	urchin_mat.albedo_color = Color(0.16, 0.12, 0.24)
	urchin_mat.roughness = 0.75

	for i in range(45):
		var angle: float = rng.randf() * TAU
		var radius: float = rng.randf_range(4.0, 58.0)
		var x: float = cos(angle) * radius
		var z: float = sin(angle) * radius
		var y: float = get_seafloor_height(x, z)
		if i % 2 == 0:
			var sm: StandardMaterial3D = star_mat_orange if (i % 4 == 0) else star_mat_red
			_spawn_starfish(flora_container, Vector3(x, y + 0.05, z), sm, rng)
		else:
			_spawn_sea_urchin(flora_container, Vector3(x, y + 0.12, z), urchin_mat, rng)


func _spawn_kelp_plant(parent: Node3D, base_pos: Vector3, total_height: float, rng: RandomNumberGenerator) -> void:
	var kelp_root := Node3D.new()
	kelp_root.position = base_pos
	kelp_root.rotation.y = rng.randf() * TAU
	parent.add_child(kelp_root)

	var stem_mesh := CylinderMesh.new()
	stem_mesh.top_radius = 0.035
	stem_mesh.bottom_radius = 0.075
	stem_mesh.height = total_height
	stem_mesh.rings = 8
	stem_mesh.radial_segments = 8
	stem_mesh.material = _kelp_mat

	var stem_inst := MeshInstance3D.new()
	stem_inst.mesh = stem_mesh
	stem_inst.position = Vector3(0.0, total_height * 0.5, 0.0)
	kelp_root.add_child(stem_inst)

	var leaf_count: int = int(clampf(total_height * 1.6, 5.0, 10.0))
	var leaf_mesh := BoxMesh.new()
	leaf_mesh.size = Vector3(0.28, 0.85, 0.025)
	leaf_mesh.subdivide_height = 4
	leaf_mesh.material = _kelp_mat

	for i in range(leaf_count):
		var ratio: float = float(i + 1) / float(leaf_count + 1)
		var ly: float = total_height * ratio
		var leaf := MeshInstance3D.new()
		leaf.mesh = leaf_mesh
		leaf.position = Vector3(0.0, ly, 0.0)
		leaf.rotation_degrees = Vector3(52.0, float(i) * 137.5, 18.0)
		kelp_root.add_child(leaf)


func _spawn_seagrass_patch(parent: Node3D, base_pos: Vector3, rng: RandomNumberGenerator) -> void:
	var patch := Node3D.new()
	patch.position = base_pos
	parent.add_child(patch)

	var blade_mesh := BoxMesh.new()
	blade_mesh.size = Vector3(0.11, 1.05, 0.02)
	blade_mesh.subdivide_height = 3
	blade_mesh.material = _seagrass_mat

	for i in range(5):
		var blade := MeshInstance3D.new()
		blade.mesh = blade_mesh
		var h_scale: float = rng.randf_range(0.65, 1.35)
		blade.scale = Vector3(1.0, h_scale, 1.0)
		blade.position = Vector3(rng.randf_range(-0.35, 0.35), 0.45 * h_scale, rng.randf_range(-0.35, 0.35))
		blade.rotation_degrees = Vector3(rng.randf_range(-14.0, 14.0), rng.randf() * 360.0, rng.randf_range(-14.0, 14.0))
		patch.add_child(blade)


func _spawn_tube_coral(parent: Node3D, base_pos: Vector3, mat: Material, rng: RandomNumberGenerator) -> void:
	var coral := Node3D.new()
	coral.position = base_pos
	parent.add_child(coral)

	var tubes: int = rng.randi_range(4, 7)
	for i in range(tubes):
		var h: float = rng.randf_range(0.55, 1.35)
		var r: float = rng.randf_range(0.09, 0.17)
		var cyl := CylinderMesh.new()
		cyl.top_radius = r * 1.18
		cyl.bottom_radius = r * 0.75
		cyl.height = h
		cyl.radial_segments = 10
		cyl.material = mat

		var inst := MeshInstance3D.new()
		inst.mesh = cyl
		inst.position = Vector3(rng.randf_range(-0.28, 0.28), h * 0.45, rng.randf_range(-0.28, 0.28))
		inst.rotation_degrees = Vector3(rng.randf_range(-16.0, 16.0), rng.randf() * 360.0, rng.randf_range(-16.0, 16.0))
		coral.add_child(inst)


func _spawn_brain_coral(parent: Node3D, base_pos: Vector3, mat: Material, rng: RandomNumberGenerator) -> void:
	var inst := MeshInstance3D.new()
	var sph := SphereMesh.new()
	var rad: float = rng.randf_range(0.38, 0.78)
	sph.radius = rad
	sph.height = rad * 1.35
	sph.radial_segments = 14
	sph.rings = 8
	sph.material = mat
	inst.mesh = sph
	inst.position = base_pos + Vector3(0.0, rad * 0.35, 0.0)
	inst.scale = Vector3(1.0, 0.72, 1.0)
	parent.add_child(inst)


func _spawn_starfish(parent: Node3D, base_pos: Vector3, mat: Material, rng: RandomNumberGenerator) -> void:
	var star := Node3D.new()
	star.position = base_pos
	star.rotation.y = rng.randf() * TAU
	parent.add_child(star)

	var arm_mesh := BoxMesh.new()
	arm_mesh.size = Vector3(0.08, 0.035, 0.36)
	arm_mesh.material = mat

	for i in range(5):
		var arm := MeshInstance3D.new()
		arm.mesh = arm_mesh
		arm.rotation_degrees.y = float(i) * 72.0
		star.add_child(arm)


func _spawn_sea_urchin(parent: Node3D, base_pos: Vector3, mat: Material, rng: RandomNumberGenerator) -> void:
	var inst := MeshInstance3D.new()
	var sph := SphereMesh.new()
	var rad: float = rng.randf_range(0.14, 0.24)
	sph.radius = rad
	sph.height = rad * 1.5
	sph.radial_segments = 10
	sph.rings = 6
	sph.material = mat
	inst.mesh = sph
	inst.position = base_pos
	inst.add_to_group("venomous_urchin")
	parent.add_child(inst)
