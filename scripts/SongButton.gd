# SongButton.gd
# Individual button for a song in the selection screen
extends PanelContainer

signal song_selected(song: Dictionary)
signal song_hovered(song: Dictionary)
signal song_unhovered(song: Dictionary)

# UI References
@onready var title_label = $HBox/InfoVBox/TitleLabel
@onready var artist_label = $HBox/InfoVBox/ArtistLabel
@onready var genre_label = $HBox/InfoVBox/GenreLabel
@onready var stats_label = $HBox/StatsVBox/StatsLabel
@onready var cover_texture = $HBox/CoverTexture
@onready var button = $Button

# Song data
var song_data: Dictionary = {}

# Visual settings
var normal_style: StyleBox
var hover_style: StyleBox

func _ready():
	setup_styles()
	connect_signals()

func setup_styles():
	"""Setup visual styles for hover effect"""
	# Create normal style
	normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.2, 0.2, 0.25, 0.8)
	normal_style.border_color = Color(0.4, 0.4, 0.5)
	normal_style.set_border_width_all(2)
	normal_style.corner_radius_top_left = 8
	normal_style.corner_radius_top_right = 8
	normal_style.corner_radius_bottom_left = 8
	normal_style.corner_radius_bottom_right = 8
	
	# Create hover style
	hover_style = StyleBoxFlat.new()
	hover_style.bg_color = Color(0.3, 0.35, 0.4, 0.9)
	hover_style.border_color = Color(0.5, 0.7, 1.0)
	hover_style.set_border_width_all(3)
	hover_style.corner_radius_top_left = 8
	hover_style.corner_radius_top_right = 8
	hover_style.corner_radius_bottom_left = 8
	hover_style.corner_radius_bottom_right = 8
	
	add_theme_stylebox_override("panel", normal_style)

func connect_signals():
	"""Connect button signals"""
	if button:
		button.pressed.connect(_on_button_pressed)
		button.mouse_entered.connect(_on_mouse_entered)
		button.mouse_exited.connect(_on_mouse_exited)

func set_song_data(song: Dictionary):
	"""Set the song data and update display"""
	song_data = song
	update_display()

func update_display():
	"""Update all labels and visuals"""
	if song_data.is_empty():
		return
	
	# Title
	if title_label:
		title_label.text = song_data.get("title", "Unknown Song")
	
	# Artist
	if artist_label:
		artist_label.text = song_data.get("artist", "Unknown Artist")
	
	# Genre
	if genre_label:
		var genre = song_data.get("genre", "Unknown")
		var difficulty = song_data.get("difficulty", 3)
		genre_label.text = "%s | ★ %d" % [genre, difficulty]
	
	# Stats
	if stats_label:
		var bpm = song_data.get("bpm", 120)
		var duration = song_data.get("duration", 0.0)
		var duration_str = format_duration(duration)
		stats_label.text = "BPM: %d | %s" % [bpm, duration_str]
	
	# Cover image
	load_cover_image()

func load_cover_image():
	"""Load and display cover image if available"""
	if not cover_texture:
		return
	
	var song_folder = SongDatabase.SONGS_DIR + song_data.get("folder", "") + "/"
	
	# Try PNG first
	var cover_path = song_folder + "cover.png"
	if not FileAccess.file_exists(cover_path):
		# Try JPG
		cover_path = song_folder + "cover.jpg"
	
	if FileAccess.file_exists(cover_path):
		var texture = load(cover_path)
		if texture:
			cover_texture.texture = texture
	else:
		# Use default/placeholder
		create_placeholder_cover()

func create_placeholder_cover():
	"""Create a simple colored placeholder if no cover exists"""
	if not cover_texture:
		return
	
	# Create a simple colored rectangle as placeholder
	var image = Image.create(128, 128, false, Image.FORMAT_RGB8)
	image.fill(Color(0.3, 0.3, 0.4))
	
	var texture = ImageTexture.create_from_image(image)
	cover_texture.texture = texture

func format_duration(seconds: float) -> String:
	"""Format duration as MM:SS"""
	var minutes = int(seconds) / 60
	var secs = int(seconds) % 60
	return "%d:%02d" % [minutes, secs]

# === SIGNAL HANDLERS ===

func _on_button_pressed():
	"""Handle button click"""
	song_selected.emit(song_data)

func _on_mouse_entered():
	"""Handle mouse hover"""
	add_theme_stylebox_override("panel", hover_style)
	song_hovered.emit(song_data)

func _on_mouse_exited():
	"""Handle mouse exit"""
	add_theme_stylebox_override("panel", normal_style)
	song_unhovered.emit(song_data)
