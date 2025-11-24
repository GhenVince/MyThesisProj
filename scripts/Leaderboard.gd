# Leaderboard.gd
# Leaderboard display with sorting and filtering
extends Control

# UI References
@onready var leaderboard_list = $Panel/VBox/ScrollContainer/LeaderboardList
@onready var sort_option = $Panel/VBox/TopBar/SortOption
@onready var filter_option = $Panel/VBox/TopBar/FilterOption
@onready var stats_panel = $Panel/VBox/StatsPanel
@onready var back_button = $Panel/VBox/TopBar/BackButton
@onready var clear_button = $Panel/VBox/TopBar/ClearButton

# Stats labels
@onready var total_plays_label = $Panel/VBox/StatsPanel/Grid/TotalPlaysLabel
@onready var average_accuracy_label = $Panel/VBox/StatsPanel/Grid/AverageAccuracyLabel
@onready var highest_score_label = $Panel/VBox/StatsPanel/Grid/HighestScoreLabel
@onready var favorite_song_label = $Panel/VBox/StatsPanel/Grid/FavoriteSongLabel

# Current settings
var current_sort: String = "Score"
var current_filter: String = "All Songs"

# Safe access to LeaderboardManager
var leaderboard_manager: Node = null

# Entry colors
var rank_colors = {
	"S": Color(1.0, 0.84, 0.0),  # Gold
	"A": Color(0.0, 1.0, 0.5),   # Green
	"B": Color(0.3, 0.7, 1.0),   # Blue
	"C": Color(1.0, 0.6, 0.0),   # Orange
	"D": Color(1.0, 0.3, 0.3),   # Red
	"F": Color(0.5, 0.5, 0.5)    # Gray
}

func _ready():
	# Get LeaderboardManager reference safely
	if has_node("/root/LeaderboardManager"):
		leaderboard_manager = get_node("/root/LeaderboardManager")
	else:
		push_error("LeaderboardManager AutoLoad not found! Please add it in Project Settings → Autoload")
		show_autoload_error()
		return
	
	setup_filters()
	connect_signals()
	update_statistics()
	load_leaderboard()

func show_autoload_error():
	"""Show error message when AutoLoad is missing"""
	clear_leaderboard_list()
	var error_label = Label.new()
	error_label.text = "ERROR: LeaderboardManager not configured!\n\nGo to:\nProject → Project Settings → Autoload\nAdd: res://scripts/LeaderboardManager.gd as 'LeaderboardManager'"
	error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	error_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	error_label.add_theme_font_size_override("font_size", 20)
	error_label.add_theme_color_override("font_color", Color.RED)
	error_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	if leaderboard_list:
		leaderboard_list.add_child(error_label)

func setup_filters():
	"""Setup sort and filter options"""
	# Sort options
	if sort_option:
		sort_option.clear()
		sort_option.add_item("Score (Highest)")
		sort_option.add_item("Accuracy (Highest)")
		sort_option.add_item("Recent (Newest)")
		sort_option.add_item("Perfect Hits")
		sort_option.add_item("Song Name")
	
	# Filter options - All songs + individual songs
	if filter_option:
		filter_option.clear()
		filter_option.add_item("All Songs")
		
		# Add each unique song
		var songs_seen = {}
		for entry in leaderboard_manager.scores:
			var song_name = entry.get("song", "")
			if not song_name.is_empty() and not songs_seen.has(song_name):
				filter_option.add_item(song_name)
				songs_seen[song_name] = true

func connect_signals():
	"""Connect UI signals"""
	if sort_option:
		sort_option.item_selected.connect(_on_sort_changed)
	
	if filter_option:
		filter_option.item_selected.connect(_on_filter_changed)
	
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	
	if clear_button:
		clear_button.pressed.connect(_on_clear_pressed)

# === LEADERBOARD DISPLAY ===

func load_leaderboard():
	"""Load and display leaderboard entries"""
	clear_leaderboard_list()
	
	# Get filtered entries
	var entries = get_filtered_entries()
	
	# Sort entries
	entries = sort_entries(entries)
	
	# Display entries
	var rank = 1
	for entry in entries:
		create_leaderboard_entry(entry, rank)
		rank += 1
	
	# Show message if empty
	if entries.is_empty():
		show_empty_message()

func clear_leaderboard_list():
	"""Remove all entries"""
	if not leaderboard_list:
		return
	
	for child in leaderboard_list.get_children():
		child.queue_free()

func get_filtered_entries() -> Array:
	"""Get entries based on current filter"""
	if current_filter == "All Songs":
		return leaderboard_manager.get_all_scores()
	else:
		return leaderboard_manager.get_scores_for_song(current_filter)

func sort_entries(entries: Array) -> Array:
	"""Sort entries based on current sort option"""
	match current_sort:
		"Score (Highest)":
			entries.sort_custom(func(a, b): return a.get("score", 0) > b.get("score", 0))
		"Accuracy (Highest)":
			entries.sort_custom(func(a, b): return a.get("accuracy", 0.0) > b.get("accuracy", 0.0))
		"Recent (Newest)":
			entries.sort_custom(func(a, b): return a.get("date", "") > b.get("date", ""))
		"Perfect Hits":
			entries.sort_custom(func(a, b): return a.get("perfect", 0) > b.get("perfect", 0))
		"Song Name":
			entries.sort_custom(func(a, b): return a.get("song", "").to_lower() < b.get("song", "").to_lower())
	
	return entries

func create_leaderboard_entry(entry: Dictionary, rank: int):
	"""Create a visual entry for the leaderboard"""
	var entry_container = PanelContainer.new()
	
	# Style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.25, 0.6) if rank % 2 == 0 else Color(0.25, 0.25, 0.3, 0.6)
	style.set_content_margin_all(10)
	entry_container.add_theme_stylebox_override("panel", style)
	
	# Layout
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 15)
	entry_container.add_child(hbox)
	
	# Rank
	var rank_label = Label.new()
	rank_label.text = "#%d" % rank
	rank_label.custom_minimum_size = Vector2(50, 0)
	rank_label.add_theme_font_size_override("font_size", 20)
	rank_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	hbox.add_child(rank_label)
	
	# Rank badge
	var rank_badge = Label.new()
	rank_badge.text = entry.get("rank", "F")
	rank_badge.custom_minimum_size = Vector2(40, 0)
	rank_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank_badge.add_theme_font_size_override("font_size", 24)
	var badge_color = rank_colors.get(entry.get("rank", "F"), Color.GRAY)
	rank_badge.add_theme_color_override("font_color", badge_color)
	hbox.add_child(rank_badge)
	
	# Song info
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var song_label = Label.new()
	song_label.text = entry.get("song", "Unknown")
	song_label.add_theme_font_size_override("font_size", 18)
	info_vbox.add_child(song_label)
	
	var artist_label = Label.new()
	artist_label.text = entry.get("artist", "Unknown Artist")
	artist_label.add_theme_font_size_override("font_size", 14)
	artist_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	info_vbox.add_child(artist_label)
	
	hbox.add_child(info_vbox)
	
	# Stats
	var stats_vbox = VBoxContainer.new()
	stats_vbox.custom_minimum_size = Vector2(200, 0)
	
	var score_label = Label.new()
	score_label.text = "Score: %s" % leaderboard_manager.format_score(entry.get("score", 0))
	score_label.add_theme_font_size_override("font_size", 16)
	stats_vbox.add_child(score_label)
	
	var accuracy_label = Label.new()
	accuracy_label.text = "Accuracy: %.1f%%" % entry.get("accuracy", 0.0)
	accuracy_label.add_theme_font_size_override("font_size", 14)
	stats_vbox.add_child(accuracy_label)
	
	var hits_label = Label.new()
	hits_label.text = "P:%d G:%d M:%d" % [
		entry.get("perfect", 0),
		entry.get("good", 0),
		entry.get("miss", 0)
	]
	hits_label.add_theme_font_size_override("font_size", 12)
	hits_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	stats_vbox.add_child(hits_label)
	
	hbox.add_child(stats_vbox)
	
	# Date
	var date_label = Label.new()
	date_label.text = format_date(entry.get("date", ""))
	date_label.custom_minimum_size = Vector2(150, 0)
	date_label.add_theme_font_size_override("font_size", 12)
	date_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	hbox.add_child(date_label)
	
	leaderboard_list.add_child(entry_container)

func show_empty_message():
	"""Show message when no entries"""
	var label = Label.new()
	label.text = "No scores yet. Play some songs!"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)
	leaderboard_list.add_child(label)

# === STATISTICS ===

func update_statistics():
	"""Update statistics panel"""
	if not stats_panel or not leaderboard_manager:
		return
	
	# Total plays
	if total_plays_label:
		var total = leaderboard_manager.get_total_plays()
		total_plays_label.text = "Total Plays: %d" % total
	
	# Average accuracy
	if average_accuracy_label:
		var avg = leaderboard_manager.get_average_accuracy()
		average_accuracy_label.text = "Average Accuracy: %.1f%%" % avg
	
	# Highest score
	if highest_score_label:
		var highest = leaderboard_manager.get_highest_score()
		if not highest.is_empty():
			highest_score_label.text = "Highest Score: %s" % leaderboard_manager.format_score(highest.get("score", 0))
		else:
			highest_score_label.text = "Highest Score: --"
	
	# Favorite song
	if favorite_song_label:
		var favorite = leaderboard_manager.get_favorite_song()
		if not favorite.is_empty():
			favorite_song_label.text = "Favorite Song: %s" % favorite
		else:
			favorite_song_label.text = "Favorite Song: --"

# === SIGNAL HANDLERS ===

func _on_sort_changed(index: int):
	"""Handle sort option change"""
	if sort_option:
		current_sort = sort_option.get_item_text(index)
		load_leaderboard()

func _on_filter_changed(index: int):
	"""Handle filter option change"""
	if filter_option:
		current_filter = filter_option.get_item_text(index)
		load_leaderboard()

func _on_back_pressed():
	"""Return to main menu"""
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _on_clear_pressed():
	"""Clear all leaderboard data (with confirmation)"""
	# Create confirmation dialog
	var dialog = ConfirmationDialog.new()
	dialog.dialog_text = "Are you sure you want to clear ALL leaderboard data?\nThis cannot be undone!"
	dialog.title = "Clear Leaderboard"
	add_child(dialog)
	
	dialog.confirmed.connect(_on_clear_confirmed)
	dialog.popup_centered()

func _on_clear_confirmed():
	"""Actually clear the leaderboard"""
	if leaderboard_manager:
		leaderboard_manager.clear_all_scores()
		update_statistics()
		load_leaderboard()
		setup_filters()  # Refresh filter list

# === UTILITY ===

func format_date(date_string: String) -> String:
	"""Format date string to be more readable"""
	if date_string.is_empty():
		return "Unknown"
	
	# Parse format: "2024-01-15 14:30:25"
	var parts = date_string.split(" ")
	if parts.size() >= 2:
		var date_part = parts[0]
		var time_part = parts[1]
		
		# Format as "Jan 15, 2024"
		var date_components = date_part.split("-")
		if date_components.size() == 3:
			var months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
			var month_idx = int(date_components[1]) - 1
			if month_idx >= 0 and month_idx < 12:
				return "%s %s, %s" % [months[month_idx], date_components[2], date_components[0]]
	
	return date_string
