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
var _music_operation_id: int = 0
var _volume_tween: Tween = null


func play_music() -> void:
	if not bg_music.playing and music_enabled:
		bg_music.play()


func stop_music() -> void:
	bg_music.stop()


func enable_music() -> void:
	set_music_enabled(true)


func disable_music() -> void:
	set_music_enabled(false)


func toggle_music() -> void:
	set_music_enabled(not music_enabled)


func set_music_enabled(enabled: bool) -> void:
	var operation_id := _begin_music_operation()
	music_enabled = enabled

	if enabled:
		if last_music == null:
			return
		_set_loop_enabled(last_music)
		bg_music.stream = last_music
		if not bg_music.playing:
			bg_music.volume_db = -40.0
			bg_music.play()
		_fade_volume_to(MUSIC_VOLUME_DB, 0.28, operation_id, false)
		return

	if bg_music.playing:
		_fade_volume_to(-40.0, 0.18, operation_id, true)
	else:
		bg_music.stop()


func change_music(audio: AudioStream) -> void:
	if last_music == audio:
		return

	var operation_id := _begin_music_operation()
	if bg_music.playing:
		await _fade_volume_to(-40.0, 0.35, operation_id)
		if operation_id != _music_operation_id:
			return
		bg_music.stop()

	last_music = audio

	if audio and music_enabled:
		_set_loop_enabled(audio)
		bg_music.stream = audio
		bg_music.play()
		bg_music.volume_db = -40.0
		_fade_volume_to(MUSIC_VOLUME_DB, 0.5, operation_id, false)


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


func _begin_music_operation() -> int:
	_music_operation_id += 1
	if _volume_tween != null and _volume_tween.is_valid():
		_volume_tween.kill()
	_volume_tween = null
	return _music_operation_id


func _fade_volume_to(to_db: float, duration: float, operation_id: int, stop_after: bool = false) -> void:
	if operation_id != _music_operation_id:
		return
	if _volume_tween != null and _volume_tween.is_valid():
		_volume_tween.kill()
	_volume_tween = create_tween()
	_volume_tween.tween_property(bg_music, "volume_db", to_db, duration)
	await _volume_tween.finished
	if operation_id != _music_operation_id:
		return
	if stop_after and not music_enabled:
		bg_music.stop()
	_volume_tween = null


func fade_volume(player: AudioStreamPlayer, from_db: float, to_db: float, duration: float) -> void:
	var operation_id := _begin_music_operation()
	player.volume_db = from_db
	await _fade_volume_to(to_db, duration, operation_id, false)
