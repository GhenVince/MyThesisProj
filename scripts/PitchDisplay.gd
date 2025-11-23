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
	
	# Create lines from BOTTOM to TOP (C at bottom, B at top)
	for i in range(13):  # 0-12 to include both ends
		if i >= 12:
			continue
			
		var note_name = NOTE_NAMES[i]
		# Y position: 0 = top of screen, display_height = bottom
		# We want C at BOTTOM, B at TOP
		var y_pos = display_height - (i * note_spacing)
		
		# Create label for note name
		var label = Label.new()
		label.text = note_name
		label.position = Vector2(5, y_pos - 10)
		label.add_theme_color_override("font_color", Color.WHITE)
		label.add_theme_font_size_override("font_size", 14)
		add_child(label)
		
		note_lines[note_name] = y_pos
		
		# DEBUG: Print note positions
		print("Note ", note_name, " at Y=", y_pos)

func update_player_pitch(y_position: float, _note: String):
	# Clamp to display bounds (roof and floor limits)
	y_position = clamp(y_position, 0, size.y)
	
	# Add to the right edge
	var new_pos = Vector2(size.x, y_position)
	player_pitch_positions.append(new_pos)
	
	# DEBUG
	if player_pitch_positions.size() % 10 == 0:
		print("  → PitchDisplay received Y=%.1f, added position, total: %d" % [y_position, player_pitch_positions.size()])
	
	# Keep only recent history
	if player_pitch_positions.size() > max_history:
		player_pitch_positions.pop_front()
	
	queue_redraw()

func update_reference_pitch(y_position: float, time: float):
	# Clamp to display bounds (roof and floor limits)
	y_position = clamp(y_position, 0, size.y)
	
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
	# Draw note lines for 2 octaves
	var display_height = size.y
	var note_spacing = display_height / float(note_range)
	
	for i in range(note_range + 1):
		var y = display_height - (i * note_spacing)
		var color = Color(0.3, 0.3, 0.3, 0.5)
		
		# Make C notes brighter as octave markers
		if i % 12 == 0:
			color = Color(0.6, 0.6, 0.6, 0.8)
		
		draw_line(Vector2(0, y), Vector2(size.x, y), color, 1.0)
	
	# Draw current pitch indicator line
	var current_x = size.x * 0.2
	draw_line(Vector2(current_x, 0), Vector2(current_x, size.y), Color(1, 1, 1, 0.3), 2.0)
	
	# Draw reference pitch line
	if reference_pitch_positions.size() > 1:
		for i in range(reference_pitch_positions.size() - 1):
			var p1 = reference_pitch_positions[i]
			var p2 = reference_pitch_positions[i + 1]
			if p1.x >= 0 and p2.x <= size.x:
				draw_line(p1, p2, NOTE_COLORS["reference"], 3.0)
	
	# Draw player pitch line - THICK and VISIBLE
	if player_pitch_positions.size() > 1:
		for i in range(player_pitch_positions.size() - 1):
			var p1 = player_pitch_positions[i]
			var p2 = player_pitch_positions[i + 1]
			if p1.x >= 0 and p2.x <= size.x:
				draw_line(p1, p2, NOTE_COLORS["player"], 6.0)
		
		# Draw current position indicator
		if player_pitch_positions.size() > 0:
			var last_pos = player_pitch_positions[-1]
			if last_pos.x >= 0 and last_pos.x <= size.x:
				draw_circle(last_pos, 10.0, NOTE_COLORS["player"])

func clear():
	player_pitch_positions.clear()
	reference_pitch_positions.clear()
	queue_redraw()
