# GameManager.gd (AutoLoad as "GameManager")
# IMPROVED VERSION with save system and settings management
extends Node

# Current game state
var current_song: Dictionary = {}
var game_score: int = 0
var perfect_count: int = 0
var good_count: int = 0
var miss_count: int = 0
var player_timbre_data: Array = []

# Settings
var master_volume: float = 0.8
var music_volume: float = 0.7
var sfx_volume: float = 0.8
var feedback_volume: float = 0.6  # For player voice monitoring

# Constants
const SAVE_PATH = "user://game_data.save"
const SETTINGS_PATH = "user://settings.save"

func _ready():
	load_settings()
	apply_audio_settings()

# === GAME STATE MANAGEMENT ===

func reset_game_stats():
	"""Reset all game statistics for a new game"""
	game_score = 0
	perfect_count = 0
	good_count = 0
	miss_count = 0
	player_timbre_data.clear()

func add_score(score_type: String):
	"""Add score based on hit quality"""
	match score_type:
		"Perfect":
			game_score += 1000
			perfect_count += 1
		"Good":
			game_score += 500
			good_count += 1
		"Miss":
			miss_count += 1

func get_accuracy() -> float:
	"""Calculate overall accuracy percentage"""
	var total_notes = perfect_count + good_count + miss_count
	if total_notes == 0:
		return 0.0
	
	var weighted_hits = perfect_count + (good_count * 0.5)
	return (weighted_hits / float(total_notes)) * 100.0

func get_rank() -> String:
	"""Get performance rank based on accuracy"""
	var accuracy = get_accuracy()
	
	if accuracy >= 95.0:
		return "S"
	elif accuracy >= 90.0:
		return "A"
	elif accuracy >= 80.0:
		return "B"
	elif accuracy >= 70.0:
		return "C"
	elif accuracy >= 60.0:
		return "D"
	else:
		return "F"

# === SETTINGS MANAGEMENT ===

func set_master_volume(value: float):
	"""Set master volume (0.0 to 1.0)"""
	master_volume = clamp(value, 0.0, 1.0)
	apply_audio_settings()
	save_settings()

func set_music_volume(value: float):
	"""Set background music volume (0.0 to 1.0)"""
	music_volume = clamp(value, 0.0, 1.0)
	apply_audio_settings()
	save_settings()

func set_sfx_volume(value: float):
	"""Set sound effects volume (0.0 to 1.0)"""
	sfx_volume = clamp(value, 0.0, 1.0)
	apply_audio_settings()
	save_settings()

func set_feedback_volume(value: float):
	"""Set player voice feedback volume (0.0 to 1.0)"""
	feedback_volume = clamp(value, 0.0, 1.0)
	apply_audio_settings()
	save_settings()

func apply_audio_settings():
	"""Apply volume settings to audio buses"""
	var master_db = linear_to_db(master_volume)
	var music_db = linear_to_db(music_volume)
	var sfx_db = linear_to_db(sfx_volume)
	var feedback_db = linear_to_db(feedback_volume)
	
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), master_db)
	
	var music_bus = AudioServer.get_bus_index("Music")
	if music_bus != -1:
		AudioServer.set_bus_volume_db(music_bus, music_db)
	
	var sfx_bus = AudioServer.get_bus_index("SFX")
	if sfx_bus != -1:
		AudioServer.set_bus_volume_db(sfx_bus, sfx_db)
	
	var monitor_bus = AudioServer.get_bus_index("PlayerMonitor")
	if monitor_bus != -1:
		AudioServer.set_bus_volume_db(monitor_bus, feedback_db)

func linear_to_db(linear: float) -> float:
	"""Convert linear volume (0-1) to decibels"""
	if linear <= 0.0:
		return -80.0
	return 20.0 * log(linear) / log(10.0)

# === SAVE/LOAD SYSTEM ===

func save_settings():
	"""Save game settings to disk"""
	var save_data = {
		"master_volume": master_volume,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"feedback_volume": feedback_volume
	}
	
	var file = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file:
		file.store_var(save_data)
		file.close()
		print("✓ Settings saved")
	else:
		push_error("Failed to save settings")

func load_settings():
	"""Load game settings from disk"""
	if not FileAccess.file_exists(SETTINGS_PATH):
		print("No settings file found, using defaults")
		return
	
	var file = FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file:
		var save_data = file.get_var()
		file.close()
		
		if save_data is Dictionary:
			master_volume = save_data.get("master_volume", 0.8)
			music_volume = save_data.get("music_volume", 0.7)
			sfx_volume = save_data.get("sfx_volume", 0.8)
			feedback_volume = save_data.get("feedback_volume", 0.6)
			print("✓ Settings loaded")
	else:
		push_error("Failed to load settings")

# === UTILITY FUNCTIONS ===

func format_time(seconds: float) -> String:
	"""Format time as MM:SS"""
	var minutes = int(seconds) / 60
	var secs = int(seconds) % 60
	return "%02d:%02d" % [minutes, secs]

func format_score(score: int) -> String:
	"""Format score with commas"""
	var score_str = str(score)
	var result = ""
	var count = 0
	
	for i in range(score_str.length() - 1, -1, -1):
		if count == 3:
			result = "," + result
			count = 0
		result = score_str[i] + result
		count += 1
	
	return result
