extends Control

var recieve_song_title : String
var recieve_song_artist : String

@onready var songtitle = $UI/Song
@onready var songartist = $UI/Song2


func _ready():
	songtitle.text = recieve_song_title
	songartist.text = recieve_song_artist
	


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/song_selection.tscn")
