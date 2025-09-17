@tool
extends Node

@export var save_path: String = "res://songs/ReferencePitch.tres"

const SAMPLE_RATE = 44100
const FRAME_SIZE = 2048
const HOP_SIZE = 512

func _run_precompute():
	if SongManager.vocal_path == "":
		push_error("SongManager.vocal_path is empty!")
		return

	var vocal_stream = load(SongManager.vocal_path)
	if not vocal_stream:
		push_error("Failed to load vocal stream: " + SongManager.vocal_path)
		return

	var sample_count = int(vocal_stream.get_length() * SAMPLE_RATE)
	var audio_data = vocal_stream.get_samples(sample_count) as PackedFloat32Array
	if audio_data.size() == 0:
		push_error("No audio data found!")
		return

	var reference_pitch := PackedFloat32Array()

	for i in range(0, audio_data.size() - FRAME_SIZE, HOP_SIZE):
		var frame = audio_data.slice(i, i + FRAME_SIZE) as PackedFloat32Array
		var pitch = _analyze_pitch(frame)
		reference_pitch.append(pitch)

	# Wrap in custom resource
	var pitch_res = load("res://scripts/PitchArrayResource.gd").new()
	pitch_res.pitches = reference_pitch

	# Correct ResourceSaver usage: resource first, path second
	var err = ResourceSaver.save(pitch_res, save_path)
	if err == OK:
		print("Reference pitch saved to ", save_path)
	else:
		push_error("Failed to save reference pitch resource")

func _analyze_pitch(frame: PackedFloat32Array) -> float:
	# TODO: replace with your NWaves/YIN pitch detection
	return 440.0
