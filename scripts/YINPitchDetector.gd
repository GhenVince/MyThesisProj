# YINPitchDetector.gd
extends Node

const SAMPLE_RATE = 44100
const BUFFER_SIZE = 1024
const THRESHOLD = 0.15

var audio_effect_capture: AudioEffectCapture
var audio_stream_player: AudioStreamPlayer
var pitch_history: Array = []
var last_pitch: float = 0.0

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
	
	var effect_count = AudioServer.get_bus_effect_count(idx)
	print("Removing ", effect_count, " existing effects...")
	for i in range(effect_count - 1, -1, -1):
		AudioServer.remove_bus_effect(idx, i)
	
	print("Starting AudioStreamMicrophone for capture...")
	var mic_stream = AudioStreamMicrophone.new()
	audio_stream_player = AudioStreamPlayer.new()
	audio_stream_player.stream = mic_stream
	audio_stream_player.bus = "Record"
	audio_stream_player.volume_db = -80
	add_child(audio_stream_player)
	audio_stream_player.play()
	print("✓ Microphone stream started (silent)")
	
	var amplifier = AudioEffectAmplify.new()
	amplifier.volume_db = 30.0
	AudioServer.add_bus_effect(idx, amplifier)
	print("Added AudioEffectAmplify: +30dB")
	
	audio_effect_capture = AudioEffectCapture.new()
	audio_effect_capture.buffer_length = 0.5
	AudioServer.add_bus_effect(idx, audio_effect_capture)
	print("Added AudioEffectCapture with buffer: ", audio_effect_capture.buffer_length)
	
	AudioServer.set_bus_mute(idx, false)
	print("Bus unmuted")
	
	await get_tree().create_timer(1.0).timeout
	
	if audio_effect_capture and audio_effect_capture.can_get_buffer(100):
		print("✓✓✓ AudioCapture is WORKING!")
		
		var test_frames = audio_effect_capture.get_buffer(100)
		var volume = 0.0
		for frame in test_frames:
			volume += abs(frame.x) + abs(frame.y)
		volume = volume / (test_frames.size() * 2.0) if test_frames.size() > 0 else 0.0
		print("Current volume level: ", volume)
		if volume < 0.001:
			print("⚠ Volume very low - speak into microphone!")
		else:
			print("✓ Good volume level!")
	else:
		push_error("❌❌❌ AudioCapture NOT receiving data!")

func get_frames() -> PackedVector2Array:
	if not audio_effect_capture:
		return PackedVector2Array()
	
	if audio_effect_capture.can_get_buffer(BUFFER_SIZE):
		return audio_effect_capture.get_buffer(BUFFER_SIZE)
	elif audio_effect_capture.can_get_buffer(512):
		return audio_effect_capture.get_buffer(512)
	
	return PackedVector2Array()

func detect_pitch() -> float:
	var frames = get_frames()
	if frames.size() < 512:
		return 0.0
	
	var mono_buffer = PackedFloat32Array()
	mono_buffer.resize(frames.size())
	
	var max_amplitude = 0.0
	for i in frames.size():
		mono_buffer[i] = (frames[i].x + frames[i].y) / 2.0
		max_amplitude = max(max_amplitude, abs(mono_buffer[i]))
	
	if max_amplitude < 0.0005:
		return 0.0
	
	var gain = 10.0
	for i in mono_buffer.size():
		mono_buffer[i] *= gain
	
	var pitch = yin_algorithm(mono_buffer)
	
	# DEBUG: Show actual detected frequency
	if pitch > 0 and Engine.get_process_frames() % 30 == 0:
		print("Detected: %.1f Hz (%s)" % [pitch, frequency_to_note(pitch)])
	
	# Smooth the pitch MORE aggressively
	if pitch > 0:
		pitch_history.append(pitch)
		if pitch_history.size() > 5:  # Increased from 3 to 5
			pitch_history.pop_front()
		
		var smoothed = 0.0
		for p in pitch_history:
			smoothed += p
		smoothed /= pitch_history.size()
		
		# Stricter jump rejection (was 100 Hz, now 50 Hz)
		if last_pitch == 0.0 or abs(smoothed - last_pitch) < 50.0:
			last_pitch = smoothed
			pitch = smoothed
		else:
			# Reject jump, keep previous pitch
			pitch = last_pitch
	else:
		pitch_history.clear()
		last_pitch = 0.0
	
	return pitch

func yin_algorithm(samples: PackedFloat32Array) -> float:
	var buffer_size = samples.size()
	var half_buffer = int(buffer_size / 2.0)
	
	var difference = PackedFloat32Array()
	difference.resize(half_buffer)
	difference.fill(0.0)
	
	for tau in range(1, half_buffer):
		for i in range(half_buffer):
			var delta = samples[i] - samples[i + tau]
			difference[tau] += delta * delta
	
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
	
	# Find the absolute minimum (best period)
	var best_tau = 2
	var best_value = cmnd[2]
	
	# Search range for human voice (80-800 Hz)
	var min_tau = int(SAMPLE_RATE / 800.0)  # ~55 samples
	var max_tau = int(SAMPLE_RATE / 80.0)   # ~551 samples
	
	for tau in range(max(2, min_tau), min(half_buffer, max_tau)):
		if cmnd[tau] < best_value:
			best_value = cmnd[tau]
			best_tau = tau
	
	# Only accept if below threshold
	if best_value > THRESHOLD:
		return 0.0
	
	# Parabolic interpolation
	var better_tau = best_tau
	if best_tau > 0 and best_tau < half_buffer - 1:
		var s0 = cmnd[best_tau - 1]
		var s1 = cmnd[best_tau]
		var s2 = cmnd[best_tau + 1]
		var denominator = 2 * (2 * s1 - s2 - s0)
		if abs(denominator) > 0.0001:
			better_tau = best_tau + (s2 - s0) / denominator
	
	var frequency = SAMPLE_RATE / better_tau
	
	# Singing range - wider for deeper voices
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
