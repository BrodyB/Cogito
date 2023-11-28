extends Control

@onready var health_bar = $PlayerAttributes/MarginContainer/VBoxContainer/HealthBar
@onready var sanity_bar = $PlayerAttributes/MarginContainer/VBoxContainer/SanityBar
@onready var brightness_bar = $PlayerAttributes/MarginContainer/VBoxContainer/BrightnessBar
@onready var health_bar_label = $PlayerAttributes/MarginContainer/VBoxContainer/HealthBar/Label
@onready var sanity_bar_label = $PlayerAttributes/MarginContainer/VBoxContainer/SanityBar/Label

@onready var interaction_button = $ButtonPrompt/HBoxContainer/InteractionButton
@onready var interaction_text = $ButtonPrompt/HBoxContainer/InteractionText

@onready var hint_icon = $HintPrompt/MarginContainer/HBoxContainer/HintIcon
@onready var hint_text = $HintPrompt/MarginContainer/HBoxContainer/HintText
@onready var hint_timer = $HintTimer
@onready var inventory_interface = $InventoryInterface

@onready var primary_use_icon = $UseBar/HBoxContainer/WieldablePrimaryUse/PrimaryUseIcon
@onready var primary_use_label = $UseBar/HBoxContainer/WieldablePrimaryUse/PrimaryUseLabel

@onready var wieldable_icon = $UseBar/HBoxContainer/WieldableData/WieldableIcon
@onready var wieldable_text = $UseBar/HBoxContainer/WieldableData/WieldableText

@export var player : Node

var is_inventory_open : bool = false
var device_id : int = -1
var interaction_texture : Texture2D

## Used to reset icons etc, useful to have.
@export var empty_texture : Texture2D
# The hint icon that displays when no other icon is passed.
@export var default_hint_icon : Texture2D

@export_group("Input Icons")
@export_subgroup("Input Icons Keyboard")
@export var interaction_keyboard : Texture2D
@export var inventory_move_keyboard : Texture2D
@export var inventory_use_keyboard : Texture2D
@export var wieldable_use_primary_keyboard : Texture2D

@export_subgroup("Input Icons Gamepad")
@export var interaction_gamepad : Texture2D
@export var inventory_move_gamepad : Texture2D
@export var inventory_use_gamepad : Texture2D
@export var inventory_drop_gamepad : Texture2D
@export var wieldable_use_primary_gamepad : Texture2D


func _ready():
	# Call this function once to set interaction_texture:
	_joy_connection_changed(device_id,false)
	
	# Connect to signal that detecs change of input device/gamepad
	Input.joy_connection_changed.connect(_joy_connection_changed)
	
	# Setting up player attribute values
	health_bar.max_value = player.health_component.max_health
	health_bar.value = player.health_component.current_health
	
	sanity_bar.max_value = player.sanity_component.max_sanity
	sanity_bar.value = player.sanity_component.current_sanity
	
	brightness_bar.max_value = player.brightness_component.max_brightness
	brightness_bar.value = player.brightness_component.current_brightness
	
	health_bar_label.text = str(health_bar.value, "/", health_bar.max_value)
	sanity_bar_label.text = str(sanity_bar.value, "/", sanity_bar.max_value)
	
	
	# Set up for HUD elements for interactions and wieldables
	interaction_button.set_texture(empty_texture)
	interaction_text.text = ""
	primary_use_label.text = ""
	primary_use_icon.hide()
	wieldable_icon.set_texture(empty_texture)
	wieldable_text.text = ""
	
	# Set up for HUD elements for hints
	hint_icon.set_texture(empty_texture)
	hint_text.text = ""
	
	inventory_interface.set_player_inventory_data(player.inventory_data)
	inventory_interface.hot_bar_inventory.set_inventory_data(player.inventory_data)
	
	# Connecting to Signals from Player
	player.health_component.health_changed.connect(_on_player_health_changed)
	player.sanity_component.sanity_changed.connect(_on_player_sanity_changed)
	player.brightness_component.brightness_changed.connect(_on_player_brightness_changed)
	player.player_interaction_component.interaction_prompt.connect(_on_interaction_prompt)
	player.player_interaction_component.set_use_prompt.connect(_on_set_use_prompt)
	player.player_interaction_component.hint_prompt.connect(_on_set_hint_prompt)
	player.toggle_inventory_interface.connect(toggle_inventory_interface)
	player.player_interaction_component.update_wieldable_data.connect(_on_update_wieldable_data)

	# Grabbing external inventories in scene.
	for node in get_tree().get_nodes_in_group("external_inventory"):
		print("Is in external_inventory group: ", node)
		node.toggle_inventory.connect(toggle_inventory_interface)


func _joy_connection_changed(passed_device_id : int, connected : bool):
	print("Joy connection changed: passed_device_id=",passed_device_id,". connected=", connected, ".")
	if connected:
		device_id = passed_device_id
	elif _is_steam_deck():
		device_id = 1
	else:
		device_id = -1
		
	if device_id == -1:
		set_input_icons_to_kbm()
	else:
		set_input_icons_to_gamepad()


func _is_steam_deck() -> bool:
	if RenderingServer.get_rendering_device().get_device_name().contains("RADV VANGOGH") \
	or OS.get_processor_name().contains("AMD CUSTOM APU 0405"):
		return true
	else:
		return false


func set_input_icons_to_gamepad():
	interaction_texture = interaction_gamepad
	$InventoryInterface/InfoPanel/MarginContainer/VBoxContainer/HBoxUse/BtnUse.set_texture(inventory_use_gamepad)
	$InventoryInterface/InfoPanel/MarginContainer/VBoxContainer/HBoxMove/BtnMove.set_texture(inventory_move_gamepad)
	$InventoryInterface/InfoPanel/MarginContainer/VBoxContainer/HBoxDrop/BtnDrop.set_texture(inventory_drop_gamepad)
	$InventoryInterface/InfoPanel/MarginContainer/VBoxContainer/HBoxDrop.show()
	primary_use_icon.set_texture(wieldable_use_primary_gamepad)
	
	
func set_input_icons_to_kbm():
	interaction_texture = interaction_keyboard
	$InventoryInterface/InfoPanel/MarginContainer/VBoxContainer/HBoxUse/BtnUse.set_texture(inventory_use_keyboard)
	$InventoryInterface/InfoPanel/MarginContainer/VBoxContainer/HBoxMove/BtnMove.set_texture(inventory_move_keyboard)
	$InventoryInterface/InfoPanel/MarginContainer/VBoxContainer/HBoxDrop.hide()
	primary_use_icon.set_texture(wieldable_use_primary_keyboard)


func toggle_inventory_interface(external_inventory_owner = null):
	if !inventory_interface.is_inventory_open:
		player._on_pause_movement()
		inventory_interface.open_inventory()
		if external_inventory_owner:
			external_inventory_owner.interaction_text = "Close"
	else:
		inventory_interface.close_inventory()
		player._on_resume_movement()
		if external_inventory_owner:
			external_inventory_owner.interaction_text = "Open"
		
	if external_inventory_owner and inventory_interface.is_inventory_open:
		inventory_interface.set_external_inventory(external_inventory_owner)
	else:
		inventory_interface.clear_external_inventory()


# When HUD receives interaction prompt signal (usually if player interaction raycast hits an object on layer 2)
func _on_interaction_prompt(passed_interaction_prompt):
	if(passed_interaction_prompt == ""):
		interaction_button.set_texture(empty_texture)
	else:
		interaction_button.set_texture(interaction_texture)
	interaction_text.text = passed_interaction_prompt
	

# When HUD receives set use prompt signal (usually when equipping a wieldable)
func _on_set_use_prompt(passed_use_text):
	primary_use_label.text = passed_use_text
	if passed_use_text != "":
		primary_use_icon.show()
	else:
		primary_use_icon.hide()


# Updating HUD wieldable data, used for stuff like flashlight battery charge, ammo display, etc
func _on_update_wieldable_data(passed_wieldable_icon, passed_wieldable_text):
	wieldable_text.text = passed_wieldable_text
	if passed_wieldable_icon != null:
		wieldable_icon.set_texture(passed_wieldable_icon)
	else:
		wieldable_icon.set_texture(empty_texture)


# When the HUD receives hint prompt signal
func _on_set_hint_prompt(passed_hint_icon, passed_hint_text):
	hint_text.text = passed_hint_text
	if passed_hint_icon != null:
		hint_icon.set_texture(passed_hint_icon)
	else:
		hint_icon.set_texture(default_hint_icon)
		
	# Starts the timer that sets how long the hint is going to be displayed.
	hint_timer.start()
	

# Resetting the hint display when hint timer runs out.
func _on_hint_timer_timeout():
	hint_text.text = ""
	hint_icon.set_texture(empty_texture)



# Updating player health bar
func _on_player_health_changed(new_health, max_health):
	health_bar.max_value = max_health
	health_bar.value = new_health
	health_bar_label.text = str(int(health_bar.value), "/", int(health_bar.max_value))


# Updating player sanity bar
func _on_player_sanity_changed(new_sanity, max_sanity):
	sanity_bar.value = new_sanity
	sanity_bar.max_value = max_sanity
	sanity_bar_label.text = str(int(sanity_bar.value), "/", int(sanity_bar.max_value))
	
	
# Updating player brightness bar
func _on_player_brightness_changed(new_brightness, max_brightness):
	brightness_bar.value = new_brightness
	brightness_bar.max_value = max_brightness


# On Inventory UI Item Drop
func _on_inventory_interface_drop_slot_data(slot_data):
	var scene_to_drop = load(slot_data.inventory_item.drop_scene)
	AudioManagerPd.play_audio("item_drop")
	var dropped_item = scene_to_drop.instantiate()
	dropped_item.position = player.drop_position.global_position
	dropped_item.slot_data = slot_data
	get_parent().add_child(dropped_item)


