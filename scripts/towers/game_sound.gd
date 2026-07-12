extends Node

func play(stream: AudioStream, volume_db: float = 0.0):
	if not SaveManager.sound_enabled:
		return
	var player = AudioStreamPlayer.new()
	add_child(player)
	player.stream = stream
	player.volume_db = volume_db
	player.play()
	await player.finished
	player.queue_free()
