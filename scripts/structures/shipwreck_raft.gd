extends StaticBody3D

@export var water_drag: float = 1.8
@export var angular_drag: float = 2.6
@export var max_speed: float = 5.5
@export var paddle_acceleration: float = 7.5

## Limites úteis do deck de madeira para posicionamento de estruturas (Baús, etc.)
const DECK_LIMIT_X: float = 1.80
const DECK_LIMIT_Z_MIN: float = -1.80
const DECK_LIMIT_Z_MAX: float = 1.80

## Obstáculos fixos do design do raft (Mastro quebrado e Caixote de suprimentos)
const OBSTACLE_MAST_POS := Vector2(1.2, -1.1)
const OBSTACLE_MAST_RADIUS: float = 0.45
const OBSTACLE_CRATE_POS := Vector2(-1.35, -1.25)
const OBSTACLE_CRATE_RADIUS: float = 0.65

var linear_velocity_xz: Vector3 = Vector3.ZERO
var angular_velocity_y: float = 0.0


func _ready() -> void:
	add_to_group("raft")


func _physics_process(delta: float) -> void:
	if linear_velocity_xz.length_squared() < 0.0001 and absf(angular_velocity_y) < 0.0001:
		return

	var displacement: Vector3 = linear_velocity_xz * delta
	var rot_delta: float = angular_velocity_y * delta

	global_position += displacement
	rotate_y(rot_delta)

	# Se o jogador estiver em cima do raft, move-o junto com a embarcação
	var players := get_tree().get_nodes_in_group("player")
	for p in players:
		if p is CharacterBody3D and is_player_on_raft(p):
			var rel_pos: Vector3 = p.global_position - (global_position - displacement)
			var rotated_rel: Vector3 = rel_pos.rotated(Vector3.UP, rot_delta)
			p.global_position = global_position + rotated_rel
			p.rotate_y(rot_delta)

	linear_velocity_xz = linear_velocity_xz.lerp(Vector3.ZERO, water_drag * delta)
	angular_velocity_y = lerpf(angular_velocity_y, 0.0, angular_drag * delta)


func is_player_on_raft(player: CharacterBody3D) -> bool:
	if player.get("is_swimming"):
		return false
	var local_pos: Vector3 = to_local(player.global_position)
	return absf(local_pos.x) <= 2.8 and local_pos.z >= -2.8 and local_pos.z <= 4.2 and local_pos.y >= -0.75 and local_pos.y <= 3.5


func apply_continuous_paddle(direction_xz: Vector3, turn_rate: float, delta: float) -> void:
	var flat_dir := Vector3(direction_xz.x, 0.0, direction_xz.z)
	if flat_dir.length_squared() > 0.001:
		flat_dir = flat_dir.normalized()
	linear_velocity_xz = linear_velocity_xz.move_toward(flat_dir * max_speed, paddle_acceleration * delta)
	angular_velocity_y = lerpf(angular_velocity_y, clampf(turn_rate, -1.1, 1.1), 4.0 * delta)


func is_valid_structure_placement(local_pos: Vector3, structure_radius: float = 0.48) -> bool:
	# 1. Verifica se está dentro dos limites das tábuas do deck do raft
	if absf(local_pos.x) > (DECK_LIMIT_X - structure_radius * 0.5):
		return false
	if local_pos.z < (DECK_LIMIT_Z_MIN + structure_radius * 0.5) or local_pos.z > (DECK_LIMIT_Z_MAX - structure_radius * 0.5):
		return false

	var pos_2d := Vector2(local_pos.x, local_pos.z)

	# 2. Verifica colisão com o mastro quebrado e com o caixote do naufrágio
	if pos_2d.distance_to(OBSTACLE_MAST_POS) < (OBSTACLE_MAST_RADIUS + structure_radius):
		return false
	if pos_2d.distance_to(OBSTACLE_CRATE_POS) < (OBSTACLE_CRATE_RADIUS + structure_radius):
		return false

	# 3. Verifica colisão com outros baús/estruturas já colocados no raft
	for existing in get_tree().get_nodes_in_group("storage_chest"):
		if existing is Node3D:
			var ex_local: Vector3 = to_local(existing.global_position)
			if pos_2d.distance_to(Vector2(ex_local.x, ex_local.z)) < (structure_radius * 1.75):
				return false

	return true
