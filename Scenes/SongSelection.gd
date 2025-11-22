# SongSelection.gd
extends Control

@onready var song_list = $UI/VBoxContainer/ScrollContainer/SongList
@onready var search_bar = $UI/VBoxContainer/Topbar/SearchBar
@onready var genre_filter = $UI/VBoxContainer/Topbar/GenreFilter
@onready var preview_player = $UI/VBoxContainer/PreviewPlayer
@onready var back_button = $UI/VBoxContainer/Topbar/BackButton

var current_preview_song: Dictionary = {}
var preview_tween: Tween

func _ready():
	populate_song_list()
	setup_filters()
	
	search_bar.text_changed.connect(_on_search_changed)
	genre_filter.item_selected.connect(_on_genre_selected)
	back_button.pressed.connect(_on_back_pressed)

func setup_filters():
	genre_filter.clear()
	genre_filter.add_item("All Genres")
	
	var genres = []
	for song in SongDatabase.songs:
		var genre = song.get("genre", "Unknown")
		if genre not in genres:
			genres.append(genre)
	
	genres.sort()
	for genre in genres:
		genre_filter.add_item(genre)

func populate_song_list(filter_songs: Array = []):
	# Clear existing buttons
	for child in song_list.get_children():
		child.queue_free()
	
	var songs_to_show = filter_songs if filter_songs.size() > 0 else SongDatabase.songs
	
	for song in songs_to_show:
		var button = create_song_button(song)
		song_list.add_child(button)

func create_song_button(song: Dictionary) -> Button:
	var button = Button.new()
	button.text = "%s - %s" % [song.get("title", "Unknown"), song.get("artist", "Unknown")]
	button.custom_minimum_size = Vector2(0, 60)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	
	# Store song data in metadata
	button.set_meta("song_data", song)
	
	# Connect signals
	button.pressed.connect(_on_song_selected.bind(song))
	button.mouse_entered.connect(_on_song_hover.bind(song))
	button.mouse_exited.connect(_on_song_unhover)
	
	return button

func _on_song_hover(song: Dictionary):
	# Start preview after short delay
	if preview_tween:
		preview_tween.kill()
	
	preview_tween = create_tween()
	preview_tween.tween_callback(func(): play_preview(song)).set_delay(0.3)

func _on_song_unhover():
	if preview_tween:
		preview_tween.kill()
	stop_preview()

func play_preview(song: Dictionary):
	if current_preview_song == song:
		return
	
	current_preview_song = song
	var preview_path = SongDatabase.SONGS_DIR + song["folder"] + "/preview.ogg"
	
	if not FileAccess.file_exists(preview_path):
		preview_path = SongDatabase.SONGS_DIR + song["folder"] + "/audio.ogg"
	
	if FileAccess.file_exists(preview_path):
		var audio_stream = load(preview_path)
		preview_player.stream = audio_stream
		preview_player.play()

func stop_preview():
	preview_player.stop()
	current_preview_song = {}

func _on_song_selected(song: Dictionary):
	stop_preview()
	GameManager.current_song = song
	GameManager.reset_game_stats()
	get_tree().change_scene_to_file("res://scenes/Gameplay.tscn")

func _on_search_changed(text: String):
	if text.is_empty():
		populate_song_list()
	else:
		var filtered = SongDatabase.search_songs(text)
		populate_song_list(filtered)

func _on_genre_selected(index: int):
	var genre = genre_filter.get_item_text(index)
	if genre == "All Genres":
		populate_song_list()
	else:
		var filtered = SongDatabase.get_songs_by_genre(genre)
		populate_song_list(filtered)

func _on_back_pressed():
	stop_preview()
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
