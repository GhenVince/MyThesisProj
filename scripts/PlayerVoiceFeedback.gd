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
	"""Setup independent microphone playback with reverb"""
	print("\n🎤 Setting up voice feedback...")
	
	# Don't create a new bus - just use Master directly like Test 4!
	# Test 4 worked because it used Master directly at +18 dB
	
	print("✓ Using Master bus directly (like Test 4 that worked!)")
	
	# Create a separate bus for mic processing (noise suppression + effects)
	var mic_bus_idx = AudioServer.get_bus_index("MicProcessing")
	if mic_bus_idx == -1:
		mic_bus_idx = AudioServer.bus_count
		AudioServer.add_bus(mic_bus_idx)
		AudioServer.set_bus_name(mic_bus_idx, "MicProcessing")
		print("✓ Created MicProcessing bus at index: " + str(mic_bus_idx))
	
	# Clear existing effects
	for i in range(AudioServer.get_bus_effect_count(mic_bus_idx) - 1, -1, -1):
		AudioServer.remove_bus_effect(mic_bus_idx, i)
	
	# 1. Noise Gate - Suppress background noise
	var noise_gate = AudioEffectCompressor.new()
	noise_gate.threshold = -35.0  # Only let sound through above this level
	noise_gate.ratio = 20.0       # Heavy compression below threshold
	noise_gate.attack_us = 10.0   # Fast attack
	noise_gate.release_ms = 100.0 # Smooth release
	AudioServer.add_bus_effect(mic_bus_idx, noise_gate)
	print("✓ Added Noise Gate (-35 dB threshold)")
	
	# 2. High-pass filter (remove low frequency noise)
	var highpass = AudioEffectHighPassFilter.new()
	highpass.cutoff_hz = 80.0     # Remove rumble below 80 Hz
	highpass.resonance = 0.5
	AudioServer.add_bus_effect(mic_bus_idx, highpass)
	print("✓ Added High-pass Filter (80 Hz)")
	
	# 3. Reverb - Karaoke effect
	var reverb = AudioEffectReverb.new()
	reverb.room_size = 0.8
	reverb.damping = 0.4
	reverb.spread = 1.0
	reverb.dry = 0.6
	reverb.wet = 0.4
	reverb.predelay_msec = 20.0
	reverb.predelay_feedback = 0.4
	AudioServer.add_bus_effect(mic_bus_idx, reverb)
	print("✓ Added Reverb (0.8 room, 40% wet)")
	
	# 4. Limiter - Prevent clipping
	var limiter = AudioEffectLimiter.new()
	limiter.threshold_db = -3.0
	limiter.ceiling_db = -0.5
	AudioServer.add_bus_effect(mic_bus_idx, limiter)
	print("✓ Added Limiter")
	
	# Route MicProcessing to Master
	AudioServer.set_bus_send(mic_bus_idx, "Master")
	AudioServer.set_bus_mute(mic_bus_idx, false)
	print("✓ MicProcessing → Master")
	
	# Create AudioStreamPlayer for microphone
	mic_player = AudioStreamPlayer.new()
	add_child(mic_player)
	mic_player.bus = "MicProcessing"  # Use processing bus with noise suppression
	mic_player.volume_db = 0.0  # Normal volume
	print("✓ Created AudioStreamPlayer on MicProcessing (0 dB)")
	
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
	print("Setup: Microphone → Noise Suppression → Reverb → Master → Speakers")
	print("You should hear yourself NOW (with clean audio)!")
	print(line + "\n")

func _exit_tree():
	"""Cleanup when node is removed"""
	if mic_player:
		mic_player.stop()
		mic_player.queue_free()
