# Gameplay.gd - COMPLETE WITH PAUSE MENU
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
var last_reference_pitch: float = 0.0
var reference_pitch_smoothing: Array = []

var vocal_effect_capture: AudioEffectCapture

# Pitch display bounds
const MIN_DISPLAY_FREQ = 100.0  # Hz
const MAX_DISPLAY_FREQ = 500.0  # Hz

const NOTE_POSITIONS = {
	"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5,
	"F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11
}

func _ready():
	if GameManager.current_song.is_empty():
		push_error("No song selected!")
		get_tree().change_scene_to_file("res://scenes/SongSelection.tscn")
		return
	
	song_data = GameManager.current_song
	load_song_data()
	setup_audio()
	setup_pitch_detection()
	
	pause_menu.hide()
	countdown_label.hide()
	
	start_countdown()

func load_song_data():
	if not song_data.has("folder"):
		push_error("Song data missing 'folder' key!")
		return
	
	var song_folder = SongDatabase.SONGS_DIR + song_data["folder"] + "/"
	
	var lyrics_path = song_folder + "lyrics.json"
	if FileAccess.file_exists(lyrics_path):
		var file = FileAccess.open(lyrics_path, FileAccess.READ)
		var json = JSON.new()
		json.parse(file.get_as_text())
		lyrics_data = json.data
		file.close()
	
	var bpm = song_data.get("bpm", 120)
	beat_duration = 60.0 / bpm

func setup_audio():
	var song_folder = SongDatabase.SONGS_DIR + song_data["folder"] + "/"
	
	var audio_path = song_folder + "audio.ogg"
	if FileAccess.file_exists(audio_path):
		audio_player.stream = load(audio_path)
	
	var vocal_path = song_folder + "vocals.ogg"
	if FileAccess.file_exists(vocal_path):
		setup_vocal_analysis_bus()
		vocal_player.stream = load(vocal_path)
		vocal_player.bus = "VocalAnalysis"
		reference_analyzer_active = true
		print("✓ Reference vocals loaded")
	
	setup_player_monitoring()

func setup_vocal_analysis_bus():
	var vocal_bus_idx = AudioServer.get_bus_index("VocalAnalysis")
	if vocal_bus_idx == -1:
		vocal_bus_idx = AudioServer.bus_count
		AudioServer.add_bus(vocal_bus_idx)
		AudioServer.set_bus_name(vocal_bus_idx, "VocalAnalysis")
	
	for i in range(AudioServer.get_bus_effect_count(vocal_bus_idx) - 1, -1, -1):
		AudioServer.remove_bus_effect(vocal_bus_idx, i)
	
	var amp = AudioEffectAmplify.new()
	amp.volume_db = 12.0
	AudioServer.add_bus_effect(vocal_bus_idx, amp)
	
	vocal_effect_capture = AudioEffectCapture.new()
	vocal_effect_capture.buffer_length = 0.1
	AudioServer.add_bus_effect(vocal_bus_idx, vocal_effect_capture)
	
	AudioServer.set_bus_mute(vocal_bus_idx, true)
	print("✓ Vocal analysis bus created")

func setup_player_monitoring():
	var monitor_bus_idx = AudioServer.get_bus_index("PlayerMonitor")
	if monitor_bus_idx == -1:
		monitor_bus_idx = AudioServer.bus_count
		AudioServer.add_bus(monitor_bus_idx)
		AudioServer.set_bus_name(monitor_bus_idx, "PlayerMonitor")
	
	for i in range(AudioServer.get_bus_effect_count(monitor_bus_idx) - 1, -1, -1):
		AudioServer.remove_bus_effect(monitor_bus_idx, i)
	
	var noise_gate = AudioEffectCompressor.new()
	noise_gate.threshold = -30.0
	noise_gate.ratio = 20.0
	noise_gate.attack_us = 20.0
	noise_gate.release_ms = 200.0
	AudioServer.add_bus_effect(monitor_bus_idx, noise_gate)
	
	var reverb = AudioEffectReverb.new()
	reverb.room_size = 0.6
	reverb.damping = 0.5
	reverb.spread = 0.8
	reverb.dry = 0.7
	reverb.wet = 0.3
	AudioServer.add_bus_effect(monitor_bus_idx, reverb)
	
	var eq = AudioEffectEQ.new()
	eq.set_band_gain_db(2, 3.0)
	AudioServer.add_bus_effect(monitor_bus_idx, eq)
	
	AudioServer.set_bus_volume_db(monitor_bus_idx, -6.0)
	AudioServer.set_bus_send(AudioServer.get_bus_index("Record"), "PlayerMonitor")
	
	print("✓ Player monitoring enabled")

func setup_pitch_detection():
	if not has_node("/root/PitchDetector"):
		push_error("PitchDetector AutoLoad not found! Creating manually...")
		pitch_detector = load("res://scripts/YINPitchDetector.gd").new()
		add_child(pitch_detector)
	else:
		pitch_detector = get_node("/root/PitchDetector")
	
	spectral_analyzer = load("res://scripts/SpectralAnalyzer.gd").new()
	add_child(spectral_analyzer)

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
	
	var frequency = pitch_detector.detect_pitch()
	
	# Update player pitch if detected
	if frequency > 0:
		var note_data = pitch_detector.get_note_with_cents(frequency)
		update_pitch_display(note_data)
		player_pitch_history.append(note_data)
		
		if player_pitch_history.size() % 20 == 0:
			analyze_player_timbre()
	
	# Always scroll the display
	pitch_display.scroll_display(delta)
	
	if reference_analyzer_active:
		detect_reference_pitch()
	
	if current_time - last_beat_time >= beat_duration:
		last_beat_time = current_time
		check_pitch_accuracy()
	
	update_lyrics()
	update_score_display()
	
	if not audio_player.playing and is_playing:
		end_game()

func detect_reference_pitch():
	if not vocal_effect_capture:
		return
	
	if vocal_effect_capture.can_get_buffer(2048):
		var frames = vocal_effect_capture.get_buffer(2048)
		
		var mono_buffer = PackedFloat32Array()
		mono_buffer.resize(frames.size())
		for i in frames.size():
			mono_buffer[i] = (frames[i].x + frames[i].y) / 2.0
		
		var frequency = analyze_reference_frequency(mono_buffer)
		
		if frequency > 0:
			reference_pitch_smoothing.append(frequency)
			if reference_pitch_smoothing.size() > 5:
				reference_pitch_smoothing.pop_front()
			
			var smoothed_freq = 0.0
			for f in reference_pitch_smoothing:
				smoothed_freq += f
			smoothed_freq /= reference_pitch_smoothing.size()
			
			if abs(smoothed_freq - last_reference_pitch) < 50.0 or last_reference_pitch == 0.0:
				last_reference_pitch = smoothed_freq
				
				var note_data = pitch_detector.get_note_with_cents(smoothed_freq)
				var y_position = get_position_from_frequency(smoothed_freq)
				
				pitch_display.update_reference_pitch(y_position, current_time)
				
				reference_pitches.append({
					"time": current_time,
					"note": note_data["note"],
					"frequency": smoothed_freq
				})

func analyze_reference_frequency(samples: PackedFloat32Array) -> float:
	var buffer_size = samples.size()
	if buffer_size < 512:
		return 0.0
	
	var half_buffer = int(buffer_size / 2.0)
	
	var max_amp = 0.0
	for sample in samples:
		max_amp = max(max_amp, abs(sample))
	
	if max_amp < 0.03:
		return 0.0
	
	var best_period = 0
	var best_correlation = 0.0
	
	var min_period = int(44100.0 / 800.0)
	var max_period = int(44100.0 / 80.0)
	
	for period in range(min_period, min(max_period, half_buffer)):
		var correlation = 0.0
		for i in range(half_buffer):
			correlation += samples[i] * samples[i + period]
		
		if correlation > best_correlation:
			best_correlation = correlation
			best_period = period
	
	if best_period > 0 and best_correlation > 0.1:
		var frequency = 44100.0 / best_period
		if frequency >= 80 and frequency <= 800:
			return frequency
	
	return 0.0

func update_pitch_display(note_data: Dictionary):
	var frequency = note_data["frequency"]
	var note = note_data["note"]
	
	var position_y = get_position_from_frequency(frequency)
	pitch_display.update_player_pitch(position_y, note)

func get_position_from_frequency(frequency: float) -> float:
	"""Convert frequency to Y position with STRICT clamping"""
	if frequency <= 0:
		return pitch_display.size.y / 2.0
	
	var display_height = pitch_display.size.y
	
	# Clamp frequency to display range FIRST
	frequency = clamp(frequency, MIN_DISPLAY_FREQ, MAX_DISPLAY_FREQ)
	
	# Calculate normalized position (0 = top, 1 = bottom)
	var normalized = (frequency - MIN_DISPLAY_FREQ) / (MAX_DISPLAY_FREQ - MIN_DISPLAY_FREQ)
	var y_position = display_height * (1.0 - normalized)
	
	# STRICT clamping with larger margin
	y_position = clamp(y_position, 20, display_height - 20)
	
	return y_position

func get_note_position(note: String) -> float:
	var note_index = NOTE_POSITIONS.get(note, 0)
	var display_height = pitch_display.size.y
	var note_position = display_height - (note_index * (display_height / 12.0))
	return clamp(note_position, 20, display_height - 20)

func check_pitch_accuracy():
	if player_pitch_history.is_empty():
		GameManager.add_score("Miss")
		return
	
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
	for ref in reference_pitches:
		if abs(ref["time"] - _time) < 0.5:
			return ref["note"]
	return "C"

func calculate_note_accuracy(player_note: String, reference_note: String) -> float:
	if player_note == reference_note:
		return 1.0
	
	var player_pos = NOTE_POSITIONS.get(player_note, 0)
	var ref_pos = NOTE_POSITIONS.get(reference_note, 0)
	var diff = abs(player_pos - ref_pos)
	
	if diff <= 1:
		return 0.8
	elif diff <= 2:
		return 0.6
	else:
		return 0.3

func show_judgment(judgment: String):
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
	is_paused = false
	audio_player.stream_paused = false
	if reference_analyzer_active:
		vocal_player.stream_paused = false
	get_tree().paused = false

# === PAUSE MENU BUTTON HANDLERS ===

func _on_continue_pressed():
	"""Continue playing"""
	resume_game()

func _on_retry_pressed():
	"""Restart the song"""
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_pause_options_pressed():
	"""Open options from pause menu"""
	get_tree().paused = false
	if ResourceLoader.exists("res://scenes/OptionsMenu.tscn"):
		get_tree().change_scene_to_file("res://scenes/OptionsMenu.tscn")
	else:
		print("OptionsMenu.tscn not found!")
		get_tree().paused = true

func _on_exit_pressed():
	"""Exit to main menu"""
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func end_game():
	is_playing = false
	
	SongDatabase.save_score(
		song_data["title"],
		GameManager.game_score,
		GameManager.perfect_count,
		GameManager.good_count,
		GameManager.miss_count
	)
	
	get_tree().change_scene_to_file("res://scenes/ResultsScreen.tscn")
