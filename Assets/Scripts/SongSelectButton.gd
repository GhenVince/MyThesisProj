class_name Song

extends Button

@export var instrumental_path: String
@export var vocals_path: String


func _pressed():
	SongManager.bgm_path = "res://songs/Song1_BGM.ogg"
	SongManager.vocal_path = "res://songs/Song1_Vocals.ogg"
	SongManager.reference_pitch_path = "res://songs/Song1_Pitch.tres"
	get_tree().change_scene("res://scenes/KaraokeScene.tscn")
