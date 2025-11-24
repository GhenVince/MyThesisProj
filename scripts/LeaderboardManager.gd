# LeaderboardManager.gd (AutoLoad as "LeaderboardManager")
# Complete leaderboard system with multiple sorting options
extends Node

const SAVE_PATH = "user://leaderboard.save"
const MAX_ENTRIES_PER_SONG = 100  # Keep top 100 scores per song
const MAX_GLOBAL_ENTRIES = 500    # Keep top 500 scores overall

var scores: Array = []  # All score entries

signal scores_updated
signal new_high_score(entry: Dictionary)

func _ready():
	load_scores()

# === SCORE MANAGEMENT ===

func add_score(score_entry: Dictionary) -> void:
	"""Add a new score to the leaderboard
	
	score_entry should contain:
	- song: String (song title)
	- artist: String
	- score: int
	- accuracy: float
	- perfect: int
	- good: int
	- miss: int
	- rank: String (S, A, B, C, D, F)
	- date: String (timestamp)
	"""
	
	# Add unique ID and timestamp
	score_entry["id"] = generate_id()
	if not score_entry.has("date"):
		score_entry["date"] = Time.get_datetime_string_from_system()
	
	# Check if this is a new high score for this song
	var is_high_score = check_if_high_score(score_entry)
	
	scores.append(score_entry)
	
	# Sort by score (highest first)
	scores.sort_custom(func(a, b): return a["score"] > b["score"])
	
	# Trim to max entries
	if scores.size() > MAX_GLOBAL_ENTRIES:
		scores = scores.slice(0, MAX_GLOBAL_ENTRIES)
	
	save_scores()
	scores_updated.emit()
	
	if is_high_score:
		new_high_score.emit(score_entry)
		print("🎉 NEW HIGH SCORE! %d points on %s" % [score_entry["score"], score_entry["song"]])

func check_if_high_score(entry: Dictionary) -> bool:
	"""Check if this score is the highest for this song"""
	var song_scores = get_scores_for_song(entry["song"])
	
	if song_scores.is_empty():
		return true
	
	return entry["score"] > song_scores[0]["score"]

func generate_id() -> String:
	"""Generate unique ID for score entry"""
	return "%d_%d" % [Time.get_ticks_msec(), randi()]

# === SCORE RETRIEVAL ===

func get_all_scores() -> Array:
	"""Get all scores sorted by total score"""
	var sorted = scores.duplicate()
	sorted.sort_custom(func(a, b): return a["score"] > b["score"])
	return sorted

func get_scores_for_song(song_title: String) -> Array:
	"""Get all scores for a specific song"""
	var song_scores = []
	
	for entry in scores:
		if entry.get("song", "") == song_title:
			song_scores.append(entry)
	
	# Sort by score
	song_scores.sort_custom(func(a, b): return a["score"] > b["score"])
	
	return song_scores

func get_top_scores(count: int = 10) -> Array:
	"""Get top N scores across all songs"""
	var sorted = get_all_scores()
	return sorted.slice(0, min(count, sorted.size()))

func get_top_scores_for_song(song_title: String, count: int = 10) -> Array:
	"""Get top N scores for a specific song"""
	var song_scores = get_scores_for_song(song_title)
	return song_scores.slice(0, min(count, song_scores.size()))

func get_recent_scores(count: int = 10) -> Array:
	"""Get most recent scores"""
	var sorted = scores.duplicate()
	sorted.sort_custom(func(a, b): return a["date"] > b["date"])
	return sorted.slice(0, min(count, sorted.size()))

func get_scores_by_rank(rank: String) -> Array:
	"""Get all scores with a specific rank (S, A, B, etc.)"""
	var rank_scores = []
	
	for entry in scores:
		if entry.get("rank", "") == rank:
			rank_scores.append(entry)
	
	rank_scores.sort_custom(func(a, b): return a["score"] > b["score"])
	return rank_scores

func get_scores_by_accuracy_range(min_accuracy: float, max_accuracy: float) -> Array:
	"""Get scores within an accuracy range"""
	var filtered = []
	
	for entry in scores:
		var accuracy = entry.get("accuracy", 0.0)
		if accuracy >= min_accuracy and accuracy <= max_accuracy:
			filtered.append(entry)
	
	filtered.sort_custom(func(a, b): return a["score"] > b["score"])
	return filtered

# === STATISTICS ===

func get_total_plays() -> int:
	"""Get total number of songs played"""
	return scores.size()

func get_total_perfects() -> int:
	"""Get total perfect hits across all plays"""
	var total = 0
	for entry in scores:
		total += entry.get("perfect", 0)
	return total

func get_average_accuracy() -> float:
	"""Get average accuracy across all plays"""
	if scores.is_empty():
		return 0.0
	
	var total = 0.0
	for entry in scores:
		total += entry.get("accuracy", 0.0)
	
	return total / scores.size()


func get_highest_score() -> Dictionary:
	"""Get the highest score entry"""
	if scores.is_empty():
		return {}
	
	var sorted = get_all_scores()
	return sorted[0]

func get_highest_accuracy() -> Dictionary:
	"""Get the play with highest accuracy"""
	if scores.is_empty():
		return {}
	
	var highest = scores[0]
	for entry in scores:
		if entry.get("accuracy", 0.0) > highest.get("accuracy", 0.0):
			highest = entry
	
	return highest

func get_favorite_song() -> String:
	"""Get most played song"""
	if scores.is_empty():
		return ""
	
	var song_counts = {}
	
	for entry in scores:
		var song = entry.get("song", "")
		if song.is_empty():
			continue
		
		if not song_counts.has(song):
			song_counts[song] = 0
		song_counts[song] += 1
	
	var favorite = ""
	var max_plays = 0
	
	for song in song_counts.keys():
		if song_counts[song] > max_plays:
			max_plays = song_counts[song]
			favorite = song
	
	return favorite

func get_play_count_for_song(song_title: String) -> int:
	"""Get how many times a song has been played"""
	var count = 0
	for entry in scores:
		if entry.get("song", "") == song_title:
			count += 1
	return count

func get_rank_distribution() -> Dictionary:
	"""Get count of each rank"""
	var distribution = {
		"S": 0,
		"A": 0,
		"B": 0,
		"C": 0,
		"D": 0,
		"F": 0
	}
	
	for entry in scores:
		var rank = entry.get("rank", "F")
		if distribution.has(rank):
			distribution[rank] += 1
	
	return distribution

# === FILTERING AND SORTING ===

func sort_by_score() -> Array:
	"""Sort scores by total score (descending)"""
	var sorted = scores.duplicate()
	sorted.sort_custom(func(a, b): return a["score"] > b["score"])
	return sorted

func sort_by_accuracy() -> Array:
	"""Sort scores by accuracy (descending)"""
	var sorted = scores.duplicate()
	sorted.sort_custom(func(a, b): return a["accuracy"] > b["accuracy"])
	return sorted

func sort_by_date() -> Array:
	"""Sort scores by date (newest first)"""
	var sorted = scores.duplicate()
	sorted.sort_custom(func(a, b): return a["date"] > b["date"])
	return sorted

func sort_by_perfects() -> Array:
	"""Sort scores by perfect hits (descending)"""
	var sorted = scores.duplicate()
	sorted.sort_custom(func(a, b): return a["perfect"] > b["perfect"])
	return sorted

# === PERSISTENCE ===

func save_scores() -> void:
	"""Save leaderboard to disk"""
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		push_error("Failed to save leaderboard")
		return
	
	var save_data = {
		"version": 1,
		"scores": scores
	}
	
	file.store_var(save_data)
	file.close()
	print("✓ Leaderboard saved (%d entries)" % scores.size())

func load_scores() -> void:
	"""Load leaderboard from disk"""
	if not FileAccess.file_exists(SAVE_PATH):
		print("No leaderboard file found, starting fresh")
		return
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		push_error("Failed to load leaderboard")
		return
	
	var save_data = file.get_var()
	file.close()
	
	if save_data is Dictionary and save_data.has("scores"):
		scores = save_data["scores"]
		print("✓ Leaderboard loaded (%d entries)" % scores.size())
	else:
		push_error("Invalid leaderboard file format")

func clear_all_scores() -> void:
	"""Clear all scores (use with caution!)"""
	scores.clear()
	save_scores()
	scores_updated.emit()
	print("⚠️ Leaderboard cleared")

func delete_scores_for_song(song_title: String) -> void:
	"""Delete all scores for a specific song"""
	var original_size = scores.size()
	scores = scores.filter(func(entry): return entry.get("song", "") != song_title)
	
	var deleted = original_size - scores.size()
	if deleted > 0:
		save_scores()
		scores_updated.emit()
		print("Deleted %d scores for '%s'" % [deleted, song_title])

# === EXPORT ===

func export_to_json() -> String:
	"""Export leaderboard as JSON string"""
	return JSON.stringify(scores, "\t")

func export_to_csv() -> String:
	"""Export leaderboard as CSV string"""
	var csv = "Song,Artist,Score,Accuracy,Perfect,Good,Miss,Rank,Date\n"
	
	for entry in scores:
		csv += "\"%s\",\"%s\",%d,%.2f,%d,%d,%d,%s,%s\n" % [
			entry.get("song", ""),
			entry.get("artist", ""),
			entry.get("score", 0),
			entry.get("accuracy", 0.0),
			entry.get("perfect", 0),
			entry.get("good", 0),
			entry.get("miss", 0),
			entry.get("rank", ""),
			entry.get("date", "")
		]
	
	return csv

# === UTILITY ===

func format_score(score: int) -> String:
	"""Format score with commas"""
	var score_str = str(score)
	var result = ""
	var count = 0
	
	for i in range(score_str.length() - 1, -1, -1):
		if count == 3:
			result = "," + result
			count = 0
		result = score_str[i] + result
		count += 1
	
	return result

func get_rank_color(rank: String) -> Color:
	"""Get display color for rank"""
	match rank:
		"S": return Color(1.0, 0.84, 0.0)  # Gold
		"A": return Color(0.0, 1.0, 0.5)   # Green
		"B": return Color(0.3, 0.7, 1.0)   # Blue
		"C": return Color(1.0, 0.6, 0.0)   # Orange
		"D": return Color(1.0, 0.3, 0.3)   # Red
		_: return Color(0.5, 0.5, 0.5)     # Gray
