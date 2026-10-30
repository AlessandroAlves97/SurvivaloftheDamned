extends Node3D

@export var water_level: float = 0.0
@export var max_floating_wood: int = 7
@export var wood_spawn_interval: float = 8.5
@export var max_fish: int = 28
@export var fish_spawn_interval: float = 5.0
@export var shark_count: int = 3
@export var shark_hunt_interval: float = 18.0

const FLOATING_WOOD_SCENE := preload("res://scenes/items/floating_wood.tscn")
const FISH_SCENE := preload("res://scenes/creatures/fish.tscn")
const SHARK_SCENE := preload("res://scenes/creatures/great_white_shark.tscn")

@onready var world_env: WorldEnvironment = $WorldEnvironment
@onready var player: CharacterBody3D = $Player
@onready var ocean_mesh: MeshInstance3D = $OceanSurface
@onready var floating_debris_container: Node3D = $FloatingDebris
@onready var sea_floor: Node3D = $SeaFloor

var _was_underwater: bool = false
var _spawn_timer: float = 0.0
var _fish_spawn_timer: float = 0.0
var _shark_hunt_timer: float = 6.0
var _fish_container: Node3D = null


func _ready() -> void:
	_apply_atmosphere(false)
	_fish_container = Node3D.new()
	_fish_container.name = "MarineLifeContainer"
	add_child(_fish_container)
	call_deferred("_spawn_initial_fish_population")
	call_deferred("_spawn_sharks")


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
	_process_fish_spawner(delta)
	_process_shark_director(delta)


func _spawn_sharks() -> void:
	var radii: Array[float] = [22.0, 32.0, 42.0]
	var depths: Array[float] = [-11.5, -15.5, -18.5]
	for i in range(shark_count):
		var shark := SHARK_SCENE.instantiate() as Node3D
		var angle: float = float(i) * (TAU / float(maxi(shark_count, 1))) + 0.6
		var rad: float = radii[i % radii.size()]
		var dep: float = depths[i % depths.size()]
		var pos := Vector3(cos(angle) * rad, dep, sin(angle) * rad)
		if _fish_container:
			_fish_container.add_child(shark)
		else:
			add_child(shark)
		if shark.has_method("setup_shark"):
			shark.call("setup_shark", pos, rad, dep)


func _process_shark_director(delta: float) -> void:
	if player.get("is_dead"):
		return
	var speed_mult: float = 1.85 if bool(player.get("is_swimming")) else 1.0
	_shark_hunt_timer += delta * speed_mult
	if _shark_hunt_timer < shark_hunt_interval:
		return
	_shark_hunt_timer = 0.0

	var sharks := get_tree().get_nodes_in_group("shark")
	if sharks.is_empty():
		return

	# Escolhe um dos tubarões para subir das profundezas e vir atrás do jogador (estilo Raft)
	var chosen: Node = sharks[randi() % sharks.size()]
	if chosen and chosen.has_method("trigger_player_hunt"):
		chosen.call("trigger_player_hunt", randf_range(15.0, 22.0))


func _spawn_initial_fish_population() -> void:
	for i in range(max_fish):
		_spawn_single_fish(true, i)


func _process_fish_spawner(delta: float) -> void:
	_fish_spawn_timer += delta
	if _fish_spawn_timer < fish_spawn_interval:
		return
	_fish_spawn_timer = 0.0

	var all_fish := get_tree().get_nodes_in_group("fish")
	for f in all_fish:
		if f is Node3D and f.global_position.distance_to(player.global_position) > 95.0:
			f.queue_free()

	all_fish = get_tree().get_nodes_in_group("fish")
	if all_fish.size() >= max_fish:
		return

	_spawn_single_fish(false, randi() % 4)


func _spawn_single_fish(initial: bool, idx: int) -> void:
	if not player:
		return
	var fish_inst := FISH_SCENE.instantiate() as Node3D
	var angle: float = randf() * TAU
	var dist: float = randf_range(5.0, 48.0) if initial else randf_range(12.0, 42.0)

	var center_xz := Vector2(player.global_position.x, player.global_position.z)
	if initial and idx < 8:
		# Posiciona parte dos cardumes perto das cavernas submarinas
		var cave_centers: Array[Vector2] = [
			Vector2(-18.0, -20.0),
			Vector2(25.0, -16.0),
			Vector2(14.0, 22.0),
			Vector2(-26.0, 18.0)
		]
		center_xz = cave_centers[idx % cave_centers.size()]
		dist = randf_range(2.0, 10.0)

	var wx: float = center_xz.x + cos(angle) * dist
	var wz: float = center_xz.y + sin(angle) * dist

	var floor_y: float = -20.0
	if sea_floor and sea_floor.has_method("get_seafloor_height"):
		floor_y = float(sea_floor.call("get_seafloor_height", wx, wz))

	var min_depth_y: float = floor_y + 1.5
	var max_depth_y: float = water_level - 1.8
	if max_depth_y <= min_depth_y:
		max_depth_y = min_depth_y + 1.0

	var wy: float = randf_range(min_depth_y, max_depth_y)
	var spawn_pos := Vector3(wx, wy, wz)

	if _fish_container:
		_fish_container.add_child(fish_inst)
	else:
		add_child(fish_inst)

	if fish_inst.has_method("setup_fish"):
		var species_idx: int = 3 if (initial and idx < 8) else (idx % 4)
		fish_inst.call("setup_fish", spawn_pos, spawn_pos, species_idx)
	else:
		fish_inst.global_position = spawn_pos


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
		env.fog_light_color = Color(0.04, 0.28, 0.40)
		env.fog_density = 0.019
		env.fog_sky_affect = 0.85
		env.ambient_light_color = Color(0.08, 0.38, 0.52)
		env.ambient_light_energy = 0.95
	else:
		env.fog_enabled = true
		env.fog_light_color = Color(0.62, 0.78, 0.88)
		env.fog_density = 0.0008
		env.fog_sky_affect = 0.25
		env.ambient_light_color = Color(0.75, 0.85, 0.95)
		env.ambient_light_energy = 0.5
