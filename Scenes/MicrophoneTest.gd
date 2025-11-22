# MicrophoneTest.gd
# Attach to a Node in a test scene and run (F6)
extends Node

var audio_effect_capture: AudioEffectCapture
var test_duration = 5.0
var elapsed = 0.0

func _ready():
	print("\n" + "=".repeat(60))
	print("MICROPHONE SETUP AND TEST")
	print("=".repeat(60))
	
	check_project_settings()
	setup_audio_bus()
	list_audio_devices()
	
	print("\n🎤 Speak into your microphone now...")
	print("Testing for ", test_duration, " seconds...\n")

func check_project_settings():
	print("\n[1] Checking Project Settings...")
	
	# Note: Can't directly check "Enable Audio Input" via code
	# but we can check if input device exists
	var input_device = AudioServer.get_input_device()
	print("  Input Device: ", input_device if input_device != "" else "Default")
	
	print("\n  ⚠ IMPORTANT: Verify in Project Settings:")
	print("     Project → Project Settings → Audio → Driver")
	print("     'Enable Audio Input' must be checked ✓")

func list_audio_devices():
	print("\n[2] Available Audio Devices...")
	
	# Get input device
	var input_device = AudioServer.get_input_device()
	print("  Current Input: ", input_device if input_device != "" else "Default")
	
	# List all available devices (if supported)
	var device_list = AudioServer.get_input_device_list()
	if device_list.size() > 0:
		print("  Available inputs:")
		for device in device_list:
			print("    - ", device)
	else:
		print("  (Device list not available on this platform)")

func setup_audio_bus():
	print("\n[3] Setting Up Audio Bus...")
	
	# Get or create Record bus
	var idx = AudioServer.get_bus_index("Record")
	if idx == -1:
		idx = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, "Record")
		print("  Created 'Record' bus at index: ", idx)
	else:
		print("  'Record' bus exists at index: ", idx)
	
	# Clear existing effects
	var effect_count = AudioServer.get_bus_effect_count(idx)
	print("  Existing effects: ", effect_count)
	for i in range(effect_count - 1, -1, -1):
		AudioServer.remove_bus_effect(idx, i)
	
	# Add capture effect
	audio_effect_capture = AudioEffectCapture.new()
	audio_effect_capture.buffer_length = 0.1
	AudioServer.add_bus_effect(idx, audio_effect_capture)
	
	print("  ✓ AudioEffectCapture added")
	print("  Buffer length: ", audio_effect_capture.buffer_length, " seconds")
	
	# Enable the bus
	AudioServer.set_bus_mute(idx, false)
	print("  ✓ Bus unmuted")

func _process(delta):
	if not audio_effect_capture:
		return
	
	elapsed += delta
	
	# Try to get audio data
	if audio_effect_capture.can_get_buffer(512):
		var buffer = audio_effect_capture.get_buffer(512)
		
		if buffer.size() > 0:
			# Calculate volume
			var sum = 0.0
			var max_amp = 0.0
			for frame in buffer:
				var amp = (abs(frame.x) + abs(frame.y)) / 2.0
				sum += amp
				max_amp = max(max_amp, amp)
			
			var avg_volume = sum / buffer.size()
			
			# Visual feedback
			if max_amp > 0.01:
				var bar_length = int(max_amp * 50)
				var bar = "█".repeat(bar_length)
				print("🎤 ", bar, " (", "%.4f" % max_amp, ")")
			else:
				if int(elapsed * 2) % 2 == 0:  # Print every 0.5 seconds
					print("   ... (too quiet or no input)")
	else:
		if int(elapsed * 2) % 2 == 0:
			print("   ⚠ No audio data available")
	
	# End test
	if elapsed >= test_duration:
		print("\n" + "=".repeat(60))
		print("TEST COMPLETE")
		print("=".repeat(60))
		
		if audio_effect_capture.can_get_buffer(100):
			print("✓ SUCCESS: Microphone is working!")
			print("\nYour microphone is set up correctly.")
		else:
			print("❌ PROBLEM: No audio data received")
			print("\nPossible fixes:")
			print("1. Enable Audio Input in Project Settings")
			print("2. Check microphone permissions")
			print("3. Select correct input device")
			print("4. Restart Godot after changing settings")
		
		get_tree().quit()

# Alternative: Manual device selection
func set_input_device(device_name: String):
	AudioServer.set_input_device(device_name)
	print("Input device set to: ", device_name)
