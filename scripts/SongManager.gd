# SongManager.gd
extends Node

# Store the selected song
var bgm_path: String = ""
var vocal_path: String = ""
var reference_pitch_path: String = ""  # precomputed pitch file
var song_duration: float = 0.0         # in seconds
