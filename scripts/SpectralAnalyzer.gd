# SpectralAnalyzer.gd
extends Node

const SAMPLE_RATE = 44100
const FFT_SIZE = 2048

func calculate_spectral_centroid(samples: PackedFloat32Array) -> float:
	var spectrum = perform_fft(samples)
	
	var weighted_sum = 0.0
	var magnitude_sum = 0.0
	
	for i in range(spectrum.size()):
		var frequency = i * SAMPLE_RATE / float(FFT_SIZE)
		var magnitude = spectrum[i]
		weighted_sum += frequency * magnitude
		magnitude_sum += magnitude
	
	if magnitude_sum == 0:
		return 0.0
	
	return weighted_sum / magnitude_sum

func perform_fft(samples: PackedFloat32Array) -> PackedFloat32Array:
	# Simplified FFT using Godot's built-in capabilities
	# For production, you might want to use a proper FFT library
	var fft_size = min(samples.size(), FFT_SIZE)
	var spectrum = PackedFloat32Array()
	spectrum.resize(fft_size / 2)
	
	# Apply Hamming window
	var windowed = apply_hamming_window(samples, fft_size)
	
	# Compute magnitude spectrum (simplified)
	for k in range(fft_size / 2):
		var real_part = 0.0
		var imag_part = 0.0
		
		for n in range(fft_size):
			var angle = -2.0 * PI * k * n / fft_size
			real_part += windowed[n] * cos(angle)
			imag_part += windowed[n] * sin(angle)
		
		spectrum[k] = sqrt(real_part * real_part + imag_part * imag_part)
	
	return spectrum

func apply_hamming_window(samples: PackedFloat32Array, size: int) -> PackedFloat32Array:
	var windowed = PackedFloat32Array()
	windowed.resize(size)
	
	for i in range(size):
		var window = 0.54 - 0.46 * cos(2.0 * PI * i / (size - 1))
		windowed[i] = samples[i] * window
	
	return windowed

func analyze_timbre(audio_stream: AudioStream) -> Dictionary:
	# Analyze timbre characteristics of an audio stream
	var centroids = []
	var samples = extract_samples_from_stream(audio_stream)
	
	if samples.size() < FFT_SIZE:
		return {"average_centroid": 0.0, "centroid_variance": 0.0}
	
	# Analyze in chunks
	var chunk_size = FFT_SIZE
	for i in range(0, samples.size() - chunk_size, chunk_size / 2):
		var chunk = samples.slice(i, i + chunk_size)
		var centroid = calculate_spectral_centroid(chunk)
		if centroid > 0:
			centroids.append(centroid)
	
	if centroids.is_empty():
		return {"average_centroid": 0.0, "centroid_variance": 0.0}
	
	# Calculate statistics
	var avg_centroid = centroids.reduce(func(a, b): return a + b, 0.0) / centroids.size()
	
	var variance = 0.0
	for c in centroids:
		variance += pow(c - avg_centroid, 2)
	variance /= centroids.size()
	
	return {
		"average_centroid": avg_centroid,
		"centroid_variance": variance,
		"centroids": centroids
	}

func extract_samples_from_stream(audio_stream: AudioStream) -> PackedFloat32Array:
	# Extract raw samples from audio stream
	var samples = PackedFloat32Array()
	
	if audio_stream is AudioStreamWAV:
		samples = audio_stream.data
	elif audio_stream is AudioStreamOggVorbis or audio_stream is AudioStreamMP3:
		# For compressed formats, we need to play and record
		# This is a placeholder - actual implementation would require playback
		pass
	
	return samples

func compare_timbre(timbre1: Dictionary, timbre2: Dictionary) -> float:
	# Return similarity score between 0 (different) and 1 (similar)
	var centroid_diff = abs(timbre1["average_centroid"] - timbre2["average_centroid"])
	var variance_diff = abs(timbre1["centroid_variance"] - timbre2["centroid_variance"])
	
	# Normalize differences (assuming typical range of 0-5000 Hz for centroid)
	var centroid_similarity = 1.0 - min(centroid_diff / 5000.0, 1.0)
	var variance_similarity = 1.0 - min(variance_diff / 1000000.0, 1.0)
	
	# Weighted average
	return centroid_similarity * 0.7 + variance_similarity * 0.3
