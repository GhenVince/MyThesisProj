extends Node

# YIN Algorithm for pitch detection
class_name YINPitchDetector

@onready var pitch_label: Label = $PitchLabel

var audio_stream_player: AudioStreamPlayer
var audio_effect_capture: AudioEffectCapture
var sample_rate: float = 44100.0
var buffer_size: int = 1024
var yin_threshold: float = 0.15
var recording_bus_index: int

# Noise filtering parameters
var noise_gate_threshold: float = 0.0001  # Lower threshold - more sensitive
var signal_history: Array[float] = []
var history_size: int = 10
var pitch_stability_threshold: float = 50.0  # Hz difference for stable pitch
var show_debug_levels: bool = true  # Show signal levels for debugging

func _ready():
	setup_audio_recording()
	pitch_label.text = "Pitch: Setting up..."

func setup_audio_recording():
	# Create a dedicated bus for recording
	recording_bus_index = AudioServer.bus_count
	AudioServer.add_bus(recording_bus_index)
	AudioServer.set_bus_name(recording_bus_index, "Recording")
	
	# Add capture effect to the recording bus
	audio_effect_capture = AudioEffectCapture.new()
	audio_effect_capture.set_buffer_length(1.0)
	AudioServer.add_bus_effect(recording_bus_index, audio_effect_capture)
	
	# Create audio stream player and set it to use microphone
	audio_stream_player = AudioStreamPlayer.new()
	add_child(audio_stream_player)
	
	var microphone_stream = AudioStreamMicrophone.new()
	audio_stream_player.stream = microphone_stream
	audio_stream_player.bus = "Recording"  # Route to our recording bus
	
	# Much lower volume to prevent feedback and reverb detection
	audio_stream_player.volume_db = -60  # Very quiet
	
	# Start recording
	audio_stream_player.play()
	
	print("Audio recording setup complete")
	pitch_label.text = "Pitch: Listening..."

func _process(_delta):
	var audio_data = get_audio_samples()
	if audio_data.size() >= buffer_size:
		# Calculate and show signal level for debugging
		var signal_level = calculate_signal_level(audio_data)
		
		if show_debug_levels:
			print("Signal level: %.6f (threshold: %.6f)" % [signal_level, noise_gate_threshold])
		
		# Apply noise gate - check if signal is strong enough
		if signal_level > noise_gate_threshold:
			var pitch = yin_pitch_detection(audio_data)
			if pitch > 80 and pitch < 2000:  # Reasonable pitch range
				# Apply pitch stability filter
				if is_pitch_stable(pitch):
					var note_name = frequency_to_note(pitch)
					pitch_label.text = "Pitch: %.1f Hz (%s)" % [pitch, note_name]
				else:
					pitch_label.text = "Pitch: Unstable signal"
			else:
				pitch_label.text = "Pitch: No clear pitch detected"
		else:
			pitch_label.text = "Signal too weak (%.6f)" % signal_level

func get_audio_samples() -> PackedFloat32Array:
	var available_frames = audio_effect_capture.get_frames_available()
	
	if available_frames > buffer_size:
		var stereo_frames = audio_effect_capture.get_buffer(buffer_size)
		var mono_samples = PackedFloat32Array()
		
		# Convert stereo to mono and apply simple high-pass filter
		for frame in stereo_frames:
			var sample = (frame.x + frame.y) * 0.5  # Mix stereo to mono
			mono_samples.append(sample)
		
		# Apply simple high-pass filter to remove low-frequency noise
		return apply_high_pass_filter(mono_samples)
	
	return PackedFloat32Array()

func apply_high_pass_filter(samples: PackedFloat32Array) -> PackedFloat32Array:
	# Simple high-pass filter to remove low-frequency noise and reverb
	var filtered = PackedFloat32Array()
	var alpha: float = 0.99  # Filter coefficient (higher = more filtering)
	var prev_input: float = 0.0
	var prev_output: float = 0.0
	
	for sample in samples:
		var output = alpha * (prev_output + sample - prev_input)
		filtered.append(output)
		prev_input = sample
		prev_output = output
	
	return filtered

func calculate_signal_level(samples: PackedFloat32Array) -> float:
	# Calculate RMS (Root Mean Square) for better noise detection
	var sum_squares: float = 0.0
	for sample in samples:
		sum_squares += sample * sample
	
	return sqrt(sum_squares / float(samples.size()))

func is_signal_above_noise_gate(samples: PackedFloat32Array) -> bool:
	return calculate_signal_level(samples) > noise_gate_threshold

func is_pitch_stable(current_pitch: float) -> bool:
	# Add current pitch to history
	signal_history.append(current_pitch)
	if signal_history.size() > history_size:
		signal_history.pop_front()
	
	# Need at least 3 readings for stability check
	if signal_history.size() < 3:
		return false
	
	# Check if recent pitches are consistent
	var recent_pitches = signal_history.slice(-3)  # Last 3 pitches
	var avg_pitch: float = 0.0
	for pitch in recent_pitches:
		avg_pitch += pitch
	avg_pitch /= float(recent_pitches.size())
	
	# Check if all recent pitches are within threshold of average
	for pitch in recent_pitches:
		if abs(pitch - avg_pitch) > pitch_stability_threshold:
			return false
	
	return true

func yin_pitch_detection(samples: PackedFloat32Array) -> float:
	var half_buffer = buffer_size / 2
	var yin_buffer = PackedFloat32Array()
	yin_buffer.resize(half_buffer)
	
	# Step 1: Difference function
	for tau in range(half_buffer):
		var sum = 0.0
		for j in range(half_buffer):
			if j + tau < samples.size():
				var delta = samples[j] - samples[j + tau]
				sum += delta * delta
		yin_buffer[tau] = sum
	
	# Step 2: Cumulative mean normalized difference
	yin_buffer[0] = 1.0
	var cumulative_sum = 0.0
	
	for tau in range(1, half_buffer):
		cumulative_sum += yin_buffer[tau]
		if cumulative_sum != 0:
			yin_buffer[tau] = yin_buffer[tau] * float(tau) / cumulative_sum
		else:
			yin_buffer[tau] = 1.0
	
	# Step 3: Absolute threshold
	var tau = get_pitch_period(yin_buffer)
	if tau == -1:
		return -1
	
	# Step 4: Parabolic interpolation
	var better_tau = parabolic_interpolation(yin_buffer, tau)
	
	return sample_rate / better_tau

func get_pitch_period(yin_buffer: PackedFloat32Array) -> int:
	var tau = 1
	
	# Find first point below threshold
	while tau < yin_buffer.size():
		if yin_buffer[tau] < yin_threshold:
			# Look for local minimum
			while tau + 1 < yin_buffer.size() and yin_buffer[tau + 1] < yin_buffer[tau]:
				tau += 1
			return tau
		tau += 1
	
	return -1

func parabolic_interpolation(yin_buffer: PackedFloat32Array, tau: int) -> float:
	if tau < 1 or tau >= yin_buffer.size() - 1:
		return float(tau)
	
	var s0 = yin_buffer[tau - 1]
	var s1 = yin_buffer[tau]
	var s2 = yin_buffer[tau + 1]
	
	var a = (s0 - 2.0 * s1 + s2) / 2.0
	var b = (s2 - s0) / 2.0
	
	if abs(a) < 0.000001:
		return float(tau)
	
	return float(tau) - b / (2.0 * a)

func frequency_to_note(frequency: float) -> String:
	if frequency <= 0:
		return "N/A"
	
	var A4 = 440.0
	var semitones_from_A4 = 12.0 * log(frequency / A4) / log(2.0)
	var semitone = int(round(semitones_from_A4)) % 12
	
	# Handle negative modulo
	if semitone < 0:
		semitone += 12
	
	var octave = int(4 + floor(semitones_from_A4 / 12.0))
	
	var notes = ["A", "A#", "B", "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#"]
	
	return notes[semitone] + str(octave)
