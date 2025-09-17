extends Node

# UI nodes
@onready var score_label = $"../UI/ScoreLabel"
@onready var accuracy_label = $"../UI/AccuracyLabel"
@onready var pitch_graph = $"../UI/PitchGraph"  # Control node with ReferenceLine & PlayerLine Line2D
@onready var detector = $"../Audio/PitchDetector"

# Gameplay variables
var score := 0
var timer := 0.0
var reference_pitch := 440.0  # Example: A4
var pitch_buffer := []         # buffer for smoothing

# Constants
const PERFECT_MARGIN = 25.0    # cents
const GOOD_MARGIN = 75.0       # cents
const SMOOTH_FRAMES = 5        # rolling buffer frames

func _ready():
	score_label.text = "Score: 0"
	detector.connect("PitchDetected", Callable(self, "_on_pitch_detected"))

func _process(delta):
	timer += delta

	# --- Smooth pitch for visualization ---
	var avg_pitch = 0.0
	if pitch_buffer.size() > 0:
		for p in pitch_buffer:
			avg_pitch += p
		avg_pitch /= pitch_buffer.size()
	else:
		avg_pitch = 0.0

	# --- Update the pitch graph (player vs reference) ---
	pitch_graph.add_pitch(avg_pitch, reference_pitch, delta)

	# --- Evaluate score per second ---
	if timer >= 1.0:
		if pitch_buffer.size() > 0:
			_evaluate_pitch(avg_pitch, reference_pitch)
			pitch_buffer.clear()
		timer = 0.0

func _on_pitch_detected(pitch: float):
	if pitch <= 0:
		return
	pitch_buffer.append(pitch)
	if pitch_buffer.size() > SMOOTH_FRAMES:
		pitch_buffer.pop_front()

func _evaluate_pitch(d_pitch: float, r_pitch: float):
	if d_pitch <= 0 or r_pitch <= 0:
		accuracy_label.text = "Miss!"
		return

	# Difference in cents
	var cents_error = 1200.0 * log(d_pitch / r_pitch) / log(2)

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
