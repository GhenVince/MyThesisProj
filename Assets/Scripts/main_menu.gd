extends Control

func _ready():
	pass

func _on_playbtn_pressed():
	get_tree().change_scene_to_file("res://Scenes/song_selection.tscn")


func _on_leaderboardsbtn_pressed():
	print('l')


func _on_optionsbtn_pressed():
	print('op')


func _on_exitbtn_pressed():
	get_tree().quit()
