extends StaticBody3D

@export var wood_amount: int = 1
@export var drift_velocity: Vector3 = Vector3(0.35, 0.0, 0.2)
@export var wave_height: float = 0.14
@export var wave_speed: float = 1.1

var _base_y: float = 0.0
var _phase_offset: float = 0.0


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("floating_wood")
	_phase_offset = randf() * TAU


func _process(delta: float) -> void:
	# Deriva suave na correnteza
	global_position.x += drift_velocity.x * delta
	global_position.z += drift_velocity.z * delta

	# Acompanha a altura das ondas do shader
	var t: float = Time.get_ticks_msec() * 0.001
	var pos := Vector2(global_position.x, global_position.z)
	var w1: float = sin(pos.x * 0.4 + t * wave_speed) * cos(pos.y * 0.3 + t * wave_speed * 0.8)
	var w2: float = sin((pos.x * 0.7 - pos.y * 0.5) + t * wave_speed * 1.3) * 0.5
	global_position.y = _base_y + (w1 + w2) * wave_height

	# Leve oscilação angular na água
	rotation.z = sin(t * 1.5 + _phase_offset) * 0.08
	rotation.x = cos(t * 1.2 + _phase_offset) * 0.06


func get_interaction_prompt() -> String:
	return "[E] Coletar Madeira (+%d)" % wood_amount


func interact(player: Node) -> void:
	if player.has_method("add_wood"):
		player.add_wood(wood_amount)
		queue_free()
