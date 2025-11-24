# UltimateMicTest.gd
# This will check EVERYTHING and tell us exactly what's wrong
extends Node

var test_player: AudioStreamPlayer
var mic_stream: AudioStreamMicrophone

func _ready():
	var line = "=================================================="
	print("\n" + line)
	print("ULTIMATE MICROPHONE DIAGNOSTIC")
	print(line)
	
	await get_tree().create_timer(1.0).timeout
	
	run_all_tests()

func run_all_tests():
	print("\n=== TEST 1: CHECKING MICROPHONE DEVICES ===")
	check_mic_devices()
	
	await get_tree().create_timer(1.0).timeout
	
	print("\n=== TEST 2: CHECKING AUDIO BUSES ===")
	check_audio_buses()
	
	await get_tree().create_timer(1.0).timeout
	
	print("\n=== TEST 3: SIMPLE BEEP TEST ===")
	await test_beep()
	
	await get_tree().create_timer(2.0).timeout
	
	print("\n=== TEST 4: DIRECT MICROPHONE STREAM TEST ===")
	await test_direct_mic_stream()
	
	await get_tree().create_timer(1.0).timeout
	
	print("\n=== TEST 5: CHECKING PLAYBACK DEVICE ===")
	check_output_device()
	
	var line = "=================================================="
	print("\n" + line)
	print("DIAGNOSTIC COMPLETE - CHECK RESULTS ABOVE")
	print(line + "\n")

func check_mic_devices():
	"""Check what microphone devices are available"""
	print("\n🎤 Available Input Devices:")
	
	var input_device = AudioServer.get_input_device()
	print("   Current input device: " + str(input_device))
	
	var device_list = AudioServer.get_input_device_list()
	print("   Total devices found: " + str(device_list.size()))
	
	if device_list.size() == 0:
		print("   ❌ NO INPUT DEVICES FOUND!")
		print("   This means:")
		print("   - No microphone detected by system")
		print("   - Or Godot can't access microphone")
		print("   - Check Windows Settings → Privacy → Microphone")
	else:
		for i in range(device_list.size()):
			var marker = " ← CURRENT" if device_list[i] == input_device else ""
			print("   " + str(i + 1) + ". " + device_list[i] + marker)

func check_audio_buses():
	"""Check all audio buses"""
	print("\n🔊 Audio Buses:")
	
	for i in range(AudioServer.bus_count):
		var bus_name = AudioServer.get_bus_name(i)
		var volume = AudioServer.get_bus_volume_db(i)
		var muted = AudioServer.is_bus_mute(i)
		var send = AudioServer.get_bus_send(i)
		
		print("\n   " + str(i) + ". " + bus_name)
		print("      Volume: " + str(volume) + " dB")
		print("      Muted: " + str(muted))
		print("      Sends to: " + send)
		
		if muted:
			print("      ⚠️  THIS BUS IS MUTED!")

func test_beep():
	"""Test if we can hear ANY audio from Godot"""
	print("\n🔊 Testing audio output...")
	print("   Playing 1 second beep at 440 Hz...")
	print("   LISTEN NOW!")
	
	var player = AudioStreamPlayer.new()
	add_child(player)
	player.bus = "Master"
	player.volume_db = 12.0  # LOUD
	
	var stream = AudioStreamGenerator.new()
	stream.mix_rate = 44100.0
	player.stream = stream
	player.play()
	
	var playback = player.get_stream_playback()
	if playback:
		for i in range(44100):  # 1 second
			var phase = float(i) / 44100.0
			var sample = sin(phase * 440.0 * TAU) * 0.5
			playback.push_frame(Vector2(sample, sample))
	
	await get_tree().create_timer(1.2).timeout
	
	player.queue_free()
	
	print("\n   Did you hear the beep?")
	print("   YES → Godot audio output works")
	print("   NO → System audio issue (check volume mixer)")

func test_direct_mic_stream():
	"""Test AudioStreamMicrophone directly"""
	print("\n🎤 Testing AudioStreamMicrophone...")
	
	# Create fresh player
	test_player = AudioStreamPlayer.new()
	add_child(test_player)
	
	# Set to Master with HIGH volume
	test_player.bus = "Master"
	test_player.volume_db = 18.0  # VERY LOUD
	print("   ✓ Created player on Master bus (+18 dB)")
	
	# Create microphone stream
	mic_stream = AudioStreamMicrophone.new()
	test_player.stream = mic_stream
	print("   ✓ Created AudioStreamMicrophone")
	
	# Check if stream is valid
	if mic_stream == null:
		print("   ❌ Failed to create microphone stream!")
		return
	
	print("   ✓ Microphone stream created successfully")
	
	# Start playing
	test_player.play()
	print("   ✓ Started playback")
	
	print("\n   🎤 SPEAK OR SING NOW FOR 5 SECONDS!")
	print("   Volume is set to +18 dB (VERY LOUD)")
	print("   You should DEFINITELY hear yourself...")
	
	# Monitor for 5 seconds
	for i in range(5):
		await get_tree().create_timer(1.0).timeout
		var is_playing = test_player.playing
		print("   ... second " + str(i + 1) + "/5 (playing: " + str(is_playing) + ")")
	
	print("\n   Test finished!")
	print("   Did you hear yourself?")
	print("   YES → Microphone works, something else is interfering")
	print("   NO → Microphone not being captured OR output issue")
	
	test_player.stop()
	test_player.queue_free()

func check_output_device():
	"""Check output device settings"""
	print("\n🔊 Output Device Check:")
	
	var output_device = AudioServer.get_output_device()
	print("   Current output device: " + str(output_device))
	
	var device_list = AudioServer.get_output_device_list()
	print("   Total output devices: " + str(device_list.size()))
	
	if device_list.size() == 0:
		print("   ❌ NO OUTPUT DEVICES FOUND!")
	else:
		for i in range(device_list.size()):
			var marker = " ← CURRENT" if device_list[i] == output_device else ""
			print("   " + str(i + 1) + ". " + device_list[i] + marker)
	
	print("\n   Master bus volume: " + str(AudioServer.get_bus_volume_db(0)) + " dB")
	print("   Master bus muted: " + str(AudioServer.is_bus_mute(0)))
