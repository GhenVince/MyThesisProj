extends Node

@onready var score_label = $"../UI/ScoreLabel"
@onready var accuracy_label = $"../UI/AccuracyLabel"
@onready var pitch_graph = $"../UI/PitchGraph"
@onready var detector = $"../Audio/PitchDetector"

var score := 0
var timer := 0.0
var detected_pitch := 0.0
var reference_pitch := 440.0  # Example: A4

const PERFECT_MARGIN = 25.0
const GOOD_MARGIN = 75.0

func _ready():
	score_label.text = "Score: 0"
	detector.connect("PitchDetected", Callable(self, "_on_pitch_detected"))


func _process(delta):
	timer += delta
	pitch_graph.add_pitch(detected_pitch, reference_pitch, delta)
	if timer >= 1.0:
		_evaluate_pitch(detected_pitch, reference_pitch)
		timer = 0.0

func _evaluate_pitch(d_pitch: float, r_pitch: float):
	if d_pitch <= 0 or r_pitch <= 0:
		accuracy_label.text = "Miss!"
		return

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

func _on_pitch_detected(pitch: float):
	detected_pitch = pitch

	if timer >= 1.0:
		_evaluate_pitch(detected_pitch, reference_pitch)
		timer = 0.0
