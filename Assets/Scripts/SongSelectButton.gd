class_name Song

extends Button

@export var instrumental_path: String
@export var vocals_path: String


func _pressed():
	SongManager.instrumental_path = instrumental_path
	SongManager.vocals_path = vocals_path
	get_tree().change_scene_to_file("res://GameScene.tscn")
