extends StaticBody3D

@export var max_capacity: int = 50
var stored_wood: int = 0


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("storage_chest")


func get_interaction_prompt() -> String:
	return "[E] Abrir Baú (Madeira: %d/%d)" % [stored_wood, max_capacity]


func interact(player: Node) -> void:
	if player.has_method("open_chest_ui"):
		player.open_chest_ui(self)
