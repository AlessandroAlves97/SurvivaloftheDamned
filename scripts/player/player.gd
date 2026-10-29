extends CharacterBody3D

const STORAGE_CHEST_SCENE := preload("res://scenes/structures/storage_chest.tscn")
const PADDLE_COST_WOOD: int = 4
const CHEST_COST_WOOD: int = 6
const HOTBAR_SIZE: int = 6

const ITEM_NAMES: Dictionary = {
	"wood": "Madeira",
	"paddle": "Remo",
	"chest": "Baú"
}

## Define quais itens leves/pequenos podem ser segurados diretamente nas mãos em 1ª pessoa
## (Estruturas pesadas/grandes como o "chest" ficam false e usam preview de posicionamento)
const ITEM_HOLDABLE: Dictionary = {
	"wood": true,
	"paddle": true,
	"chest": false
}

## Configurações de Movimentação em Terra / Jangada
@export_group("Movimentação na Superfície")
@export var walk_speed: float = 4.8
@export var sprint_speed: float = 7.5
@export var jump_velocity: float = 5.2
@export var surface_acceleration: float = 10.0
@export var surface_friction: float = 12.0

## Configurações de Natação (Estilo Subnautica)
@export_group("Natação e Mergulho")
@export var swim_speed: float = 4.2
@export var fast_swim_speed: float = 6.8
@export var swim_acceleration: float = 5.5
@export var water_drag: float = 3.5
@export var water_level: float = 0.0

## Configurações de Câmera
@export_group("Câmera First-Person")
@export var mouse_sensitivity: float = 0.0022

## Status de Sobrevivência
@export_group("Sobrevivência")
@export var max_health: float = 100.0
@export var max_oxygen: float = 45.0
@export var max_hunger: float = 100.0
@export var max_thirst: float = 100.0

var health: float = 100.0
var oxygen: float = 45.0
var hunger: float = 100.0
var thirst: float = 100.0

## Sistema de Inventário e HotBar (Slots 0 a 5 -> Teclas 1 a 6)
var inventory: Dictionary = {
	"wood": 0,
	"paddle": 0,
	"chest": 0
}
var hotbar: Array[String] = ["", "", "", "", "", ""]
var selected_hotbar_slot: int = 0

var _is_rowing: bool = false
var _row_cycle: float = 0.0
var _walk_bob_cycle: float = 0.0
var _swim_stroke_cycle: float = 0.0
var _idle_cycle: float = 0.0
var _equip_dip: float = 0.0
var _last_displayed_item: String = "__init__"
var _chest_preview_valid: bool = false
var _chest_preview_local_pos: Vector3 = Vector3.ZERO

var is_swimming: bool = false
var is_head_underwater: bool = false
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

var _current_interactable: Node = null
var _active_chest: Node = null
var _feedback_timer: float = 0.0
var _hotbar_slot_panels: Array[PanelContainer] = []
var _hotbar_slot_labels: Array[Label] = []

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var interaction_ray: RayCast3D = $Head/Camera3D/InteractionRay
@onready var first_person_rig: Node3D = $Head/Camera3D/FirstPersonRig
@onready var left_arm: Node3D = $Head/Camera3D/FirstPersonRig/LeftArm
@onready var right_arm: Node3D = $Head/Camera3D/FirstPersonRig/RightArm
@onready var left_hand: Node3D = $Head/Camera3D/FirstPersonRig/LeftArm/LeftHand
@onready var right_hand: Node3D = $Head/Camera3D/FirstPersonRig/RightArm/RightHand
@onready var left_fingers: Node3D = $Head/Camera3D/FirstPersonRig/LeftArm/LeftHand/LeftFingers
@onready var right_fingers: Node3D = $Head/Camera3D/FirstPersonRig/RightArm/RightHand/RightFingers
@onready var held_wood: Node3D = $Head/Camera3D/FirstPersonRig/RightArm/RightHand/HeldWood
@onready var paddle_holder: Node3D = $Head/Camera3D/PaddleHolder
@onready var chest_preview: MeshInstance3D = $ChestPreview

@onready var underwater_overlay: ColorRect = $HUD/UnderwaterOverlay
@onready var interaction_label: Label = $HUD/InteractionLabel
@onready var feedback_label: Label = $HUD/FeedbackLabel
@onready var stats_label: Label = $HUD/MarginContainer/VBoxContainer/StatsLabel
@onready var mode_label: Label = $HUD/MarginContainer/VBoxContainer/ModeLabel
@onready var hotbar_slots_container: HBoxContainer = $HUD/HotBarPanel/Margin/SlotsContainer

@onready var inventory_menu: PanelContainer = $HUD/InventoryMenu
@onready var inv_items_list: VBoxContainer = $HUD/InventoryMenu/Margin/VBox/ContentHBox/InventoryCol/ItemsList
@onready var craft_paddle_btn: Button = $HUD/InventoryMenu/Margin/VBox/ContentHBox/CraftCol/CraftPaddleBtn
@onready var craft_chest_btn: Button = $HUD/InventoryMenu/Margin/VBox/ContentHBox/CraftCol/CraftChestBtn
@onready var close_inv_btn: Button = $HUD/InventoryMenu/Margin/VBox/CloseInvBtn

@onready var chest_menu: PanelContainer = $HUD/ChestMenu
@onready var chest_status_label: Label = $HUD/ChestMenu/Margin/VBox/StatusLabel
@onready var deposit_one_btn: Button = $HUD/ChestMenu/Margin/VBox/DepositOneBtn
@onready var deposit_all_btn: Button = $HUD/ChestMenu/Margin/VBox/DepositAllBtn
@onready var withdraw_one_btn: Button = $HUD/ChestMenu/Margin/VBox/WithdrawOneBtn
@onready var withdraw_all_btn: Button = $HUD/ChestMenu/Margin/VBox/WithdrawAllBtn
@onready var close_chest_btn: Button = $HUD/ChestMenu/Margin/VBox/CloseChestBtn

@onready var pause_menu: PanelContainer = $HUD/PauseMenu
@onready var pause_main_buttons: VBoxContainer = $HUD/PauseMenu/Margin/MainButtons
@onready var pause_options_box: VBoxContainer = $HUD/PauseMenu/Margin/OptionsBox
@onready var resume_btn: Button = $HUD/PauseMenu/Margin/MainButtons/ResumeBtn
@onready var options_btn: Button = $HUD/PauseMenu/Margin/MainButtons/OptionsBtn
@onready var quit_btn: Button = $HUD/PauseMenu/Margin/MainButtons/QuitBtn
@onready var sens_label: Label = $HUD/PauseMenu/Margin/OptionsBox/SensLabel
@onready var sens_slider: HSlider = $HUD/PauseMenu/Margin/OptionsBox/SensSlider
@onready var fov_label: Label = $HUD/PauseMenu/Margin/OptionsBox/FovLabel
@onready var fov_slider: HSlider = $HUD/PauseMenu/Margin/OptionsBox/FovSlider
@onready var back_btn: Button = $HUD/PauseMenu/Margin/OptionsBox/BackBtn


func _ready() -> void:
	add_to_group("player")
	_ensure_input_actions()
	_build_hotbar_ui()
	_connect_ui_signals()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_refresh_hotbar_ui()
	_update_hud()


func _build_hotbar_ui() -> void:
	for child in hotbar_slots_container.get_children():
		child.queue_free()
	_hotbar_slot_panels.clear()
	_hotbar_slot_labels.clear()

	for i in range(HOTBAR_SIZE):
		var slot_panel := PanelContainer.new()
		slot_panel.custom_minimum_size = Vector2(84, 56)
		slot_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var lbl := Label.new()
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_constant_override("outline_size", 3)
		lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		slot_panel.add_child(lbl)

		hotbar_slots_container.add_child(slot_panel)
		_hotbar_slot_panels.append(slot_panel)
		_hotbar_slot_labels.append(lbl)


func _connect_ui_signals() -> void:
	# Pause Menu
	resume_btn.pressed.connect(_resume_game)
	options_btn.pressed.connect(_open_options)
	quit_btn.pressed.connect(_quit_game)
	back_btn.pressed.connect(_close_options)
	sens_slider.value_changed.connect(_on_sens_changed)
	fov_slider.value_changed.connect(_on_fov_changed)

	# Inventory & Craft Menu
	craft_paddle_btn.pressed.connect(_on_craft_paddle_pressed)
	craft_chest_btn.pressed.connect(_on_craft_chest_pressed)
	close_inv_btn.pressed.connect(_close_all_submenus)

	# Chest Menu
	deposit_one_btn.pressed.connect(func(): _transfer_chest_wood(1))
	deposit_all_btn.pressed.connect(func(): _transfer_chest_wood(int(inventory["wood"])))
	withdraw_one_btn.pressed.connect(func(): _transfer_chest_wood(-1))
	withdraw_all_btn.pressed.connect(func():
		if _active_chest:
			_transfer_chest_wood(-int(_active_chest.get("stored_wood")))
	)
	close_chest_btn.pressed.connect(_close_all_submenus)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if inventory_menu.visible or chest_menu.visible:
			_close_all_submenus()
		elif pause_menu.visible:
			_resume_game()
		else:
			_open_pause_menu()
		get_viewport().set_input_as_handled()
		return

	if get_tree().paused:
		return

	if event.is_action_pressed("toggle_inventory"):
		if chest_menu.visible or inventory_menu.visible:
			_close_all_submenus()
		else:
			_open_inventory_menu()
		get_viewport().set_input_as_handled()
		return

	# Seleção dos slots 1 a 6 da HotBar
	for i in range(HOTBAR_SIZE):
		if event.is_action_pressed("hotbar_%d" % (i + 1)):
			_select_hotbar_slot(i)
			get_viewport().set_input_as_handled()
			return

	if _is_any_menu_open():
		return

	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clampf(head.rotation.x, deg_to_rad(-89.0), deg_to_rad(89.0))

	elif event.is_action_pressed("interact"):
		if _current_interactable and _current_interactable.has_method("interact"):
			_current_interactable.interact(self)

	elif event is InputEventMouseButton and event.pressed:
		if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if _get_equipped_item() == "chest":
				_try_place_equipped_chest()


func _process(delta: float) -> void:
	if _feedback_timer > 0.0:
		_feedback_timer -= delta
		if _feedback_timer <= 0.0 and feedback_label:
			feedback_label.text = ""

	if get_tree().paused:
		return

	_update_chest_placement_preview()
	_update_interaction_target()
	_animate_first_person_hands(delta)


func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return

	var chest_y: float = global_position.y + 0.9
	is_swimming = chest_y < water_level
	is_head_underwater = camera.global_position.y < water_level

	if underwater_overlay:
		underwater_overlay.visible = is_head_underwater

	var equipped: String = _get_equipped_item()

	# Remada contínua mantendo LMB (frente) ou RMB (ré) pressionado
	_is_rowing = false
	if equipped == "paddle" and not is_swimming and not _is_any_menu_open() and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_process_continuous_rowing(1.0, delta)
		elif Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			_process_continuous_rowing(-0.7, delta)

	if is_swimming:
		_process_swimming(delta)
	else:
		_process_surface_movement(delta)

	move_and_slide()
	_process_survival(delta)


func _process_surface_movement(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	var can_control: bool = not _is_any_menu_open()

	if can_control and Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward") if can_control else Vector2.ZERO
	var direction: Vector3 = (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

	var target_speed: float = sprint_speed if Input.is_action_pressed("sprint") else walk_speed

	if direction != Vector3.ZERO:
		velocity.x = lerpf(velocity.x, direction.x * target_speed, surface_acceleration * delta)
		velocity.z = lerpf(velocity.z, direction.z * target_speed, surface_acceleration * delta)
	else:
		velocity.x = lerpf(velocity.x, 0.0, surface_friction * delta)
		velocity.z = lerpf(velocity.z, 0.0, surface_friction * delta)


func _process_swimming(delta: float) -> void:
	var can_control: bool = not _is_any_menu_open()
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward") if can_control else Vector2.ZERO

	var cam_basis: Basis = camera.global_transform.basis
	var wish_dir: Vector3 = (cam_basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

	if can_control and Input.is_action_pressed("jump"):
		wish_dir.y += 1.0
	if can_control and Input.is_action_pressed("crouch"):
		wish_dir.y -= 1.0

	wish_dir = wish_dir.normalized()
	var current_swim_speed: float = fast_swim_speed if Input.is_action_pressed("sprint") else swim_speed

	if wish_dir != Vector3.ZERO:
		velocity = velocity.lerp(wish_dir * current_swim_speed, swim_acceleration * delta)
	else:
		velocity = velocity.lerp(Vector3(0.0, -0.15, 0.0), water_drag * delta)

	var chest_y: float = global_position.y + 0.9
	if can_control and chest_y > water_level - 0.35 and Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity * 1.05


func _process_continuous_rowing(power_multiplier: float, delta: float) -> void:
	var raft := get_tree().get_first_node_in_group("raft")
	if not raft or not raft.has_method("is_player_on_raft"):
		return

	if not raft.is_player_on_raft(self):
		return

	_is_rowing = true
	var forward_dir: Vector3 = -camera.global_transform.basis.z
	forward_dir.y = 0.0
	forward_dir = forward_dir.normalized() * power_multiplier

	var raft_forward: Vector3 = -raft.global_transform.basis.z
	var turn_rate: float = raft_forward.cross(forward_dir).y * 0.45
	raft.apply_continuous_paddle(forward_dir, turn_rate, delta)


func is_item_holdable(item_id: String) -> bool:
	return bool(ITEM_HOLDABLE.get(item_id, false))


func _animate_first_person_hands(delta: float) -> void:
	var equipped: String = _get_equipped_item()
	var holdable: bool = is_item_holdable(equipped)
	var active_hand_item: String = equipped if holdable else ""

	# Dispara uma leve animação de transição nos braços ao trocar o item exibido
	if active_hand_item != _last_displayed_item:
		_last_displayed_item = active_hand_item
		_equip_dip = 1.0

	_equip_dip = move_toward(_equip_dip, 0.0, delta * 5.0)
	_idle_cycle = wrapf(_idle_cycle + delta * 2.0, 0.0, TAU)

	var horiz_speed: float = Vector2(velocity.x, velocity.z).length()
	var total_speed: float = velocity.length()

	# Atualiza visibilidade dos itens leves seguráveis nas mãos
	var show_paddle: bool = (active_hand_item == "paddle") and not is_swimming
	var show_wood: bool = (active_hand_item == "wood")

	if paddle_holder:
		paddle_holder.visible = show_paddle
	if held_wood:
		held_wood.visible = show_wood
		if show_wood:
			# Posiciona a tábua apoiada na palma e inclinada diagonalmente para cima/frente,
			# ficando claramente visível na tela em uma pegada humana natural
			held_wood.position = Vector3(-0.025, 0.045, -0.055)
			held_wood.rotation_degrees = Vector3(46.0, 14.0, 22.0)

	# Animação do Remo (quando visível)
	if show_paddle and paddle_holder:
		if _is_rowing:
			_row_cycle = wrapf(_row_cycle + delta * 5.0, 0.0, TAU)
			var s: float = sin(_row_cycle)
			var c: float = cos(_row_cycle)
			paddle_holder.position = Vector3(0.24 + c * 0.045, -0.22 + s * 0.085 - _equip_dip * 0.12, -0.52 - c * 0.12)
			paddle_holder.rotation_degrees = Vector3(-14.0 + s * 22.0, -24.0 + c * 10.0, 18.0)
		else:
			_row_cycle = 0.0
			var target_paddle_pos := Vector3(0.24, -0.22 - _equip_dip * 0.12, -0.52)
			paddle_holder.position = paddle_holder.position.lerp(target_paddle_pos, 10.0 * delta)
			paddle_holder.rotation_degrees = paddle_holder.rotation_degrees.lerp(Vector3(-14.0, -24.0, 18.0), 10.0 * delta)

	if not left_arm or not right_arm:
		return

	var idle_y: float = sin(_idle_cycle) * 0.005
	var idle_x: float = cos(_idle_cycle * 0.5) * 0.004
	var dip_offset: float = -_equip_dip * 0.11

	# Postura base anatômica: cotovelos entram pelos cantos inferiores externos e
	# os antebraços dobram para dentro (±46° yaw) e levemente para cima (+20° pitch)
	var left_target_pos := Vector3(-0.30 + idle_x, -0.30 + idle_y + dip_offset, -0.27)
	var left_target_rot := Vector3(20.0, -46.0, 16.0)
	var left_hand_rot := Vector3(6.0, -8.0, 12.0)
	var left_finger_curl: float = -12.0

	var right_target_pos := Vector3(0.30 - idle_x, -0.30 + idle_y + dip_offset, -0.27)
	var right_target_rot := Vector3(20.0, 46.0, -16.0)
	var right_hand_rot := Vector3(6.0, 8.0, -12.0)
	var right_finger_curl: float = -12.0

	if is_swimming:
		var swim_move_factor: float = clampf(total_speed / swim_speed, 0.0, 1.4)
		var stroke_speed: float = lerpf(2.2, 4.2, clampf(swim_move_factor, 0.0, 1.0))
		_swim_stroke_cycle = wrapf(_swim_stroke_cycle + delta * stroke_speed, 0.0, TAU)

		if swim_move_factor > 0.15:
			# Nado Peito (Breaststroke) humano realista em 3 fases contínuas:
			# 1) Esticar mãos juntas à frente -> 2) Puxada aberta para os lados/trás -> 3) Recolhimento pelo peito
			var p: float = _swim_stroke_cycle
			var reach_forward: float = cos(p)                     # +1 esticado à frente, -1 puxado atrás
			var sweep_wide: float = maxf(0.0, sin(p))             # Abre os braços para fora na fase de puxada
			var recovery_tuck: float = maxf(0.0, -sin(p))         # Recolhe os cotovelos por baixo na volta
			var vertical_wave: float = sin(p - 0.6)               # Desce na puxada, sobe no alcance

			var spread_x: float = 0.15 + sweep_wide * 0.19 - recovery_tuck * 0.03
			var stroke_y: float = -0.23 + vertical_wave * 0.045 - recovery_tuck * 0.035
			var stroke_z: float = -0.31 - reach_forward * 0.075 + sweep_wide * 0.03

			var arm_pitch: float = 24.0 + reach_forward * 10.0 - sweep_wide * 12.0
			var arm_yaw_inward: float = 42.0 + reach_forward * 8.0 - sweep_wide * 24.0
			var arm_roll: float = 18.0 + sweep_wide * 28.0 - recovery_tuck * 14.0

			left_target_pos = Vector3(-spread_x, stroke_y + idle_y, stroke_z)
			left_target_rot = Vector3(arm_pitch, -arm_yaw_inward, arm_roll)
			left_hand_rot = Vector3(-8.0 * sweep_wide, -10.0, 18.0 * sweep_wide)
			left_finger_curl = 4.0

			if show_wood:
				# Se estiver segurando madeira durante o nado, mão direita mantém a madeira firme junto ao corpo
				right_target_pos = Vector3(0.24, -0.22 + vertical_wave * 0.015 + dip_offset, -0.27)
				right_target_rot = Vector3(26.0, 44.0, -18.0)
				right_hand_rot = Vector3(10.0, 12.0, -18.0)
				right_finger_curl = -42.0
			else:
				right_target_pos = Vector3(spread_x, stroke_y + idle_y, stroke_z)
				right_target_rot = Vector3(arm_pitch, arm_yaw_inward, -arm_roll)
				right_hand_rot = Vector3(-8.0 * sweep_wide, 10.0, -18.0 * sweep_wide)
				right_finger_curl = 4.0
		else:
			# Boiando parado na água (Treading Water / Sculling suave de sustentação)
			var scull_s: float = sin(_swim_stroke_cycle)
			var scull_c: float = cos(_swim_stroke_cycle)

			left_target_pos = Vector3(-0.24 - scull_s * 0.035, -0.26 + scull_c * 0.012, -0.29)
			left_target_rot = Vector3(22.0, -44.0 - scull_s * 10.0, 18.0 + scull_c * 14.0)
			left_hand_rot = Vector3(4.0, -8.0, 16.0 * scull_c)
			left_finger_curl = -4.0

			if show_wood:
				right_target_pos = Vector3(0.24, -0.21 + scull_c * 0.01 + dip_offset, -0.27)
				right_target_rot = Vector3(28.0, 44.0, -18.0)
				right_hand_rot = Vector3(10.0, 12.0, -18.0)
				right_finger_curl = -42.0
			else:
				right_target_pos = Vector3(0.24 + scull_s * 0.035, -0.26 + scull_c * 0.012, -0.29)
				right_target_rot = Vector3(22.0, 44.0 + scull_s * 10.0, -18.0 - scull_c * 14.0)
				right_hand_rot = Vector3(4.0, 8.0, -16.0 * scull_c)
				right_finger_curl = -4.0
	else:
		# Balanço de caminhada/corrida na superfície
		if horiz_speed > 0.2 and is_on_floor():
			var bob_speed: float = clampf(horiz_speed / walk_speed, 0.5, 1.8) * 7.5
			_walk_bob_cycle = wrapf(_walk_bob_cycle + delta * bob_speed, 0.0, TAU)
		else:
			_walk_bob_cycle = move_toward(_walk_bob_cycle, 0.0, delta * 4.0)

		var move_amp: float = clampf(horiz_speed / walk_speed, 0.0, 1.2)
		var bob_s: float = sin(_walk_bob_cycle) * move_amp
		var bob_c: float = cos(_walk_bob_cycle) * move_amp

		if show_paddle:
			# As duas mãos seguram a haste do remo em ângulo anatômico e acompanham a remada
			var row_s: float = sin(_row_cycle) if _is_rowing else 0.0
			var row_c: float = cos(_row_cycle) if _is_rowing else 0.0

			right_target_pos = Vector3(0.27 + row_c * 0.035, -0.20 + row_s * 0.065 + dip_offset, -0.28 - row_c * 0.08)
			right_target_rot = Vector3(28.0 + row_s * 16.0, 38.0 - row_c * 6.0, -22.0)
			right_hand_rot = Vector3(8.0, 10.0, -20.0)
			right_finger_curl = -46.0

			left_target_pos = Vector3(-0.18 + row_c * 0.03, -0.24 + row_s * 0.06 + dip_offset, -0.31 - row_c * 0.08)
			left_target_rot = Vector3(24.0 + row_s * 14.0, -54.0 + row_c * 6.0, 20.0)
			left_hand_rot = Vector3(6.0, -12.0, 18.0)
			left_finger_curl = -46.0
		elif show_wood:
			# Mão direita traz a tábua de madeira para uma posição visível e ergonômica à frente/direita;
			# dedos fecham ao redor da madeira e mão esquerda acompanha relaxada no canto inferior
			right_target_pos = Vector3(0.24 + bob_c * 0.01, -0.21 + absf(bob_s) * 0.014 + idle_y + dip_offset, -0.27 - bob_s * 0.012)
			right_target_rot = Vector3(28.0 + bob_s * 3.5, 44.0, -18.0)
			right_hand_rot = Vector3(10.0, 12.0, -18.0)
			right_finger_curl = -42.0

			left_target_pos = Vector3(-0.30 - bob_c * 0.01, -0.30 + absf(bob_c) * 0.014 + idle_y, -0.27 + bob_s * 0.018)
			left_target_rot = Vector3(18.0 - bob_s * 4.5, -48.0, 16.0)
			left_hand_rot = Vector3(6.0, -8.0, 12.0)
			left_finger_curl = -14.0
		elif equipped == "chest":
			# Item pesado (Baú): mãos livres dobradas para dentro em postura de posicionamento
			left_target_pos = Vector3(-0.27, -0.27 + idle_y + dip_offset * 0.5, -0.28)
			left_target_rot = Vector3(24.0, -44.0, 14.0)
			left_finger_curl = -8.0

			right_target_pos = Vector3(0.27, -0.27 + idle_y + dip_offset * 0.5, -0.28)
			right_target_rot = Vector3(24.0, 44.0, -14.0)
			right_finger_curl = -8.0
		else:
			# Mãos vazias dobradas naturalmente nos cantos inferiores, com balanço de caminhada
			left_target_pos = Vector3(-0.30, -0.30 + absf(bob_s) * 0.015 + idle_y + dip_offset * 0.4, -0.27 + bob_s * 0.022)
			left_target_rot = Vector3(18.0 + bob_s * 5.5, -48.0 + bob_c * 3.0, 16.0)
			left_finger_curl = -14.0

			right_target_pos = Vector3(0.30, -0.30 + absf(bob_c) * 0.015 + idle_y + dip_offset * 0.4, -0.27 - bob_s * 0.022)
			right_target_rot = Vector3(18.0 - bob_s * 5.5, 48.0 - bob_c * 3.0, -16.0)
			right_finger_curl = -14.0

	left_arm.position = left_arm.position.lerp(left_target_pos, 12.0 * delta)
	left_arm.rotation_degrees = left_arm.rotation_degrees.lerp(left_target_rot, 12.0 * delta)

	right_arm.position = right_arm.position.lerp(right_target_pos, 12.0 * delta)
	right_arm.rotation_degrees = right_arm.rotation_degrees.lerp(right_target_rot, 12.0 * delta)

	if left_hand:
		left_hand.rotation_degrees = left_hand.rotation_degrees.lerp(left_hand_rot, 12.0 * delta)
	if right_hand:
		right_hand.rotation_degrees = right_hand.rotation_degrees.lerp(right_hand_rot, 12.0 * delta)
	if left_fingers:
		left_fingers.rotation_degrees.x = lerpf(left_fingers.rotation_degrees.x, left_finger_curl, 14.0 * delta)
	if right_fingers:
		right_fingers.rotation_degrees.x = lerpf(right_fingers.rotation_degrees.x, right_finger_curl, 14.0 * delta)


func _update_chest_placement_preview() -> void:
	if not chest_preview:
		return

	if _get_equipped_item() != "chest" or is_swimming or _is_any_menu_open():
		chest_preview.visible = false
		_chest_preview_valid = false
		return

	var raft := get_tree().get_first_node_in_group("raft") as Node3D
	if not raft or not raft.has_method("is_valid_structure_placement"):
		chest_preview.visible = false
		_chest_preview_valid = false
		return

	# Calcula o ponto no plano do deck do raft onde o jogador está mirando
	var cam_origin: Vector3 = camera.global_position
	var cam_dir: Vector3 = -camera.global_transform.basis.z
	var deck_plane := Plane(raft.global_transform.basis.y, raft.global_position + raft.global_transform.basis.y * 0.2)
	var hit_world: Variant = deck_plane.intersects_ray(cam_origin, cam_dir)

	var target_world: Vector3
	if hit_world is Vector3 and cam_origin.distance_to(hit_world) <= 4.2:
		target_world = hit_world
	else:
		target_world = global_position + (-transform.basis.z * 1.6)

	var local_pos: Vector3 = raft.to_local(target_world)
	local_pos.y = 0.20

	_chest_preview_local_pos = local_pos
	_chest_preview_valid = raft.is_valid_structure_placement(local_pos, 0.48)

	chest_preview.visible = true
	chest_preview.global_position = raft.to_global(local_pos + Vector3(0.0, 0.28, 0.0))
	chest_preview.global_rotation = Vector3(0.0, rotation.y, 0.0)

	var mat := chest_preview.get_active_material(0) as StandardMaterial3D
	if mat:
		if _chest_preview_valid:
			mat.albedo_color = Color(0.2, 0.95, 0.4, 0.48)
		else:
			mat.albedo_color = Color(0.95, 0.22, 0.22, 0.52)


func _try_place_equipped_chest() -> void:
	if _get_equipped_item() != "chest" or int(inventory["chest"]) <= 0:
		return

	if not _chest_preview_valid:
		_show_feedback("Posição inválida! Coloque dentro dos limites livres do raft.")
		return

	var raft := get_tree().get_first_node_in_group("raft") as Node3D
	if not raft:
		return

	_remove_item("chest", 1)

	var chest_instance := STORAGE_CHEST_SCENE.instantiate() as Node3D
	var container := raft.get_node_or_null("PlacedStructures") as Node3D
	if container:
		container.add_child(chest_instance)
	else:
		raft.add_child(chest_instance)

	chest_instance.position = _chest_preview_local_pos
	chest_instance.rotation.y = rotation.y - raft.rotation.y
	_update_chest_placement_preview()


func _update_interaction_target() -> void:
	_current_interactable = null

	if _is_any_menu_open():
		interaction_label.text = ""
		return

	if _get_equipped_item() == "chest" and chest_preview and chest_preview.visible:
		if _chest_preview_valid:
			interaction_label.text = "[Clique Esquerdo] Posicionar Baú no Raft"
		else:
			interaction_label.text = "Fora dos limites do Raft ou local ocupado"
		return

	if interaction_ray and interaction_ray.is_colliding():
		var col: Object = interaction_ray.get_collider()
		if col is Node and col.is_in_group("interactable"):
			_current_interactable = col as Node

	# Fallback de proximidade para facilitar pegar madeiras oscilando nas ondas
	if not _current_interactable:
		var cam_pos: Vector3 = camera.global_position
		var cam_forward: Vector3 = -camera.global_transform.basis.z
		var best_score: float = 0.65
		for item in get_tree().get_nodes_in_group("interactable"):
			if item is Node3D:
				var dist: float = cam_pos.distance_to(item.global_position)
				if dist <= 3.4:
					var dir_to: Vector3 = (item.global_position - cam_pos).normalized()
					var dot_val: float = cam_forward.dot(dir_to)
					if dot_val > best_score:
						best_score = dot_val
						_current_interactable = item

	if _current_interactable and _current_interactable.has_method("get_interaction_prompt"):
		interaction_label.text = _current_interactable.get_interaction_prompt()
	else:
		interaction_label.text = ""


## ==========================================
## INVENTÁRIO, HOTBAR E CRAFT
## ==========================================

func add_wood(amount: int) -> void:
	# Sem exibir mensagem de total coletado na tela, conforme solicitado
	_add_item("wood", amount)


func _add_item(item_id: String, amount: int) -> void:
	if amount <= 0:
		return
	inventory[item_id] = int(inventory.get(item_id, 0)) + amount
	_auto_equip_to_hotbar(item_id)
	_refresh_hotbar_ui()
	_refresh_inventory_ui()
	_update_hud()


func _remove_item(item_id: String, amount: int) -> void:
	if amount <= 0:
		return
	inventory[item_id] = maxi(0, int(inventory.get(item_id, 0)) - amount)
	if int(inventory[item_id]) <= 0:
		for i in range(HOTBAR_SIZE):
			if hotbar[i] == item_id:
				hotbar[i] = ""
	_refresh_hotbar_ui()
	_refresh_inventory_ui()
	_update_hud()


func _auto_equip_to_hotbar(item_id: String) -> void:
	# Se já está em algum slot da HotBar, não duplica
	if hotbar.has(item_id):
		return
	# Equipa automaticamente no primeiro slot vazio (1 a 6)
	for i in range(HOTBAR_SIZE):
		if hotbar[i] == "":
			hotbar[i] = item_id
			return


func _select_hotbar_slot(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= HOTBAR_SIZE:
		return
	if selected_hotbar_slot != slot_index:
		_equip_dip = maxf(_equip_dip, 0.65)
	selected_hotbar_slot = slot_index
	_refresh_hotbar_ui()
	_update_hud()


func _get_equipped_item() -> String:
	if selected_hotbar_slot < 0 or selected_hotbar_slot >= HOTBAR_SIZE:
		return ""
	var item_id: String = hotbar[selected_hotbar_slot]
	if item_id != "" and int(inventory.get(item_id, 0)) > 0:
		return item_id
	return ""


func _toggle_item_in_hotbar(item_id: String) -> void:
	var existing_idx: int = hotbar.find(item_id)
	if existing_idx != -1:
		hotbar[existing_idx] = ""
	else:
		# Tenta colocar no primeiro slot vazio ou no slot selecionado atualmente
		var placed := false
		for i in range(HOTBAR_SIZE):
			if hotbar[i] == "":
				hotbar[i] = item_id
				selected_hotbar_slot = i
				placed = true
				break
		if not placed:
			hotbar[selected_hotbar_slot] = item_id

	_refresh_hotbar_ui()
	_refresh_inventory_ui()
	_update_hud()


func _refresh_hotbar_ui() -> void:
	for i in range(_hotbar_slot_panels.size()):
		var panel := _hotbar_slot_panels[i]
		var lbl := _hotbar_slot_labels[i]
		var is_selected: bool = (i == selected_hotbar_slot)

		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.16, 0.28, 0.36, 0.95) if is_selected else Color(0.09, 0.13, 0.18, 0.85)
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.border_color = Color(0.98, 0.82, 0.32, 1.0) if is_selected else Color(0.28, 0.42, 0.52, 0.7)
		style.corner_radius_top_left = 6
		style.corner_radius_top_right = 6
		style.corner_radius_bottom_right = 6
		style.corner_radius_bottom_left = 6
		panel.add_theme_stylebox_override("panel", style)

		var item_id: String = hotbar[i]
		var count: int = int(inventory.get(item_id, 0)) if item_id != "" else 0
		if item_id == "" or count <= 0:
			lbl.text = "[%d]\n—" % (i + 1)
			lbl.add_theme_color_override("font_color", Color(0.55, 0.62, 0.68, 0.8))
		else:
			var item_name: String = str(ITEM_NAMES.get(item_id, item_id))
			if item_id == "paddle":
				lbl.text = "[%d]\n%s" % [i + 1, item_name]
			else:
				lbl.text = "[%d]\n%s x%d" % [i + 1, item_name, count]
			lbl.add_theme_color_override("font_color", Color(1.0, 0.96, 0.82, 1.0) if is_selected else Color(0.88, 0.94, 0.98, 1.0))


func _open_inventory_menu() -> void:
	chest_menu.visible = false
	inventory_menu.visible = true
	_refresh_inventory_ui()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _refresh_inventory_ui() -> void:
	if not inv_items_list:
		return

	for child in inv_items_list.get_children():
		child.queue_free()

	var any_item := false
	for item_id: String in ["wood", "paddle", "chest"]:
		var count: int = int(inventory.get(item_id, 0))
		if count <= 0:
			continue
		any_item = true

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)

		var name_lbl := Label.new()
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var display_name: String = str(ITEM_NAMES.get(item_id, item_id))
		var slot_idx: int = hotbar.find(item_id)
		var slot_tag: String = " (HotBar [%d])" % (slot_idx + 1) if slot_idx != -1 else ""
		name_lbl.text = "• %s  (Qtd: %d)%s" % [display_name, count, slot_tag]
		row.add_child(name_lbl)

		var eq_btn := Button.new()
		eq_btn.custom_minimum_size = Vector2(145, 32)
		eq_btn.text = "Tirar da HotBar" if slot_idx != -1 else "Equipar HotBar"
		eq_btn.pressed.connect(func(): _toggle_item_in_hotbar(item_id))
		row.add_child(eq_btn)

		inv_items_list.add_child(row)

	if not any_item:
		var empty_lbl := Label.new()
		empty_lbl.text = "Inventário vazio. Colete madeiras no mar com [E]!"
		empty_lbl.add_theme_color_override("font_color", Color(0.65, 0.72, 0.78, 1.0))
		inv_items_list.add_child(empty_lbl)

	var wood_owned: int = int(inventory.get("wood", 0))
	var has_paddle: bool = int(inventory.get("paddle", 0)) > 0

	if has_paddle:
		craft_paddle_btn.text = "Remo de Madeira (Já Possui)"
		craft_paddle_btn.disabled = true
	else:
		craft_paddle_btn.text = "Criar Remo de Madeira (%d Madeiras)" % PADDLE_COST_WOOD
		craft_paddle_btn.disabled = wood_owned < PADDLE_COST_WOOD

	craft_chest_btn.text = "Criar Baú de Armazenamento (%d Madeiras)" % CHEST_COST_WOOD
	craft_chest_btn.disabled = wood_owned < CHEST_COST_WOOD


func _on_craft_paddle_pressed() -> void:
	if int(inventory.get("paddle", 0)) > 0 or int(inventory.get("wood", 0)) < PADDLE_COST_WOOD:
		return
	_remove_item("wood", PADDLE_COST_WOOD)
	_add_item("paddle", 1)
	var paddle_slot: int = hotbar.find("paddle")
	if paddle_slot != -1:
		selected_hotbar_slot = paddle_slot
	_refresh_hotbar_ui()
	_refresh_inventory_ui()
	_show_feedback("Remo criado e enviado para o Inventário/HotBar!")


func _on_craft_chest_pressed() -> void:
	if int(inventory.get("wood", 0)) < CHEST_COST_WOOD:
		return
	_remove_item("wood", CHEST_COST_WOOD)
	_add_item("chest", 1)
	var chest_slot: int = hotbar.find("chest")
	if chest_slot != -1:
		selected_hotbar_slot = chest_slot
	_refresh_hotbar_ui()
	_refresh_inventory_ui()
	_show_feedback("Baú criado! Selecione-o na HotBar (1-6) para posicionar no raft.")


## ==========================================
## BAÚ DE ARMAZENAMENTO
## ==========================================

func open_chest_ui(chest: Node) -> void:
	_active_chest = chest
	inventory_menu.visible = false
	chest_menu.visible = true
	_refresh_chest_ui()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _refresh_chest_ui() -> void:
	if not _active_chest:
		return
	var wood_owned: int = int(inventory.get("wood", 0))
	var stored: int = int(_active_chest.get("stored_wood"))
	var cap: int = int(_active_chest.get("max_capacity"))
	chest_status_label.text = "Inventário: %d Madeiras   |   No Baú: %d / %d" % [wood_owned, stored, cap]
	deposit_one_btn.disabled = wood_owned <= 0 or stored >= cap
	deposit_all_btn.disabled = wood_owned <= 0 or stored >= cap
	withdraw_one_btn.disabled = stored <= 0
	withdraw_all_btn.disabled = stored <= 0


func _transfer_chest_wood(amount: int) -> void:
	if not _active_chest or amount == 0:
		return
	var wood_owned: int = int(inventory.get("wood", 0))
	var stored: int = int(_active_chest.get("stored_wood"))
	var cap: int = int(_active_chest.get("max_capacity"))

	if amount > 0:
		var can_store: int = mini(amount, mini(wood_owned, cap - stored))
		_remove_item("wood", can_store)
		_active_chest.set("stored_wood", stored + can_store)
	else:
		var can_take: int = mini(-amount, stored)
		_active_chest.set("stored_wood", stored - can_take)
		_add_item("wood", can_take)

	_refresh_chest_ui()


## ==========================================
## PAUSE E OPÇÕES
## ==========================================

func _close_all_submenus() -> void:
	inventory_menu.visible = false
	chest_menu.visible = false
	_active_chest = null
	if not pause_menu.visible:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _open_pause_menu() -> void:
	inventory_menu.visible = false
	chest_menu.visible = false
	pause_main_buttons.visible = true
	pause_options_box.visible = false
	pause_menu.visible = true
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _resume_game() -> void:
	pause_menu.visible = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _open_options() -> void:
	pause_main_buttons.visible = false
	pause_options_box.visible = true


func _close_options() -> void:
	pause_options_box.visible = false
	pause_main_buttons.visible = true


func _on_sens_changed(val: float) -> void:
	mouse_sensitivity = val
	var pct: int = int(round((val / 0.0022) * 100.0))
	sens_label.text = "Sensibilidade do Mouse: %d%%" % pct


func _on_fov_changed(val: float) -> void:
	if camera:
		camera.fov = val
	fov_label.text = "Campo de Visão (FOV): %d°" % int(round(val))


func _quit_game() -> void:
	get_tree().quit()


func _is_any_menu_open() -> bool:
	return pause_menu.visible or inventory_menu.visible or chest_menu.visible


func _show_feedback(msg: String) -> void:
	if feedback_label:
		feedback_label.text = msg
		_feedback_timer = 3.2


func _process_survival(delta: float) -> void:
	if is_head_underwater:
		oxygen = maxf(0.0, oxygen - delta)
		if oxygen <= 0.0:
			health = maxf(0.0, health - 5.0 * delta)
	else:
		oxygen = minf(max_oxygen, oxygen + delta * 15.0)

	hunger = maxf(0.0, hunger - delta * 0.08)
	thirst = maxf(0.0, thirst - delta * 0.12)

	_update_hud()


func _update_hud() -> void:
	if not stats_label or not mode_label:
		return

	var state_text: String = "MERGULHANDO" if is_head_underwater else ("NADANDO" if is_swimming else "NA JANGADA")
	var equipped: String = _get_equipped_item()
	var item_hint: String = ""
	if equipped == "paddle":
		item_hint = "  |  Segure [Clique Esq.] Remar"
	elif equipped == "chest":
		item_hint = "  |  [Clique Esq.] Posicionar Baú"

	mode_label.text = "Estado: %s  |  [E] Interagir  |  [Tab/I] Inventário & Craft  |  [1-6] HotBar%s" % [state_text, item_hint]

	stats_label.text = "Vida: %d%%   |   Oxigênio: %ds/%ds   |   Sede: %d%%   |   Fome: %d%%" % [
		int(round(health)),
		int(ceil(oxygen)),
		int(round(max_oxygen)),
		int(round(thirst)),
		int(round(hunger))
	]


func _ensure_input_actions() -> void:
	var bindings: Dictionary = {
		"move_forward": [KEY_W, KEY_UP],
		"move_backward": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"jump": [KEY_SPACE],
		"sprint": [KEY_SHIFT],
		"crouch": [KEY_CTRL, KEY_C],
		"interact": [KEY_E],
		"toggle_inventory": [KEY_TAB, KEY_I, KEY_B],
		"hotbar_1": [KEY_1, KEY_KP_1],
		"hotbar_2": [KEY_2, KEY_KP_2],
		"hotbar_3": [KEY_3, KEY_KP_3],
		"hotbar_4": [KEY_4, KEY_KP_4],
		"hotbar_5": [KEY_5, KEY_KP_5],
		"hotbar_6": [KEY_6, KEY_KP_6]
	}

	for action_name: String in bindings.keys():
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
		for key_code: int in bindings[action_name]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key_code as Key
			if not InputMap.action_has_event(action_name, ev):
				InputMap.action_add_event(action_name, ev)
