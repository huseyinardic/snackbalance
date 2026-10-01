extends Node

# Autoload "Sfx": efektler ve müzik. Sesler sounds/ altında, oyuna özel sentezlendi
# (bambu/tahta + marimba + çan paleti; lisans derdi yok). Ayarlar GameData'da
# (music_on / sfx_on); tam ekran reklam açılınca (uygulama fokusu gidince) müzik durur.

const MUSIC_DB := -16.0          # müzik efektlerin altında, düşünmeyi bozmayan bir fon (kullanıcı: biraz kısık)
const POOL := 8                  # aynı anda çalabilecek efekt sayısı

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _music: AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # duraklatma ekranında da düğme sesi çalsın
	for i in POOL:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	var m: AudioStreamOggVorbis = load("res://sounds/music.ogg")
	m.loop = true
	_music.stream = m
	_music.volume_db = MUSIC_DB
	add_child(_music)
	apply_settings()

# volume_db: sesin kendi seviyesine ek; pitch_spread: her çalışta küçük perde farkı
# (aynı ses art arda gelince makine gibi duyulmasın).
func play(sound: String, volume_db: float = 0.0, pitch: float = 1.0, pitch_spread: float = 0.0) -> void:
	if not GameData.sfx_on:
		return
	if not _streams.has(sound):
		_streams[sound] = load("res://sounds/%s.ogg" % sound)
	var p := _players[_next]
	_next = (_next + 1) % POOL
	p.stream = _streams[sound]
	p.volume_db = volume_db
	p.pitch_scale = pitch * (1.0 + randf_range(-pitch_spread, pitch_spread))
	p.play()

# t saniye sonra çal (ör. kazanma melodisinden sonra ödül sesi).
func play_later(t: float, sound: String, volume_db: float = 0.0) -> void:
	await get_tree().create_timer(t).timeout
	play(sound, volume_db)

func apply_settings() -> void:
	if GameData.music_on and not _music.playing:
		_music.play()
	elif not GameData.music_on:
		_music.stop()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_music.stream_paused = true
	elif what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		_music.stream_paused = false
