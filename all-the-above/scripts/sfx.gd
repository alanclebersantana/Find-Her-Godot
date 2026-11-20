extends Node
class_name Sfx
## Sons gerados no código (sem arquivos): gancho, pisão do colosso, rugido, golpe, pulo, peça.

const RATE := 22050
var cache := {}
var players: Array = []

func _ready() -> void:
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	for n in ["hook", "thud", "roar", "hit", "jump", "piece", "hurt", "stab", "land", "swish"]:
		cache[n] = _make(n)

func play(n: String, vol_db: float = 0.0, pitch: float = 1.0) -> void:
	if not cache.has(n):
		return
	for p in players:
		if not p.playing:
			p.stream = cache[n]
			p.volume_db = vol_db
			p.pitch_scale = pitch
			p.play()
			return

func _make(n: String) -> AudioStreamWAV:
	var dur: float = {"hook": .28, "thud": .9, "roar": 2.2, "hit": .18, "jump": .22, "piece": 1.1, "hurt": .3, "stab": .25, "land": .25, "swish": .3}.get(n, .3)
	var cnt := int(RATE * dur)
	var data := PackedByteArray()
	data.resize(cnt * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = n.hash()
	var lp := 0.0
	for i in cnt:
		var t := float(i) / RATE
		var u := t / dur
		var v := 0.0
		match n:
			"hook":
				v = sin(TAU * (900.0 - 600.0 * u) * t) * (1.0 - u) * .5 + rng.randf_range(-1, 1) * .15 * (1.0 - u)
			"thud":
				v = sin(TAU * (55.0 - 25.0 * u) * t) * exp(-u * 5.0) + rng.randf_range(-1, 1) * .25 * exp(-u * 9.0)
			"roar":
				var f := 70.0 + 30.0 * sin(u * 9.0)
				var noise := rng.randf_range(-1, 1)
				lp = lp * .93 + noise * .07
				v = (sin(TAU * f * t) * .5 + sin(TAU * f * 1.51 * t) * .3 + lp * 3.0) * sin(PI * u) * .7
			"hit":
				v = rng.randf_range(-1, 1) * exp(-u * 8.0) * .8 + sin(TAU * 180.0 * t) * exp(-u * 10.0) * .5
			"stab":
				v = (sin(TAU * 1400.0 * t) * .4 + rng.randf_range(-1, 1) * .5) * exp(-u * 9.0)
			"jump":
				v = sin(TAU * (300.0 + 500.0 * u) * t) * (1.0 - u) * .4
			"land":
				v = rng.randf_range(-1, 1) * exp(-u * 12.0) * .5
			"swish":
				var nz := rng.randf_range(-1, 1)
				lp = lp * .8 + nz * .2
				v = lp * sin(PI * u) * 1.2
			"hurt":
				v = sin(TAU * (420.0 - 260.0 * u) * t) * (1.0 - u) * .5
			"piece":
				v = (sin(TAU * 660.0 * t) + sin(TAU * 880.0 * t) * (1.0 if u > .25 else 0.0) + sin(TAU * 1320.0 * t) * (1.0 if u > .5 else 0.0)) * .22 * (1.0 - u)
		var s := int(clampf(v, -1.0, 1.0) * 30000.0)
		data.encode_s16(i * 2, s)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w
