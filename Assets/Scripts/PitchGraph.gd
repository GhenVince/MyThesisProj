extends Control

@onready var reference_line = $ReferenceLine
@onready var player_line = $PlayerLine

var reference_points: Array[Vector2] = []
var player_points: Array[Vector2] = []
var time := 0.0

func add_pitch(detected_pitch: float, reference_pitch: float, delta: float):
	time += delta * 100  # scale x axis
	var y_ref = _pitch_to_y(reference_pitch)
	var y_player = _pitch_to_y(detected_pitch)

	reference_points.append(Vector2(time, y_ref))
	player_points.append(Vector2(time, y_player))

	reference_line.points = reference_points
	player_line.points = player_points

func _pitch_to_y(pitch: float) -> float:
	if pitch <= 0: return 0
	return 400 - (1200.0 * log(pitch / 440.0) / log(2)) # relative to A4
