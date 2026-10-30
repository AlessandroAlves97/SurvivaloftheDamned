extends Node3D

enum SharkState {
	PATROL_DEEP,
	SURFACE_STALK,
	HUNT_PLAYER,
	BITE_COOLDOWN
}

@export var deep_patrol_speed: float = 3.6
@export var stalk_speed: float = 4.4
@export var hunt_speed: float = 6.2
@export var turn_speed: float = 2.4
@export var bite_damage: float = 34.0
@export var bite_range: float = 2.45
@export var water_level: float = 0.0

var state: SharkState = SharkState.PATROL_DEEP
var patrol_center: Vector3 = Vector3.ZERO
var patrol_radius: float = 26.0
var patrol_depth: float = -13.5

var _orbit_angle: float = 0.0
var _orbit_dir: float = 1.0
var _current_speed: float = 3.6
var _swim_cycle: float = 0.0
var _state_timer: float = 0.0
var _bite_anim_timer: float = 0.0
var _jaw_open_amount: float = 0.0

@onready var visuals: Node3D = $Visuals
@onready var lower_jaw: Node3D = $Visuals/HeadGroup/LowerJawPivot
@onready var tail_body_pivot: Node3D = $Visuals/TailBodyPivot
@onready var caudal_fin_pivot: Node3D = $Visuals/TailBodyPivot/CaudalFinPivot
@onready var left_pectoral: Node3D = $Visuals/LeftPectoralPivot
@onready var right_pectoral: Node3D = $Visuals/RightPectoralPivot


func _ready() -> void:
	add_to_group("shark")
	_orbit_angle = randf() * TAU
	_orbit_dir = 1.0 if randf() > 0.5 else -1.0
	_swim_cycle = randf() * TAU


func setup_shark(spawn_pos: Vector3, orbit_radius: float, depth_y: float) -> void:
	global_position = spawn_pos
	patrol_radius = orbit_radius
	patrol_depth = depth_y
	_orbit_angle = atan2(spawn_pos.z, spawn_pos.x)


## Chamado pelo controlador do oceano para enviar este tubarão atrás do jogador (estilo Raft)
func trigger_player_hunt(duration: float = 18.0) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player and player.get("is_dead"):
		return
	state = SharkState.HUNT_PLAYER
	_state_timer = duration


func reset_to_deep_patrol() -> void:
	state = SharkState.PATROL_DEEP
	_state_timer = 0.0
	_jaw_open_amount = 0.0


func _process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var raft := get_tree().get_first_node_in_group("raft") as Node3D

	if raft:
		patrol_center = Vector3(raft.global_position.x, 0.0, raft.global_position.z)
	elif player:
		patrol_center = Vector3(player.global_position.x, 0.0, player.global_position.z)

	var player_dead: bool = bool(player.get("is_dead")) if player else false
	var player_in_water: bool = bool(player.get("is_swimming")) if player else false

	if player_dead and state != SharkState.PATROL_DEEP:
		reset_to_deep_patrol()

	# Se o jogador mergulhar muito perto de um tubarão em patrulha no fundo, ele percebe e ataca
	if state == SharkState.PATROL_DEEP and player and not player_dead and player_in_water:
		var dist_to_player: float = global_position.distance_to(player.global_position)
		if dist_to_player < 13.0:
			trigger_player_hunt(15.0)

	var target_pos: Vector3 = global_position
	var desired_speed: float = deep_patrol_speed

	match state:
		SharkState.PATROL_DEEP:
			_orbit_angle = wrapf(_orbit_angle + _orbit_dir * (deep_patrol_speed / maxf(patrol_radius, 8.0)) * delta, 0.0, TAU)
			var tx: float = patrol_center.x + cos(_orbit_angle) * patrol_radius
			var tz: float = patrol_center.z + sin(_orbit_angle) * patrol_radius
			var ty: float = patrol_depth + sin(_orbit_angle * 2.0) * 2.2
			target_pos = Vector3(tx, ty, tz)
			desired_speed = deep_patrol_speed
			_jaw_open_amount = move_toward(_jaw_open_amount, 0.08, delta * 2.0)

		SharkState.HUNT_PLAYER:
			_state_timer -= delta
			if _state_timer <= 0.0 or not player or player_dead:
				state = SharkState.PATROL_DEEP
			elif player_in_water:
				# Persegue diretamente o jogador na água!
				target_pos = player.global_position + Vector3(0.0, 0.35, 0.0)
				desired_speed = hunt_speed
				var dist: float = global_position.distance_to(target_pos)
				# Abre a bocarra quando está prestes a dar o bote
				var target_jaw: float = 1.0 if dist < 5.2 else 0.25
				_jaw_open_amount = move_toward(_jaw_open_amount, target_jaw, delta * 3.8)

				if dist <= bite_range:
					_perform_bite_on_player(player)
			else:
				# Jogador está em cima da jangada: o tubarão sobe perto da superfície e rodeia a jangada (estilo Raft!)
				_orbit_angle = wrapf(_orbit_angle + _orbit_dir * (stalk_speed / 10.5) * delta, 0.0, TAU)
				var sx: float = patrol_center.x + cos(_orbit_angle) * 10.5
				var sz: float = patrol_center.z + sin(_orbit_angle) * 10.5
				target_pos = Vector3(sx, water_level - 0.95, sz)
				desired_speed = stalk_speed
				_jaw_open_amount = move_toward(_jaw_open_amount, 0.18, delta * 2.5)

		SharkState.BITE_COOLDOWN:
			_state_timer -= delta
			_orbit_angle = wrapf(_orbit_angle + _orbit_dir * 0.45 * delta, 0.0, TAU)
			var cx: float = patrol_center.x + cos(_orbit_angle) * 13.0
			var cz: float = patrol_center.z + sin(_orbit_angle) * 13.0
			target_pos = Vector3(cx, minf(global_position.y - 0.5, water_level - 2.2), cz)
			desired_speed = stalk_speed * 1.15
			_jaw_open_amount = move_toward(_jaw_open_amount, 0.1, delta * 3.0)
			if _state_timer <= 0.0:
				state = SharkState.HUNT_PLAYER
				_state_timer = 12.0

	# Respeita o relevo do fundo do mar e o nível da água
	var min_floor_y: float = -28.0
	var seafloor := get_tree().get_first_node_in_group("seafloor")
	if seafloor and seafloor.has_method("get_seafloor_height"):
		min_floor_y = float(seafloor.call("get_seafloor_height", global_position.x, global_position.z)) + 1.8

	target_pos.y = clampf(target_pos.y, min_floor_y, water_level - 0.75)

	var to_target: Vector3 = target_pos - global_position
	var desired_dir: Vector3 = to_target.normalized() if to_target.length_squared() > 0.01 else -global_transform.basis.z
	desired_dir.y = clampf(desired_dir.y, -0.55, 0.55)
	desired_dir = desired_dir.normalized()

	_current_speed = lerpf(_current_speed, desired_speed, delta * 3.0)
	var current_forward: Vector3 = -global_transform.basis.z
	var new_forward: Vector3 = current_forward.lerp(desired_dir, clampf(turn_speed * delta, 0.0, 1.0)).normalized()

	global_position += new_forward * _current_speed * delta
	global_position.y = clampf(global_position.y, min_floor_y - 0.3, water_level - 0.65)

	if new_forward.length_squared() > 0.001 and absf(new_forward.dot(Vector3.UP)) < 0.98:
		look_at(global_position + new_forward, Vector3.UP)

	_animate_shark_body(delta)


func _perform_bite_on_player(player: Node3D) -> void:
	_bite_anim_timer = 0.45
	_jaw_open_amount = 1.25
	if player.has_method("take_damage"):
		var push_dir: Vector3 = (player.global_position - global_position).normalized()
		push_dir.y = clampf(push_dir.y + 0.2, -0.3, 0.5)
		player.call("take_damage", bite_damage, "Atacado por um Grande Tubarão Branco", push_dir * 7.5)

	# Após morder, faz uma volta curta antes de investir novamente (como no Raft)
	state = SharkState.BITE_COOLDOWN
	_state_timer = 4.2
	_orbit_angle = atan2(global_position.z - patrol_center.z, global_position.x - patrol_center.x) + _orbit_dir * 0.9


func _animate_shark_body(delta: float) -> void:
	var speed_ratio: float = clampf(_current_speed / deep_patrol_speed, 0.6, 2.2)
	_swim_cycle = wrapf(_swim_cycle + delta * 4.4 * speed_ratio, 0.0, TAU)
	var s: float = sin(_swim_cycle)
	var s_lag: float = sin(_swim_cycle - 0.85)
	var c: float = cos(_swim_cycle)

	if visuals:
		visuals.rotation.y = -s * 0.085
		visuals.rotation.z = c * 0.035

	if tail_body_pivot:
		tail_body_pivot.rotation.y = s * 0.24
	if caudal_fin_pivot:
		caudal_fin_pivot.rotation.y = s_lag * 0.34

	if left_pectoral:
		left_pectoral.rotation.z = 0.15 + c * 0.07
	if right_pectoral:
		right_pectoral.rotation.z = -0.15 - c * 0.07

	if _bite_anim_timer > 0.0:
		_bite_anim_timer = maxf(0.0, _bite_anim_timer - delta)
		var bite_snap: float = sin((_bite_anim_timer / 0.45) * PI)
		if lower_jaw:
			lower_jaw.rotation_degrees.x = -38.0 * bite_snap
	else:
		if lower_jaw:
			lower_jaw.rotation_degrees.x = lerpf(lower_jaw.rotation_degrees.x, -28.0 * _jaw_open_amount, 10.0 * delta)
