# TestMicStreamingf.gd
extends Node

func _ready():
	var mic = AudioStreamMicrophone.new()
	var player = AudioStreamPlayer.new()
	player.stream = mic
	add_child(player)
	player.play()
	
	print("Microphone streaming started")
	print("You should hear yourself through speakers!")
	print("If you hear feedback, it works!")
