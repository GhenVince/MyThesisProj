# SongButton.gd
extends PanelContainer

@onready var title_label = $MarginContainer/HBoxContainer/VBoxContainer/TitleLabel
@onready var artist_label = $MarginContainer/HBoxContainer/VBoxContainer/ArtistLabel
@onready var genre_label = $MarginContainer/HBoxContainer/VBoxContainer/GenreLabel
@onready var duration_label = $MarginContainer/HBoxContainer/DurationLabel
@onready var album_art = $MarginContainer/HBoxContainer/AlbumArt

signal song_selected(song_data: Dictionary)
signal song_hovered(song_data: Dictionary)
signal song_unhovered()

var song_data: Dictionary = {}

func setup(song: Dictionary):
	song_data = song
	title_label.text = song.get("title", "Unknown")
	artist_label.text = song.get("artist", "Unknown Artist")
	genre_label.text = song.get("genre", "Unknown Genre")
	
	var duration = song.get("duration", 0.0)
	var minutes = int(duration / 60)
	var seconds = int(duration) % 60
	duration_label.text = "%d:%02d" % [minutes, seconds]
	
	# Load album art if it exists
	var art_path = "res://songs/" + song.get("folder", "") + "/cover.png"
	if FileAccess.file_exists(art_path):
		album_art.texture = load(art_path)

func _gui_input(event):
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			song_selected.emit(song_data)

func _on_mouse_entered():
	song_hovered.emit(song_data)

func _on_mouse_exited():
	song_unhovered.emit()
