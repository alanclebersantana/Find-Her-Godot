extends Node
## Efeitos, música por trecho, som ambiente e chuva.
## Músicas e ambientes (OGG) são gravados com instrumentos reais por tools/make_music.py;
## os efeitos curtos (WAV) vêm de tools/make_audio.py e tools/make_music.py.

var on := true
var sfx := {}
var players: Array[AudioStreamPlayer] = []
var music: AudioStreamPlayer
var music2: AudioStreamPlayer
var rain: AudioStreamPlayer
var danger: AudioStreamPlayer
var danger_lv := 0.0
var song := ""
var amb: AudioStreamPlayer
var amb2: AudioStreamPlayer
var amb_name := ""
## volume de cada música (dB) para todas soarem parecidas
const SONG_DB := {"perseguicao": -3.0, "vitoria": -6.0, "tarde": -8.0, "tema": -6.0}
## som ambiente de cada trecho
const AMB_FOR := {"manha": "passaros", "tarde": "passaros", "chuva": "sapos", "noite": "grilos", "tunel": "caverna", "perseguicao": "vento"}
var rain_target := 0.0
## barramentos: Música (músicas e tambores), Efeitos (sons curtos e ambiente) e Mundo (chuva e sons
## presos no cenário: fogueiras, água). O Mundo fica mudo fora do jogo (menus, fogueira grande, placar).
var bus_music := 0
var bus_sfx := 0
var bus_world := 0
var vol_music := 1.0
var vol_sfx := 1.0
var world_on := true
var world_gain := 1.0
var _mus_tw: Tween
var _amb_tw: Tween
const NAMES := ["jump", "dj", "pen", "stomp", "hurt", "item", "clue", "combine", "unlock", "splash", "slide", "fire", "thunder", "door", "spring", "climb", "die", "special", "roar"]   # (o latido do Pipoca ficou mudo: era irritante)

func _bus(n: String, send: String) -> int:
	var i := AudioServer.get_bus_index(n)
	if i < 0:
		AudioServer.add_bus()
		i = AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, n)
	AudioServer.set_bus_send(i, send)
	return i

func _ready() -> void:
	on = Save.getv("opt", "sound", true)
	bus_music = _bus("Musica", "Master")
	bus_sfx = _bus("Efeitos", "Master")
	bus_world = _bus("Mundo", "Efeitos")
	vol_music = float(Save.getv("opt", "vol_music", 1.0))
	vol_sfx = float(Save.getv("opt", "vol_sfx", 1.0))
	for n in NAMES:
		sfx[n] = load("res://assets/audio/%s.wav" % n)
	# músicas e sons de ambiente já carregados (sem travada ao mudar de trecho)
	for b in ["mus_manha", "mus_tarde", "mus_noite", "mus_chuva", "mus_perseguicao", "mus_tunel", "mus_tema", "mus_vitoria",
			"amb_caverna", "amb_grilos", "amb_passaros", "amb_sapos", "amb_vento"]:
		_stream(b)
	# latido do Pipoca: só uma vez, quando ele acha algo escondido
	# o latido do Pipoca foi retirado (ficava repetitivo): "bark" não toca nada
	for k in STEPS:
		for v in ["a", "b"]:
			var sp := "res://assets/audio/step_%s_%s.wav" % [k, v]
			if ResourceLoader.exists(sp):
				sfx["step_%s_%s" % [k, v]] = load(sp)
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.bus = "Efeitos"
		add_child(p)
		players.append(p)
	music = AudioStreamPlayer.new()
	music2 = AudioStreamPlayer.new()
	music.bus = "Musica"
	music2.bus = "Musica"
	add_child(music)
	add_child(music2)
	amb = AudioStreamPlayer.new()
	amb2 = AudioStreamPlayer.new()
	amb.bus = "Efeitos"
	amb2.bus = "Efeitos"
	add_child(amb)
	add_child(amb2)
	# camada extra da música (tambores) que cresce quando há perigo por perto
	danger = AudioStreamPlayer.new()
	danger.bus = "Musica"
	if ResourceLoader.exists("res://assets/audio/loop_tambores.wav"):
		danger.stream = _loop(load("res://assets/audio/loop_tambores.wav"))
	danger.volume_db = -60
	add_child(danger)
	rain = AudioStreamPlayer.new()
	rain.stream = _loop(load("res://assets/audio/rain.wav"))
	rain.volume_db = -60
	rain.bus = "Mundo"
	add_child(rain)
	_apply()
	_apply_volumes()

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

## volume da música e dos efeitos (0..1), guardados nas opções e aplicados na hora
func _apply_volumes() -> void:
	AudioServer.set_bus_volume_db(bus_music, linear_to_db(max(vol_music, .0001)))
	AudioServer.set_bus_mute(bus_music, vol_music <= .001)
	AudioServer.set_bus_volume_db(bus_sfx, linear_to_db(max(vol_sfx, .0001)))
	AudioServer.set_bus_mute(bus_sfx, vol_sfx <= .001)

func set_music_vol(v: float, store: bool = true) -> void:
	vol_music = clampf(v, 0.0, 1.0)
	_apply_volumes()
	if store:
		Save.setv("opt", "vol_music", vol_music)

func set_sfx_vol(v: float, store: bool = true) -> void:
	vol_sfx = clampf(v, 0.0, 1.0)
	_apply_volumes()
	if store:
		Save.setv("opt", "vol_sfx", vol_sfx)

## sons do mundo (chuva, tambores do perigo, fogueiras, água) só durante o jogo
func set_world(v: bool) -> void:
	world_on = v

## sons que se repetem muito: mais baixos e sempre um pouco diferentes (tom variando)
const TRIM := {"coin": -6.0, "jump": -5.0, "stomp": -3.0, "climb": -5.0, "swing": -4.0, "splash": -3.0, "crate": -3.0, "spring": -3.0, "unlock": -3.0}
var _last := {}
func play(n: String, vol_db: float = 0.0, pitch: float = 1.0) -> void:
	if not sfx.has(n):
		return
	# o mesmo som não empilha no mesmo instante (lápis em sequência, passos)
	var now := Time.get_ticks_msec()
	if now - int(_last.get(n, -1000)) < 45:
		return
	_last[n] = now
	if TRIM.has(n):
		vol_db += TRIM[n]
		if pitch == 1.0:
			pitch = randf_range(.93, 1.07)
	for p in players:
		if not p.playing:
			p.stream = sfx[n]
			p.volume_db = vol_db
			p.pitch_scale = pitch
			p.play()
			return
	players[0].stream = sfx[n]
	players[0].volume_db = vol_db
	players[0].pitch_scale = pitch
	players[0].play()

## passo no tipo de chão (grama, terra, neve, madeira, pedra, lama), com variação de tom
const STEPS := ["grass", "dirt", "snow", "wood", "stone", "mud"]
var _alt := false
func step(kind: String, vol_db: float = -19.0) -> void:
	_alt = not _alt
	play("step_%s_%s" % [kind, "a" if _alt else "b"], vol_db, randf_range(.9, 1.12))

var _st_cache := {}
func _stream(base: String) -> AudioStream:
	## procura .ogg (instrumentos reais) e, se não houver, .wav (sintetizado); devolve em loop
	## (fica guardada: carregar a música na troca de trecho dava uma travadinha)
	if _st_cache.has(base):
		return _st_cache[base]
	var r := _stream_load(base)
	_st_cache[base] = r
	return r

func _stream_load(base: String) -> AudioStream:
	for ext in ["ogg", "wav"]:
		var path := "res://assets/audio/%s.%s" % [base, ext]
		if ResourceLoader.exists(path):
			var st = load(path)
			if st is AudioStreamOggVorbis:
				var c: AudioStreamOggVorbis = st.duplicate()
				c.loop = true
				return c
			return _loop(st)
	return null

## Troca a música com um cruzamento suave (e o som ambiente do trecho junto)
## músicas de batalha dos reis: a mesma faixa de batalha em outro andamento e tom
const SONG_ALIAS := {"gaviao": ["perseguicao", 1.1], "bagre": ["perseguicao", .84], "urso": ["perseguicao", .94], "jangada": ["perseguicao", 1.05], "voo": ["manha", 1.06], "pedra": ["perseguicao", 1.15]}

func set_song(n: String) -> void:
	if n == song or n == "":
		return
	var al: Array = SONG_ALIAS.get(n, [n, 1.0])
	var s := _stream("mus_" + al[0])
	if s == null:
		return
	song = n
	# troca rápida (antes do cruzamento anterior acabar): o cruzamento velho é cancelado, senão
	# ele terminava parando o tocador que já estava com a música nova (ficava tudo mudo)
	if _mus_tw and _mus_tw.is_valid():
		_mus_tw.kill()
	var old := music
	music = music2
	music2 = old
	music.stream = s
	music.pitch_scale = al[1]
	music.volume_db = -40
	music.play()
	var tw := create_tween()
	_mus_tw = tw
	var fading := music2
	tw.tween_property(music, "volume_db", SONG_DB.get(al[0], -7.0), 1.4)
	tw.parallel().tween_property(fading, "volume_db", -40.0, 1.4)
	tw.tween_callback(func():
		# só para o tocador se ele ainda for o que estava saindo
		if fading != music:
			fading.stop())
	set_amb(AMB_FOR.get(al[0], ""))

func set_amb(n: String) -> void:
	if n == amb_name:
		return
	amb_name = n
	if _amb_tw and _amb_tw.is_valid():
		_amb_tw.kill()
	var old := amb
	amb = amb2
	amb2 = old
	var tw := create_tween()
	_amb_tw = tw
	if n != "":
		var s := _stream("amb_" + n)
		if s:
			amb.stream = s
			amb.volume_db = -40
			amb.play()
			tw.tween_property(amb, "volume_db", -13.0, 2.0)
		else:
			amb.stop()
	else:
		amb.stop()
	var fading := amb2
	tw.parallel().tween_property(fading, "volume_db", -40.0, 2.0)
	tw.tween_callback(func():
		if fading != amb:
			fading.stop())

func stop_music() -> void:
	if _mus_tw and _mus_tw.is_valid():
		_mus_tw.kill()
	music.stop()
	music2.stop()
	danger.stop()
	danger_lv = 0.0
	song = ""
	set_amb("")

## perigo de 0 a 1: os tambores entram aos poucos e saem suavemente
func set_danger(v: float) -> void:
	if danger.stream == null:
		return
	danger_lv = lerpf(danger_lv, v, .02 if v > danger_lv else .008)
	if danger_lv > .02 and not danger.playing:
		danger.play()
	elif danger_lv <= .02 and danger.playing:
		danger.stop()
	danger.volume_db = linear_to_db(max(danger_lv, .0001)) - 9.0

## som que sai de um ponto do mundo (fogueira, riacho): mais alto de perto e do lado certo no fone
func emitter(parent: Node, name_: String, pos: Vector2, vol: float, dist: float) -> void:
	var path := "res://assets/audio/%s.wav" % name_
	if not ResourceLoader.exists(path):
		return
	var e := AudioStreamPlayer2D.new()
	e.stream = _loop(load(path))
	e.position = pos
	e.volume_db = vol
	e.max_distance = dist
	e.attenuation = 1.6
	e.autoplay = true
	e.bus = "Mundo"
	parent.add_child(e)

func set_rain(v: float) -> void:
	rain_target = v
	if v > 0.01 and not rain.playing:
		rain.play()

func _process(_d: float) -> void:
	# fora do jogo o Mundo some suave; os tambores do perigo também saem
	world_gain = move_toward(world_gain, 1.0 if world_on else 0.0, _d * 3.0)
	AudioServer.set_bus_volume_db(bus_world, linear_to_db(max(world_gain, .0001)))
	AudioServer.set_bus_mute(bus_world, world_gain <= .001)
	if not world_on and danger_lv > 0.0:
		danger_lv = move_toward(danger_lv, 0.0, _d * 1.5)
		danger.volume_db = linear_to_db(max(danger_lv, .0001)) - 9.0
		if danger_lv <= .02 and danger.playing:
			danger.stop()
			danger_lv = 0.0
	var tgt := -60.0 if rain_target < 0.01 else lerpf(-30.0, -10.0, rain_target)
	rain.volume_db = lerpf(rain.volume_db, tgt, 0.05)
	if rain_target < 0.01 and rain.volume_db < -55 and rain.playing:
		rain.stop()

func vib(ms: int) -> void:
	if Save.getv("opt", "vibrate", true):
		Input.vibrate_handheld(ms)
