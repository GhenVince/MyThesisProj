# SongDatabase.gd (AutoLoad as "SongDatabase")
# Complete song management system with search and filtering
extends Node

const SONGS_DIR = "res://songs/"
const SONG_CACHE_PATH = "user://song_cache.json"

var songs: Array = []
var genres: Array = []
var artists: Array = []

signal songs_loaded
signal song_added(song_data: Dictionary)

func _ready():
	load_all_songs()

# === SONG LOADING ===

func load_all_songs():
	"""Load all songs from the songs directory"""
	songs.clear()
	genres.clear()
	artists.clear()
	
	if not DirAccess.dir_exists_absolute(SONGS_DIR):
		push_error("Songs directory not found: " + SONGS_DIR)
		DirAccess.make_dir_recursive_absolute(SONGS_DIR)
		return
	
	var dir = DirAccess.open(SONGS_DIR)
	if not dir:
		push_error("Failed to open songs directory")
		return
	
	dir.list_dir_begin()
	var folder_name = dir.get_next()
	
	while folder_name != "":
		if dir.current_is_dir() and not folder_name.begins_with("."):
			var song_data = load_song_metadata(folder_name)
			if not song_data.is_empty():
				songs.append(song_data)
				
				# Track unique genres and artists
				if not genres.has(song_data.get("genre", "Unknown")):
					genres.append(song_data.get("genre", "Unknown"))
				if not artists.has(song_data.get("artist", "Unknown")):
					artists.append(song_data.get("artist", "Unknown"))
		
		folder_name = dir.get_next()
	
	dir.list_dir_end()
	
	# Sort songs alphabetically by title
	songs.sort_custom(func(a, b): return a["title"] < b["title"])
	genres.sort()
	artists.sort()
	
	print("✓ Loaded %d songs" % songs.size())
	songs_loaded.emit()

func load_song_metadata(folder_name: String) -> Dictionary:
	"""Load metadata for a single song"""
	var song_folder = SONGS_DIR + folder_name + "/"
	var metadata_path = song_folder + "metadata.json"
	
	if not FileAccess.file_exists(metadata_path):
		print("Warning: No metadata.json found in " + folder_name)
		return {}
	
	var file = FileAccess.open(metadata_path, FileAccess.READ)
	if not file:
		push_error("Failed to open metadata: " + metadata_path)
		return {}
	
	var json = JSON.new()
	var parse_result = json.parse(file.get_as_text())
	file.close()
	
	if parse_result != OK:
		push_error("Failed to parse JSON in " + folder_name)
		return {}
	
	var data = json.data
	if not data is Dictionary:
		push_error("Invalid metadata format in " + folder_name)
		return {}
	
	# Add folder reference
	data["folder"] = folder_name
	
	# Validate required fields
	if not data.has("title"):
		data["title"] = folder_name
	if not data.has("artist"):
		data["artist"] = "Unknown Artist"
	if not data.has("bpm"):
		data["bpm"] = 120
	if not data.has("genre"):
		data["genre"] = "Unknown"
	if not data.has("duration"):
		data["duration"] = 0.0
	
	return data

# === SEARCH AND FILTER ===

func search_songs(query: String) -> Array:
	"""Search songs by title, artist, or genre"""
	if query.is_empty():
		return songs.duplicate()
	
	query = query.to_lower()
	var results = []
	
	for song in songs:
		var title = song.get("title", "").to_lower()
		var artist = song.get("artist", "").to_lower()
		var genre = song.get("genre", "").to_lower()
		
		if title.contains(query) or artist.contains(query) or genre.contains(query):
			results.append(song)
	
	return results

func filter_by_genre(genre: String) -> Array:
	"""Get all songs of a specific genre"""
	if genre == "All" or genre.is_empty():
		return songs.duplicate()
	
	var results = []
	for song in songs:
		if song.get("genre", "") == genre:
			results.append(song)
	
	return results

func filter_by_artist(artist: String) -> Array:
	"""Get all songs by a specific artist"""
	if artist == "All" or artist.is_empty():
		return songs.duplicate()
	
	var results = []
	for song in songs:
		if song.get("artist", "") == artist:
			results.append(song)
	
	return results

func filter_by_difficulty(min_difficulty: int, max_difficulty: int) -> Array:
	"""Filter songs by difficulty range (1-5)"""
	var results = []
	for song in songs:
		var difficulty = song.get("difficulty", 3)
		if difficulty >= min_difficulty and difficulty <= max_difficulty:
			results.append(song)
	
	return results

func filter_by_bpm_range(min_bpm: int, max_bpm: int) -> Array:
	"""Filter songs by BPM range"""
	var results = []
	for song in songs:
		var bpm = song.get("bpm", 120)
		if bpm >= min_bpm and bpm <= max_bpm:
			results.append(song)
	
	return results

func advanced_search(params: Dictionary) -> Array:
	"""Advanced search with multiple filters
	
	params can include:
	- query: String (title/artist/genre search)
	- genre: String
	- artist: String
	- min_bpm: int
	- max_bpm: int
	- min_difficulty: int
	- max_difficulty: int
	"""
	var results = songs.duplicate()
	
	# Text search
	if params.has("query") and not params["query"].is_empty():
		results = search_songs_in_array(results, params["query"])
	
	# Genre filter
	if params.has("genre") and params["genre"] != "All":
		results = filter_array_by_genre(results, params["genre"])
	
	# Artist filter
	if params.has("artist") and params["artist"] != "All":
		results = filter_array_by_artist(results, params["artist"])
	
	# BPM range
	if params.has("min_bpm") and params.has("max_bpm"):
		results = filter_array_by_bpm(results, params["min_bpm"], params["max_bpm"])
	
	# Difficulty range
	if params.has("min_difficulty") and params.has("max_difficulty"):
		results = filter_array_by_difficulty(results, params["min_difficulty"], params["max_difficulty"])
	
	return results

# Helper functions for advanced search
func search_songs_in_array(song_array: Array, query: String) -> Array:
	query = query.to_lower()
	var results = []
	for song in song_array:
		var title = song.get("title", "").to_lower()
		var artist = song.get("artist", "").to_lower()
		var genre = song.get("genre", "").to_lower()
		if title.contains(query) or artist.contains(query) or genre.contains(query):
			results.append(song)
	return results

func filter_array_by_genre(song_array: Array, genre: String) -> Array:
	return song_array.filter(func(s): return s.get("genre", "") == genre)

func filter_array_by_artist(song_array: Array, artist: String) -> Array:
	return song_array.filter(func(s): return s.get("artist", "") == artist)

func filter_array_by_bpm(song_array: Array, min_bpm: int, max_bpm: int) -> Array:
	return song_array.filter(func(s): return s.get("bpm", 120) >= min_bpm and s.get("bpm", 120) <= max_bpm)

func filter_array_by_difficulty(song_array: Array, min_diff: int, max_diff: int) -> Array:
	return song_array.filter(func(s): return s.get("difficulty", 3) >= min_diff and s.get("difficulty", 3) <= max_diff)

# === SONG VALIDATION ===

func validate_song(folder_name: String) -> Dictionary:
	"""Check if a song folder has all required files"""
	var song_folder = SONGS_DIR + folder_name + "/"
	var result = {
		"valid": true,
		"missing_files": [],
		"warnings": []
	}
	
	# Required files
	var required_files = [
		"metadata.json",
		"audio.ogg",
		"lyrics.json"
	]
	
	# Optional but recommended files
	var optional_files = [
		"vocals.ogg",
		"cover.png",
		"timbre.json"
	]
	
	# Check required files
	for file_name in required_files:
		if not FileAccess.file_exists(song_folder + file_name):
			result["valid"] = false
			result["missing_files"].append(file_name)
	
	# Check optional files
	for file_name in optional_files:
		if not FileAccess.file_exists(song_folder + file_name):
			result["warnings"].append("Missing optional file: " + file_name)
	
	return result

# === SONG MANAGEMENT ===

func get_song_by_id(song_id: String) -> Dictionary:
	"""Get song data by folder name"""
	for song in songs:
		if song.get("folder", "") == song_id:
			return song
	return {}

func get_songs_by_artist(artist_name: String) -> Array:
	"""Get all songs by an artist"""
	return filter_by_artist(artist_name)

func get_random_song() -> Dictionary:
	"""Get a random song"""
	if songs.is_empty():
		return {}
	return songs[randi() % songs.size()]

func get_recommended_songs(base_song: Dictionary, count: int = 5) -> Array:
	"""Get recommended songs based on a song (same genre or artist)"""
	var recommendations = []
	
	# Same artist
	for song in songs:
		if song == base_song:
			continue
		if song.get("artist", "") == base_song.get("artist", ""):
			recommendations.append(song)
	
	# Same genre
	for song in songs:
		if song == base_song:
			continue
		if recommendations.has(song):
			continue
		if song.get("genre", "") == base_song.get("genre", ""):
			recommendations.append(song)
	
	# Shuffle and return top N
	recommendations.shuffle()
	return recommendations.slice(0, min(count, recommendations.size()))

# === SONG ADDITION (For external tools) ===

func add_song_to_database(song_data: Dictionary) -> bool:
	"""Add a new song to the database (called by song manager tool)"""
	if not song_data.has("folder"):
		push_error("Song data must have 'folder' field")
		return false
	
	# Check if song already exists
	for song in songs:
		if song.get("folder", "") == song_data["folder"]:
			push_error("Song already exists: " + song_data["folder"])
			return false
	
	songs.append(song_data)
	
	# Update genre and artist lists
	var genre = song_data.get("genre", "Unknown")
	if not genres.has(genre):
		genres.append(genre)
		genres.sort()
	
	var artist = song_data.get("artist", "Unknown")
	if not artists.has(artist):
		artists.append(artist)
		artists.sort()
	
	song_added.emit(song_data)
	print("✓ Song added to database: " + song_data.get("title", "Unknown"))
	return true

func reload_songs():
	"""Reload all songs from disk"""
	load_all_songs()
