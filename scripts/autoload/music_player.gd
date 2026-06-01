extends Node

@onready var bg_music: AudioStreamPlayer = $bgMusic

var last_music: AudioStreamOggVorbis
var music_enabled: bool = true
var is_transitioning: bool = false  # ← spam lock

# ─── Play / Stop ───────────────────────────────────────────

func play_music():
	if not bg_music.playing and music_enabled:
		bg_music.play()

func stop_music():
	bg_music.stop()

func enable_music():
	music_enabled = true
	if last_music:
		last_music.loop = true
		bg_music.stream = last_music
		bg_music.play()
		fade_volume(bg_music, -40, 0, 1.0)

func disable_music():
	music_enabled = false
	await fade_volume(bg_music, 0, -40, 1.0)
	bg_music.stop()

# ─── Toggle (single call for UI button) ────────────────────

func toggle_music():
	if is_transitioning:  # ← block spam clicks
		return
	is_transitioning = true

	if music_enabled:
		await disable_music()
	else:
		enable_music()

	is_transitioning = false  # ← unlock after done

# ─── Change Track ───────────────────────────────────────────

func change_music(audio: AudioStreamOggVorbis) -> void:
	if last_music == audio:
		return

	await fade_volume(bg_music, 0, -40, 1.0)
	bg_music.stop()

	last_music = audio  # ← update BEFORE playing

	if audio and music_enabled:
		audio.loop = true
		bg_music.stream = audio
		bg_music.play()
		fade_volume(bg_music, -40, 0, 1.0)

# ─── Fade Helper ────────────────────────────────────────────

func fade_volume(player: AudioStreamPlayer, from_db: float, to_db: float, duration: float) -> void:
	player.volume_db = from_db
	var tween = create_tween()
	tween.tween_property(player, "volume_db", to_db, duration)
	await tween.finished
