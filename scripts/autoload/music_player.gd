extends Node

const GAME_MUSIC_TRACKS: Array[String] = [
	"res://assets/audio/music/GameMusic/music1.mp3",
	"res://assets/audio/music/GameMusic/music2.mp3",
	"res://assets/audio/music/GameMusic/music3.mp3",
	"res://assets/audio/music/GameMusic/music4.mp3",
]
const MUSIC_VOLUME_DB: float = -2.0

@onready var bg_music: AudioStreamPlayer = $bgMusic

var last_music: AudioStream
var music_enabled: bool = true
var is_transitioning: bool = false


func play_music() -> void:
	if not bg_music.playing and music_enabled:
		bg_music.play()


func stop_music() -> void:
	bg_music.stop()


func enable_music() -> void:
	music_enabled = true
	if last_music:
		_set_loop_enabled(last_music)
		bg_music.stream = last_music
		bg_music.play()
		fade_volume(bg_music, -40.0, MUSIC_VOLUME_DB, 1.0)


func disable_music() -> void:
	music_enabled = false
	await fade_volume(bg_music, 0.0, -40.0, 1.0)
	bg_music.stop()


func toggle_music() -> void:
	if is_transitioning:
		return

	is_transitioning = true
	if music_enabled:
		await disable_music()
	else:
		enable_music()
	is_transitioning = false


func change_music(audio: AudioStream) -> void:
	if last_music == audio:
		return

	await fade_volume(bg_music, 0.0, -40.0, 1.0)
	bg_music.stop()
	last_music = audio

	if audio and music_enabled:
		_set_loop_enabled(audio)
		bg_music.stream = audio
		bg_music.play()
		fade_volume(bg_music, -40.0, MUSIC_VOLUME_DB, 1.0)


func play_random_game_music() -> void:
	if GAME_MUSIC_TRACKS.is_empty():
		return

	var available_tracks: Array[String] = GAME_MUSIC_TRACKS.duplicate()
	if last_music != null and available_tracks.size() > 1:
		var current_stream: AudioStream = last_music
		available_tracks = available_tracks.filter(
			func(track_path: String) -> bool:
				return load(track_path) != current_stream
		)

	var track_path: String = available_tracks.pick_random()
	var audio: AudioStream = load(track_path) as AudioStream
	if audio == null:
		push_warning("AudioController: failed to load game music at %s" % track_path)
		return

	change_music(audio)


func _set_loop_enabled(audio: AudioStream) -> void:
	if audio is AudioStreamOggVorbis:
		(audio as AudioStreamOggVorbis).loop = true
	elif audio is AudioStreamMP3:
		(audio as AudioStreamMP3).loop = true


func fade_volume(player: AudioStreamPlayer, from_db: float, to_db: float, duration: float) -> void:
	player.volume_db = from_db
	var tween: Tween = create_tween()
	tween.tween_property(player, "volume_db", to_db, duration)
	await tween.finished
