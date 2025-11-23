# SongManagerTool.gd
# STANDALONE TOOL FOR ADDING SONGS TO YOUR KARAOKE GAME
# This creates a user-friendly interface for adding new songs
extends Control

# UI References
@onready var title_edit = $Panel/ScrollContainer/VBox/BasicInfo/TitleEdit
@onready var artist_edit = $Panel/ScrollContainer/VBox/BasicInfo/ArtistEdit
@onready var genre_edit = $Panel/ScrollContainer/VBox/BasicInfo/GenreEdit
@onready var bpm_spin = $Panel/ScrollContainer/VBox/BasicInfo/BPMSpin
@onready var difficulty_spin = $Panel/ScrollContainer/VBox/BasicInfo/DifficultySpin
@onready var duration_edit = $Panel/ScrollContainer/VBox/BasicInfo/DurationEdit

@onready var audio_path_label = $Panel/ScrollContainer/VBox/Files/AudioPath
@onready var vocal_path_label = $Panel/ScrollContainer/VBox/Files/VocalPath
@onready var cover_path_label = $Panel/ScrollContainer/VBox/Files/CoverPath

@onready var lyrics_text = $Panel/ScrollContainer/VBox/Lyrics/LyricsTextEdit
@onready var status_label = $Panel/ScrollContainer/VBox/Status/StatusLabel
@onready var progress_bar = $Panel/ScrollContainer/VBox/Status/ProgressBar

# File paths
var audio_file_path: String = ""
var vocal_file_path: String = ""
var cover_file_path: String = ""

# File dialogs
var audio_dialog: FileDialog
var vocal_dialog: FileDialog
var cover_dialog: FileDialog

const SONGS_DIR = "res://songs/"

func _ready():
	setup_ui()
	setup_file_dialogs()
	connect_signals()

func setup_ui():
	"""Initialize UI elements"""
	progress_bar.hide()
	status_label.text = "Ready to add a new song"
	
	# Set default values
	bpm_spin.value = 120
	difficulty_spin.value = 3
	duration_edit.text = "0:00"

func setup_file_dialogs():
	"""Create file selection dialogs"""
	# Audio file dialog
	audio_dialog = FileDialog.new()
	audio_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	audio_dialog.access = FileDialog.ACCESS_FILESYSTEM
	audio_dialog.filters = PackedStringArray(["*.ogg ; OGG Audio", "*.mp3 ; MP3 Audio", "*.wav ; WAV Audio"])
	audio_dialog.title = "Select Main Audio File"
	add_child(audio_dialog)
	audio_dialog.file_selected.connect(_on_audio_file_selected)
	
	# Vocal file dialog
	vocal_dialog = FileDialog.new()
	vocal_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	vocal_dialog.access = FileDialog.ACCESS_FILESYSTEM
	vocal_dialog.filters = PackedStringArray(["*.ogg ; OGG Audio", "*.mp3 ; MP3 Audio", "*.wav ; WAV Audio"])
	vocal_dialog.title = "Select Isolated Vocals (Optional)"
	add_child(vocal_dialog)
	vocal_dialog.file_selected.connect(_on_vocal_file_selected)
	
	# Cover image dialog
	cover_dialog = FileDialog.new()
	cover_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	cover_dialog.access = FileDialog.ACCESS_FILESYSTEM
	cover_dialog.filters = PackedStringArray(["*.png ; PNG Images", "*.jpg ; JPEG Images"])
	cover_dialog.title = "Select Cover Image (Optional)"
	add_child(cover_dialog)
	cover_dialog.file_selected.connect(_on_cover_file_selected)

func connect_signals():
	"""Connect button signals"""
	$Panel/ScrollContainer/VBox/Files/BrowseAudioBtn.pressed.connect(_on_browse_audio_pressed)
	$Panel/ScrollContainer/VBox/Files/BrowseVocalBtn.pressed.connect(_on_browse_vocal_pressed)
	$Panel/ScrollContainer/VBox/Files/BrowseCoverBtn.pressed.connect(_on_browse_cover_pressed)
	
	$Panel/ScrollContainer/VBox/Lyrics/ParseLyricsBtn.pressed.connect(_on_parse_lyrics_pressed)
	$Panel/ScrollContainer/VBox/Lyrics/ClearLyricsBtn.pressed.connect(_on_clear_lyrics_pressed)
	
	$Panel/ScrollContainer/VBox/Actions/CreateSongBtn.pressed.connect(_on_create_song_pressed)
	$Panel/ScrollContainer/VBox/Actions/ClearFormBtn.pressed.connect(_on_clear_form_pressed)
	$Panel/ScrollContainer/VBox/Actions/OpenFolderBtn.pressed.connect(_on_open_folder_pressed)

# === FILE SELECTION ===

func _on_browse_audio_pressed():
	audio_dialog.popup_centered(Vector2i(800, 600))

func _on_browse_vocal_pressed():
	vocal_dialog.popup_centered(Vector2i(800, 600))

func _on_browse_cover_pressed():
	cover_dialog.popup_centered(Vector2i(800, 600))

func _on_audio_file_selected(path: String):
	audio_file_path = path
	audio_path_label.text = path.get_file()
	update_status("Audio file selected: " + path.get_file(), Color.GREEN)
	
	# Try to auto-detect duration
	auto_detect_duration(path)

func _on_vocal_file_selected(path: String):
	vocal_file_path = path
	vocal_path_label.text = path.get_file()
	update_status("Vocal file selected: " + path.get_file(), Color.GREEN)

func _on_cover_file_selected(path: String):
	cover_file_path = path
	cover_path_label.text = path.get_file()
	update_status("Cover image selected: " + path.get_file(), Color.GREEN)

# === LYRICS HANDLING ===

func _on_parse_lyrics_pressed():
	"""Help format lyrics with timestamps"""
	var help_text = """
LYRICS FORMAT HELP:
Enter lyrics in this format:

[0.0] First line of lyrics
[5.5] Second line of lyrics
[10.0] Third line of lyrics

- Time in seconds goes in brackets [time]
- One line per lyric
- Times should match the song timing

You can also use simple format (will be auto-timed):
Line 1
Line 2
Line 3

Click 'Create Song' when done.
"""
	update_status(help_text, Color.CYAN)

func _on_clear_lyrics_pressed():
	lyrics_text.text = ""
	update_status("Lyrics cleared", Color.YELLOW)

# === SONG CREATION ===

func _on_create_song_pressed():
	"""Create the song folder and all necessary files"""
	# Validate input
	if not validate_input():
		return
	
	progress_bar.show()
	progress_bar.value = 0
	
	# Create folder name from title (sanitized)
	var folder_name = sanitize_folder_name(title_edit.text)
	var song_folder = SONGS_DIR + folder_name + "/"
	
	# Check if folder exists
	if DirAccess.dir_exists_absolute(song_folder):
		update_status("ERROR: Song folder already exists: " + folder_name, Color.RED)
		progress_bar.hide()
		return
	
	# Create folder
	var dir = DirAccess.open(SONGS_DIR)
	if not dir:
		DirAccess.make_dir_recursive_absolute(SONGS_DIR)
		dir = DirAccess.open(SONGS_DIR)
	
	dir.make_dir(folder_name)
	update_status("Created folder: " + folder_name, Color.CYAN)
	progress_bar.value = 20
	
	# Copy audio files
	if not copy_file(audio_file_path, song_folder + "audio.ogg"):
		return
	progress_bar.value = 40
	
	if not vocal_file_path.is_empty():
		if not copy_file(vocal_file_path, song_folder + "vocals.ogg"):
			update_status("Warning: Failed to copy vocals file", Color.YELLOW)
	progress_bar.value = 50
	
	if not cover_file_path.is_empty():
		var cover_ext = cover_file_path.get_extension()
		if not copy_file(cover_file_path, song_folder + "cover." + cover_ext):
			update_status("Warning: Failed to copy cover image", Color.YELLOW)
	progress_bar.value = 60
	
	# Create metadata.json
	if not create_metadata_file(song_folder, folder_name):
		return
	progress_bar.value = 80
	
	# Create lyrics.json
	if not create_lyrics_file(song_folder):
		return
	progress_bar.value = 100
	
	update_status("SUCCESS! Song created: " + title_edit.text, Color.GREEN)
	
	# Ask if user wants to add another
	await get_tree().create_timer(2.0).timeout
	
	var should_clear = await confirm_dialog("Song added successfully! Clear form to add another song?")
	if should_clear:
		clear_form()
	
	progress_bar.hide()

func validate_input() -> bool:
	"""Check if all required fields are filled"""
	if title_edit.text.is_empty():
		update_status("ERROR: Title is required", Color.RED)
		return false
	
	if artist_edit.text.is_empty():
		update_status("ERROR: Artist is required", Color.RED)
		return false
	
	if audio_file_path.is_empty():
		update_status("ERROR: Audio file is required", Color.RED)
		return false
	
	if not FileAccess.file_exists(audio_file_path):
		update_status("ERROR: Audio file not found: " + audio_file_path, Color.RED)
		return false
	
	if lyrics_text.text.is_empty():
		update_status("ERROR: Lyrics are required", Color.RED)
		return false
	
	return true

func sanitize_folder_name(title: String) -> String:
	"""Create a safe folder name from song title"""
	var safe_name = title.to_lower()
	safe_name = safe_name.replace(" ", "_")
	safe_name = safe_name.replace("/", "_")
	safe_name = safe_name.replace("\\", "_")
	safe_name = safe_name.replace(":", "_")
	safe_name = safe_name.replace("*", "_")
	safe_name = safe_name.replace("?", "_")
	safe_name = safe_name.replace("\"", "_")
	safe_name = safe_name.replace("<", "_")
	safe_name = safe_name.replace(">", "_")
	safe_name = safe_name.replace("|", "_")
	return safe_name

func copy_file(source: String, destination: String) -> bool:
	"""Copy a file from source to destination"""
	var source_file = FileAccess.open(source, FileAccess.READ)
	if not source_file:
		update_status("ERROR: Cannot read source file: " + source, Color.RED)
		return false
	
	var content = source_file.get_buffer(source_file.get_length())
	source_file.close()
	
	var dest_file = FileAccess.open(destination, FileAccess.WRITE)
	if not dest_file:
		update_status("ERROR: Cannot write to: " + destination, Color.RED)
		return false
	
	dest_file.store_buffer(content)
	dest_file.close()
	
	update_status("Copied: " + source.get_file() + " → " + destination.get_file(), Color.GREEN)
	return true

func create_metadata_file(song_folder: String, folder_name: String) -> bool:
	"""Create the metadata.json file"""
	var metadata = {
		"title": title_edit.text,
		"artist": artist_edit.text,
		"genre": genre_edit.text if not genre_edit.text.is_empty() else "Unknown",
		"bpm": int(bpm_spin.value),
		"difficulty": int(difficulty_spin.value),
		"duration": parse_duration(duration_edit.text),
		"folder": folder_name,
		"date_added": Time.get_date_string_from_system()
	}
	
	var file = FileAccess.open(song_folder + "metadata.json", FileAccess.WRITE)
	if not file:
		update_status("ERROR: Cannot create metadata.json", Color.RED)
		return false
	
	file.store_string(JSON.stringify(metadata, "\t"))
	file.close()
	
	update_status("Created metadata.json", Color.GREEN)
	return true

func create_lyrics_file(song_folder: String) -> bool:
	"""Create the lyrics.json file"""
	var lyrics_lines = lyrics_text.text.split("\n")
	var lyrics_array = []
	
	for line in lyrics_lines:
		if line.strip_edges().is_empty():
			continue
		
		var lyric_entry = parse_lyric_line(line)
		if not lyric_entry.is_empty():
			lyrics_array.append(lyric_entry)
	
	# If no timestamps, auto-generate based on BPM
	if lyrics_array.is_empty() or not lyrics_array[0].has("time"):
		lyrics_array = auto_time_lyrics(lyrics_lines)
	
	var file = FileAccess.open(song_folder + "lyrics.json", FileAccess.WRITE)
	if not file:
		update_status("ERROR: Cannot create lyrics.json", Color.RED)
		return false
	
	file.store_string(JSON.stringify(lyrics_array, "\t"))
	file.close()
	
	update_status("Created lyrics.json with %d lines" % lyrics_array.size(), Color.GREEN)
	return true

func parse_lyric_line(line: String) -> Dictionary:
	"""Parse a lyric line like '[5.5] Lyric text' """
	line = line.strip_edges()
	
	# Check if line has timestamp format [time]
	if line.begins_with("["):
		var bracket_end = line.find("]")
		if bracket_end > 0:
			var time_str = line.substr(1, bracket_end - 1)
			var text = line.substr(bracket_end + 1).strip_edges()
			
			if time_str.is_valid_float():
				return {
					"time": float(time_str),
					"text": text
				}
	
	# No timestamp format
	return {}

func auto_time_lyrics(lines: Array) -> Array:
	"""Automatically time lyrics based on BPM"""
	var result = []
	var bpm = bpm_spin.value
	var seconds_per_beat = 60.0 / bpm
	var beats_per_line = 4.0  # Assume 4 beats per lyric line
	
	var current_time = 0.0
	
	for line in lines:
		if line.strip_edges().is_empty():
			continue
		
		result.append({
			"time": current_time,
			"text": line.strip_edges()
		})
		
		current_time += seconds_per_beat * beats_per_line
	
	return result

func parse_duration(duration_str: String) -> float:
	"""Parse duration string like '3:45' to seconds"""
	var parts = duration_str.split(":")
	if parts.size() == 2:
		var minutes = parts[0].to_int()
		var seconds = parts[1].to_int()
		return minutes * 60.0 + seconds
	return 0.0

func auto_detect_duration(audio_path: String):
	"""Try to detect audio duration (simplified version)"""
	# This is a placeholder - in a real implementation you'd use
	# AudioStreamPlayer to load and check the stream length
	update_status("Note: Please enter duration manually (format: MM:SS)", Color.YELLOW)

# === UI HELPERS ===

func update_status(message: String, color: Color = Color.WHITE):
	"""Update status label"""
	status_label.text = message
	status_label.modulate = color
	print(message)

func _on_clear_form_pressed():
	clear_form()

func clear_form():
	"""Clear all form fields"""
	title_edit.text = ""
	artist_edit.text = ""
	genre_edit.text = ""
	bpm_spin.value = 120
	difficulty_spin.value = 3
	duration_edit.text = "0:00"
	
	audio_file_path = ""
	vocal_file_path = ""
	cover_file_path = ""
	
	audio_path_label.text = "No file selected"
	vocal_path_label.text = "No file selected"
	cover_path_label.text = "No file selected"
	
	lyrics_text.text = ""
	
	update_status("Form cleared", Color.YELLOW)

func _on_open_folder_pressed():
	"""Open the songs folder in file explorer"""
	OS.shell_open(ProjectSettings.globalize_path(SONGS_DIR))

func confirm_dialog(message: String) -> bool:
	"""Show a simple confirmation (simplified version)"""
	# In a real implementation, use an AcceptDialog
	# For now, just return true
	return true
