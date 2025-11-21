# ResultsScreen.gd
extends Control

@onready var total_score_label = $Panel/VBoxContainer/TotalScore
@onready var perfect_label = $Panel/VBoxContainer/Stats/PerfectLabel
@onready var good_label = $Panel/VBoxContainer/Stats/GoodLabel
@onready var miss_label = $Panel/VBoxContainer/Stats/MissLabel
@onready var accuracy_label = $Panel/VBoxContainer/AccuracyLabel
@onready var recommendation_container = $Panel/VBoxContainer/RecommendationPanel/RecommendationList
@onready var continue_button = $Panel/VBoxContainer/Buttons/ContinueButton
@onready var replay_button = $Panel/VBoxContainer/Buttons/ReplayButton
@onready var menu_button = $Panel/VBoxContainer/Buttons/MenuButton

var spectral_analyzer: Node

func _ready():
	display_results()
	generate_recommendations()
	
	continue_button.pressed.connect(_on_continue_pressed)
	replay_button.pressed.connect(_on_replay_pressed)
	menu_button.pressed.connect(_on_menu_pressed)

func display_results():
	total_score_label.text = "Total Score: %d" % GameManager.game_score
	perfect_label.text = "Perfect: %d" % GameManager.perfect_count
	good_label.text = "Good: %d" % GameManager.good_count
	miss_label.text = "Miss: %d" % GameManager.miss_count
	
	var total_notes = GameManager.perfect_count + GameManager.good_count + GameManager.miss_count
	var accuracy = 0.0
	if total_notes > 0:
		accuracy = (GameManager.perfect_count + GameManager.good_count * 0.5) / float(total_notes) * 100.0
	
	accuracy_label.text = "Accuracy: %.1f%%" % accuracy

func generate_recommendations():
	spectral_analyzer = load("res://scripts/SpectralAnalyzer.gd").new()
	add_child(spectral_analyzer)
	
	# Analyze player's timbre
	var player_timbre = calculate_player_timbre()
	
	# Compare with all songs
	var recommendations = []
	for song in SongDatabase.songs:
		if song == GameManager.current_song:
			continue
		
		var song_timbre = get_song_timbre(song)
		if song_timbre.is_empty():
			continue
		
		var similarity = spectral_analyzer.compare_timbre(player_timbre, song_timbre)
		recommendations.append({
			"song": song,
			"similarity": similarity
		})
	
	# Sort by similarity
	recommendations.sort_custom(func(a, b): return a["similarity"] > b["similarity"])
	
	# Display top 3 recommendations
	for i in range(min(3, recommendations.size())):
		var rec = recommendations[i]
		var label = Label.new()
		label.text = "%s - %s (%.0f%% match)" % [
			rec["song"]["title"],
			rec["song"]["artist"],
			rec["similarity"] * 100
		]
		recommendation_container.add_child(label)

func calculate_player_timbre() -> Dictionary:
	# Simplified timbre calculation from player's pitch history
	if GameManager.player_timbre_data.is_empty():
		return {"average_centroid": 2000.0, "centroid_variance": 1000.0}
	
	# This is a placeholder - in production, you'd calculate actual spectral centroid
	var avg_freq = 0.0
	var count = 0
	
	for segment in GameManager.player_timbre_data:
		for note_data in segment:
			if note_data.has("frequency"):
				avg_freq += note_data["frequency"]
				count += 1
	
	if count > 0:
		avg_freq /= count
	
	return {
		"average_centroid": avg_freq * 2.5,  # Rough approximation
		"centroid_variance": 1000.0
	}

func get_song_timbre(song: Dictionary) -> Dictionary:
	# Load pre-analyzed timbre data or calculate on-the-fly
	var timbre_path = SongDatabase.SONGS_DIR + song["folder"] + "/timbre.json"
	
	if FileAccess.file_exists(timbre_path):
		var file = FileAccess.open(timbre_path, FileAccess.READ)
		var json = JSON.new()
		json.parse(file.get_as_text())
		file.close()
		return json.data
	
	# Default timbre if not pre-analyzed
	return {"average_centroid": 2500.0, "centroid_variance": 1200.0}

func _on_continue_pressed():
	get_tree().change_scene_to_file("res://scenes/SongSelection.tscn")

func _on_replay_pressed():
	GameManager.reset_game_stats()
	get_tree().change_scene_to_file("res://scenes/Gameplay.tscn")

func _on_menu_pressed():
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
