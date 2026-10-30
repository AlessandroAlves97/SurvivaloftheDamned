extends StaticBody3D

@export var swim_speed: float = 2.4
@export var dart_speed: float = 4.6
@export var turn_speed: float = 3.2
@export var roam_radius: float = 12.0
@export var water_level: float = 0.0

var species_name: String = "Peixe"
var home_position: Vector3 = Vector3.ZERO
var _target_dir: Vector3 = Vector3.FORWARD
var _current_speed: float = 2.4
var _swim_cycle: float = 0.0
var _retarget_timer: float = 0.0
var _species_index: int = 0

@onready var visuals: Node3D = $Visuals
@onready var tail_pivot: Node3D = $Visuals/TailPivot
@onready var left_fin: Node3D = $Visuals/LeftPectoralFin
@onready var right_fin: Node3D = $Visuals/RightPectoralFin
@onready var body_mesh: MeshInstance3D = $Visuals/BodyMesh
@onready var stripe_mesh: MeshInstance3D = $Visuals/StripeMesh
@onready var dorsal_mesh: MeshInstance3D = $Visuals/DorsalFin
@onready var tail_upper: MeshInstance3D = $Visuals/TailPivot/TailUpper
@onready var tail_lower: MeshInstance3D = $Visuals/TailPivot/TailLower


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("fish")
	if home_position == Vector3.ZERO:
		home_position = global_position
	_swim_cycle = randf() * TAU
	_retarget_timer = randf_range(1.5, 4.0)
	_pick_new_direction()
	_apply_random_species_style()


func setup_fish(spawn_pos: Vector3, home_pos: Vector3, species_idx: int = -1) -> void:
	global_position = spawn_pos
	home_position = home_pos
	if species_idx >= 0:
		_species_index = species_idx
	else:
		_species_index = randi() % 4
	if is_inside_tree():
		_apply_random_species_style()


func _apply_random_species_style() -> void:
	var presets: Array[Dictionary] = [
		{
			"name": "Peixe-Recife",
			"body": Color(0.10, 0.58, 0.85),
			"accent": Color(0.98, 0.82, 0.18),
			"emission": Color(0.0, 0.0, 0.0),
			"scale": Vector3(1.0, 1.0, 1.0)
		},
		{
			"name": "Peixe-Coral",
			"body": Color(0.95, 0.42, 0.14),
			"accent": Color(0.98, 0.94, 0.88),
			"emission": Color(0.0, 0.0, 0.0),
			"scale": Vector3(0.92, 0.95, 0.92)
		},
		{
			"name": "Peixe-Prateado",
			"body": Color(0.62, 0.75, 0.84),
			"accent": Color(0.24, 0.46, 0.62),
			"emission": Color(0.0, 0.0, 0.0),
			"scale": Vector3(1.12, 0.90, 1.15)
		},
		{
			"name": "Peixe-Luminescente",
			"body": Color(0.08, 0.32, 0.48),
			"accent": Color(0.22, 0.96, 0.88),
			"emission": Color(0.12, 0.78, 0.72),
			"scale": Vector3(0.96, 1.02, 0.98)
		}
	]

	var preset: Dictionary = presets[_species_index % presets.size()]
	species_name = str(preset["name"])
	if visuals:
		visuals.scale = preset["scale"]

	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = preset["body"]
	body_mat.roughness = 0.28
	body_mat.metallic = 0.25

	var accent_mat := StandardMaterial3D.new()
	accent_mat.albedo_color = preset["accent"]
	accent_mat.roughness = 0.35
	var em: Color = preset["emission"]
	if em.r > 0.01 or em.g > 0.01 or em.b > 0.01:
		accent_mat.emission_enabled = true
		accent_mat.emission = em
		accent_mat.emission_energy_multiplier = 1.6

	if body_mesh:
		body_mesh.material_override = body_mat
	if stripe_mesh:
		stripe_mesh.material_override = accent_mat
	if dorsal_mesh:
		dorsal_mesh.material_override = accent_mat
	if tail_upper:
		tail_upper.material_override = accent_mat
	if tail_lower:
		tail_lower.material_override = accent_mat


func _process(delta: float) -> void:
	_retarget_timer -= delta
	if _retarget_timer <= 0.0:
		_retarget_timer = randf_range(2.2, 5.0)
		_pick_new_direction()

	var target_spd: float = swim_speed
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player:
		var dist_to_player: float = global_position.distance_to(player.global_position)
		if dist_to_player < 2.2:
			# Reage sutilmente à aproximação rápida, mas permite ser alcançado pelo jogador
			var away: Vector3 = (global_position - player.global_position).normalized()
			_target_dir = (_target_dir.lerp(away, 0.35)).normalized()
			target_spd = dart_speed

	# Mantém dentro dos limites seguros de profundidade (entre a superfície e o relevo do fundo)
	var min_y: float = -24.0
	var seafloor := get_tree().get_first_node_in_group("seafloor")
	if seafloor and seafloor.has_method("get_seafloor_height"):
		min_y = float(seafloor.call("get_seafloor_height", global_position.x, global_position.z)) + 1.15

	var max_y: float = water_level - 1.15
	if max_y <= min_y + 0.5:
		max_y = min_y + 0.5

	if global_position.y > max_y:
		_target_dir.y = -absf(_target_dir.y) - 0.35
		_target_dir = _target_dir.normalized()
	elif global_position.y < min_y:
		_target_dir.y = absf(_target_dir.y) + 0.45
		_target_dir = _target_dir.normalized()

	# Se afastar demais do ponto de origem (recife/caverna), volta suavemente
	var to_home: Vector3 = home_position - global_position
	if to_home.length() > roam_radius:
		_target_dir = _target_dir.lerp(to_home.normalized(), delta * 1.8).normalized()

	_current_speed = lerpf(_current_speed, target_spd, delta * 3.5)

	var current_forward: Vector3 = -global_transform.basis.z
	var new_forward: Vector3 = current_forward.lerp(_target_dir, clampf(turn_speed * delta, 0.0, 1.0)).normalized()
	new_forward.y = clampf(new_forward.y, -0.45, 0.45)
	new_forward = new_forward.normalized()

	global_position += new_forward * _current_speed * delta
	global_position.y = clampf(global_position.y, min_y - 0.3, water_level - 0.65)

	if new_forward.length_squared() > 0.001 and absf(new_forward.dot(Vector3.UP)) < 0.98:
		look_at(global_position + new_forward, Vector3.UP)

	# Animação de nado da cauda e nadadeiras
	var wag_freq: float = lerpf(6.5, 13.5, clampf((_current_speed - swim_speed) / maxf(dart_speed - swim_speed, 0.1), 0.0, 1.0))
	_swim_cycle = wrapf(_swim_cycle + delta * wag_freq, 0.0, TAU)
	var s: float = sin(_swim_cycle)
	var c: float = cos(_swim_cycle)

	if tail_pivot:
		tail_pivot.rotation.y = s * 0.42
	if visuals:
		visuals.rotation.y = -s * 0.09
		visuals.rotation.z = c * 0.05
	if left_fin:
		left_fin.rotation.z = 0.25 + s * 0.22
	if right_fin:
		right_fin.rotation.z = -0.25 - s * 0.22


func _pick_new_direction() -> void:
	var rand_angle: float = randf() * TAU
	var vertical_bias: float = randf_range(-0.22, 0.22)
	var dir := Vector3(cos(rand_angle), vertical_bias, sin(rand_angle)).normalized()
	var to_home: Vector3 = home_position - global_position
	if to_home.length() > roam_radius * 0.65:
		dir = dir.lerp(to_home.normalized(), 0.55).normalized()
	_target_dir = dir


func get_interaction_prompt() -> String:
	return "[E] Coletar %s (+1 Peixe)" % species_name


func interact(player: Node) -> void:
	if player.has_method("add_fish"):
		player.add_fish(1)
		queue_free()
