# ResultsScreen.gd
extends Control

# Get references to UI elements
@onready var song_title_label = $Panel/VBoxContainer/SongTitle
@onready var score_value_label = $Panel/VBoxContainer/ScoreContainer/ScoreValue
@onready var accuracy_value_label = $Panel/VBoxContainer/AccuracyContainer/AccuracyValue
@onready var perfect_value_label = $Panel/VBoxContainer/StatsContainer/PerfectContainer/PerfectValue
@onready var good_value_label = $Panel/VBoxContainer/StatsContainer/GoodContainer/GoodValue
@onready var miss_value_label = $Panel/VBoxContainer/StatsContainer/MissContainer/MissValue
@onready var rank_label = $Panel/VBoxContainer/RankLabel
@onready var retry_button = $Panel/VBoxContainer/ButtonContainer/RetryButton
@onready var menu_button = $Panel/VBoxContainer/ButtonContainer/MenuButton
@onready var panel = $Panel

func _ready():
	var line = "=================================================="
	print("\n" + line)
	print("RESULTS SCREEN")
	print(line)
	
	# Display the results
	display_results()
	
	# Save to leaderboard
	save_to_leaderboard()
	
	# Connect buttons
	if retry_button:
		retry_button.pressed.connect(_on_retry_pressed)
		print("✓ Retry button connected")
	
	if menu_button:
		menu_button.pressed.connect(_on_menu_pressed)
		print("✓ Menu button connected")
	
	# Animate in
	animate_results()
	
	print(line + "\n")

func display_results():
	"""Display all game results"""
	print("\n📊 Displaying Results:")
	
	# Song title - read from scene tree metadata
	var song_title = "Song Complete!"
	if get_tree().root.has_meta("last_song_title"):
		song_title = get_tree().root.get_meta("last_song_title")
	
	# Get stored values (in case GameManager was reset)
	var score = GameManager.game_score
	var perfect = GameManager.perfect_count
	var good = GameManager.good_count
	var miss = GameManager.miss_count
	
	# If GameManager is empty, try metadata fallback
	if score == 0 and get_tree().root.has_meta("last_song_score"):
		score = get_tree().root.get_meta("last_song_score")
		perfect = get_tree().root.get_meta("last_song_perfect")
		good = get_tree().root.get_meta("last_song_good")
		miss = get_tree().root.get_meta("last_song_miss")
	
	if song_title_label:
		song_title_label.text = song_title
		print("   Song: " + song_title)
	
	# Score
	if score_value_label:
		score_value_label.text = str(score)
		print("   Score: " + str(score))
	
	# Calculate accuracy
	var total_notes = perfect + good + miss
	var accuracy = 0.0
	if total_notes > 0:
		accuracy = (perfect + good * 0.5) / float(total_notes) * 100.0
	
	if accuracy_value_label:
		accuracy_value_label.text = str(int(accuracy)) + "%"
		print("   Accuracy: " + str(int(accuracy)) + "%")
	
	# Stats
	if perfect_value_label:
		perfect_value_label.text = str(perfect)
		print("   Perfect: " + str(perfect))
	
	if good_value_label:
		good_value_label.text = str(good)
		print("   Good: " + str(good))
	
	if miss_value_label:
		miss_value_label.text = str(miss)
		print("   Miss: " + str(miss))
	
	# Rank
	var rank = calculate_rank(accuracy)
	if rank_label:
		rank_label.text = rank
		set_rank_color(rank)
		print("   Rank: " + rank)

func calculate_rank(accuracy: float) -> String:
	"""Calculate rank based on accuracy"""
	if accuracy >= 95:
		return "S"
	elif accuracy >= 90:
		return "A"
	elif accuracy >= 80:
		return "B"
	elif accuracy >= 70:
		return "C"
	elif accuracy >= 60:
		return "D"
	else:
		return "F"

func set_rank_color(rank: String):
	"""Set rank label color based on rank"""
	if not rank_label:
		return
	
	match rank:
		"S":
			rank_label.modulate = Color(1.0, 0.84, 0.0)  # Gold
		"A":
			rank_label.modulate = Color(0.0, 1.0, 0.0)   # Green
		"B":
			rank_label.modulate = Color(0.0, 0.8, 1.0)   # Cyan
		"C":
			rank_label.modulate = Color(1.0, 1.0, 0.0)   # Yellow
		"D":
			rank_label.modulate = Color(1.0, 0.5, 0.0)   # Orange
		"F":
			rank_label.modulate = Color(1.0, 0.0, 0.0)   # Red

func save_to_leaderboard():
	"""Save score to leaderboard"""
	print("\n💾 Saving to Leaderboard:")
	
	# Get song title from metadata
	var song_title = "Unknown Song"
	if get_tree().root.has_meta("last_song_title"):
		song_title = get_tree().root.get_meta("last_song_title")
	
	# Get player name (default to "Player")
	var player_name = "Player"
	
	# Get stats (from metadata if GameManager reset)
	var score = GameManager.game_score
	var perfect = GameManager.perfect_count
	var good = GameManager.good_count
	var miss = GameManager.miss_count
	
	if score == 0 and get_tree().root.has_meta("last_song_score"):
		score = get_tree().root.get_meta("last_song_score")
		perfect = get_tree().root.get_meta("last_song_perfect")
		good = get_tree().root.get_meta("last_song_good")
		miss = get_tree().root.get_meta("last_song_miss")
	
	# Calculate accuracy
	var total_notes = perfect + good + miss
	var accuracy = 0.0
	if total_notes > 0:
		accuracy = (perfect + good * 0.5) / float(total_notes) * 100.0
	
	# Get rank
	var rank = calculate_rank(accuracy)
	
	# Print stats
	print("   Song: " + song_title)
	print("   Score: " + str(score))
	print("   Accuracy: " + str(int(accuracy)) + "%")
	print("   Rank: " + rank)
	
	# Save to LeaderboardManager
	if has_node("/root/LeaderboardManager"):
		var leaderboard = get_node("/root/LeaderboardManager")
		
		if leaderboard.has_method("add_score"):
			# Create score entry dictionary matching LeaderboardManager format
			var score_entry = {
				"song": song_title,
				"artist": "",  # Could add this later
				"score": score,
				"accuracy": accuracy,
				"perfect": perfect,
				"good": good,
				"miss": miss,
				"rank": rank,
				"date": Time.get_datetime_string_from_system()
			}
			
			# Call add_score with the dictionary
			leaderboard.add_score(score_entry)
			print("   ✓ Score saved to leaderboard!")
		else:
			print("   ⚠️ LeaderboardManager.add_score() not found")
	else:
		print("   ℹ️ LeaderboardManager not found")

func animate_results():
	"""Animate the results appearing"""
	if not panel:
		return
	
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.8, 0.8)
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "modulate:a", 1.0, 0.5)
	tween.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	print("✓ Results animated in")

func _on_retry_pressed():
	"""Retry the same song"""
	print("\n🔄 Retrying song...")
	
	# Reset GameManager if it has reset_game method
	if GameManager.has_method("reset_game"):
		GameManager.reset_game()
	else:
		# Manually reset if method doesn't exist
		GameManager.game_score = 0
		GameManager.perfect_count = 0
		GameManager.good_count = 0
		GameManager.miss_count = 0
	
	# Metadata persists, so song info will still be available
	# Go back to gameplay
	get_tree().change_scene_to_file("res://scenes/Gameplay.tscn")

func _on_menu_pressed():
	"""Return to main menu"""
	print("\n🏠 Returning to main menu...")
	
	# Reset GameManager if it has reset_game method
	if GameManager.has_method("reset_game"):
		GameManager.reset_game()
	else:
		# Manually reset if method doesn't exist
		GameManager.game_score = 0
		GameManager.perfect_count = 0
		GameManager.good_count = 0
		GameManager.miss_count = 0
	
	# Go to main menu
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
