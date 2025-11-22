# YINPitchDetector.gd
extends Node

const SAMPLE_RATE = 44100
const BUFFER_SIZE = 2048
const THRESHOLD = 0.15

var audio_effect_capture: AudioEffectCapture
var recording_effect: AudioEffectRecord
var playback: AudioStreamGeneratorPlayback

var buffer: PackedFloat32Array = []

var audio_stream_player: AudioStreamPlayer

func _ready():
	print("=== YINPitchDetector Initializing ===")
	setup_audio_capture()

func setup_audio_capture():
	var idx = AudioServer.get_bus_index("Record")
	if idx == -1:
		idx = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, "Record")
		print("Created Record bus at index: ", idx)
	else:
		print("Using existing Record bus at index: ", idx)
	
	# CRITICAL: Clear ALL existing effects first
	var effect_count = AudioServer.get_bus_effect_count(idx)
	print("Removing ", effect_count, " existing effects...")
	for i in range(effect_count - 1, -1, -1):
		AudioServer.remove_bus_effect(idx, i)
	
	# CRITICAL FIX: Start AudioStreamMicrophone to activate the mic
	print("Starting AudioStreamMicrophone to activate microphone...")
	var mic_stream = AudioStreamMicrophone.new()
	audio_stream_player = AudioStreamPlayer.new()
	audio_stream_player.stream = mic_stream
	audio_stream_player.bus = "Record"
	audio_stream_player.volume_db = -80  # Silent - we just need it active
	add_child(audio_stream_player)
	audio_stream_player.play()
	print("✓ Microphone stream started (silent)")
	
	# Add amplifier for volume boost
	var amplifier = AudioEffectAmplify.new()
	amplifier.volume_db = 18.0
	AudioServer.add_bus_effect(idx, amplifier)
	print("Added AudioEffectAmplify: +18dB")
	
	# Add capture effect
	audio_effect_capture = AudioEffectCapture.new()
	audio_effect_capture.buffer_length = 0.5
	AudioServer.add_bus_effect(idx, audio_effect_capture)
	print("Added AudioEffectCapture with buffer: ", audio_effect_capture.buffer_length)
	
	# Enable microphone input on this bus
	var input_device = AudioServer.get_input_device()
	print("Current input device: ", input_device if input_device != "" else "Default")
	
	# Unmute the bus
	AudioServer.set_bus_mute(idx, false)
	print("Bus unmuted")
	
	# Wait a moment then check if working
	await get_tree().create_timer(1.0).timeout
	
	if audio_effect_capture and audio_effect_capture.can_get_buffer(100):
		print("✓✓✓ AudioCapture is WORKING!")
	else:
		push_error("❌❌❌ AudioCapture NOT receiving data!")
		push_error("Speak into microphone and check if you see audio bars")

func get_frames() -> PackedVector2Array:
	if not audio_effect_capture:
		return PackedVector2Array()
	
	if audio_effect_capture.can_get_buffer(BUFFER_SIZE):
		return audio_effect_capture.get_buffer(BUFFER_SIZE)
	
	return PackedVector2Array()

func detect_pitch() -> float:
	var frames = get_frames()
	if frames.size() < BUFFER_SIZE:
		return 0.0
	
	# Convert stereo to mono
	var mono_buffer = PackedFloat32Array()
	mono_buffer.resize(frames.size())
	
	var max_amplitude = 0.0
	for i in frames.size():
		mono_buffer[i] = (frames[i].x + frames[i].y) / 2.0
		max_amplitude = max(max_amplitude, abs(mono_buffer[i]))
	
	# Much lower threshold - detect quieter voices (was 0.01, now 0.003)
	if max_amplitude < 0.003:
		return 0.0
	
	# Apply gain to boost signals
	if max_amplitude < 0.1:
		var gain = 4.0  # Increased from 2.0
		for i in mono_buffer.size():
			mono_buffer[i] *= gain
	
	var pitch = yin_algorithm(mono_buffer)
	
	# Debug output
	if Engine.get_process_frames() % 60 == 0:
		if pitch > 0:
			print("✓ PLAYER PITCH DETECTED: %.2f Hz (volume: %.4f)" % [pitch, max_amplitude])
		else:
			print("⚠ No pitch (volume: %.4f)" % max_amplitude)
	
	return pitch

func yin_algorithm(samples: PackedFloat32Array) -> float:
	var buffer_size = samples.size()
	var half_buffer = int(buffer_size / 2.0)
	
	# Step 1: Calculate difference function
	var difference = PackedFloat32Array()
	difference.resize(half_buffer)
	difference.fill(0.0)
	
	for tau in range(1, half_buffer):
		for i in range(half_buffer):
			var delta = samples[i] - samples[i + tau]
			difference[tau] += delta * delta
	
	# Step 2: Cumulative mean normalized difference
	var cmnd = PackedFloat32Array()
	cmnd.resize(half_buffer)
	cmnd[0] = 1.0
	
	var running_sum = 0.0
	for tau in range(1, half_buffer):
		running_sum += difference[tau]
		if running_sum == 0:
			cmnd[tau] = 1.0
		else:
			cmnd[tau] = difference[tau] / (running_sum / tau)
	
	# Step 3: Absolute threshold
	var tau = 1
	while tau < half_buffer:
		if cmnd[tau] < THRESHOLD:
			while tau + 1 < half_buffer and cmnd[tau + 1] < cmnd[tau]:
				tau += 1
			break
		tau += 1
	
	if tau >= half_buffer - 1:
		return 0.0
	
	# Step 4: Parabolic interpolation
	var better_tau = tau
	if tau > 0 and tau < half_buffer - 1:
		var s0 = cmnd[tau - 1]
		var s1 = cmnd[tau]
		var s2 = cmnd[tau + 1]
		better_tau = tau + (s2 - s0) / (2 * (2 * s1 - s2 - s0))
	
	# Convert tau to frequency
	var frequency = SAMPLE_RATE / better_tau
	
	# Filter out unrealistic frequencies
	if frequency < 80 or frequency > 1000:
		return 0.0
	
	return frequency

func frequency_to_note(frequency: float) -> String:
	if frequency <= 0:
		return ""
	
	var note_names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
	var a4_freq = 440.0
	var c0_freq = a4_freq * pow(2.0, -4.75)
	
	var half_steps = round(12.0 * log(frequency / c0_freq) / log(2.0))
	var octave = int(half_steps / 12)
	var note_index = int(half_steps) % 12
	
	return note_names[note_index]

func get_note_with_cents(frequency: float) -> Dictionary:
	if frequency <= 0:
		return {"note": "", "cents": 0, "octave": 0}
	
	var note_names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
	var a4_freq = 440.0
	var c0_freq = a4_freq * pow(2.0, -4.75)
	
	var half_steps_float = 12.0 * log(frequency / c0_freq) / log(2.0)
	var half_steps = round(half_steps_float)
	var cents = (half_steps_float - half_steps) * 100.0
	
	var _octave = int(half_steps / 12.0)
	var note_index = int(half_steps) % 12
	
	return {
		"note": note_names[note_index],
		"octave": _octave,
		"cents": cents,
		"frequency": frequency
	}
