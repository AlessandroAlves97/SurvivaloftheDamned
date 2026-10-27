extends Node3D

@export var water_level: float = 0.0
@export var max_floating_wood: int = 7
@export var wood_spawn_interval: float = 8.5

const FLOATING_WOOD_SCENE := preload("res://scenes/items/floating_wood.tscn")

@onready var world_env: WorldEnvironment = $WorldEnvironment
@onready var player: CharacterBody3D = $Player
@onready var ocean_mesh: MeshInstance3D = $OceanSurface
@onready var floating_debris_container: Node3D = $FloatingDebris

var _was_underwater: bool = false
var _spawn_timer: float = 0.0


func _ready() -> void:
	_apply_atmosphere(false)


func _process(delta: float) -> void:
	if not player:
		return

	# Mantém a malha da superfície do oceano centralizada no jogador (oceano infinito)
	if ocean_mesh:
		ocean_mesh.global_position.x = snappedf(player.global_position.x, 31.4159)
		ocean_mesh.global_position.z = snappedf(player.global_position.z, 31.4159)

	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam:
		var is_underwater: bool = cam.global_position.y < water_level
		if is_underwater != _was_underwater:
			_was_underwater = is_underwater
			_apply_atmosphere(is_underwater)

	_process_wood_spawner(delta)


func _process_wood_spawner(delta: float) -> void:
	_spawn_timer += delta
	if _spawn_timer < wood_spawn_interval:
		return
	_spawn_timer = 0.0

	# Remove madeiras que já derivaram para muito longe (> 65m) para permitir renovação
	var woods := get_tree().get_nodes_in_group("floating_wood")
	for w in woods:
		if w is Node3D and w.global_position.distance_to(player.global_position) > 65.0:
			w.queue_free()

	woods = get_tree().get_nodes_in_group("floating_wood")
	if woods.size() >= max_floating_wood:
		return

	# Spawna um novo pedaço de madeira a uma distância moderada (14m a 30m)
	var wood_instance := FLOATING_WOOD_SCENE.instantiate() as Node3D
	var angle: float = randf() * TAU
	var dist: float = randf_range(14.0, 30.0)
	var spawn_pos := Vector3(
		player.global_position.x + cos(angle) * dist,
		water_level,
		player.global_position.z + sin(angle) * dist
	)
	if floating_debris_container:
		floating_debris_container.add_child(wood_instance)
	else:
		add_child(wood_instance)
	wood_instance.global_position = spawn_pos
	wood_instance.rotation.y = randf() * TAU


func _apply_atmosphere(underwater: bool) -> void:
	if not world_env or not world_env.environment:
		return

	var env: Environment = world_env.environment
	if underwater:
		env.fog_enabled = true
		env.fog_light_color = Color(0.03, 0.24, 0.34)
		env.fog_density = 0.035
		env.fog_sky_affect = 0.85
		env.ambient_light_color = Color(0.05, 0.30, 0.42)
		env.ambient_light_energy = 0.8
	else:
		env.fog_enabled = true
		env.fog_light_color = Color(0.62, 0.78, 0.88)
		env.fog_density = 0.0008
		env.fog_sky_affect = 0.25
		env.ambient_light_color = Color(0.75, 0.85, 0.95)
		env.ambient_light_energy = 0.5
