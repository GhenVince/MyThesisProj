# PauseMenu.gd
extends Control

@onready var continue_button = $PanelContainer/Panel/VBoxContainer/ContinueButton
@onready var retry_button = $PanelContainer/Panel/VBoxContainer/RetryButton
@onready var options_button = $PanelContainer/Panel/VBoxContainer/OptionsButton
@onready var menu_button = $PanelContainer/Panel/VBoxContainer/MenuButton

signal continue_requested
signal retry_requested
signal options_requested
signal menu_requested

func _ready():
	continue_button.pressed.connect(_on_continue_pressed)
	retry_button.pressed.connect(_on_retry_pressed)
	options_button.pressed.connect(_on_options_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED

func _on_continue_pressed():
	var gameplay = get_parent()
	if gameplay.has_method("resume_game"):
		gameplay.resume_game()

func _on_retry_pressed():
	get_tree().paused = false
	GameManager.reset_game_stats()
	get_tree().reload_current_scene()

func _on_options_pressed():
	# Open options menu (to be implemented)
	pass

func _on_menu_pressed():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
