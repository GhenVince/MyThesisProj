# PauseMenu.gd
extends Control

signal continue_game
signal retry_game
signal open_options
signal exit_to_menu

func _ready():
	hide()

func open():
	"""Show the pause menu"""
	show()
	get_tree().paused = true

func close():
	"""Hide the pause menu"""
	hide()
	get_tree().paused = false

func _on_continue_pressed():
	print("Continue pressed")
	continue_game.emit()
	close()

func _on_retry_pressed():
	print("Retry pressed")
	get_tree().paused = false
	retry_game.emit()

func _on_options_pressed():
	print("Options pressed")
	get_tree().paused = false
	open_options.emit()

func _on_exit_pressed():
	print("Exit pressed")
	get_tree().paused = false
	exit_to_menu.emit()
