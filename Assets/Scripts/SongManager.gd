extends Control
var instrumental_path: String
var vocals_path: String


func _ready():
	pass


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")
