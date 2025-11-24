# MainMenu.gd - WORKS FOR ANY STRUCTURE
extends Control

func _ready():
	print("=== Connecting Buttons ===")
	connect_all_buttons(self)

func connect_all_buttons(node: Node):
	"""Find and connect all buttons automatically"""
	if node is Button:
		var name = node.name.to_lower()
		if "play" in name:
			node.pressed.connect(_on_play_pressed)
			print("✅ Connected Play")
		elif "leaderboard" in name:
			node.pressed.connect(_on_leaderboard_pressed)
			print("✅ Connected Leaderboard")
		elif "option" in name:
			node.pressed.connect(_on_options_pressed)
			print("✅ Connected Options")
		elif "exit" in name or "quit" in name:
			node.pressed.connect(_on_exit_pressed)
			print("✅ Connected Exit")
	
	for child in node.get_children():
		connect_all_buttons(child)

func _on_play_pressed():
	print("🎮 Play!")
	get_tree().change_scene_to_file("res://scenes/SongSelection.tscn")

func _on_leaderboard_pressed():
	print("🏆 Leaderboard!")
	get_tree().change_scene_to_file("res://scenes/Leaderboard.tscn")

func _on_options_pressed():
	print("⚙️ Options!")
	get_tree().change_scene_to_file("res://scenes/OptionsMenu.tscn")

func _on_exit_pressed():
	print("🚪 Exit!")
	get_tree().quit()
