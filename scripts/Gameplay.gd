# Gameplay.gd
extends Control

@onready var pitch_display = $UI/PitchDisplay
@onready var lyrics_label = $UI/BottomPanel/LyricsLabel
@onready var score_label = $UI/TopPanel/ScoreLabel
@onready var accuracy_label = $UI/TopPanel/AccuracyLabel
@onready var audio_player = $UI/AudioPlayer
@onready var vocal_player = $UI/VocalPlayer
@onready var pause_menu = $UI/PauseMenu
@onready var countdown_label = $UI/CountdownLabel

var pitch_detector: Node
var spectral_analyzer: Node
var song_data: Dictionary
var lyrics_data: Array = []
var reference_pitches: Array = []

var current_time: float = 0.0
var is_paused: bool = false
var is_playing: bool = false
var beat_duration: float = 0.0
var last_beat_time: float = 0.0
var current_lyric_index: int = 0

var player_pitch_history: Array = []
var reference_analyzer_active: bool = false

const NOTE_POSITIONS = {
	"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5,
	"F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11
}

func _ready():
	# Verify we have valid song data
	if GameManager.current_song.is_empty():
		push_error("No song selected! Returning to song selection...")
		get_tree().change_scene_to_file("res://scenes/SongSelection.tscn")
		return
	
	song_data = GameManager.current_song
	load_song_data()
	setup_audio()
	setup_pitch_detection()
	
	# DEBUG: Check audio setup
	print("\n=== Audio Setup Debug ===")
	var record_bus_idx = AudioServer.get_bus_index("Record")
	print("Record bus index: ", record_bus_idx)
	
	if record_bus_idx == -1:
		print("❌ ERROR: 'Record' bus not found!")
		print("Creating it now...")
	else:
		print("✓ Record bus exists")
		print("Effect count: ", AudioServer.get_bus_effect_count(record_bus_idx))
	
	# Rest of code...
	
	
	pause_menu.hide()
	countdown_label.hide()
	
	start_countdown()

func setup_pitch_detection():
	# Don't create if already exists
	if pitch_detector:
		print("Pitch detector already exists, reusing it")
		return
	
	pitch_detector = load("res://scripts/YINPitchDetector.gd").new()
	add_child(pitch_detector)
	
	spectral_analyzer = load("res://scripts/SpectralAnalyzer.gd").new()
	add_child(spectral_analyzer)

func load_song_data():
	# Check if folder key exists, if not we have an issue
	if not song_data.has("folder"):
		push_error("Song data missing 'folder' key! Song data: " + str(song_data))
		return
	
	var song_folder = SongDatabase.SONGS_DIR + song_data["folder"] + "/"
	
	# Load lyrics
	var lyrics_path = song_folder + "lyrics.json"
	if FileAccess.file_exists(lyrics_path):
		var file = FileAccess.open(lyrics_path, FileAccess.READ)
		var json = JSON.new()
		json.parse(file.get_as_text())
		lyrics_data = json.data
		file.close()
	
	# Calculate beat duration from BPM
	var bpm = song_data.get("bpm", 120)
	beat_duration = 60.0 / bpm

func setup_audio():
	var song_folder = SongDatabase.SONGS_DIR + song_data["folder"] + "/"
	
	# Load main audio (instrumental + vocals)
	var audio_path = song_folder + "audio.ogg"
	if FileAccess.file_exists(audio_path):
		audio_player.stream = load(audio_path)
	
	# Load isolated vocals for reference pitch detection
	var vocal_path = song_folder + "vocals.ogg"
	if FileAccess.file_exists(vocal_path):
		vocal_player.stream = load(vocal_path)
		vocal_player.volume_db = -80  # Silent but playing
		reference_analyzer_active = true

func start_countdown():
	countdown_label.show()
	var countdown = 3
	
	for i in range(3):
		countdown_label.text = str(countdown)
		await get_tree().create_timer(1.0).timeout
		countdown -= 1
	
	countdown_label.text = "GO!"
	await get_tree().create_timer(0.5).timeout
	countdown_label.hide()
	
	start_game()

func start_game():
	is_playing = true
	audio_player.play()
	if reference_analyzer_active:
		vocal_player.play()

func _process(delta):
	if not is_playing or is_paused:
		return
	
	current_time += delta
	
	# Detect player pitch
	var frequency = pitch_detector.detect_pitch()
	
	# DEBUG: Show detection status every second
	if int(current_time) != int(current_time - delta):
		if frequency > 0:
			print("✓ Pitch detected: %.2f Hz" % frequency)
		else:
			print("⚠ No pitch detected - speak/sing into microphone!")
	
	if frequency > 0:
		var note_data = pitch_detector.get_note_with_cents(frequency)
		update_pitch_display(note_data)
		player_pitch_history.append(note_data)
		
		# Analyze for timbre (every 0.5 seconds)
		if player_pitch_history.size() % 20 == 0:
			analyze_player_timbre()
	
	# Detect reference pitch
	if reference_analyzer_active:
		detect_reference_pitch()
	
	# Check for scoring at each beat
	if current_time - last_beat_time >= beat_duration:
		last_beat_time = current_time
		check_pitch_accuracy()
	
	# Update lyrics
	update_lyrics()
	
	# Update UI
	update_score_display()
	
	# Check if song ended
	if not audio_player.playing and is_playing:
		end_game()

func detect_reference_pitch():
	# This would need to capture the vocal_player's output
	# For now, we'll use pre-analyzed data from the song file
	pass

func update_pitch_display(note_data: Dictionary):
	var note = note_data["note"]
	var position_y = get_note_position(note)
	pitch_display.update_player_pitch(position_y, note)

func get_note_position(note: String) -> float:
	var note_index = NOTE_POSITIONS.get(note, 0)
	var display_height = pitch_display.size.y
	var note_position = display_height - (note_index * (display_height / 12.0))
	return note_position

func check_pitch_accuracy():
	if player_pitch_history.is_empty():
		GameManager.add_score("Miss")
		return
	
	# Get average pitch over the last beat
	var recent_pitches = player_pitch_history.slice(max(0, player_pitch_history.size() - 10))
	if recent_pitches.is_empty():
		GameManager.add_score("Miss")
		return
	
	var avg_note = get_most_common_note(recent_pitches)
	var reference_note = get_reference_note_at_time(current_time)
	
	if reference_note.is_empty():
		return
	
	var accuracy = calculate_note_accuracy(avg_note, reference_note)
	
	if accuracy >= 0.9:
		GameManager.add_score("Perfect")
		show_judgment("Perfect")
	elif accuracy >= 0.6:
		GameManager.add_score("Good")
		show_judgment("Good")
	else:
		GameManager.add_score("Miss")
		show_judgment("Miss")

func get_most_common_note(pitches: Array) -> String:
	var note_counts = {}
	for p in pitches:
		var note = p["note"]
		note_counts[note] = note_counts.get(note, 0) + 1
	
	var most_common = ""
	var max_count = 0
	for note in note_counts.keys():
		if note_counts[note] > max_count:
			max_count = note_counts[note]
			most_common = note
	
	return most_common

func get_reference_note_at_time(_time: float) -> String:
	# This should load from pre-analyzed pitch data
	# For now returning placeholder
	return "C"

func calculate_note_accuracy(player_note: String, reference_note: String) -> float:
	if player_note == reference_note:
		return 1.0
	
	var player_pos = NOTE_POSITIONS.get(player_note, 0)
	var ref_pos = NOTE_POSITIONS.get(reference_note, 0)
	var diff = abs(player_pos - ref_pos)
	
	# Within 1 semitone = good, within 2 = okay
	if diff <= 1:
		return 0.8
	elif diff <= 2:
		return 0.6
	else:
		return 0.3

func show_judgment(judgment: String):
	# Visual feedback for scoring
	var label = Label.new()
	label.text = judgment
	label.position = Vector2(size.x / 2, size.y / 2)
	add_child(label)
	
	var tween = create_tween()
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(label.queue_free)

func update_lyrics():
	if current_lyric_index >= lyrics_data.size():
		return
	
	var lyric_entry = lyrics_data[current_lyric_index]
	if current_time >= lyric_entry.get("time", 0.0):
		lyrics_label.text = lyric_entry.get("text", "")
		current_lyric_index += 1

func update_score_display():
	score_label.text = "Score: %d" % GameManager.game_score
	var total_notes = GameManager.perfect_count + GameManager.good_count + GameManager.miss_count
	var accuracy = 0.0
	if total_notes > 0:
		accuracy = (GameManager.perfect_count + GameManager.good_count * 0.5) / float(total_notes) * 100.0
	accuracy_label.text = "Accuracy: %.1f%%" % accuracy

func analyze_player_timbre():
	# Store timbre data for later comparison
	if player_pitch_history.size() >= 20:
		var recent = player_pitch_history.slice(-20)
		GameManager.player_timbre_data.append(recent)

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		toggle_pause()

func toggle_pause():
	if is_paused:
		resume_game()
	else:
		pause_game()

func pause_game():
	is_paused = true
	audio_player.stream_paused = true
	if reference_analyzer_active:
		vocal_player.stream_paused = true
	pause_menu.show()
	get_tree().paused = true

func resume_game():
	pause_menu.hide()
	start_countdown()
	
func continue_after_countdown():
	is_paused = false
	audio_player.stream_paused = false
	if reference_analyzer_active:
		vocal_player.stream_paused = false
	get_tree().paused = false

func end_game():
	is_playing = false
	
	# Save score
	SongDatabase.save_score(
		song_data["title"],
		GameManager.game_score,
		GameManager.perfect_count,
		GameManager.good_count,
		GameManager.miss_count
	)
	
	# Go to results screen
	get_tree().change_scene_to_file("res://scenes/ResultsScreen.tscn")
