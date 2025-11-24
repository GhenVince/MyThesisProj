# OptionsMenu.gd
# Options popup menu with volume controls and settings
extends Control

signal closed

# UI References - Volume Sliders
@onready var master_volume_slider = $Panel/VBox/VolumeSection/MasterVolume/Slider
@onready var master_volume_label = $Panel/VBox/VolumeSection/MasterVolume/ValueLabel
@onready var music_volume_slider = $Panel/VBox/VolumeSection/MusicVolume/Slider
@onready var music_volume_label = $Panel/VBox/VolumeSection/MusicVolume/ValueLabel
@onready var sfx_volume_slider = $Panel/VBox/VolumeSection/SFXVolume/Slider
@onready var sfx_volume_label = $Panel/VBox/VolumeSection/SFXVolume/ValueLabel
@onready var feedback_volume_slider = $Panel/VBox/VolumeSection/FeedbackVolume/Slider
@onready var feedback_volume_label = $Panel/VBox/VolumeSection/FeedbackVolume/ValueLabel

# UI References - Graphics
@onready var fullscreen_checkbox = $Panel/VBox/GraphicsSection/FullscreenCheck
@onready var vsync_checkbox = $Panel/VBox/GraphicsSection/VsyncCheck
@onready var fps_limit_option = $Panel/VBox/GraphicsSection/FPSLimit/OptionButton

# UI References - Gameplay
@onready var pitch_sensitivity_slider = $Panel/VBox/GameplaySection/PitchSensitivity/Slider
@onready var pitch_sensitivity_label = $Panel/VBox/GameplaySection/PitchSensitivity/ValueLabel
@onready var lyric_offset_slider = $Panel/VBox/GameplaySection/LyricOffset/Slider
@onready var lyric_offset_label = $Panel/VBox/GameplaySection/LyricOffset/ValueLabel
@onready var auto_pause_checkbox = $Panel/VBox/GameplaySection/AutoPauseCheck

# UI References - Buttons
@onready var close_button = $Panel/VBox/ButtonSection/CloseButton
@onready var reset_button = $Panel/VBox/ButtonSection/ResetButton
@onready var apply_button = $Panel/VBox/ButtonSection/ApplyButton

# Settings
var settings: Dictionary = {
	"master_volume": 0.8,
	"music_volume": 0.7,
	"sfx_volume": 0.8,
	"feedback_volume": 0.6,
	"fullscreen": false,
	"vsync": true,
	"fps_limit": 0,  # 0 = unlimited
	"pitch_sensitivity": 1.0,
	"lyric_offset": 0.0,
	"auto_pause": true
}

func _ready():
	# Make it a popup
	setup_as_popup()
	
	# Load current settings
	load_settings()
	
	# Connect signals
	connect_signals()
	
	# Update UI
	update_all_ui()

func setup_as_popup():
	"""Configure as a popup window"""
	hide()  # Start hidden
	
	# Center on screen
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	
	# Add background dimming
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP  # Block clicks behind
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = -1
	add_child(overlay)
	move_child(overlay, 0)

func connect_signals():
	"""Connect all UI signals"""
	# Volume sliders
	if master_volume_slider:
		master_volume_slider.value_changed.connect(_on_master_volume_changed)
	if music_volume_slider:
		music_volume_slider.value_changed.connect(_on_music_volume_changed)
	if sfx_volume_slider:
		sfx_volume_slider.value_changed.connect(_on_sfx_volume_changed)
	if feedback_volume_slider:
		feedback_volume_slider.value_changed.connect(_on_feedback_volume_changed)
	
	# Graphics
	if fullscreen_checkbox:
		fullscreen_checkbox.toggled.connect(_on_fullscreen_toggled)
	if vsync_checkbox:
		vsync_checkbox.toggled.connect(_on_vsync_toggled)
	if fps_limit_option:
		fps_limit_option.item_selected.connect(_on_fps_limit_changed)
	
	# Gameplay
	if pitch_sensitivity_slider:
		pitch_sensitivity_slider.value_changed.connect(_on_pitch_sensitivity_changed)
	if lyric_offset_slider:
		lyric_offset_slider.value_changed.connect(_on_lyric_offset_changed)
	if auto_pause_checkbox:
		auto_pause_checkbox.toggled.connect(_on_auto_pause_toggled)
	
	# Buttons
	if close_button:
		close_button.pressed.connect(_on_close_pressed)
	if reset_button:
		reset_button.pressed.connect(_on_reset_pressed)
	if apply_button:
		apply_button.pressed.connect(_on_apply_pressed)

# === VOLUME CONTROLS ===

func _on_master_volume_changed(value: float):
	settings["master_volume"] = value / 100.0
	master_volume_label.text = "%d%%" % int(value)
	GameManager.set_master_volume(settings["master_volume"])

func _on_music_volume_changed(value: float):
	settings["music_volume"] = value / 100.0
	music_volume_label.text = "%d%%" % int(value)
	GameManager.set_music_volume(settings["music_volume"])

func _on_sfx_volume_changed(value: float):
	settings["sfx_volume"] = value / 100.0
	sfx_volume_label.text = "%d%%" % int(value)
	GameManager.set_sfx_volume(settings["sfx_volume"])

func _on_feedback_volume_changed(value: float):
	settings["feedback_volume"] = value / 100.0
	feedback_volume_label.text = "%d%%" % int(value)
	GameManager.set_feedback_volume(settings["feedback_volume"])

# === GRAPHICS CONTROLS ===

func _on_fullscreen_toggled(toggled: bool):
	settings["fullscreen"] = toggled
	if toggled:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _on_vsync_toggled(toggled: bool):
	settings["vsync"] = toggled
	if toggled:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

func _on_fps_limit_changed(index: int):
	var limits = [0, 30, 60, 120, 144]
	settings["fps_limit"] = limits[index]
	Engine.max_fps = settings["fps_limit"]

# === GAMEPLAY CONTROLS ===

func _on_pitch_sensitivity_changed(value: float):
	settings["pitch_sensitivity"] = value
	pitch_sensitivity_label.text = "%.1fx" % value

func _on_lyric_offset_changed(value: float):
	settings["lyric_offset"] = value
	lyric_offset_label.text = "%.2fs" % value

func _on_auto_pause_toggled(toggled: bool):
	settings["auto_pause"] = toggled

# === BUTTON ACTIONS ===

func _on_close_pressed():
	"""Close and return to main menu"""
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _on_reset_pressed():
	"""Reset to default settings"""
	reset_to_defaults()
	update_all_ui()
	apply_all_settings()

func _on_apply_pressed():
	"""Apply and save settings"""
	apply_all_settings()
	save_settings()

# === SETTINGS MANAGEMENT ===

func load_settings():
	"""Load settings from GameManager or saved file"""
	# Load from GameManager (which loads from disk)
	settings["master_volume"] = GameManager.master_volume
	settings["music_volume"] = GameManager.music_volume
	settings["sfx_volume"] = GameManager.sfx_volume
	settings["feedback_volume"] = GameManager.feedback_volume
	
	# Load other settings from a custom file
	var save_path = "user://options.save"
	if FileAccess.file_exists(save_path):
		var file = FileAccess.open(save_path, FileAccess.READ)
		if file:
			var saved_data = file.get_var()
			file.close()
			
			if saved_data is Dictionary:
				for key in saved_data:
					if settings.has(key):
						settings[key] = saved_data[key]

func save_settings():
	"""Save all settings to disk"""
	# Volume settings are saved by GameManager
	GameManager.set_master_volume(settings["master_volume"])
	GameManager.set_music_volume(settings["music_volume"])
	GameManager.set_sfx_volume(settings["sfx_volume"])
	GameManager.set_feedback_volume(settings["feedback_volume"])
	
	# Save other settings
	var save_path = "user://options.save"
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_var(settings)
		file.close()
		print("✓ Options saved")

func apply_all_settings():
	"""Apply all current settings"""
	# Volume
	GameManager.set_master_volume(settings["master_volume"])
	GameManager.set_music_volume(settings["music_volume"])
	GameManager.set_sfx_volume(settings["sfx_volume"])
	GameManager.set_feedback_volume(settings["feedback_volume"])
	
	# Graphics
	if settings["fullscreen"]:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	
	if settings["vsync"]:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	
	Engine.max_fps = settings["fps_limit"]

func reset_to_defaults():
	"""Reset all settings to default values"""
	settings = {
		"master_volume": 0.8,
		"music_volume": 0.7,
		"sfx_volume": 0.8,
		"feedback_volume": 0.6,
		"fullscreen": false,
		"vsync": true,
		"fps_limit": 0,
		"pitch_sensitivity": 1.0,
		"lyric_offset": 0.0,
		"auto_pause": true
	}

func update_all_ui():
	"""Update all UI elements to match current settings"""
	# Volume sliders
	if master_volume_slider:
		master_volume_slider.value = settings["master_volume"] * 100
		master_volume_label.text = "%d%%" % int(settings["master_volume"] * 100)
	
	if music_volume_slider:
		music_volume_slider.value = settings["music_volume"] * 100
		music_volume_label.text = "%d%%" % int(settings["music_volume"] * 100)
	
	if sfx_volume_slider:
		sfx_volume_slider.value = settings["sfx_volume"] * 100
		sfx_volume_label.text = "%d%%" % int(settings["sfx_volume"] * 100)
	
	if feedback_volume_slider:
		feedback_volume_slider.value = settings["feedback_volume"] * 100
		feedback_volume_label.text = "%d%%" % int(settings["feedback_volume"] * 100)
	
	# Graphics
	if fullscreen_checkbox:
		fullscreen_checkbox.button_pressed = settings["fullscreen"]
	
	if vsync_checkbox:
		vsync_checkbox.button_pressed = settings["vsync"]
	
	if fps_limit_option:
		var limits = [0, 30, 60, 120, 144]
		var index = limits.find(settings["fps_limit"])
		if index >= 0:
			fps_limit_option.selected = index
	
	# Gameplay
	if pitch_sensitivity_slider:
		pitch_sensitivity_slider.value = settings["pitch_sensitivity"]
		pitch_sensitivity_label.text = "%.1fx" % settings["pitch_sensitivity"]
	
	if lyric_offset_slider:
		lyric_offset_slider.value = settings["lyric_offset"]
		lyric_offset_label.text = "%.2fs" % settings["lyric_offset"]
	
	if auto_pause_checkbox:
		auto_pause_checkbox.button_pressed = settings["auto_pause"]

# === PUBLIC API ===

func open():
	"""Show the options menu"""
	load_settings()
	update_all_ui()
	show()

func get_setting(key: String):
	"""Get a specific setting value"""
	return settings.get(key, null)
