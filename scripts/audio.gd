extends Node
## Efeitos, música por trecho e chuva. Os WAV ficam em assets/audio (gerados por tools/make_audio.py).

var on := true
var sfx := {}
var players: Array[AudioStreamPlayer] = []
var music: AudioStreamPlayer
var music2: AudioStreamPlayer
var rain: AudioStreamPlayer
var song := ""
var rain_target := 0.0
const NAMES := ["jump", "dj", "pen", "stomp", "hurt", "item", "clue", "combine", "unlock", "splash", "slide", "fire", "thunder", "door", "spring", "climb", "die", "special"]

func _ready() -> void:
	on = Save.getv("opt", "sound", true)
	for n in NAMES:
		sfx[n] = load("res://assets/audio/%s.wav" % n)
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	music = AudioStreamPlayer.new()
	music2 = AudioStreamPlayer.new()
	add_child(music)
	add_child(music2)
	rain = AudioStreamPlayer.new()
	rain.stream = _loop(load("res://assets/audio/rain.wav"))
	rain.volume_db = -60
	add_child(rain)
	_apply()

func _loop(s: AudioStreamWAV) -> AudioStreamWAV:
	var c: AudioStreamWAV = s.duplicate()
	c.loop_mode = AudioStreamWAV.LOOP_FORWARD
	c.loop_begin = 0
	c.loop_end = int(c.get_length() * c.mix_rate)
	return c

func _apply() -> void:
	AudioServer.set_bus_mute(0, not on)

func set_on(v: bool) -> void:
	on = v
	Save.setv("opt", "sound", v)
	_apply()

func play(n: String, vol_db: float = 0.0) -> void:
	if not sfx.has(n):
		return
	for p in players:
		if not p.playing:
			p.stream = sfx[n]
			p.volume_db = vol_db
			p.play()
			return
	players[0].stream = sfx[n]
	players[0].play()

## Troca a música com um cruzamento suave
func set_song(n: String) -> void:
	if n == song or n == "":
		return
	song = n
	var s := _loop(load("res://assets/audio/mus_%s.wav" % n))
	var old := music
	music = music2
	music2 = old
	music.stream = s
	music.volume_db = -40
	music.play()
	var tw := create_tween()
	tw.tween_property(music, "volume_db", -6.0, 1.2)
	tw.parallel().tween_property(music2, "volume_db", -40.0, 1.2)
	tw.tween_callback(music2.stop)

func stop_music() -> void:
	music.stop()
	music2.stop()
	song = ""

func set_rain(v: float) -> void:
	rain_target = v
	if v > 0.01 and not rain.playing:
		rain.play()

func _process(_d: float) -> void:
	var tgt := -60.0 if rain_target < 0.01 else lerpf(-30.0, -10.0, rain_target)
	rain.volume_db = lerpf(rain.volume_db, tgt, 0.05)
	if rain_target < 0.01 and rain.volume_db < -55 and rain.playing:
		rain.stop()

func vib(ms: int) -> void:
	if Save.getv("opt", "vibrate", true):
		Input.vibrate_handheld(ms)
