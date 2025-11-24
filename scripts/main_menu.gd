# main_menu.gd - FIXED VERSION
extends Control

# Get the OptionsMenu instance that's already in the scene
@onready var options_menu = $UI/OptionsMenu

func _ready():
	print("=== MainMenu Ready ===")
	
	# Make sure options menu starts hidden
	if options_menu:
		options_menu.hide()
		print("✓ OptionsMenu found and hidden")
	
	# Connect buttons
	var play_btn = $UI/VBoxContainer/HBoxContainer2/PlayButton
	var leaderboard_btn = $UI/VBoxContainer/HBoxContainer2/LeaderboardButton
	var options_btn = $UI/VBoxContainer/HBoxContainer/OptionsButton
	var exit_btn = $UI/VBoxContainer/HBoxContainer/ExitButton
	
	if play_btn and not play_btn.pressed.is_connected(_on_playbtn_pressed):
		play_btn.pressed.connect(_on_playbtn_pressed)
		print("✓ Play button connected")
	
	if leaderboard_btn and not leaderboard_btn.pressed.is_connected(_on_leaderboardsbtn_pressed):
		leaderboard_btn.pressed.connect(_on_leaderboardsbtn_pressed)
		print("✓ Leaderboard button connected")
	
	if options_btn and not options_btn.pressed.is_connected(_on_optionsbtn_pressed):
		options_btn.pressed.connect(_on_optionsbtn_pressed)
		print("✓ Options button connected")
	
	if exit_btn and not exit_btn.pressed.is_connected(_on_exitbtn_pressed):
		exit_btn.pressed.connect(_on_exitbtn_pressed)
		print("✓ Exit button connected")

func _on_playbtn_pressed():
	print("🎮 Play button pressed")
	get_tree().change_scene_to_file("res://scenes/SongSelection.tscn")

func _on_leaderboardsbtn_pressed():
	print("🏆 Leaderboard button pressed")
	get_tree().change_scene_to_file("res://scenes/Leaderboard.tscn")

func _on_optionsbtn_pressed():
	print("⚙️ Options button pressed")
	if options_menu:
		print("  Showing options menu...")
		options_menu.show()
		# Connect the closed signal if not already connected
		if not options_menu.closed.is_connected(_on_options_closed):
			options_menu.closed.connect(_on_options_closed)
	else:
		print("  ERROR: options_menu is null!")

func _on_options_closed():
	"""Called when options menu is closed"""
	print("Options menu closed")
	if options_menu:
		options_menu.hide()

func _on_exitbtn_pressed():
	print("🚪 Exit button pressed")
	get_tree().quit()
