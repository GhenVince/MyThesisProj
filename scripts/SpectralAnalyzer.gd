# SpectralAnalyzer.gd
# Complete spectral analysis for voice timbre comparison
extends Node

const SAMPLE_RATE = 44100
const FFT_SIZE = 2048

# === SPECTRAL CENTROID CALCULATION ===

func calculate_spectral_centroid(audio_buffer: PackedFloat32Array) -> float:
	"""Calculate the spectral centroid (brightness of sound)
	
	The spectral centroid is a measure of where the "center of mass" 
	of the spectrum is located. It's a good indicator of timbre.
	"""
	
	if audio_buffer.size() < FFT_SIZE:
		return 0.0
	
	# Perform FFT
	var fft_result = perform_fft(audio_buffer)
	
	# Calculate magnitude spectrum
	var magnitudes = []
	for i in range(fft_result.size()):
		var real = fft_result[i]["real"]
		var imag = fft_result[i]["imag"]
		var magnitude = sqrt(real * real + imag * imag)
		magnitudes.append(magnitude)
	
	# Calculate centroid
	var weighted_sum = 0.0
	var magnitude_sum = 0.0
	
	for i in range(magnitudes.size()):
		var frequency = i * SAMPLE_RATE / float(FFT_SIZE)
		weighted_sum += frequency * magnitudes[i]
		magnitude_sum += magnitudes[i]
	
	if magnitude_sum == 0.0:
		return 0.0
	
	return weighted_sum / magnitude_sum

func calculate_spectral_centroid_from_frames(frames: PackedVector2Array) -> float:
	"""Calculate spectral centroid from stereo frames"""
	if frames.size() < FFT_SIZE:
		return 0.0
	
	# Convert to mono buffer
	var mono_buffer = PackedFloat32Array()
	mono_buffer.resize(min(frames.size(), FFT_SIZE))
	
	for i in range(mono_buffer.size()):
		mono_buffer[i] = (frames[i].x + frames[i].y) / 2.0
	
	return calculate_spectral_centroid(mono_buffer)

# === FFT IMPLEMENTATION ===

func perform_fft(samples: PackedFloat32Array) -> Array:
	"""Perform Fast Fourier Transform
	
	Returns array of dictionaries with 'real' and 'imag' components
	"""
	
	var n = samples.size()
	
	# Ensure power of 2
	var fft_size = 1
	while fft_size < n:
		fft_size *= 2
	
	# Pad with zeros if necessary
	var padded = PackedFloat32Array()
	padded.resize(fft_size)
	for i in range(n):
		padded[i] = samples[i]
	for i in range(n, fft_size):
		padded[i] = 0.0
	
	# Apply windowing (Hamming window)
	var windowed = apply_hamming_window(padded)
	
	# Perform FFT
	return fft_recursive(windowed)

func fft_recursive(samples: PackedFloat32Array) -> Array:
	"""Recursive FFT implementation (Cooley-Tukey algorithm)"""
	var n = samples.size()
	
	if n <= 1:
		return [{"real": samples[0] if n > 0 else 0.0, "imag": 0.0}]
	
	# Split into even and odd
	var even = PackedFloat32Array()
	var odd = PackedFloat32Array()
	
	for i in range(n / 2):
		even.append(samples[i * 2])
		odd.append(samples[i * 2 + 1])
	
	# Recursive calls
	var fft_even = fft_recursive(even)
	var fft_odd = fft_recursive(odd)
	
	# Combine
	var result = []
	result.resize(n)
	
	for k in range(n / 2):
		var angle = -2.0 * PI * k / n
		var cos_val = cos(angle)
		var sin_val = sin(angle)
		
		var t_real = cos_val * fft_odd[k]["real"] - sin_val * fft_odd[k]["imag"]
		var t_imag = cos_val * fft_odd[k]["imag"] + sin_val * fft_odd[k]["real"]
		
		result[k] = {
			"real": fft_even[k]["real"] + t_real,
			"imag": fft_even[k]["imag"] + t_imag
		}
		
		result[k + n / 2] = {
			"real": fft_even[k]["real"] - t_real,
			"imag": fft_even[k]["imag"] - t_imag
		}
	
	return result

func apply_hamming_window(samples: PackedFloat32Array) -> PackedFloat32Array:
	"""Apply Hamming window to reduce spectral leakage"""
	var n = samples.size()
	var windowed = PackedFloat32Array()
	windowed.resize(n)
	
	for i in range(n):
		var window_val = 0.54 - 0.46 * cos(2.0 * PI * i / (n - 1))
		windowed[i] = samples[i] * window_val
	
	return windowed

# === TIMBRE ANALYSIS ===

func analyze_timbre(audio_buffer: PackedFloat32Array) -> Dictionary:
	"""Comprehensive timbre analysis
	
	Returns dictionary with:
	- spectral_centroid: float
	- spectral_variance: float
	- brightness: float (0-1)
	- richness: float (0-1)
	"""
	
	if audio_buffer.size() < FFT_SIZE:
		return {
			"spectral_centroid": 0.0,
			"spectral_variance": 0.0,
			"brightness": 0.0,
			"richness": 0.0
		}
	
	# Calculate spectral centroid
	var centroid = calculate_spectral_centroid(audio_buffer)
	
	# Calculate spectral variance (spread around centroid)
	var variance = calculate_spectral_variance(audio_buffer, centroid)
	
	# Brightness (normalized centroid)
	var brightness = clamp(centroid / 5000.0, 0.0, 1.0)
	
	# Richness (harmonic content)
	var richness = calculate_harmonic_richness(audio_buffer)
	
	return {
		"spectral_centroid": centroid,
		"spectral_variance": variance,
		"brightness": brightness,
		"richness": richness
	}

func calculate_spectral_variance(audio_buffer: PackedFloat32Array, centroid: float) -> float:
	"""Calculate spectral variance (spread)"""
	var fft_result = perform_fft(audio_buffer)
	
	var weighted_sum = 0.0
	var magnitude_sum = 0.0
	
	for i in range(fft_result.size()):
		var real = fft_result[i]["real"]
		var imag = fft_result[i]["imag"]
		var magnitude = sqrt(real * real + imag * imag)
		
		var frequency = i * SAMPLE_RATE / float(FFT_SIZE)
		var diff = frequency - centroid
		
		weighted_sum += diff * diff * magnitude
		magnitude_sum += magnitude
	
	if magnitude_sum == 0.0:
		return 0.0
	
	return weighted_sum / magnitude_sum

func calculate_harmonic_richness(audio_buffer: PackedFloat32Array) -> float:
	"""Calculate harmonic richness (0-1)"""
	var fft_result = perform_fft(audio_buffer)
	
	# Find fundamental frequency
	var fundamental_idx = find_fundamental_frequency_index(fft_result)
	
	if fundamental_idx == 0:
		return 0.0
	
	# Calculate energy in harmonics vs total energy
	var harmonic_energy = 0.0
	var total_energy = 0.0
	
	for i in range(fft_result.size()):
		var real = fft_result[i]["real"]
		var imag = fft_result[i]["imag"]
		var magnitude = real * real + imag * imag
		
		total_energy += magnitude
		
		# Check if this is a harmonic (multiple of fundamental)
		if fundamental_idx > 0:
			var ratio = float(i) / fundamental_idx
			if abs(ratio - round(ratio)) < 0.1:  # Close to integer multiple
				harmonic_energy += magnitude
	
	if total_energy == 0.0:
		return 0.0
	
	return clamp(harmonic_energy / total_energy, 0.0, 1.0)

func find_fundamental_frequency_index(fft_result: Array) -> int:
	"""Find the index of the fundamental frequency"""
	var max_magnitude = 0.0
	var max_idx = 0
	
	# Search in human voice range (80-800 Hz)
	var min_idx = int(80.0 * FFT_SIZE / SAMPLE_RATE)
	var max_idx_range = int(800.0 * FFT_SIZE / SAMPLE_RATE)
	
	for i in range(min_idx, min(max_idx_range, fft_result.size())):
		var real = fft_result[i]["real"]
		var imag = fft_result[i]["imag"]
		var magnitude = sqrt(real * real + imag * imag)
		
		if magnitude > max_magnitude:
			max_magnitude = magnitude
			max_idx = i
	
	return max_idx

# === TIMBRE COMPARISON ===

func compare_timbre(timbre_a: Dictionary, timbre_b: Dictionary) -> float:
	"""Compare two timbre profiles and return similarity (0-1)
	
	Higher value = more similar
	"""
	
	if timbre_a.is_empty() or timbre_b.is_empty():
		return 0.0
	
	# Compare spectral centroid (normalized)
	var centroid_a = timbre_a.get("average_centroid", 0.0)
	var centroid_b = timbre_b.get("average_centroid", 0.0)
	var centroid_diff = abs(centroid_a - centroid_b)
	var centroid_similarity = 1.0 - clamp(centroid_diff / 3000.0, 0.0, 1.0)
	
	# Compare variance (normalized)
	var variance_a = timbre_a.get("centroid_variance", 0.0)
	var variance_b = timbre_b.get("centroid_variance", 0.0)
	var variance_diff = abs(variance_a - variance_b)
	var variance_similarity = 1.0 - clamp(variance_diff / 2000.0, 0.0, 1.0)
	
	# Weighted average
	var similarity = (
		centroid_similarity * 0.7 +
		variance_similarity * 0.3
	)
	
	return similarity

func compare_detailed_timbre(timbre_a: Dictionary, timbre_b: Dictionary) -> float:
	"""More detailed timbre comparison using all features"""
	
	if timbre_a.is_empty() or timbre_b.is_empty():
		return 0.0
	
	var similarities = []
	
	# Spectral centroid similarity
	if timbre_a.has("spectral_centroid") and timbre_b.has("spectral_centroid"):
		var diff = abs(timbre_a["spectral_centroid"] - timbre_b["spectral_centroid"])
		similarities.append(1.0 - clamp(diff / 3000.0, 0.0, 1.0))
	
	# Brightness similarity
	if timbre_a.has("brightness") and timbre_b.has("brightness"):
		var diff = abs(timbre_a["brightness"] - timbre_b["brightness"])
		similarities.append(1.0 - diff)
	
	# Richness similarity
	if timbre_a.has("richness") and timbre_b.has("richness"):
		var diff = abs(timbre_a["richness"] - timbre_b["richness"])
		similarities.append(1.0 - diff)
	
	# Variance similarity
	if timbre_a.has("spectral_variance") and timbre_b.has("spectral_variance"):
		var diff = abs(timbre_a["spectral_variance"] - timbre_b["spectral_variance"])
		similarities.append(1.0 - clamp(diff / 2000.0, 0.0, 1.0))
	
	if similarities.is_empty():
		return 0.0
	
	# Average all similarities
	var total = 0.0
	for sim in similarities:
		total += sim
	
	return total / similarities.size()

# === VOICE CHARACTERISTICS ===

func classify_voice_type(average_frequency: float) -> String:
	"""Classify voice type based on average frequency"""
	if average_frequency < 150:
		return "Bass"
	elif average_frequency < 200:
		return "Baritone"
	elif average_frequency < 250:
		return "Tenor"
	elif average_frequency < 350:
		return "Alto"
	elif average_frequency < 450:
		return "Mezzo-Soprano"
	else:
		return "Soprano"

func get_voice_characteristics(timbre_data: Dictionary, avg_frequency: float) -> Dictionary:
	"""Get comprehensive voice characteristics"""
	return {
		"voice_type": classify_voice_type(avg_frequency),
		"brightness": timbre_data.get("brightness", 0.5),
		"richness": timbre_data.get("richness", 0.5),
		"warmth": 1.0 - timbre_data.get("brightness", 0.5),  # Inverse of brightness
		"average_pitch": avg_frequency
	}

# === UTILITY FUNCTIONS ===

func frequency_to_note(frequency: float) -> String:
	"""Convert frequency to musical note"""
	if frequency <= 0:
		return ""
	
	var note_names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
	var a4_freq = 440.0
	var c0_freq = a4_freq * pow(2.0, -4.75)
	
	var half_steps = round(12.0 * log(frequency / c0_freq) / log(2.0))
	var note_index = int(half_steps) % 12
	
	return note_names[note_index]

func get_frequency_band_energy(fft_result: Array, min_freq: float, max_freq: float) -> float:
	"""Get energy in a specific frequency band"""
	var min_idx = int(min_freq * FFT_SIZE / SAMPLE_RATE)
	var max_idx = int(max_freq * FFT_SIZE / SAMPLE_RATE)
	
	var energy = 0.0
	
	for i in range(max(0, min_idx), min(max_idx, fft_result.size())):
		var real = fft_result[i]["real"]
		var imag = fft_result[i]["imag"]
		energy += real * real + imag * imag
	
	return energy
