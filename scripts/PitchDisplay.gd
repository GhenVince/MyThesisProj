# PitchDisplay.gd
extends Control

const NOTE_NAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
const NOTE_COLORS = {
	"player": Color(0.2, 0.8, 1.0, 1.0),  # Blue
	"reference": Color(1.0, 0.2, 0.2, 0.8)  # Red
}

var player_pitch_positions: Array = []
var reference_pitch_positions: Array = []
var max_history: int = 150  # Increased from 100 for longer horizontal trails
var scroll_offset: float = 0.0
var scroll_speed: float = 50.0  # pixels per second

var note_lines: Dictionary = {}

func _ready():
	print("=== PitchDisplay Initialized ===")
	print("Size: ", size)
	print("Position: ", position)
	print("Global Position: ", global_position)
	
	if size.x == 0 or size.y == 0:
		push_error("PitchDisplay has zero size! Set Custom Minimum Size or anchors")
	
	create_note_lines()
	
	# Draw test line immediately to verify display works
	queue_redraw()

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

func update_player_pitch(y_position: float, _note: String):
	# Add to the right edge
	player_pitch_positions.append(Vector2(size.x, y_position))
	
	# Keep only recent history
	if player_pitch_positions.size() > max_history:
		player_pitch_positions.pop_front()
	
	queue_redraw()

func update_reference_pitch(y_position: float, time: float):
	# Add reference pitch to the right edge
	reference_pitch_positions.append(Vector2(size.x, y_position))
	
	if reference_pitch_positions.size() > max_history:
		reference_pitch_positions.pop_front()
	
	queue_redraw()

func scroll_display(delta: float):
	# Scroll everything to the left continuously
	scroll_offset += scroll_speed * delta
	
	# Shift all positions left
	for i in range(player_pitch_positions.size()):
		player_pitch_positions[i].x -= scroll_speed * delta
	
	for i in range(reference_pitch_positions.size()):
		reference_pitch_positions[i].x -= scroll_speed * delta
	
	# Remove positions that scrolled off screen
	while player_pitch_positions.size() > 0 and player_pitch_positions[0].x < 0:
		player_pitch_positions.pop_front()
	
	while reference_pitch_positions.size() > 0 and reference_pitch_positions[0].x < 0:
		reference_pitch_positions.pop_front()
	
	queue_redraw()

func _draw():
	# Draw note lines
	for note in note_lines.keys():
		var y = note_lines[note]
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.3, 0.3, 0.3, 0.5), 1.0)
	
	# Draw current pitch indicator line (vertical line showing "now")
	var current_x = size.x * 0.2  # 20% from left edge
	draw_line(Vector2(current_x, 0), Vector2(current_x, size.y), Color(1, 1, 1, 0.3), 2.0)
	
	# Draw reference pitch line (ahead of current position)
	if reference_pitch_positions.size() > 1:
		for i in range(reference_pitch_positions.size() - 1):
			var p1 = reference_pitch_positions[i]
			var p2 = reference_pitch_positions[i + 1]
			# Only draw if within screen bounds
			if p1.x >= 0 and p2.x <= size.x:
				draw_line(p1, p2, NOTE_COLORS["reference"], 3.0)
	
	# Draw player pitch line (scrolls from right to left)
	if player_pitch_positions.size() > 1:
		for i in range(player_pitch_positions.size() - 1):
			var p1 = player_pitch_positions[i]
			var p2 = player_pitch_positions[i + 1]
			# Only draw if within screen bounds
			if p1.x >= 0 and p2.x <= size.x:
				draw_line(p1, p2, NOTE_COLORS["player"], 4.0)
		
		# Draw current position indicator at the "now" line
		if player_pitch_positions.size() > 0:
			var last_pos = player_pitch_positions[-1]
			if last_pos.x >= 0 and last_pos.x <= size.x:
				draw_circle(last_pos, 6.0, NOTE_COLORS["player"])

func clear():
	player_pitch_positions.clear()
	reference_pitch_positions.clear()
	queue_redraw()
