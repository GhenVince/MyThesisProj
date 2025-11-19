# PitchDisplay.gd
extends Control

const NOTE_NAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
const NOTE_COLORS = {
	"player": Color(0.2, 0.8, 1.0, 1.0),  # Blue
	"reference": Color(1.0, 0.2, 0.2, 0.8)  # Red
}

var player_pitch_positions: Array = []
var reference_pitch_positions: Array = []
var max_history: int = 100

var note_lines: Dictionary = {}

func _ready():
	create_note_lines()

func create_note_lines():
	var display_height = size.y
	var note_spacing = display_height / 12.0
	
	for i in range(12):
		var note_name = NOTE_NAMES[i]
		var y_pos = display_height - (i * note_spacing)
		
		# Create label for note name
		var label = Label.new()
		label.text = note_name
		label.position = Vector2(5, y_pos - 10)
		label.add_theme_color_override("font_color", Color.WHITE)
		add_child(label)
		
		note_lines[note_name] = y_pos

func update_player_pitch(y_position: float, note: String):
	player_pitch_positions.append(Vector2(size.x, y_position))
	
	# Keep only recent history
	if player_pitch_positions.size() > max_history:
		player_pitch_positions.pop_front()
	
	queue_redraw()

func update_reference_pitch(y_position: float, time: float):
	var x_pos = (time / 10.0) * size.x  # Assuming 10 second window
	reference_pitch_positions.append(Vector2(x_pos, y_position))
	
	if reference_pitch_positions.size() > max_history:
		reference_pitch_positions.pop_front()
	
	queue_redraw()

func _draw():
	# Draw note lines
	for note in note_lines.keys():
		var y = note_lines[note]
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.3, 0.3, 0.3, 0.5), 1.0)
	
	# Draw reference pitch line
	if reference_pitch_positions.size() > 1:
		for i in range(reference_pitch_positions.size() - 1):
			var p1 = reference_pitch_positions[i]
			var p2 = reference_pitch_positions[i + 1]
			draw_line(p1, p2, NOTE_COLORS["reference"], 3.0)
	
	# Draw player pitch line
	if player_pitch_positions.size() > 1:
		var x_spacing = size.x / float(max_history)
		for i in range(player_pitch_positions.size() - 1):
			var p1 = Vector2(i * x_spacing, player_pitch_positions[i].y)
			var p2 = Vector2((i + 1) * x_spacing, player_pitch_positions[i + 1].y)
			draw_line(p1, p2, NOTE_COLORS["player"], 4.0)
		
		# Draw current position indicator
		if player_pitch_positions.size() > 0:
			var current_pos = player_pitch_positions[-1]
			var x = (player_pitch_positions.size() - 1) * x_spacing
			draw_circle(Vector2(x, current_pos.y), 6.0, NOTE_COLORS["player"])

func clear():
	player_pitch_positions.clear()
	reference_pitch_positions.clear()
	queue_redraw()
