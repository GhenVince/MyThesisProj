extends Control

@onready var reference_line = $ReferenceLine
@onready var player_line = $PlayerLine

var reference_points: Array[Vector2] = []
var player_points: Array[Vector2] = []
var time := 0.0

const PIXELS_PER_SECOND := 200.0  # speed of graph scrolling

func add_pitch(detected_pitch: float, reference_pitch: float, delta: float):
	time += delta * PIXELS_PER_SECOND

	var y_ref = _pitch_to_y(reference_pitch)
	var y_player = _pitch_to_y(detected_pitch)

	reference_points.append(Vector2(time, y_ref))
	player_points.append(Vector2(time, y_player))

	reference_line.points = reference_points
	player_line.points = player_points

	# Optional: remove old points for long songs
	if reference_points.size() > 1000:
		reference_points.pop_front()
		player_points.pop_front()

func _pitch_to_y(pitch: float) -> float:
	if pitch <= 0:
		return 0
	# Convert to cents relative to A4 and scale for display
	return 400 - (1200.0 * log(pitch / 440.0) / log(2))
