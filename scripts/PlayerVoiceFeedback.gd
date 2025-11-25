# PlayerVoiceFeedback.gd
# Dedicated node for playing back player's voice with reverb
# Independent from pitch detection system
extends Node

var mic_player: AudioStreamPlayer
var mic_stream: AudioStreamMicrophone

func _ready():
	var line = "=================================================="
	print("\n" + line)
	print("PLAYER VOICE FEEDBACK - STARTING")
	print(line)
	
	await get_tree().create_timer(0.5).timeout
	
	setup_voice_feedback()

func setup_voice_feedback():
	"""Setup microphone playback with reverb only"""
	print("\n🎤 Setting up voice feedback with reverb...")
	
	# Create a bus for mic with effects
	var mic_bus_idx = AudioServer.get_bus_index("MicFeedback")
	if mic_bus_idx == -1:
		mic_bus_idx = AudioServer.bus_count
		AudioServer.add_bus(mic_bus_idx)
		AudioServer.set_bus_name(mic_bus_idx, "MicFeedback")
		print("✓ Created MicFeedback bus at index: " + str(mic_bus_idx))
	
	# Clear any existing effects
	for i in range(AudioServer.get_bus_effect_count(mic_bus_idx) - 1, -1, -1):
		AudioServer.remove_bus_effect(mic_bus_idx, i)
	
	# Just Reverb - Karaoke effect (NO noise gate!)
	var reverb = AudioEffectReverb.new()
	reverb.room_size = 0.8
	reverb.damping = 0.5
	reverb.spread = 1.0
	reverb.dry = 0.7   # 70% original
	reverb.wet = 0.3   # 30% reverb
	AudioServer.add_bus_effect(mic_bus_idx, reverb)
	print("✓ Added reverb only (0.8 room, 30% wet)")
	
	# Route to Master
	AudioServer.set_bus_send(mic_bus_idx, "Master")
	AudioServer.set_bus_mute(mic_bus_idx, false)
	print("✓ MicFeedback → Master")
	
	# Create AudioStreamPlayer for microphone
	mic_player = AudioStreamPlayer.new()
	add_child(mic_player)
	mic_player.bus = "MicFeedback"
	mic_player.volume_db = -6.0  # Comfortable volume
	print("✓ Created AudioStreamPlayer (-6 dB)")
	
	# Create microphone stream
	mic_stream = AudioStreamMicrophone.new()
	mic_player.stream = mic_stream
	print("✓ Created AudioStreamMicrophone")
	
	# Start playing
	mic_player.play()
	print("✓ Microphone playback STARTED")
	
	var line = "=================================================="
	print("\n" + line)
	print("🎤 VOICE FEEDBACK ACTIVE!")
	print("Setup: Microphone → Reverb → Master (NO noise gate)")
	print("You should hear yourself clearly with reverb!")
	print(line + "\n")

func _exit_tree():
	"""Cleanup when node is removed"""
	if mic_player:
		mic_player.stop()
		mic_player.queue_free()
