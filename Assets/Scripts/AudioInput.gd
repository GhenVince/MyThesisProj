extends Node

var capture : AudioEffectCapture

func _ready():
	# Add an audio bus for the mic
	capture = AudioEffectCapture.new()
	AudioServer.add_bus_effect(AudioServer.get_bus_index("Master"), capture, 0)

	# Add reverb for feedback
	var reverb = AudioEffectReverb.new()
	AudioServer.add_bus_effect(AudioServer.get_bus_index("Master"), reverb, 1)

func _process(delta):
	var buffer = capture.get_buffer(512) # grab mic samples
	if buffer.size() > 0:
		# buffer is raw audio for pitch detection
		# (you’ll send this to C# or GDScript processing)
		pass
