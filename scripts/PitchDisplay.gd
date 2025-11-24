# PitchDisplay.gd
# Visual display for pitch tracking in karaoke gameplay
extends Control

# Visual settings
@export var note_height: float = 40.0
@export var line_color: Color = Color.WHITE
@export var player_color: Color = Color.GREEN
@export var reference_color: Color = Color.CYAN
@export var perfect_zone_color: Color = Color(0.0, 1.0, 0.0, 0.3)
@export var good_zone_color: Color = Color(1.0, 1.0, 0.0, 0.2)

# Note configuration
const NOTES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
const NOTE_POSITIONS = {
	"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5,
	"F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11
}

# Display range (which octaves to show)
var note_range: Dictionary = {
	"min_octave": 3,  # C3
	"max_octave": 5   # B5
}

# Runtime data
var player_pitch: float = 0.0
var reference_pitch: float = 0.0
var player_note: String = ""
var reference_note: String = ""
var player_octave: int = 0
var reference_octave: int = 0

# History for smooth visualization
var pitch_history: Array = []
const MAX_HISTORY_SIZE = 30

# UI nodes (if you want to add labels)
var player_note_label: Label
var reference_note_label: Label

func _ready():
	set_process(true)
	setup_ui_labels()

func setup_ui_labels():
	"""Create optional note labels"""
	# You can customize these positions
	player_note_label = Label.new()
	player_note_label.position = Vector2(10, 10)
	player_note_label.add_theme_font_size_override("font_size", 24)
	add_child(player_note_label)
	
	reference_note_label = Label.new()
	reference_note_label.position = Vector2(10, 40)
	reference_note_label.add_theme_font_size_override("font_size", 20)
	reference_note_label.modulate = reference_color
	add_child(reference_note_label)

func _draw():
	"""Draw the pitch display"""
	draw_note_lines()
	draw_reference_pitch()
	draw_player_pitch()
	draw_pitch_zones()

func _process(_delta):
	queue_redraw()  # Godot 4.x uses queue_redraw() instead of update()

# === PITCH UPDATE FUNCTIONS ===

func update_player_pitch(frequency: float = 0.0):
	"""Update player's current pitch"""
	player_pitch = frequency
	
	if frequency > 0:
		var note_data = frequency_to_note_data(frequency)
		player_note = note_data["note"]
		player_octave = note_data["octave"]
		
		# Add to history for smoothing
		pitch_history.append(frequency)
		if pitch_history.size() > MAX_HISTORY_SIZE:
			pitch_history.pop_front()
		
		# Update label
		if player_note_label:
			player_note_label.text = "Player: %s%d (%.1f Hz)" % [player_note, player_octave, frequency]
	else:
		player_note = ""
		player_octave = 0
		if player_note_label:
			player_note_label.text = "Player: --"

func update_reference_pitch(frequency: float = 0.0):
	"""Update reference pitch (from vocals)"""
	reference_pitch = frequency
	
	if frequency > 0:
		var note_data = frequency_to_note_data(frequency)
		reference_note = note_data["note"]
		reference_octave = note_data["octave"]
		
		# Update label
		if reference_note_label:
			reference_note_label.text = "Target: %s%d (%.1f Hz)" % [reference_note, reference_octave, frequency]
	else:
		reference_note = ""
		reference_octave = 0
		if reference_note_label:
			reference_note_label.text = "Target: --"

func set_note_range(min_octave: int, max_octave: int):
	"""Set the display range for notes"""
	note_range["min_octave"] = min_octave
	note_range["max_octave"] = max_octave

# === DRAWING FUNCTIONS ===

func draw_note_lines():
	"""Draw horizontal lines for each note"""
	var display_height = size.y
	var total_notes = (note_range["max_octave"] - note_range["min_octave"] + 1) * 12
	
	if total_notes <= 0:
		return
	
	var note_spacing = display_height / float(total_notes)
	
	for i in range(total_notes + 1):
		var y_pos = display_height - (i * note_spacing)
		
		# Determine note name for this line
		var note_index = i % 12
		var note_name = NOTES[note_index]
		
		# Draw line (thicker for C notes)
		var line_width = 2.0 if note_name == "C" else 1.0
		var alpha = 0.3 if note_name == "C" else 0.15
		var color = Color(line_color.r, line_color.g, line_color.b, alpha)
		
		draw_line(
			Vector2(0, y_pos),
			Vector2(size.x, y_pos),
			color,
			line_width
		)
		
		# Draw note labels
		if note_name == "C" or note_name == "F":
			var octave = note_range["min_octave"] + int(i / 12.0)
			draw_string(
				ThemeDB.fallback_font,
				Vector2(5, y_pos - 5),
				"%s%d" % [note_name, octave],
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				16,
				Color(line_color.r, line_color.g, line_color.b, 0.5)
			)

func draw_reference_pitch():
	"""Draw the reference pitch line (from vocals)"""
	if reference_pitch <= 0:
		return
	
	var y_pos = get_y_position_for_frequency(reference_pitch)
	
	if y_pos < 0 or y_pos > size.y:
		return  # Out of display range
	
	# Draw reference line
	draw_line(
		Vector2(0, y_pos),
		Vector2(size.x, y_pos),
		reference_color,
		4.0
	)
	
	# Draw note indicator
	draw_circle(Vector2(size.x - 30, y_pos), 8.0, reference_color)

func draw_player_pitch():
	"""Draw the player's current pitch"""
	if player_pitch <= 0:
		return
	
	var y_pos = get_y_position_for_frequency(player_pitch)
	
	if y_pos < 0 or y_pos > size.y:
		return  # Out of display range
	
	# Draw main pitch indicator
	draw_circle(Vector2(size.x / 2, y_pos), 12.0, player_color)
	
	# Draw pitch history trail
	if pitch_history.size() > 1:
		var trail_points = PackedVector2Array()
		for i in range(pitch_history.size()):
			var freq = pitch_history[i]
			var trail_y = get_y_position_for_frequency(freq)
			if trail_y >= 0 and trail_y <= size.y:
				var x = lerp(size.x / 4, size.x / 2, float(i) / pitch_history.size())
				trail_points.append(Vector2(x, trail_y))
		
		if trail_points.size() > 1:
			for i in range(trail_points.size() - 1):
				var alpha = float(i) / trail_points.size()
				var trail_color = Color(player_color.r, player_color.g, player_color.b, alpha * 0.5)
				draw_line(trail_points[i], trail_points[i + 1], trail_color, 3.0)

func draw_pitch_zones():
	"""Draw colored zones showing perfect/good hit areas"""
	if reference_pitch <= 0:
		return
	
	var ref_y = get_y_position_for_frequency(reference_pitch)
	
	if ref_y < 0 or ref_y > size.y:
		return
	
	# Perfect zone (±25 cents = ~1.5 semitones)
	var perfect_range = note_height * 0.25  # About 1/4 of a note
	draw_rect(
		Rect2(0, ref_y - perfect_range, size.x, perfect_range * 2),
		perfect_zone_color
	)
	
	# Good zone (±50 cents = ~3 semitones)
	var good_range = note_height * 0.5  # About 1/2 of a note
	draw_rect(
		Rect2(0, ref_y - good_range, size.x, perfect_range),
		good_zone_color
	)
	draw_rect(
		Rect2(0, ref_y + perfect_range, size.x, good_range - perfect_range),
		good_zone_color
	)

# === HELPER FUNCTIONS ===

func get_y_position_for_frequency(frequency: float) -> float:
	"""Convert frequency to Y position on screen"""
	if frequency <= 0:
		return -1.0
	
	# Convert frequency to semitones from C0
	var a4_freq = 440.0
	var c0_freq = a4_freq * pow(2.0, -4.75)
	var semitones_from_c0 = 12.0 * log(frequency / c0_freq) / log(2.0)
	
	# Get position within our display range
	var min_semitones = note_range["min_octave"] * 12
	var max_semitones = (note_range["max_octave"] + 1) * 12
	var total_range = max_semitones - min_semitones
	
	# Calculate Y position (inverted, 0 at top)
	var normalized = (semitones_from_c0 - min_semitones) / float(total_range)
	return size.y * (1.0 - normalized)

func frequency_to_note_data(frequency: float) -> Dictionary:
	"""Convert frequency to note name and octave"""
	if frequency <= 0:
		return {"note": "", "octave": 0, "cents": 0}
	
	var a4_freq = 440.0
	var c0_freq = a4_freq * pow(2.0, -4.75)
	
	var half_steps_float = 12.0 * log(frequency / c0_freq) / log(2.0)
	var half_steps = round(half_steps_float)
	var cents = (half_steps_float - half_steps) * 100.0
	
	var octave = int(half_steps / 12)
	var note_index = int(half_steps) % 12
	
	return {
		"note": NOTES[note_index],
		"octave": octave,
		"cents": cents,
		"frequency": frequency
	}

func get_note_difference(freq1: float, freq2: float) -> float:
	"""Get the difference between two frequencies in semitones"""
	if freq1 <= 0 or freq2 <= 0:
		return 999.0
	
	return abs(12.0 * log(freq1 / freq2) / log(2.0))

func is_pitch_close(player_freq: float, reference_freq: float, threshold_semitones: float = 0.5) -> bool:
	"""Check if two pitches are close enough"""
	if player_freq <= 0 or reference_freq <= 0:
		return false
	
	var diff = get_note_difference(player_freq, reference_freq)
	return diff <= threshold_semitones

func get_hit_quality(player_freq: float, reference_freq: float) -> String:
	"""Determine hit quality based on pitch accuracy"""
	if player_freq <= 0 or reference_freq <= 0:
		return "Miss"
	
	var diff = get_note_difference(player_freq, reference_freq)
	
	if diff <= 0.25:  # Within 25 cents
		return "Perfect"
	elif diff <= 0.5:  # Within 50 cents
		return "Good"
	else:
		return "Miss"

# === PUBLIC API ===

func clear():
	"""Clear all pitch data"""
	player_pitch = 0.0
	reference_pitch = 0.0
	player_note = ""
	reference_note = ""
	pitch_history.clear()
	queue_redraw()

func set_display_range(min_note: String, max_note: String):
	"""Set display range by note names (e.g., "C3", "B5")"""
	# Parse note names to extract octaves
	# This is a simplified version
	var min_octave = int(min_note.substr(-1, 1))
	var max_octave = int(max_note.substr(-1, 1))
	set_note_range(min_octave, max_octave)

func set_colors(player: Color, reference: Color):
	"""Customize display colors"""
	player_color = player
	reference_color = reference

func scroll_display(_scroll_amount: float):
	"""Scroll the pitch display (for moving visualization)"""
	# This can be used if you want the display to scroll/move
	# For now, it's a placeholder that does nothing
	# You can implement scrolling behavior if needed
	pass
