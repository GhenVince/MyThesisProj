# SongSelection.gd
# Song selection screen with search, filters, and preview playback
extends Control

# UI References
@onready var song_list_container = $Panel/VBox/ScrollContainer/SongList
@onready var search_box = $Panel/VBox/TopBar/SearchBox
@onready var genre_filter = $Panel/VBox/TopBar/GenreFilter
@onready var artist_filter = $Panel/VBox/TopBar/ArtistFilter
@onready var sort_option = $Panel/VBox/TopBar/SortOption
@onready var back_button = $Panel/VBox/TopBar/BackButton

# Preview playback
@onready var preview_player = $PreviewPlayer

# Song button scene
var song_button_scene = preload("res://scenes/SongButton.tscn")

# Current filters
var current_search: String = ""
var current_genre: String = "All"
var current_artist: String = "All"
var current_sort: String = "Title"

# Currently playing preview
var current_preview_song: Dictionary = {}

func _ready():
	setup_ui()
	setup_filters()
	connect_signals()
	load_songs()

func setup_ui():
	"""Initialize UI elements"""
	if not preview_player:
		preview_player = AudioStreamPlayer.new()
		preview_player.bus = "Music"
		add_child(preview_player)

func setup_filters():
	"""Setup filter dropdowns"""
	# Genre filter
	if genre_filter:
		genre_filter.clear()
		genre_filter.add_item("All")
		for genre in SongDatabase.genres:
			genre_filter.add_item(genre)
	
	# Artist filter
	if artist_filter:
		artist_filter.clear()
		artist_filter.add_item("All")
		for artist in SongDatabase.artists:
			artist_filter.add_item(artist)
	
	# Sort options
	if sort_option:
		sort_option.clear()
		sort_option.add_item("Title")
		sort_option.add_item("Artist")
		sort_option.add_item("BPM")
		sort_option.add_item("Difficulty")
		sort_option.add_item("Recently Added")

func connect_signals():
	"""Connect UI signals"""
	if search_box:
		search_box.text_changed.connect(_on_search_changed)
	
	if genre_filter:
		genre_filter.item_selected.connect(_on_genre_selected)
	
	if artist_filter:
		artist_filter.item_selected.connect(_on_artist_selected)
	
	if sort_option:
		sort_option.item_selected.connect(_on_sort_changed)
	
	if back_button:
		back_button.pressed.connect(_on_back_pressed)

func load_songs():
	"""Load and display all songs"""
	# Clear existing buttons
	clear_song_list()
	
	# Get filtered songs
	var songs = get_filtered_songs()
	
	# Sort songs
	songs = sort_songs(songs)
	
	# Create buttons for each song
	for song in songs:
		create_song_button(song)
	
	# If no songs found, show message
	if songs.is_empty():
		show_no_songs_message()

func clear_song_list():
	"""Remove all song buttons"""
	if not song_list_container:
		return
	
	for child in song_list_container.get_children():
		child.queue_free()

func get_filtered_songs() -> Array:
	"""Get songs based on current filters"""
	var songs = SongDatabase.songs.duplicate()
	
	# Apply search
	if not current_search.is_empty():
		songs = SongDatabase.search_songs(current_search)
	
	# Apply genre filter
	if current_genre != "All":
		songs = songs.filter(func(s): return s.get("genre", "") == current_genre)
	
	# Apply artist filter
	if current_artist != "All":
		songs = songs.filter(func(s): return s.get("artist", "") == current_artist)
	
	return songs

func sort_songs(songs: Array) -> Array:
	"""Sort songs based on current sort option"""
	match current_sort:
		"Title":
			songs.sort_custom(func(a, b): return a.get("title", "").to_lower() < b.get("title", "").to_lower())
		"Artist":
			songs.sort_custom(func(a, b): return a.get("artist", "").to_lower() < b.get("artist", "").to_lower())
		"BPM":
			songs.sort_custom(func(a, b): return a.get("bpm", 120) < b.get("bpm", 120))
		"Difficulty":
			songs.sort_custom(func(a, b): return a.get("difficulty", 3) < b.get("difficulty", 3))
		"Recently Added":
			songs.sort_custom(func(a, b): return a.get("date_added", "") > b.get("date_added", ""))
	
	return songs

func create_song_button(song: Dictionary):
	"""Create a button for a song"""
	if not song_button_scene:
		push_error("SongButton scene not found!")
		return
	
	var button = song_button_scene.instantiate()
	song_list_container.add_child(button)
	
	# Set song data
	if button.has_method("set_song_data"):
		button.set_song_data(song)
	
	# Connect signals
	if button.has_signal("song_selected"):
		button.song_selected.connect(_on_song_selected)
	
	if button.has_signal("song_hovered"):
		button.song_hovered.connect(_on_song_hovered)
	
	if button.has_signal("song_unhovered"):
		button.song_unhovered.connect(_on_song_unhovered)

func show_no_songs_message():
	"""Show message when no songs found"""
	var label = Label.new()
	label.text = "No songs found. Try different filters or add songs!"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)
	song_list_container.add_child(label)

# === SIGNAL HANDLERS ===

func _on_search_changed(new_text: String):
	"""Handle search box text change"""
	current_search = new_text
	load_songs()

func _on_genre_selected(index: int):
	"""Handle genre filter change"""
	if genre_filter:
		current_genre = genre_filter.get_item_text(index)
		load_songs()

func _on_artist_selected(index: int):
	"""Handle artist filter change"""
	if artist_filter:
		current_artist = artist_filter.get_item_text(index)
		load_songs()

func _on_sort_changed(index: int):
	"""Handle sort option change"""
	if sort_option:
		current_sort = sort_option.get_item_text(index)
		load_songs()

func _on_song_selected(song: Dictionary):
	"""Handle song selection"""
	stop_preview()
	GameManager.current_song = song
	GameManager.reset_game_stats()
	get_tree().change_scene_to_file("res://scenes/Gameplay.tscn")

func _on_song_hovered(song: Dictionary):
	"""Handle song hover - start preview"""
	if song != current_preview_song:
		play_preview(song)

func _on_song_unhovered(_song: Dictionary):
	"""Handle song unhover"""
	# Don't stop preview immediately, let it play
	pass

func _on_back_pressed():
	"""Return to main menu"""
	stop_preview()
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

# === PREVIEW PLAYBACK ===

func play_preview(song: Dictionary):
	"""Play preview of a song"""
	stop_preview()
	
	var song_folder = SongDatabase.SONGS_DIR + song.get("folder", "") + "/"
	var audio_path = song_folder + "audio.ogg"
	
	if not FileAccess.file_exists(audio_path):
		return
	
	var stream = load(audio_path)
	if stream:
		preview_player.stream = stream
		preview_player.volume_db = -10.0  # Quieter preview
		preview_player.play()
		current_preview_song = song

func stop_preview():
	"""Stop current preview"""
	if preview_player and preview_player.playing:
		preview_player.stop()
	current_preview_song = {}

func _exit_tree():
	"""Cleanup when leaving scene"""
	stop_preview()
