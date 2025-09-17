class_name Song

extends Button

@export var song : String
@export var artist : String


func _on_pressed():
	var scene2 = load("res://Scenes/gameplay.tscn").instantiate()
	
	scene2.recieve_song_title = song
	scene2.recieve_song_artist = artist
	
	get_tree().get_root().add_child(scene2)
	get_tree().get_root().remove_child(get_parent())
