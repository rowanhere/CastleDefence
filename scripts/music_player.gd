extends Node

@onready var bg_music: AudioStreamPlayer = $bgMusic
var last_music: AudioStreamOggVorbis
# Called when the node enters the scene tree for the first time.
func play_music():
	
	if not bg_music.playing:
		bg_music.play()

func stop_music():
	bg_music.stop()

	

func change_music(audio:AudioStreamOggVorbis) ->void:
	if last_music != audio:
		await fade_volume(bg_music,0,-40,1.0)
		if audio:
			audio.loop = true 
			bg_music.stream = audio
			bg_music.play()
			fade_volume(bg_music,-40,0,1.0)
	 
	last_music = audio

func fade_volume(player, from_db, to_db, duration):
	var tween = create_tween()
	bg_music.volume_db = from_db
	tween.tween_property(player,"volume_db",to_db,duration)
   
	 
