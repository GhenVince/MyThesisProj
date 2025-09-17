extends Node

# --- Nodes ---
@onready var score_label = $"../UI/ScoreLabel"
@onready var accuracy_label = $"../UI/AccuracyLabel"
@onready var pitch_graph = $"../PitchGraph"
@onready var detector = $"../Audio/PitchDetector"

# --- Gameplay variables ---
var score := 0
var timer := 0.0
var pitch_buffer := []

# --- Precomputed reference pitch ---
var reference_pitch_data: PackedFloat32Array = PackedFloat32Array()
var song_timer := 0.0
var song_duration := 0.0

# --- Constants ---
const PERFECT_MARGIN = 25.0
const GOOD_MARGIN = 75.0
const SMOOTH_FRAMES = 5

func _ready():
	score_label.text = "Score: 0"
	
	# Connect pitch detector
	if detector:
		detector.connect("PitchDetected", Callable(self, "_on_pitch_detected"))
	
	# Load precomputed reference pitch
	if SongManager.reference_pitch_path != "":
		var res = load(SongManager.reference_pitch_path)
		if res is Resource and res.has("pitches"):
			reference_pitch_data = res.pitches.duplicate() as PackedFloat32Array
		else:
			push_warning("Reference pitch resource not found or invalid")
	else:
		push_warning("SongManager.reference_pitch_path is empty")

	# Get song duration from AudioStreamPlayer
	var instrumental = $"../Audio/InstrumentalPlayer"
	if instrumental and instrumental.stream:
		SongManager.song_duration = instrumental.stream.get_length()
		song_duration = SongManager.song_duration

func _process(delta):
	song_timer += delta
	timer += delta

	# End song when duration reached
	if song_timer >= song_duration:
		get_tree().change_scene("res://scenes/EndScreen.tscn")

	# --- Smooth player pitch ---
	var avg_pitch = 0.0
	if pitch_buffer.size() > 0:
		for p in pitch_buffer:
			avg_pitch += p
		avg_pitch /= pitch_buffer.size()

	# --- Current reference pitch from precomputed array ---
	var current_reference_pitch = 440.0
	if reference_pitch_data.size() > 0 and song_duration > 0.0:
		var current_index = int(song_timer / song_duration * reference_pitch_data.size())
		current_index = clamp(current_index, 0, reference_pitch_data.size() - 1)
		current_reference_pitch = reference_pitch_data[current_index]

	# --- Update pitch graph ---
	pitch_graph.add_pitch(avg_pitch, current_reference_pitch, delta)

	# --- Evaluate score every second ---
	if timer >= 1.0:
		if pitch_buffer.size() > 0:
			_evaluate_pitch(avg_pitch, current_reference_pitch)
			pitch_buffer.clear()
		timer = 0.0

func _on_pitch_detected(pitch: float):
	if pitch <= 0:
		return
	pitch_buffer.append(pitch)
	if pitch_buffer.size() > SMOOTH_FRAMES:
		pitch_buffer.pop_front()

func _evaluate_pitch(player_pitch: float, reference_pitch: float):
	if player_pitch <= 0 or reference_pitch <= 0:
		accuracy_label.text = "Miss!"
		return

	var cents_error = 1200.0 * log(player_pitch / reference_pitch) / log(2)
	var comment := "Miss!"
	var points := 0

	if abs(cents_error) <= PERFECT_MARGIN:
		comment = "Perfect!"
		points = 100
	elif abs(cents_error) <= GOOD_MARGIN:
		comment = "Good!"
		points = 70

	score += points
	score_label.text = "Score: %d" % score
	accuracy_label.text = comment
