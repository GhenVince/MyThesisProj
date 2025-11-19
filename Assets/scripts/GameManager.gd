# GameManager.gd (AutoLoad as "GameManager")
extends Node

var current_song: Dictionary = {}
var game_score: int = 0
var perfect_count: int = 0
var good_count: int = 0
var miss_count: int = 0
var player_timbre_data: Array = []

func reset_game_stats():
	game_score = 0
	perfect_count = 0
	good_count = 0
	miss_count = 0
	player_timbre_data.clear()

func add_score(score_type: String):
	match score_type:
		"Perfect":
			game_score += 1000
			perfect_count += 1
		"Good":
			game_score += 500
			good_count += 1
		"Miss":
			miss_count += 1

# ===================================

# SongDatabase.gd (AutoLoad as "SongDatabase")
extends Node

const SONGS_DIR = "res://songs/"
const LEADERBOARD_FILE = "user://leaderboard.json"

var songs: Array = []
var leaderboard_data: Dictionary = {}

func _ready():
	load_songs()
	load_leaderboard()

func load_songs():
	songs.clear()
	var dir = DirAccess.open(SONGS_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir() and not file_name.begins_with("."):
				var song_data = load_song_data(file_name)
				if song_data:
					songs.append(song_data)
			file_name = dir.get_next()
		dir.list_dir_end()

func load_song_data(song_folder: String) -> Dictionary:
	var config_path = SONGS_DIR + song_folder + "/song.json"
	if not FileAccess.file_exists(config_path):
		return {}
	
	var file = FileAccess.open(config_path, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		var json = JSON.new()
		var error = json.parse(json_string)
		if error == OK:
			var data = json.data
			data["folder"] = song_folder
			return data
	return {}

func get_songs_by_genre(genre: String) -> Array:
	if genre == "All":
		return songs
	return songs.filter(func(s): return s.get("genre", "") == genre)

func search_songs(query: String) -> Array:
	var q = query.to_lower()
	return songs.filter(func(s): 
		return s.get("title", "").to_lower().contains(q) or 
			   s.get("artist", "").to_lower().contains(q)
	)

func save_score(song_title: String, score: int, perfect: int, good: int, miss: int):
	if not leaderboard_data.has(song_title):
		leaderboard_data[song_title] = []
	
	leaderboard_data[song_title].append({
		"score": score,
		"perfect": perfect,
		"good": good,
		"miss": miss,
		"date": Time.get_datetime_string_from_system()
	})
	
	save_leaderboard()

func get_leaderboard(song_title: String = "") -> Array:
	if song_title == "":
		# Return all scores sorted by highest
		var all_scores = []
		for song in leaderboard_data.keys():
			for entry in leaderboard_data[song]:
				var score_entry = entry.duplicate()
				score_entry["song"] = song
				all_scores.append(score_entry)
		all_scores.sort_custom(func(a, b): return a["score"] > b["score"])
		return all_scores
	else:
		# Return scores for specific song
		if leaderboard_data.has(song_title):
			var scores = leaderboard_data[song_title].duplicate()
			scores.sort_custom(func(a, b): return a["score"] > b["score"])
			return scores
	return []

func save_leaderboard():
	var file = FileAccess.open(LEADERBOARD_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(leaderboard_data, "\t"))
		file.close()

func load_leaderboard():
	if not FileAccess.file_exists(LEADERBOARD_FILE):
		return
	
	var file = FileAccess.open(LEADERBOARD_FILE, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		var json = JSON.new()
		var error = json.parse(json_string)
		if error == OK:
			leaderboard_data = json.data
