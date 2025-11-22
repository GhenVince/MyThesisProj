# AudioCaptureComparison.gd
# Run this to see the difference between test and game setup
extends Node

var test_capture: AudioEffectCapture
var game_style_capture: AudioEffectCapture

func _ready():
	print("\n" + "=".repeat(70))
	print("AUDIO CAPTURE COMPARISON TEST")
	print("This will show you the difference between test setup and game setup")
	print("=".repeat(70))
	
	setup_test_style()
	await get_tree().create_timer(1.0).timeout
	setup_game_style()
	await get_tree().create_timer(1.0).timeout
	
	print("\n🎤 Speak into your microphone for 10 seconds...")
	print("Comparing both setups...\n")

func setup_test_style():
	print("\n[1] Setting up TEST STYLE (like MicrophoneTest.gd)...")
	
	# Create a fresh bus for test
	var test_idx = AudioServer.bus_count
	AudioServer.add_bus(test_idx)
	AudioServer.set_bus_name(test_idx, "TestCapture")
	
	# Clear effects
	for i in range(AudioServer.get_bus_effect_count(test_idx) - 1, -1, -1):
		AudioServer.remove_bus_effect(test_idx, i)
	
	# Add amplifier
	var amp = AudioEffectAmplify.new()
	amp.volume_db = 18.0
	AudioServer.add_bus_effect(test_idx, amp)
	
	# Add capture
	test_capture = AudioEffectCapture.new()
	test_capture.buffer_length = 0.1
	AudioServer.add_bus_effect(test_idx, test_capture)
	
	AudioServer.set_bus_mute(test_idx, false)
	
	print("  ✓ Test bus created at index: ", test_idx)
	print("  ✓ Amplifier: +18dB")
	print("  ✓ Capture buffer: 0.1s")

func setup_game_style():
	print("\n[2] Setting up GAME STYLE (like YINPitchDetector)...")
	
	# Use or create Record bus
	var game_idx = AudioServer.get_bus_index("Record")
	if game_idx == -1:
		game_idx = AudioServer.bus_count
		AudioServer.add_bus(game_idx)
		AudioServer.set_bus_name(game_idx, "Record")
	
	# Clear effects
	for i in range(AudioServer.get_bus_effect_count(game_idx) - 1, -1, -1):
		AudioServer.remove_bus_effect(game_idx, i)
	
	# Add amplifier
	var amp = AudioEffectAmplify.new()
	amp.volume_db = 18.0
	AudioServer.add_bus_effect(game_idx, amp)
	
	# Add capture
	game_style_capture = AudioEffectCapture.new()
	game_style_capture.buffer_length = 0.1
	AudioServer.add_bus_effect(game_idx, game_style_capture)
	
	AudioServer.set_bus_mute(game_idx, false)
	
	print("  ✓ Record bus at index: ", game_idx)
	print("  ✓ Amplifier: +18dB")
	print("  ✓ Capture buffer: 0.1s")

var elapsed = 0.0
var test_working_count = 0
var game_working_count = 0

func _process(delta):
	elapsed += delta
	
	# Test capture
	var test_volume = 0.0
	if test_capture and test_capture.can_get_buffer(512):
		var buffer = test_capture.get_buffer(512)
		for frame in buffer:
			test_volume += abs(frame.x) + abs(frame.y)
		test_volume = test_volume / (buffer.size() * 2.0) if buffer.size() > 0 else 0.0
		if test_volume > 0.001:
			test_working_count += 1
	
	# Game capture
	var game_volume = 0.0
	if game_style_capture and game_style_capture.can_get_buffer(512):
		var buffer = game_style_capture.get_buffer(512)
		for frame in buffer:
			game_volume += abs(frame.x) + abs(frame.y)
		game_volume = game_volume / (buffer.size() * 2.0) if buffer.size() > 0 else 0.0
		if game_volume > 0.001:
			game_working_count += 1
	
	# Print comparison every 0.5 seconds
	if int(elapsed * 2) % 2 == 0 and Engine.get_process_frames() % 30 == 0:
		var test_bar = "█".repeat(int(test_volume * 100))
		var game_bar = "█".repeat(int(game_volume * 100))
		
		print("TEST: ", test_bar if test_bar != "" else "(silent)", " | GAME: ", game_bar if game_bar != "" else "(silent)")
	
	# End test
	if elapsed > 10.0:
		print("\n" + "=".repeat(70))
		print("TEST COMPLETE - RESULTS:")
		print("=".repeat(70))
		
		print("\nTEST setup captured audio: ", test_working_count, " times")
		print("GAME setup captured audio: ", game_working_count, " times")
		
		if test_working_count > 0 and game_working_count == 0:
			print("\n❌ PROBLEM FOUND!")
			print("TEST works but GAME doesn't!")
			print("\nPossible causes:")
			print("  1. Multiple YINPitchDetector instances created")
			print("  2. Record bus being cleared somewhere else")
			print("  3. Timing issue - capture created before audio starts")
			print("\nSolution:")
			print("  - Make sure YINPitchDetector is only created ONCE")
			print("  - Create it as AutoLoad singleton")
			print("  - Or create it in _ready() and never delete it")
		elif test_working_count > 0 and game_working_count > 0:
			print("\n✓ BOTH WORK!")
			print("The setup is identical and both capture audio.")
			print("If game still doesn't work, check:")
			print("  - Is detect_pitch() being called every frame?")
			print("  - Is update_pitch_display() being called?")
			print("  - Is PitchDisplay.queue_redraw() being called?")
		elif test_working_count == 0:
			print("\n❌ NEITHER WORKS!")
			print("Microphone isn't being captured at all.")
			print("Check:")
			print("  1. Enable Audio Input in Project Settings")
			print("  2. Restart Godot")
			print("  3. Check microphone permissions")
			print("  4. Increase system mic volume")
		
		get_tree().quit()
