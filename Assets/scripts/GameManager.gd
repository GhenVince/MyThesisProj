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
