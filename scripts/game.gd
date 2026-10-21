extends Node2D
class_name Game
## Simulação da fase (porta fiel da versão HTML): física do Tomé, fase 1 (escadas, agachar,
## mochila, cadeados, pântano, noite), inimigos, itens e câmera. Tudo roda em passos fixos.

signal clue_opened(id: int)
signal results_ready
signal game_over
signal level_won
signal rest_reached(n: int)

# ---------- física (mesmos números da versão HTML) ----------
const GRAV := .62
const JUMP := -11.8
const DJUMP := -10.8
const TOP := 4.3
const ACCg := .9
const ACCa := .52
const FRIC := .80
const COY := 7
const BUF := 8
const PUFF_GRAV := .10
const PUFF_FALL := 1.8
const PUFF_TOP := 3.8
const PUFF_ACC := .55
const SLAM_GRAV := 1.8
const SLAM_MAX := 21.0
const STOMP := -9.6
const MAXHP := 3
const VINE_G := .3          # gravidade do balanço no cipó
const RUN_TOP := 6.6
const RUN_ACC := 1.05
const FLY := {"fly": 1, "owl": 1, "bat": 1, "crow": 1, "piranha": 1}

var L: Dictionary
var level_idx := 0
var SOL: Array = []
var CR: Array = []
var SPR: Array = []
var EN: Array = []
var COINS: Array = []
var CHK: Array = []
var VINES: Array = []
var CLK: Array = []
var DRWS: Array = []
var CLIMB: Array = []
var ENTR: Array = []
var ITEMS: Array = []
var LOCKS: Array = []
var CLUES: Array = []
var SPECS: Array = []
var LILY: Array = []
var MUD: Array = []
var SWAMP: Array = []
var BUSH: Array = []
var VIL = null
var DOOR: Dictionary
var INV: Array = []
var CLUEGOT := {}
var SPECGOT := {}
var DRAWN := {}
var STATS := {"pen": 0, "penTotal": 0}
var AMB := {"dark": 0.0, "rain": 0.0, "night": 0.0, "tint": "", "song": "manha", "fog": 0.0, "wind": 0.0, "snow": 0.0}
var X: Extras
var M: Mech
var PR: Props
var TR: Traps
var ZN: Zones
var NT: Nature
var K: Kings
var RD: Ride
var RESTED := {}        # fogueiras grandes já descansadas
var player: Dictionary = {}
var keys := {}
var T := 0
var time_left := 0
var lives := 3
var coins := 0
var coin_life := 0
var shake := 0.0
var hit_stop := 0
var iris_t := 0
var flash_msg := ""
var flash_t := 0
var lantern_lit := true
var look_y := 0.0
var thunder_t := 200
var lightning := 0
var thunder_snd := 0
var PARTS: Array = []
var COAL: Array = []
var no_coal := false
var FXS: Array = []
var cam := 0.0
var cam_y := 0.0
var cam_focus := 0.0
var cam_vx := 0.0          # velocidades da câmera (mola amortecida: sem tremedeira)
var cam_vy := 0.0
var look_x := 0.0
var look_vx := 0.0
var look_hold := 0
var CINE := {}             # cena dramática dentro do jogo (câmera, faixas de cinema, falas)
var W := 960.0
var H := 540.0
var running := false
var cur_chk := -1           # fogueira onde o Tomé volta ao morrer
var auto_cine: bool = DisplayServer.get_name() == "headless"   # testes automáticos: falas passam sozinhas
var max_x := 0.0          # até onde o Tomé já chegou (para o mapa)
var tps := 60
var shown_crate := false
var rng := RandomNumberGenerator.new()
var camera: Camera2D
# interpolação do desenho entre passos fixos (movimento liso em telas de 90/120 Hz)
var prev_px := 0.0
var prev_py := 0.0
var prev_cam := 0.0
var prev_cam_y := 0.0
var rcam := 0.0
var rcam_y := 0.0
# analógico: inclinação horizontal (1 = digital / máximo)
var axis_x := 1.0

func _ready() -> void:
	camera = Camera2D.new()
	camera.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	add_child(camera)
	camera.make_current()

# ======================================================================
#  CARREGAR
# ======================================================================
func load_level(i: int) -> void:
	level_idx = i
	max_x = 0.0
	cur_chk = -1
	L = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/level%d.json" % (i + 1)))
	SOL = []
	for s in L.solids:
		if s.get("deco"):
			continue
		var o: Dictionary = s.duplicate()
		if s.t in ["plat", "branch", "island"]:
			o.h = 16
			o.oneway = 1
		SOL.append(o)
	CR = []
	for c in L.get("crates", []):
		var o: Dictionary = c.duplicate()
		o.ox = c.x
		o.oy = c.y
		o.w = c.get("w", 70 if c.t == "push" else 38)
		o.h = c.get("h", 70 if c.t == "push" else 38)
		o.vy = 0.0
		o.dead = false
		o.shake = 0
		o.crate = 1
		CR.append(o)
	SPR = []
	for s in L.get("springs", []):
		var o: Dictionary = s.duplicate()
		o.t = 0
		SPR.append(o)
	EN = []
	for e in L.get("enemies", []):
		var o: Dictionary = e.duplicate()
		o.dir = -1
		o.dead = 0
		o.base = e.y
		o.y = e.cy if e.has("cy") else e.y
		o.stun = 0
		o.leap = 0
		o.x0 = e.x
		o.sx = e.x
		EN.append(o)
	COINS = []
	for k in L.get("coins", []).size():
		var c = L.coins[k]
		COINS.append({"x": c[0], "y": c[1], "got": false, "ci": k})
	CHK = []
	for c in L.get("checks", []):
		var ch := {"x": c[0], "y": c[1], "on": false}
		if c.size() > 3 and c[2] == "rest":
			ch.rest = int(c[3])
		CHK.append(ch)
	VINES = []
	for v in L.get("vines", []):
		var vo := {"x": v.x, "y": v.y, "len": v.len, "th": 0.0, "om": 0.0, "bend": 0.0}
		if v.has("aim"):
			vo.aim = v.aim
		VINES.append(vo)
	CLK = []
	for c in L.get("clocks", []):
		CLK.append({"x": c[0], "y": c[1], "got": false})
	DRWS = []
	var di := 0
	for d in L.get("drawings", []):
		var o: Dictionary = d.duplicate()
		o.i = di
		o.got = DRAWN.has("%d:%d" % [level_idx, di])
		o.hidden = d.has("toca") and not o.got
		DRWS.append(o)
		di += 1
	DOOR = {"x": L.door.x, "y": L.door.y, "w": 60, "h": 90, "locked": false}
	# troncos de assento das fogueiras grandes: só onde há chão firme embaixo; são degraus baixos
	for c in CHK:
		if not c.has("rest"):
			continue
		c.seats = []
		for sx in [-74, 74]:
			var lx: float = c.x + sx
			var ok := false
			for s in SOL:
				if s.t in ["ground", "dirt", "cliff", "stone"] and abs(s.y - c.y) < 2 and s.x <= lx - 36 and s.x + s.w >= lx + 36:
					ok = true
			# e sem nada perto que atrapalhe a passagem (parede, passagem baixa, escada)
			var area := R(lx - 90, c.y - 90, 180, 88)
			for s in SOL:
				if not s.get("oneway") and hit(area, s) and not (abs(s.y - c.y) < 2 and s.t in ["ground", "dirt"]):
					ok = false
			for cl in CLIMB:
				if hit(area, cl):
					ok = false
			if ok:
				c.seats.append(lx)
				SOL.append({"t": "seat", "x": lx - 34, "y": c.y - 12, "w": 68, "h": 12})
	_p1_load()
	# objetos perto do chão ficam pousados nele (não flutuando)
	for arr in [COINS, ITEMS, CLUES, SPECS]:
		for o in arr:
			o.ry = _rest_y(o.x, o.y)
	for c in CLK:
		c.ry = _rest_y(c.x, c.y, 110)
	X = Extras.new(self)
	X.load_level()
	M = Mech.new(self)
	M.load_level()
	PR = Props.new(self)
	PR.load_level()
	TR = Traps.new(self)
	TR.load_level()
	ZN = Zones.new(self)
	ZN.load_level()
	NT = Nature.new(self)
	NT.load_level()
	K = Kings.new(self)
	K.load_level()
	RD = Ride.new(self)
	RD.load_level()
	RESTED = {}
	_reset_player(L.spawn.x - 12, L.spawn.y - 34)
	time_left = int(L.get("time", 180)) * 60
	coins = 0
	T = 0
	PARTS = []
	FXS = []
	COAL = []
	cam = clamp(player.x - W / 2, 0, max(0, L.spanX - W))
	cam_focus = player.y
	cam_y = clamp(player.y - H * .55, L.top, max(L.top, L.bottom - H))
	flash_t = 0
	running = true

func _rest_y(x: float, y: float, reach: float = 48) -> float:
	var best := INF
	for s in SOL:
		if x >= s.x - 2 and x <= s.x + s.w + 2 and s.y >= y - 4 and s.y - y <= reach and s.y < best:
			best = s.y
	return best if best < INF else -1.0

func _p1_load() -> void:
	CLIMB = []
	for z in L.get("climb", []):
		CLIMB.append(z.duplicate())
	ENTR = []
	for e in L.get("entrances", []):
		ENTR.append(e.duplicate())
	ITEMS = []
	for it in L.get("items", []):
		var o: Dictionary = it.duplicate()
		o.got = false
		ITEMS.append(o)
	LOCKS = []
	for l in L.get("locks", []):
		var o: Dictionary = l.duplicate()
		o.done = false
		LOCKS.append(o)
	CLUES = []
	for c in L.get("clues", []):
		var o: Dictionary = c.duplicate()
		o.got = CLUEGOT.has(int(c.id))
		CLUES.append(o)
	SPECS = []
	for s in L.get("specials", []):
		var o: Dictionary = s.duplicate()
		o.got = SPECGOT.has(s.c)
		SPECS.append(o)
	LILY = []
	for p in L.get("lily", []):
		var o: Dictionary = p.duplicate()
		o.y0 = p.y
		o.h = 14
		o.oneway = 1
		o.lily = 1
		o.t = 0
		o.st = 0
		o.tm = 0
		LILY.append(o)
	MUD = L.get("mud", []).duplicate(true)
	SWAMP = []
	for s in L.get("swamp", []):
		var o: Dictionary = s.duplicate()
		o.y0 = s.y
		SWAMP.append(o)
	BUSH = L.get("bushes", []).duplicate(true)
	VIL = null
	if L.has("villain"):
		VIL = L.villain.duplicate()
		VIL.x = VIL.x0
		VIL.go = false
		VIL.gone = false
	INV = ["picareta"]
	lantern_lit = not L.has("lanternOutX")
	look_y = 0
	STATS = {"pen": 0, "penTotal": L.get("coins", []).size()}

func _reset_player(x: float, y: float) -> void:
	player = make_body(x, y)
	if M:
		M.ctrl = false

func make_body(x: float, y: float) -> Dictionary:
	return {"x": x, "y": y, "w": 24, "h": 34, "vx": 0.0, "vy": 0.0, "onGround": false, "face": 1, "puff": false, "slam": false,
		"coyote": 0, "jbuf": 0, "airJumps": 1, "cutOk": false, "hp": MAXHP, "iframe": 0, "armor": 0, "squash": 0.0, "landT": 0, "anim": 0.0,
		"run": 0, "rdir": 1, "tR": -99, "tL": -99, "hR": false, "hL": false, "holdT": 0, "skidT": 0, "spawnX": x, "spawnY": y,
		"vine": null, "vr": 0.0, "vineCD": 0, "dyingT": 0, "exitT": 0, "_g": null, "actT": 0, "act": "", "pushT": 0, "leap": 0,
		"crouch": false, "slideT": 0, "ladder": null, "ladderCD": 0, "dropT": 0, "lookT": 0, "climbA": 0.0, "mud": false,
		"nearE": null, "nearL": null, "blink": 0, "turnT": 0, "lastFace": 1, "dieMsg": "", "swim": false, "water": null,
		"wall": 0, "wallT": 0, "wsl": 0, "lastWall": 0, "wlock": 0, "wslide": false, "guard": false, "dog": false,
		"warp": {}, "wdy": 0.0, "wal": 1.0, "wpose": "", "bar": null, "lastVine": null}

# ======================================================================
#  UTILIDADES
# ======================================================================
static func hit(a: Dictionary, b: Dictionary) -> bool:
	return a.x < b.x + b.w and a.x + a.w > b.x and a.y < b.y + b.h and a.y + a.h > b.y

func R(x: float, y: float, w: float, h: float) -> Dictionary:
	return {"x": x, "y": y, "w": w, "h": h}

func pressed(k: String) -> bool:
	if keys.get(k + "p", false):
		keys[k + "p"] = false
		return true
	return false

func kd(k: String) -> bool:
	return keys.get(k, false)

func flash(m: String, t: int = 150) -> void:
	flash_msg = m
	flash_t = t

func note(m: String) -> void:
	if flash_t <= 30:
		flash(m)

## tutorial ligado? (opção do menu; perguntado no começo do jogo)
static func tutorial_on() -> bool:
	return bool(Save.getv("opt", "tutorial", true))

## dica de "como fazer": só aparece com o tutorial ligado
func tip(m: String, t: int = 150) -> void:
	if tutorial_on() and flash_t <= 30:
		flash(m, t)

## mensagem com explicação só no tutorial (sem ele, só o essencial)
func flash_tut(short: String, long: String, t: int = 150) -> void:
	flash(long if tutorial_on() else short, t)

func burst(x: float, y: float, n: int, c: Color) -> void:
	for i in n:
		PARTS.append({"x": x, "y": y, "vx": (rng.randf() - .5) * 4.5, "vy": (rng.randf() - .9) * 4.5, "life": 18 + rng.randf() * 14, "col": c})

func fx(n: String, x: float, y: float, life: int, sc: float, vy: float = 0.0) -> void:
	FXS.append({"n": n, "x": x, "y": y, "t": 0, "life": life, "sc": sc, "vy": vy})

func blockers() -> Array:
	var b: Array = []
	var dog: bool = player.get("dog", false)
	for s in SOL:
		if s.get("ghost") and not s.on:
			continue
		if s.get("fallen"):
			continue
		if s.get("open", 0.0) > .85:
			continue
		if dog and s.get("dogpass"):
			continue
		b.append(s)
	for c in CR:
		if not c.dead:
			b.append(c)
	for p in LILY:
		if p.st != 2:
			b.append(p)
	return b

func has_item(id: String) -> bool:
	return INV.has(id)

func item_name(id: String) -> String:
	return GameData.ITEM_INFO[id][0]

# ======================================================================
#  MOCHILA, CADEADOS E DICAS
# ======================================================================
func give_item(id: String) -> void:
	INV.append(id)
	if id == "engrenagem":
		player.act = "gear"
		player.actT = 60
	Audio.play("item")
	Audio.vib(40)
	flash("Achou: " + item_name(id) + " (veja a mochila)")

func try_combine(a: String, b: String) -> String:
	if not has_item(a) or not has_item(b):
		return ""
	for r in GameData.RECIPES:
		if (r[0] == a and r[1] == b) or (r[0] == b and r[1] == a):
			INV.erase(a)
			INV.erase(b)
			INV.append(r[2])
			if r[2] == "lanterna_acesa":
				lantern_lit = true
			Audio.play("combine")
			Audio.vib(60)
			return r[3]
	return ""

func lock_msg(l) -> String:
	if l == null or l.done:
		return ""
	if has_item(l.need):
		return l.use
	var miss: Array = []
	for p in l.parts:
		if not has_item(p):
			miss.append(p)
	if miss.is_empty():
		return l.pre + " Você já tem " + item_name(l.parts[0]).to_lower() + " e " + item_name(l.parts[1]).to_lower() + ": abra a mochila e junte os dois!"
	var parts: Array = []
	for p in miss:
		parts.append(item_name(p).to_lower() + " — " + l.where[p])
	return l.pre + " Falta " + "; e ".join(parts) + "."

func item_msg(id: String) -> String:
	if id == "picareta":
		return "A velha picareta de mineiro do Tomé. Perto de uma rocha rachada, toque ✦ USAR para quebrar."
	if id == "lanterna_acesa" and lantern_lit:
		return "A lanterna está acesa. Segure ✦ USAR para concentrar o facho de luz."
	for l in LOCKS:
		if l.need == id:
			if not l.done:
				return "Este objeto já está pronto, não precisa combinar! " + l.place
			return "A lanterna está acesa e iluminando o caminho." if id == "lanterna_acesa" else "Este objeto já foi usado."
	for r in GameData.RECIPES:
		if r[0] == id or r[1] == id:
			var o: String = r[1] if r[0] == id else r[0]
			if has_item(o):
				return "Agora toque em " + item_name(o).to_lower() + " para combinar."
			for l in LOCKS:
				if l.has("parts") and l.parts.has(o):
					return "Ainda falta achar: " + item_name(o).to_lower() + " — " + l.where[o] + "."
			return "Ainda falta achar: " + item_name(o).to_lower() + "."
	return ""

func hint_text() -> String:
	if not tutorial_on():
		return ""
	var px: float = player.x + player.w / 2
	for h in L.get("hints", []):
		if px < h.a or px > h.b:
			continue
		if h.has("yl") and player.y >= h.yl:
			continue
		if h.has("yg") and player.y <= h.yg:
			continue
		if h.get("boss") and not X.boss_active():
			continue
		if h.has("crack") and X.broken.has(h.crack):
			continue
		if h.get("dogtied") and X.dog_free():
			continue
		if h.has("trap") and int(h.trap) < TR.T.size():
			var tst: String = TR.T[int(h.trap)].st
			if tst in ["down", "used", "done"] or (h.has("trapst") and tst != h.trapst):
				continue
		if h.has("toca") and (X.TOCAS.is_empty() or X.TOCAS[0].done):
			continue
		if h.get("hawk") and (K.HAWK.is_empty() or not K.HAWK.active or K.HAWK.done):
			continue
		if h.get("horse") and (RD.H.is_empty() or RD.H.st != "trapped"):
			continue
		if X.boss_active() and not h.get("boss"):
			continue
		var m: String = lock_msg(LOCKS[int(h.lock)]) if h.has("lock") else h.get("t", "")
		if m == "":
			continue
		return m
	return ""

func touching_wall(dir: int) -> bool:
	var probe := R(player.x + (player.w if dir > 0 else -3.0), player.y + 6, 3, player.h - 14)
	for s in blockers():
		if s.get("oneway") or s.get("crate") or s.get("lily"):
			continue
		if hit(probe, s):
			return true
	return false

func can_stand() -> bool:
	for s in blockers():
		if not s.get("oneway") and hit(R(player.x + 1, player.y - 14, player.w - 2, 34), s):
			return false
	return true

func stand_up() -> bool:
	if player.crouch and can_stand():
		player.crouch = false
		player.y -= 14
		player.h = 34
		player.slideT = 0
		return true
	return not player.crouch

func ambient() -> void:
	var S: Array = L.get("sections", [])
	if S.is_empty():
		return
	if ZN and ZN.zone != null:
		AMB.dark = 0.0
		AMB.rain = 0.0
		AMB.night = 0.0
		AMB.tint = ""
		AMB.fog = 0.0
		AMB.wind = 0.0
		AMB.song = ZN.zone.get("song", "manha")
		return
	var px: float = player.x + player.w / 2
	var i := 0
	while i + 1 < S.size() and S[i + 1].x <= px:
		i += 1
	var a: Dictionary = S[i]
	var b = S[i + 1] if i + 1 < S.size() else null
	var t := 0.0
	if b:
		t = clamp((px - (b.x - 260)) / 260.0, 0, 1)
	var mix = func(k: String) -> float:
		var va: float = a.get(k, 0.0)
		var vb: float = b.get(k, 0.0) if b else va
		return va + (vb - va) * t
	AMB.dark = mix.call("dark")
	AMB.rain = mix.call("rain")
	AMB.night = mix.call("night")
	AMB.snow = mix.call("snow")
	var src: Dictionary = a if (t < .5 or b == null) else b
	AMB.tint = src.get("tint", "")
	AMB.song = src.get("song", "manha")
	for z in L.get("darkZones", []):
		if px > z.x and px < z.x + z.w:
			AMB.dark = max(AMB.dark, z.dark)
	if L.has("lanternOutX") and px > L.lanternOutX and not lantern_lit:
		AMB.dark = max(AMB.dark, .86)
	if X:
		X.weather_amb()

## nome do período do dia em que o Tomé está (a fase é uma só, dividida pelas fogueiras grandes)
const PERIODS := ["Manhã no bosque", "Tarde", "Pântano", "Neve", "Noite na mina"]
func period_index() -> int:
	var px: float = player.x + player.w / 2
	var n := 0
	for c in CHK:
		if c.has("rest") and px > c.x + 30:
			n = max(n, int(c.rest))
	return n

func period_label() -> String:
	var i: int = period_index()
	return "%d/5 · %s" % [i + 1, PERIODS[min(i, 4)]]

func section_weights() -> Dictionary:
	## peso de cada cenário de fundo conforme a posição (para o fundo trocar suavemente)
	var S: Array = L.get("sections", [])
	var map := {"manha": "bosque", "tarde": "tarde", "chuva": "pantano", "noite": "noite", "tunel": "noite", "perseguicao": "noite"}
	var px: float = player.x + player.w / 2
	var out := {}
	if S.is_empty():
		return {"bosque": 1.0}
	var i := 0
	while i + 1 < S.size() and S[i + 1].x <= px:
		i += 1
	var ka: String = S[i].get("bg", map.get(S[i].get("song", "manha"), "bosque"))
	out[ka] = 1.0
	if i + 1 < S.size():
		var kb: String = S[i + 1].get("bg", map.get(S[i + 1].get("song", "manha"), "bosque"))
		var t: float = clamp((px - (S[i + 1].x - 400)) / 400.0, 0, 1)
		if kb != ka and t > 0:
			out[kb] = t
	return out

# ======================================================================
#  PASSO
# ======================================================================
func _save_prev() -> void:
	prev_px = player.x
	prev_py = player.y
	prev_cam = cam
	prev_cam_y = cam_y
	for e in EN:
		e.ppx = e.x
		e.ppy = e.y

## deslocamento para desenhar o Tomé na posição "entre" dois passos
func ip_off() -> Vector2:
	var f := Engine.get_physics_interpolation_fraction()
	if abs(player.x - prev_px) > 60 or abs(player.y - prev_py) > 60:
		return Vector2.ZERO
	return Vector2((prev_px - player.x) * (1 - f), (prev_py - player.y) * (1 - f))

func e_off(e: Dictionary) -> Vector2:
	var f := Engine.get_physics_interpolation_fraction()
	if not e.has("ppx") or abs(e.x - e.ppx) > 60 or abs(e.y - e.ppy) > 60:
		return Vector2.ZERO
	return Vector2((e.ppx - e.x) * (1 - f), (e.ppy - e.y) * (1 - f))

func update_render_cam() -> void:
	var f := Engine.get_physics_interpolation_fraction()
	if abs(cam - prev_cam) > 80 or abs(cam_y - prev_cam_y) > 80:
		rcam = cam
		rcam_y = cam_y
	else:
		rcam = lerpf(prev_cam, cam, f)
		rcam_y = lerpf(prev_cam_y, cam_y, f)

func step() -> void:
	if not running:
		return
	_save_prev()
	if hit_stop > 0:
		hit_stop -= 1
		return
	if iris_t > 0:
		iris_t -= 1
	if not CINE.is_empty():
		_cine_step()
		return
	if player.dyingT > 0:
		T += 1
		player.dyingT -= 1
		player.vy = min(player.vy + .5, 12)
		player.y += player.vy
		_tick_fx()
		if player.dyingT == 0:
			respawn()
		return
	if not player.get("warp", {}).is_empty():
		T += 1
		_warp_step()
		_tick_fx()
		_camera()
		return
	if player.exitT > 0:
		T += 1
		player.exitT -= 1
		player.vx = 0
		var dx: float = DOOR.x + DOOR.w / 2 - (player.x + player.w / 2)
		player.x += clamp(dx, -2, 2)
		_tick_fx()
		if player.exitT == 0:
			running = false
			if L.get("results"):
				results_ready.emit()
			else:
				level_won.emit()
		return
	if RD.riding:
		if flash_t > 0:
			flash_t -= 1
		if shake > 0:
			shake *= .85
		RD.step()
		max_x = max(max_x, player.x + 300)
		_tick_fx()
		_camera()
		return
	T += 1
	if ZN == null or ZN.zone == null:
		max_x = max(max_x, player.x + 300)
	if shake > 0:
		shake *= .85
	for k in ["iframe", "vineCD", "actT", "pushT", "leap", "skidT"]:
		if player[k] > 0:
			player[k] -= 1
	if flash_t > 0:
		flash_t -= 1
	time_left -= 1
	if time_left <= 0:
		die("O tempo acabou.")
		return
	X.pre_step()
	if player.dyingT > 0:
		return
	NT.pre()
	M.pre()
	TR.pre()
	ZN.pre()
	# encostado numa parede no ar (para deslizar e pular de parede em parede)
	player.wslide = false
	if player.wsl > 0:
		player.wsl -= 1
	if player.wlock > 0:
		player.wlock -= 1
	if player.onGround or player.ladder or player.vine or player.swim:
		player.lastWall = 0
		player.wall = 0
		player.wallT = 0
	elif not player.dog and not player.crouch:
		var wd := 0
		if touching_wall(1):
			wd = 1
		elif touching_wall(-1):
			wd = -1
		if wd != 0:
			player.wall = wd
			player.wallT = 6
		elif player.wallT > 0:
			player.wallT -= 1
		else:
			player.wall = 0
	if pressed("B"):
		player.x = player.spawnX
		player.y = player.spawnY
		player.vx = 0
		player.vy = 0
		player.iframe = 40
		player.puff = false
		player.slam = false
		player.vine = null
		player.ladder = null
		if player.crouch:
			player.crouch = false
			player.h = 34
		M.reset_crates(player.spawnX)
		flash("De volta à fogueira.")
	# corrida: dois toques na mesma direção
	if kd("R") and not player.hR:
		if T - player.tR < 16:
			player.run = 1
			player.rdir = 1
			burst(player.x, player.y + player.h - 4, 6, Color("#e9dbb8"))
		player.tR = T
	if kd("L") and not player.hL:
		if T - player.tL < 16:
			player.run = 1
			player.rdir = -1
			burst(player.x + player.w, player.y + player.h - 4, 6, Color("#e9dbb8"))
		player.tL = T
	player.hR = kd("R")
	player.hL = kd("L")
	if player.run and not (kd("R") if player.rdir > 0 else kd("L")):
		player.run = 0
	# cipós livres
	for v in VINES:
		if player.vine == v:
			continue
		v.om += -(VINE_G / v.len) * sin(v.th)
		v.om *= .985
		v.th += v.om

	var pcx: float = player.x + player.w / 2
	var pcy: float = player.y + player.h / 2
	player.mud = false
	for m in MUD:
		if pcx > m.x and pcx < m.x + m.w and abs(player.y + player.h - m.y) < 4:
			player.mud = true
	_p1_pre(pcx)
	if player.vine:
		_vine_step()
	elif player.ladder:
		_p1_ladder()
	elif player.get("bar"):
		NT.bar_step()
	elif player.swim:
		X.swim()
	else:
		# planar
		player.puff = (kd("P") or (kd("J") and player.airJumps == 0 and player.vy > .5)) and not player.onGround and not player.slam and player.vy > -1.5 and not player.dog and player.wall == 0
		# pulos
		var g0 = player._g
		if pressed("J"):
			if player.onGround and kd("S") and g0 and g0.get("oneway") and not g0.get("lily"):
				player.dropT = 14
				stand_up()
				player.y += 4
				player.onGround = false
			else:
				player.jbuf = BUF
		if player.jbuf > 0 and player.crouch and (player.onGround or player.coyote > 0) and not stand_up():
			player.jbuf = 0
		var mudF := .78 if player.mud else 1.0
		if player.jbuf > 0:
			if player.onGround or player.coyote > 0:
				player.vy = (JUMP * .9 if player.dog else JUMP) * mudF
				Audio.play("jump", -6)
				player.onGround = false
				player.coyote = 0
				player.airJumps = 0 if player.dog else 1
				player.jbuf = 0
				player.cutOk = true
				player.slam = false
				player.squash = -.5
				burst(player.x + player.w / 2, player.y + player.h, 6, Color("#cdbfa6"))
			elif player.wall != 0 and player.wall != player.lastWall and not player.dog and (player.wsl > 0 or player.airJumps == 0):
				# pulo na parede: empurra para o lado oposto e devolve o pulo duplo
				player.lastWall = player.wall
				player.vx = -player.wall * 6.4
				player.vy = JUMP * .93
				player.face = -player.wall
				player.wlock = 11
				player.wall = 0
				player.wallT = 0
				player.airJumps = 1
				player.jbuf = 0
				player.cutOk = true
				player.puff = false
				player.squash = -.4
				Audio.play("jump", -4)
				fx("fx_dust", player.x + (player.w if player.face < 0 else 0.0), player.y + player.h / 2, 16, .12, -.1)
				burst(player.x + player.w / 2 - player.face * 12, player.y + player.h / 2, 8, Color("#cdbfa6"))
			elif player.airJumps > 0:
				player.vy = DJUMP
				Audio.play("dj", -6)
				player.airJumps -= 1
				player.puff = false
				player.jbuf = 0
				player.squash = -.4
				player.cutOk = true
				for a in 10:
					PARTS.append({"x": player.x + player.w / 2, "y": player.y + player.h, "vx": cos(a / 10.0 * TAU) * 2.6, "vy": sin(a / 10.0 * TAU) * 2.6, "life": 16, "col": Color("#e9dbb8")})
		if player.jbuf > 0:
			player.jbuf -= 1
		if player.coyote > 0:
			player.coyote -= 1
		if player.cutOk and not kd("J") and player.vy < -3.5 and not player.slam and player.leap <= 0:
			player.vy = -3.5
		# mergulho
		if pressed("S") and not player.onGround and not player.slam and not player.dog:
			player.slam = true
			player.puff = false
			player.vy = max(player.vy, 4)
		# horizontal (logo depois de pular na parede, o controle fica um instante travado)
		var held_l: bool = keys.get("L", false)
		var held_r: bool = keys.get("R", false)
		if player.wlock > 0 or player.get("launchT", 0) > 0:
			keys.L = false
			keys.R = false
		if player.crouch:
			var want := -1 if (kd("L") and not kd("R")) else (1 if (kd("R") and not kd("L")) else 0)
			if want != 0:
				player.face = want
			if player.slideT:
				player.vx *= .9 if player.mud else .976
				if T % 4 == 0:
					fx("fx_dust", player.x + player.w / 2 - player.face * 10, player.y + player.h - 3, 12, .08, -.2)
				if abs(player.vx) < 1.3:
					player.slideT = 0
			else:
				player.vx += (want * 1.8 - player.vx) * .25
		else:
			var run: bool = player.run and not player.puff
			var acc: float = PUFF_ACC if player.puff else (( RUN_ACC if run else ACCg) if player.onGround else ACCa)
			var top: float = PUFF_TOP if player.puff else (RUN_TOP if run else TOP)
			var want := -1 if (kd("L") and not kd("R")) else (1 if (kd("R") and not kd("L")) else 0)
			if player.onGround and want != 0 and player.vx * want < -2.2 and not player.puff:
				player.vx += want * acc * 1.3
				player.skidT = 6
				if T % 3 == 0:
					fx("fx_dust", player.x + player.w / 2, player.y + player.h - 4, 14, .12, -.3)
			if player.onGround and want != 0 and abs(player.vx) >= TOP - .15 and not player.run:
				player.holdT += 1
				if player.holdT > 75:
					player.run = 1
					player.rdir = want
					burst(player.x + player.w / 2, player.y + player.h - 4, 6, Color("#e9dbb8"))
			elif want == 0 or (not player.onGround and not player.run):
				player.holdT = 0
			var wet: bool = player._g != null and player._g.get("wet") and player.onGround
			var top2 := top
			if player.mud and player.onGround:
				top2 = min(top, 1.9)
			if axis_x < 1 and player.onGround and not player.run:
				top2 = top2 * axis_x
			if X.focus:
				top2 = min(top2, 1.6)
			if player.guard:
				top2 = min(top2, 1.2)
			if player.dog:
				top2 = top2 * 1.18
			if wet and want == 0:
				# escorrega um pouco e para: gelo desliza mais que o tronco molhado
				player.vx *= (.955 if player._g.t == "ice" else .88) / FRIC
			if kd("L") and not player.slam:
				player.vx = min(-top2, player.vx * .985) if player.vx < -top2 else max(player.vx - acc, -top2)
				player.face = -1
			elif kd("R") and not player.slam:
				player.vx = max(top2, player.vx * .985) if player.vx > top2 else min(player.vx + acc, top2)
				player.face = 1
			elif player.get("launchT", 0) <= 0:
				player.vx *= FRIC if player.onGround else (.9 if player.slam else .985)
		keys.L = held_l
		keys.R = held_r
	# vertical
	if not player.vine and not player.ladder and not player.swim and not player.get("bar"):
		var g := GRAV
		var maxv := 13.0
		if player.slam:
			g = SLAM_GRAV
			maxv = SLAM_MAX
		elif player.puff:
			g = PUFF_GRAV
			maxv = PUFF_FALL
		if kd("J") and not player.puff and not player.slam and abs(player.vy) < 1.6 and player.get("launchT", 0) <= 0:
			g *= .55
		player.vy = clamp(player.vy + g, -34 if player.get("launchT", 0) > 0 else -20, maxv)
		if player.wall != 0 and not player.onGround and player.vy > 1.5 and kd("R" if player.wall > 0 else "L") and player.wlock == 0:
			player.vy = min(player.vy, 2.3)
			player.wslide = true
			player.wsl = 6
			player.face = player.wall
			player.slam = false
			if T % 6 == 0:
				PARTS.append({"x": player.x + (player.w if player.wall > 0 else 0.0), "y": player.y + 6, "vx": -player.wall * .6, "vy": -.4, "life": 14, "col": Color(.85, .78, .62, .7)})

	var prev_vy: float = player.vy
	var was_ground: bool = player.onGround
	if not player.vine and not player.get("bar"):
		player.onGround = false
		move_x(player.vx)
		move_y(player.vy)
	if player.onGround and not was_ground and prev_vy > 6:
		player.squash = min(1, prev_vy / 14)
		player.landT = 8
		if prev_vy > 10:
			Audio.vib(18)
		burst(player.x + player.w / 2, player.y + player.h, 5, Color("#b7a77f"))
		fx("fx_dust", player.x + player.w / 2, player.y + player.h - 6, 16, .08 + prev_vy * .01, -.2)
	if player.run and player.onGround and T % 8 == 0:
		fx("fx_dust", player.x + player.w / 2 - player.face * 14, player.y + player.h - 5, 14, .09, -.25)
	player.squash *= .78
	if player.landT > 0:
		player.landT -= 1
	if player.slam and player.onGround:
		shake = max(shake, 9)
		burst(player.x + player.w / 2, player.y + player.h, 16, Color("#d9c290"))
		var r := R(player.x - 30, player.y - 6, player.w + 60, player.h + 40)
		for c in CR:
			if not c.dead and c.t == "break" and hit(r, c):
				break_crate(c)
		for e in EN:
			if not e.dead and hit(r, ebox(e)):
				kill_enemy(e, "stomp")
		player.slam = false
	if player.onGround and abs(player.vx) > 2.4 and T % (2 if player.run else 4) == 0:
		PARTS.append({"x": player.x + player.w / 2 - player.face * 8, "y": player.y + player.h - 2, "vx": -player.face * 1.2, "vy": -.6, "life": 14, "col": Color(.59, .55, .43, .5)})
	if player.blink > 0:
		player.blink -= 1
	elif rng.randf() < .004:
		player.blink = 8
	player.anim += abs(player.vx) * .06
	# agarrar cipó
	if player.onGround or player.get("bar") or player.swim:
		player.lastVine = null
	if not player.vine and not player.onGround and player.vineCD <= 0 and not player.ladder and not player.dog:
		var hx: float = player.x + player.w / 2
		var hy: float = player.y + 6
		for v in VINES:
			if v == player.get("lastVine"):
				continue   # o cipó que acabou de soltar não pega de novo
			var sx := sin(v.th)
			var cy := cos(v.th)
			var dx: float = hx - v.x
			var dy: float = hy - v.y
			var t: float = dx * sx + dy * cy
			var perp: float = abs(dx * cy - dy * sx)
			if t > 24 and t < v.len + 22 and perp < 30:
				player.vine = v
				player.vr = clamp(t, 40.0, v.len)
				# conserva um pouco do embalo, sem disparar o balanço
				v.om = clamp((player.vx * cy - player.vy * sx) / player.vr * .6, -.02, .02)
				v.bend = 1.0
				player.vang = v.th * .4
				player.slam = false
				player.puff = false
				player.airJumps = 1
				player.run = 0
				Audio.play("climb", -8)
				tip("←/→ balança · ↑/↓ sobe e desce · PULAR solta")
				break

	_p1_post(pcx, pcy)
	for d in DRWS:
		if not d.got and not d.get("hidden") and hit(player, R(d.x - 22, d.y - 22, 44, 44)):
			d.got = true
			DRAWN["%d:%d" % [level_idx, d.i]] = 1
			Save.setv("gallery", "d%d" % int(d.i), true)
			flash(d.txt, 280)
			burst(d.x, d.y, 24, Color("#f6efdc"))
			Audio.play("clue")
			Audio.vib(50)
	# molas (cogumelo)
	if player.vy >= 0 and not player.vine:
		for s in SPR:
			var top_y: float = s.y - 24
			if player.x < s.x + 28 and player.x + player.w > s.x - 28 and player.y + player.h >= top_y and player.y + player.h <= s.y + 12:
				player.y = top_y - player.h
				player.vy = s.pow
				Audio.play("spring")
				player.onGround = false
				player.airJumps = 1
				player.cutOk = false
				player.slam = false
				s.t = 10
				burst(s.x, top_y, 10, Color("#8fd0ff"))
	for s in SPR:
		if s.t > 0:
			s.t -= 1
	if pressed("A") and player.nearL == null and not lantern_lit:
		tip("Aqui não há o que usar. Perto de um obstáculo, ✦ USAR tenta abrir caminho.")
	if player.y > L.bottom + 60:
		die("Você caiu.")
	for pit in L.get("pits", []):
		if pcx > pit[0] and pcx < pit[1] and player.y > 660 and player.dyingT == 0:
			die("Você caiu no buraco.")
	if not running or player.dyingT > 0:
		_tick_fx()
		_camera()
		return
	# lápis (moedas)
	for c in COINS:
		if c.got:
			continue
		if hit(player, R(c.x - 15, c.y - 15, 30, 30)):
			c.got = true
			STATS.pen += 1
			gain_coin(c.x, c.y)
	for c in CLK:
		var cyy: float = c.ry - 16 if c.ry > 0 else c.y
		if not c.got and hit(player, R(c.x - 18, cyy - 18, 36, 36)):
			c.got = true
			time_left += 20 * 60
			flash("Ampulheta: +20 segundos.")
			burst(c.x, c.y, 14, Color("#bfe3ff"))
	# fogueiras
	for k in CHK.size():
		var c: Dictionary = CHK[k]
		if k == cur_chk or player.dog or abs(player.x + player.w / 2 - c.x) >= 26 or abs(player.y + player.h - c.y) >= 60:
			continue
		# qualquer fogueira que não seja a atual vira o ponto de volta (mesmo já acesa)
		player.spawnX = c.x - 12
		player.spawnY = c.y - 34
		cur_chk = k
		if not c.on:
			c.on = true
			Audio.play("fire")
			flash("Fogueira acesa: progresso salvo.")
			burst(c.x, c.y - 30, 12, Color("#ffd76a"))
		else:
			note("Progresso salvo.")
		if c.has("rest") and not RESTED.has(c.rest):
			RESTED[c.rest] = 1
			time_left = int(L.get("period", L.get("time", 300))) * 60
			player.vx = 0.0
			save_checkpoint(k)
			running = false
			rest_reached.emit(c.rest)
			return
		save_checkpoint(k)
	# inimigos
	for e in EN:
		if e.dead:
			e.dead += 1
			if e.get("dk") == "flip":
				e.ddy += e.dvy
				e.dvy += .45
			continue
		update_enemy(e)
		if e.dead:
			continue
		var b := ebox(e)
		if hit(player, b):
			var stomp: bool = (player.vy > 1 or player.slam) and (player.y + player.h) - b.y < 22
			if stomp and e.k == "mole" and e.get("helm") and not e.get("helm_off") and e.get("st", 0) != 5:
				player.vy = STOMP * .8
				player.cutOk = false
				Audio.play("unlock", -10)
				burst(e.x, b.y, 6, Color("#e8b030"))
				if X.dog_free():
					tip("O capacete protege! O Pipoca consegue puxá-la para fora quando ela estiver debaixo da terra.")
				else:
					note("O capacete protege! Sozinho não dá...")
				continue
			if e.k == "mole" and e.get("st", 0) == 5 and not stomp:
				continue
			if stomp:
				kill_enemy(e, "stomp")
				player.vy = STOMP * .6 if player.slam else (STOMP * 1.3 if kd("J") else STOMP)
				player.slam = false
				player.squash = .6
				player.cutOk = false
				player.airJumps = 1
			elif not e.stun:
				hurt(1, e.x)
	if ZN.zone != null:
		player.x = clamp(player.x, ZN.zone.x0, ZN.zone.x1 - player.w)
	else:
		player.x = clamp(player.x, 0, L.spanX - player.w)
	# saída (porta da mina)
	if not player.dog and hit(player, R(DOOR.x + 10, DOOR.y, DOOR.w - 20, DOOR.h)) and not DOOR.locked and (VIL == null or VIL.gone):
		player.exitT = 40
		burst(DOOR.x + DOOR.w / 2, DOOR.y + DOOR.h / 2, 20, Color("#ffe9a0"))
		Audio.play("door")
	_tick_fx()
	_camera()

func _tick_fx() -> void:
	for f in FXS:
		f.t += 1
		f.y += f.vy
		f.sc *= 1.01
	FXS = FXS.filter(func(f): return f.t < f.life)
	for p in PARTS:
		p.vy += .18
		p.x += p.vx
		p.y += p.vy
		p.life -= 1
	PARTS = PARTS.filter(func(p): return p.life > 0)

## Mola criticamente amortecida (SmoothDamp): segue o alvo suave, sem passar do ponto nem tremer.
static func damp(cur: float, target: float, vel: float, smooth: float) -> Array:
	var dt := 1.0 / 60.0
	var omega: float = 2.0 / maxf(0.0001, smooth)
	var x: float = omega * dt
	var e: float = 1.0 / (1.0 + x + .48 * x * x + .235 * x * x * x)
	var change: float = cur - target
	var temp: float = (vel + omega * change) * dt
	vel = (vel - omega * temp) * e
	return [target + (change + temp) * e, vel]

func _camera() -> void:
	var px: float = player.x + player.w / 2
	var tx: float
	var ty: float
	if not CINE.is_empty():
		tx = CINE.fx - W / 2
		ty = CINE.fy - H * .55
	else:
		# olhar para a frente só depois de andar um pouco na mesma direção (virar rápido não balança a tela)
		var want: float = player.face * (120.0 if player.run else 70.0)
		if abs(player.vx) > 1.2 and sign(player.vx) == player.face:
			look_hold += 1
		else:
			look_hold = 0
		if look_hold < 14:
			want = look_x
		var r := damp(look_x, want, look_vx, .7)
		look_x = r[0]
		look_vx = r[1]
		tx = px - W / 2 + look_x
		# vertical: só muda de altura quando pisa em algo, sobe muito ou cai
		if player.onGround or player.vine or player.ladder or player.swim or player.y > cam_focus + 40:
			cam_focus = player.y
		elif player.y < cam_focus - 150:
			cam_focus = player.y + 150
		ty = cam_focus - H * .55 + look_y
	var cb := cam_bounds()
	tx = clamp(tx, cb.position.x, max(cb.position.x, cb.end.x - W))
	ty = clamp(ty, cb.position.y, max(cb.position.y, cb.end.y - H))
	var rx := damp(cam, tx, cam_vx, .16 if CINE.is_empty() else .5)
	cam = rx[0]
	cam_vx = rx[1]
	var ry := damp(cam_y, ty, cam_vy, .26 if CINE.is_empty() else .5)
	cam_y = ry[0]
	cam_vy = ry[1]

# ======================================================================
#  CENAS DRAMÁTICAS DENTRO DO JOGO
# ======================================================================
## id: "boss", "vargas", "cao". A câmera vai até o foco, aparecem as faixas de cinema e as falas.
func start_cine(id: String, fx: float, fy: float, dur: int, lines: Array = [], title: Array = []) -> void:
	CINE = {"id": id, "t": 0, "dur": dur, "fx": fx, "fy": fy, "fx0": fx, "lines": lines, "title": title}
	keys.clear()
	player.vx = 0.0
	player.run = 0
	player.puff = false
	player.slam = false

func cine_line():
	if CINE.is_empty():
		return null
	for l in CINE.lines:
		if CINE.t >= l[0] and CINE.t < l[1]:
			return l
	return null

func _cine_step() -> void:
	T += 1
	# cada fala fica parada na tela até o jogador tocar (nos testes sem tela, segue sozinha)
	var cl: Array = []
	var lv: Variant = cine_line()
	if lv is Array:
		cl = lv
	var tap: bool = pressed("J") or pressed("A")
	if pressed("K"):
		CINE.t = CINE.dur
	elif not cl.is_empty():
		var full_t: int = int(cl[0] + cl[3].length() / 1.6) + 1
		if tap and CINE.t < min(full_t, cl[1] - 3):
			CINE.t = min(full_t, cl[1] - 3)
		elif CINE.t >= cl[1] - 3 and not CINE.get("ok", {}).has(cl[0]) and not auto_cine:
			CINE.waiting = true
			if tap:
				CINE.waiting = false
				if not CINE.has("ok"):
					CINE.ok = {}
				CINE.ok[cl[0]] = 1
				CINE.t += 1
		else:
			CINE.waiting = false
			CINE.t += 1
	else:
		CINE.waiting = false
		CINE.t += 1
	var t: int = CINE.t
	# o Tomé fica parado (mas a gravidade continua)
	player.vx *= .7
	if player.swim:
		player.vy *= .9
		move_y(player.vy)
	elif not player.onGround and not player.ladder and not player.vine and not player.get("bar"):
		player.vy = min(player.vy + GRAV, 13)
		player.onGround = false
		move_y(player.vy)
	X.cine_step(CINE)
	K.cine_step(CINE)
	RD.cine_step(CINE)
	if lightning > 0:
		lightning -= 1
	if shake > 0:
		shake *= .85
	# volta a câmera para o Tomé no fim
	if t > CINE.dur - 50:
		CINE.fx = lerpf(CINE.fx, player.x + player.w / 2, .08)
		CINE.fy = lerpf(CINE.fy, player.y, .08)
	if t >= CINE.dur:
		var id: String = CINE.id
		CINE = {}
		X.cine_end(id)
		K.cine_end(id)
		RD.cine_end(id)
	_tick_fx()
	_camera()

## limites da câmera: a fase inteira, ou a sala da torre onde o Tomé está
func cam_bounds() -> Rect2:
	if ZN and ZN.zone != null:
		return ZN.cam_rect()
	return Rect2(0, L.top, L.spanX, L.bottom - L.top)

func snap_camera() -> void:
	prev_px = -99999
	cam_vx = 0.0
	cam_vy = 0.0
	look_x = player.face * 70.0
	look_vx = 0.0
	if ZN:
		ZN.zone = ZN.zone_at(player.x + player.w / 2, player.y + player.h / 2)
	var cb := cam_bounds()
	cam = clamp(player.x + player.w / 2 - W / 2 + look_x, cb.position.x, max(cb.position.x, cb.end.x - W))
	cam_focus = player.y
	cam_y = clamp(player.y - H * .55, cb.position.y, max(cb.position.y, cb.end.y - H))
	prev_cam = cam
	prev_cam_y = cam_y
	rcam = cam
	rcam_y = cam_y

# ======================================================================
#  CIPÓ: pêndulo de verdade (impulso como num balanço de parque)
# ======================================================================
func _vine_step() -> void:
	var v: Dictionary = player.vine
	var r: float = player.vr
	# gravidade puxando o pêndulo (mais fraca que a do pulo: balanço lento e tranquilo)
	v.om += -(VINE_G / r) * sin(v.th)
	# impulso: empurrar no sentido em que já está indo rende mais, sobretudo perto do ponto mais baixo
	var d := 0
	if kd("R") and not kd("L"):
		d = 1
	elif kd("L") and not kd("R"):
		d = -1
	if d != 0:
		player.face = d
		var same: bool = v.om * d > 0 or abs(v.om) < .004
		v.om += d * (.0012 if same else .0006) * max(.25, cos(v.th))
	v.om *= .994
	v.om = clamp(v.om, -.032, .032)
	# topo macio: perto do alto o cipó perde força devagar (uma pausinha no alto antes de voltar)
	var lim := .75
	if abs(v.th) > lim:
		v.om -= sign(v.th) * (abs(v.th) - lim) * .06
	v.th += v.om
	if abs(v.th) > 1.42:
		v.th = sign(v.th) * 1.42
		v.om = -v.om * .3
	# subir e descer pelo cipó (mais curto = balança mais rápido: conserva o giro)
	var nr := r
	if kd("U"):
		nr = max(40.0, r - 1.6)
	elif kd("S"):
		nr = min(v.len, r + 1.8)
	elif r < v.len * .7:
		# agarrou lá no alto: escorrega um pouco até uma altura boa para balançar
		nr = min(v.len * .7, r + 2.5)
	if nr != r:
		v.om *= clamp(r / nr, .95, 1.06)
		player.vr = nr
		player.climbA += 3
		r = nr
	if v.has("bend"):
		v.bend *= .93
	# o corpo inclina só uma parte do ângulo do cipó, com atraso (fica "pendurado" pelas mãos)
	player.vang = lerpf(player.get("vang", 0.0), v.th * .42 + v.om * 3.0, .18)
	player.x = v.x + sin(v.th) * r - player.w / 2
	player.y = v.y + cos(v.th) * r - 6
	player.vx = 0
	player.vy = 0
	player.onGround = false
	if pressed("J"):
		# solta com impulso na direção do movimento (quanto mais rápido, mais longe)
		var vt: float = r * v.om
		player.vx = clamp(vt * cos(v.th) * 1.12, -10, 10)
		player.vy = max(-15.0, -vt * sin(v.th) - 3.4)
		if d != 0 and abs(player.vx) < 2.0:
			player.vx = d * 2.0
		# ajudinha: soltando para o lado do alvo do cipó (próximo cipó, corda, margem), o pulo vai certinho até ele
		if v.has("aim"):
			var tgt := Vector2(float(v.aim[0]), float(v.aim[1]) - player.h)
			var dx: float = tgt.x - player.x - player.w / 2
			# sempre vai para a frente (o próximo cipó, a corda ou a margem), mesmo com o direcional
			# apertado para trás no balanço — para voltar, desce até a ponta do cipó e solta com ↓
			if abs(dx) < 620:
				var from := Vector2(player.x + player.w / 2, player.y)
				var sol := TR.ballistic(from, tgt, .75)
				if sol.y < -16.0:
					sol = TR.ballistic(from, tgt, .6)
				if sol.y > -17.0:
					player.vx = sol.x
					player.vy = sol.y
					player.launchT = int(sol.z)
		player.lastVine = v
		player.vine = null
		player.vineCD = 22
		player.airJumps = 1
		player.cutOk = false
		player.jbuf = 0
		player.squash = -.4
		Audio.play("jump", -6)
		burst(player.x + player.w / 2, player.y, 8, Color("#cdbfa6"))
	elif pressed("S") and r >= v.len - 1:
		player.vine = null
		player.vineCD = 22

# ======================================================================
#  ENTRAR E SAIR DE ESCONDERIJOS (tronco oco, portas, tocas): animação em vez de teleporte seco
# ======================================================================
## mode: "down" (abaixa e entra pelo buraco), "up" (sobe pela saída), "door" (atravessa a porta)
func start_warp(e: Dictionary) -> void:
	var mode: String = e.get("mode", "up" if e.get("exit") else "down")
	stand_up()
	var cx: float = e.x + e.w / 2
	if int(e.get("dir", 0)) != 0:
		cx = e.x + (e.w * .3 if int(e.dir) > 0 else e.w * .7)
	player.warp = {"e": e, "ph": "in", "t": 0, "mode": mode, "cx": cx}
	player.vx = 0.0
	player.vy = 0.0
	player.run = 0
	player.puff = false
	player.slam = false
	keys.clear()
	Audio.play("climb", -6)

func _warp_step() -> void:
	var w: Dictionary = player.warp
	w.t += 1
	var t: int = w.t
	player.vx = 0.0
	player.vy = 0.0
	if w.ph == "in":
		match w.mode:
			"up":
				# sobe pela luz da saída e some
				player.wpose = "climb"
				player.climbA += 4
				player.wdy = -t * 2.4
				player.wal = clamp(1.0 - t / 22.0, 0, 1)
				if t >= 24:
					_warp_jump()
			"door":
				player.wpose = ""
				var dx: float = w.cx - (player.x + player.w / 2)
				player.x += clamp(dx, -2.2, 2.2)
				player.anim += .1
				player.face = 1 if dx >= 0 else -1
				player.wal = clamp(1.0 - (t - 8) / 16.0, 0, 1)
				if t >= 26:
					_warp_jump()
			_:
				# anda até a boca, se abaixa e entra engatinhando, sumindo na sombra
				var dx2: float = w.cx - (player.x + player.w / 2)
				if t <= 12 and abs(dx2) > 1.5:
					player.wpose = ""
					player.x += clamp(dx2, -2.6, 2.6)
					player.anim += .12
					player.face = 1 if dx2 > 0 else -1
				elif t <= 20:
					player.wpose = "crouch"
				else:
					player.wpose = "crawl"
					var u: float = (t - 20) / 22.0
					var dd: int = int(w.e.get("dir", 0))
					if dd != 0:
						# entra engatinhando pela boca do tronco
						player.face = dd
						player.x += dd * 1.5
						player.wdy = u * 4
					else:
						player.wdy = u * 30
					player.wal = clamp(1.0 - u, 0, 1)
					if t % 5 == 0:
						PARTS.append({"x": w.cx + (rng.randf() - .5) * 30, "y": w.e.y + 2, "vx": (rng.randf() - .5) * 2, "vy": -1.5 - rng.randf(), "life": 18, "col": Color(.6, .5, .32, .8)})
				if t >= 42:
					_warp_jump()
	else:
		var from_below: bool = w.mode == "up"
		match w.mode:
			"door":
				player.wpose = ""
				player.wdy = 0.0
				player.wal = clamp(t / 16.0, 0, 1)
				if t >= 18:
					_warp_end()
			_:
				var u2: float = clamp(t / 22.0, 0, 1)
				player.wal = u2
				var od: int = int(w.e.get("odir", 0))
				if from_below and od != 0:
					# sai engatinhando pela boca do tronco, levanta e sacode a poeira
					player.face = od
					if t <= 22:
						player.x += od * 1.4
					player.wdy = 0.0
					player.wpose = "crawl" if t < 22 else ("crouch" if t < 30 else "")
				elif from_below:
					player.wdy = (1.0 - u2) * 30
					player.wpose = "crawl" if t < 22 else ("crouch" if t < 30 else "")
				else:
					# cai do buraco para dentro do esconderijo
					player.wdy = -(1.0 - u2) * (1.0 - u2) * 40
					player.wpose = "crouch" if t < 28 else ""
				if t == 30:
					player.squash = .5
					fx("fx_dust", player.x + player.w / 2, player.y + player.h - 6, 18, .12, -.2)
					burst(player.x + player.w / 2, player.y + 6, 8, Color(.75, .65, .45, .9))
					Audio.play("slide", -12)
				if t >= 36:
					_warp_end()

func _warp_jump() -> void:
	var w: Dictionary = player.warp
	var e: Dictionary = w.e
	if e.get("mode", "") == "door" and X.dog_free() and X.DOG.st in ["follow", "sit", "stay"]:
		X.DOG.st = "door"
	player.x = e.to[0] - player.w / 2 - int(e.get("odir", 0)) * 31
	player.y = e.to[1] - player.h
	_rest_player()
	w.ph = "out"
	w.t = 0
	iris_t = 30
	Audio.play("door")
	snap_camera()
	if e.get("label", "") != "":
		flash(e.label)

## pousa o Tomé no chão mais próximo do ponto de chegada
func _rest_player() -> void:
	var feet: float = player.y + player.h
	var best := INF
	for s in blockers():
		if player.x + player.w > s.x and player.x < s.x + s.w and s.y >= feet - 30 and s.y < best:
			best = s.y
	if best < INF and best - feet < 80:
		player.y = best - player.h
		player.onGround = true

func _warp_end() -> void:
	player.warp = {}
	player.wdy = 0.0
	player.wal = 1.0
	player.wpose = ""
	player.iframe = max(player.iframe, 10)

# ======================================================================
#  COLISÃO
# ======================================================================
func move_x(dx: float) -> void:
	player.x += dx
	for s in blockers():
		if s.get("oneway") or not hit(player, s):
			continue
		if s.get("crate") and dx != 0 and M.try_push(s, dx):
			if not hit(player, s):
				continue
		# degrau baixo: sobe sozinho
		if player._g and not s.get("crate") and (player.y + player.h) - s.y <= 12 and (player.y + player.h) - s.y > 0:
			player.y = s.y - player.h
			continue
		# ajuda na quina: no ar, descendo ou no alto do pulo, com os pés só um pouco abaixo do topo
		if player._g == null and player.coyote <= 0 and not player.ladder and player.vy > -1.5 and (player.y + player.h) - s.y <= 10 and (player.y + player.h) - s.y > 0:
			player.y = s.y - player.h
			continue
		if dx > 0:
			player.x = s.x - player.w
		elif dx < 0:
			player.x = s.x + s.w
		else:
			player.x = s.x - player.w if (player.x + player.w / 2 < s.x + s.w / 2) else s.x + s.w
		player.vx = 0
		player.run = 0

func move_y(dy: float) -> void:
	var prev_feet: float = player.y + player.h
	player.y += dy
	player._g = null
	for s in blockers():
		if not hit(player, s):
			continue
		if s.get("oneway"):
			if dy > 0 and not (player.dropT > 0) and not player.ladder and prev_feet <= s.y + 1 + (2 if s.get("lily") else 0):
				player.y = s.y - player.h
				_land(s)
			continue
		if dy > 0:
			if s.get("crate") and s.t == "break" and (player.vy > 1 or player.slam):
				break_crate(s)
				if not player.slam:
					player.vy = -7
					player.cutOk = false
				continue
			player.y = s.y - player.h
			_land(s)
		elif dy < 0:
			if not s.get("crate"):
				var ol: float = (player.x + player.w) - s.x
				var orr: float = (s.x + s.w) - player.x
				if ol <= 8:
					player.x = s.x - player.w
					continue
				if orr <= 8:
					player.x = s.x + s.w
					continue
			player.y = s.y + s.h
			player.vy = 0

func _land(s: Dictionary) -> void:
	player.launchT = 0
	player.onGround = true
	player.coyote = COY
	player.airJumps = 0 if player.get("dog") else 1
	player.lastWall = 0
	player._g = s
	player.vy = 0

# ======================================================================
#  FASE 1: antes e depois da física
# ======================================================================
func _p1_pre(pcx: float) -> void:
	if player.ladderCD > 0:
		player.ladderCD -= 1
	if player.dropT > 0:
		player.dropT -= 1
	# entradas de esconderijo
	var nearE = null
	for e in ENTR:
		if player.onGround and not player.dog and pcx > e.x and pcx < e.x + e.w and abs(player.y + player.h - (e.y + e.h)) < 16:
			nearE = e
	var door_up: bool = nearE != null and (nearE.get("exit") or nearE.get("mode", "") == "door") and keys.get("Up", false)
	if nearE and ((keys.get("Sp", false) and nearE.get("mode", "") != "door") or door_up) and not player.ladder:
		keys.Sp = false
		keys.Up = false
		start_warp(nearE)
	player.nearE = nearE
	# agarrar escada / rede / corda
	var z = null
	for c in CLIMB:
		if pcx > c.x - 6 and pcx < c.x + c.w + 6 and player.y + player.h > c.y - 2 and player.y < c.y + c.h:
			z = c
			break
	if not player.ladder and z and not player.vine and player.ladderCD <= 0 and not player.dog:
		var at_top: bool = player.onGround and abs(player.y + player.h - z.y) < 6
		if (kd("U") and not at_top) or (kd("S") and at_top):
			stand_up()
			player.ladder = z
			player.vx = 0
			player.vy = 0
			player.slam = false
			player.puff = false
			player.run = 0
			player.airJumps = 1
			if at_top:
				player.y += 8
				player.dropT = 10
	if player.ladder:
		var l2: Dictionary = player.ladder
		if not (pcx > l2.x - 10 and pcx < l2.x + l2.w + 10 and player.y + player.h > l2.y - 4 and player.y < l2.y + l2.h + 4):
			player.ladder = null
	# abaixar / deslizar
	var wantC: bool = player.onGround and kd("S") and not player.ladder and nearE == null and not player.vine and not player.dog
	# passagem baixa à frente: o jogador precisa segurar ↓ (só avisa, não abaixa sozinho)
	var mdir := -1 if (kd("L") and not kd("R")) else (1 if (kd("R") and not kd("L")) else 0)
	if player.onGround and not player.crouch and not player.ladder and not player.vine and not player.swim and not player.dog and mdir != 0 and X.crawl_auto(mdir):
		tip("Passagem baixa: segure ↓ para se abaixar e passar.")
	if wantC and not player.crouch:
		player.crouch = true
		player.y += 14
		player.h = 20
		if abs(player.vx) > 3.1:
			player.slideT = 1
			Audio.play("slide")
			fx("fx_dust", pcx, player.y + player.h - 4, 16, .14, -.2)
	elif player.crouch and not wantC and not player.slideT:
		stand_up()
	# olhar para cima / para baixo
	var still: bool = player.onGround and abs(player.vx) < .4 and not kd("L") and not kd("R") and not player.ladder
	if still and kd("U") and z == null:
		player.lookT += 1
	elif still and player.crouch:
		player.lookT -= 1
	else:
		player.lookT = 0
	var tgt := -150.0 if player.lookT > 28 else (150.0 if player.lookT < -40 else 0.0)
	look_y += (tgt - look_y) * .08

func _p1_ladder() -> void:
	var z: Dictionary = player.ladder
	player.puff = false
	player.slam = false
	player.onGround = false
	var sp := 2.6
	player.vy = -sp if kd("U") else (sp if kd("S") else 0.0)
	if z.kind == "net":
		player.vx = -2.2 if kd("L") else (2.2 if kd("R") else 0.0)
	elif (kd("L") or kd("R")) and not kd("U") and not kd("S"):
		player.ladder = null
		player.ladderCD = 12
		player.vx = -2.4 if kd("L") else 2.4
		player.vy = 0
		return
	else:
		player.vx = 0
		player.x += ((z.x + z.w / 2) - (player.x + player.w / 2)) * .3
	if kd("L"):
		player.face = -1
	if kd("R"):
		player.face = 1
	if (player.vy != 0 or player.vx != 0) and T % 14 == 0:
		Audio.play("climb", -10)
	player.climbA += abs(player.vy) + abs(player.vx)
	if pressed("J"):
		player.ladder = null
		player.ladderCD = 14
		player.vy = JUMP * .82
		player.vx = (-1 if kd("L") else (1 if kd("R") else 0)) * 3.6
		player.cutOk = true
		player.airJumps = 1
		Audio.play("jump", -6)
	elif player.y + player.h < z.y + 3 and kd("U"):
		var ty: float = z.get("topY", z.y)
		var nx: float = z.get("topX", player.x)
		var sup_at = func(x: float) -> bool:
			for s in blockers():
				if x + player.w > s.x + 2 and x < s.x + s.w - 2 and abs(s.y - ty) < 8:
					return true
			return false
		var nx2 = null
		var sides: Array = [z.x + z.w + 1, z.x - player.w - 1] if player.face > 0 else [z.x - player.w - 1, z.x + z.w + 1]
		if sup_at.call(nx):
			nx2 = nx
		elif not z.has("topX"):
			for c in sides:
				if sup_at.call(c):
					nx2 = c
					break
		if nx2 != null:
			player.ladder = null
			player.ladderCD = 12
			player.x = nx2
			player.y = ty - player.h - 1
			player.vy = 0
			player.squash = .3
		else:
			player.vy = 0
			player.y = z.y - player.h + 3
			if T % 90 == 0:
				tip("Topo da escada: pule para o lado (PULAR + ← ou →).")

func _p1_post(pcx: float, _pcy: float) -> void:
	if player.ladder and player.onGround and kd("S"):
		player.ladder = null
	# vitórias-régias afundam
	for p in LILY:
		if p.st == 0:
			if player._g == p:
				p.t += 1
				if p.t > 50:
					p.st = 1
			else:
				p.t = max(0, p.t - 1)
			p.y = p.y0 + sin(T * .05 + p.x) * 1.5 + (p.t * .08 if p.t > 0 else 0.0)
		elif p.st == 1:
			p.y += .9
			if p.y > p.y0 + 26:
				p.st = 2
				p.tm = 150
				Audio.play("splash")
		else:
			p.tm -= 1
			if p.tm <= 0:
				p.st = 0
				p.t = 0
				p.y = p.y0
	# brejo
	for s in SWAMP:
		if s.get("drain") and s.y < s.y2:
			s.y = min(s.y2, s.y + 1.2)
		if player.y + player.h > s.y + 14 and player.y < s.y0 + s.h and pcx > s.x and pcx < s.x + s.w and player.dyingT == 0:
			Audio.play("splash")
			burst(pcx, s.y, 14, Color("#9ab08a"))
			die("Você afundou no brejo.")
			return
	# itens, pistas, lápis especiais
	for it in ITEMS:
		if not it.got and hit(player, R(it.x - 20, it.y - 20, 40, 40)):
			it.got = true
			give_item(it.id)
			burst(it.x, it.y, 18, Color("#ffe9a0"))
	for c in CLUES:
		if not c.got and hit(player, R(c.x - 20, c.y - 20, 40, 40)):
			c.got = true
			CLUEGOT[int(c.id)] = 1
			Save.setv("gallery", "c%d" % int(c.id), true)
			Audio.play("clue")
			Audio.vib(80)
			clue_opened.emit(int(c.id))
	for s in SPECS:
		if not s.got and hit(player, R(s.x - 20, s.y - 22, 40, 44)):
			s.got = true
			SPECGOT[s.c] = 1
			Audio.play("special")
			Audio.vib(30)
			burst(s.x, s.y, 22, GameData.PEN_COL[s.c])
			flash("Lápis especial " + s.c.to_upper() + "! (%d/6)" % SPECGOT.size())
	# usar perto de um obstáculo
	var nearL = null
	for l in LOCKS:
		if not l.done and not player.dog and hit(player, R(l.x - 40, l.y - 40, l.w + 80, l.h + 80)):
			nearL = l
			break
	player.nearL = nearL
	if nearL and keys.get("Ap", false):
		keys.Ap = false
		if X.boss_active():
			flash("Agora não dá: o javali está em cima de você!", 120)
		elif has_item(nearL.need):
			use_lock(nearL)
		else:
			flash(lock_msg(nearL), 260)
			Audio.vib(15)
	X.post()
	M.post()
	PR.post()
	TR.post()
	K.post()
	NT.post()
	RD.post()
	ZN.post()
	# vilão foge
	if VIL:
		if not VIL.go and pcx > VIL.trig and pcx < L.spanX:
			VIL.go = true
			start_cine("vargas", VIL.x - 40, VIL.y - 40, 300,
				[[44, 135, "VARGAS", "Desista, Tomé! Quem mandou abrir a boca sobre o dinheiro da mina?", "vargas"],
				[135, 205, "ISIS", "PAPAI! ME AJUDA!", "lia"],
				[205, 290, "TOMÉ", "Aguenta firme, filha! Eu vou te buscar!", "tome"]],
				[8, 44, "ADEMAR VARGAS", "o gerente ladrão"])
		if VIL.go and not VIL.gone:
			if VIL.get("chase"):
				# perseguição: o carrinho fica sempre um pouco à frente (nunca dá para alcançar)
				var d: float = VIL.x - pcx
				var v: float = clamp(2.4 + (420.0 - d) * .02, 1.0, 6.8)
				VIL.x += v
				VIL.spd = v
				VIL.coal_t = VIL.get("coal_t", 70) - 1
				if VIL.coal_t <= 0 and d > 140 and d < 720 and not no_coal and player.dyingT == 0:
					VIL.coal_t = 80 + rng.randi() % 50
					COAL.append({"x": VIL.x - 40, "y": VIL.y - 74, "vx": -(2.6 + rng.randf() * 1.6), "vy": -5.5 - rng.randf() * 1.5, "b": 0, "life": 260, "rot": 0.0})
					Audio.play("slide", -6)
					note("Cuidado: o Vargas está jogando carvão em brasa!")
					Audio.play("stomp", -10)
			else:
				VIL.x += 3.3
			if VIL.x > VIL.gateX:
				VIL.gone = true
				burst(VIL.gateX, VIL.y - 30, 20, Color("#ffd28a"))
				Audio.play("door", -4)
				shake = 6
	_update_coal()
	ambient()
	# raio na tempestade
	if AMB.rain > .6:
		thunder_t -= 1
		if thunder_t <= 0:
			thunder_t = 320 + rng.randi() % 420
			lightning = 10
			thunder_snd = 18 + rng.randi() % 42
	if thunder_snd > 0:
		thunder_snd -= 1
		if thunder_snd == 0:
			Audio.play("thunder", -4)
	if lightning > 0:
		lightning -= 1

func _update_coal() -> void:
	for c in COAL:
		c.vy += .35
		c.x += c.vx
		c.y += c.vy
		c.rot += c.vx * .08
		c.life -= 1
		if T % 3 == 0:
			c.gy = _rest_y(c.x, c.y, 500)
		if not c.get("k", "") in ["dirt", "acorn"] and T % 2 == 0:
			PARTS.append({"x": c.x, "y": c.y, "vx": -c.vx * .2 + (rng.randf() - .5), "vy": -.5 - rng.randf(), "life": 14, "col": Color(1, .55 + rng.randf() * .3, .15)})
		for s in SOL:
			if s.get("oneway"):
				continue
			if c.x > s.x and c.x < s.x + s.w and c.y + 7 >= s.y and c.y + 7 <= s.y + 20 and c.vy > 0:
				c.y = s.y - 7
				if c.get("k", "") in ["dirt", "acorn"]:
					c.life = 0
					burst(c.x, c.y + 4, 10, Color("#7a5a3a"))
					break
				if c.b < 1:
					c.vy = -c.vy * .45
					c.b += 1
					burst(c.x, c.y + 6, 4, Color(.3, .3, .32))
				else:
					c.vy = 0
					c.vx *= .97
		if c.get("ref"):
			for e in EN:
				if not e.dead and hit(R(c.x - 11, c.y - 11, 22, 22), ebox(e)):
					kill_enemy(e, "hit")
					c.life = 0
			continue
		if c.life > 0 and player.dyingT == 0 and hit(player, R(c.x - 11, c.y - 11, 22, 22)) and M.blocks(c.x - c.vx * 10):
			M.reflect(c)
			continue
		if c.life > 0 and player.dyingT == 0 and hit(player, R(c.x - 11, c.y - 11, 22, 22)):
			hurt(1, c.x - c.vx * 10)
			c.life = 0
			burst(c.x, c.y, 10, Color(.25, .25, .27) if not c.get("k", "") in ["dirt", "acorn"] else Color("#7a5a3a"))
	COAL = COAL.filter(func(c): return c.life > 0 and c.y < L.bottom)

func use_lock(l: Dictionary) -> void:
	l.done = true
	INV.erase(l.need)
	Audio.play("unlock")
	Audio.vib(120)
	shake = 8
	if l.kind == "hook":
		player.act = "throw2"
		player.actT = 36
		CLIMB.append({"x": l.ring[0] - 10, "y": l.ring[1], "w": 20, "h": l.ground - l.ring[1], "kind": "rope", "topX": l.topX, "topY": l.topY})
		flash("O gancho prendeu na argola! Suba pela corda (↑).")
	elif l.kind == "dam":
		for s in SWAMP:
			if s.get("id") == l.water:
				s.drain = true
		SOL = SOL.filter(func(s): return s.get("id") != l.gate)
		flash("A comporta abriu! A água está baixando...")
	elif l.kind == "dark":
		INV.append("lanterna_acesa")
		SOL = SOL.filter(func(s): return s.get("id") != l.barrier)
		lantern_lit = true
		flash("A lanterna brilha forte de novo. Agora dá para entrar no túnel.")

# ======================================================================
#  INIMIGOS, DANO E MORTE
# ======================================================================
func ebox(e: Dictionary) -> Dictionary:
	if e.k == "plant":
		if e.dead or e.stun > 0:
			return R(-9999, -9999, 0, 0)
		return TR.plant_box(e)
	if e.k == "spider":
		return R(e.x - 16, e.y - 14, 32, 28)
	if e.k == "mole":
		if e.dead:
			return R(-9999, -9999, 0, 0)
		if e.get("st", 0) in [2, 3]:
			return R(e.x - 18, e.base - 30, 36, 30)
		if e.get("st", 0) == 5:
			return R(e.x - 22, e.base - 22, 44, 22)
		return R(-9999, -9999, 0, 0)
	if e.k == "bat" and e.get("st", 0) == 0:
		return R(e.x - 12, e.y - 2, 24, 26)
	if e.k == "leech":
		if e.get("hid", true) or e.dead:
			return R(-9999, -9999, 0, 0)
		return R(e.x - 16, e.y - 40, 32, 40)
	if FLY.has(e.k):
		return R(e.x - 22, e.y - 8, 44, 22)
	return R(e.x - 20, e.y - 34, 40, 34)

func update_enemy(e: Dictionary) -> void:
	if e.stun > 0:
		e.stun -= 1
		return
	if e.k == "plant":
		TR.plant_update(e)
		return
	if e.k == "squirrel":
		NT.squirrel(e)
		return
	if e.k == "crow":
		_crow(e)
		return
	if e.k == "piranha":
		_piranha(e)
		return
	if e.k == "leech":
		e.lt = e.get("lt", e.get("ph", 0)) + 1
		var t: int = int(e.lt) % 200
		e.hid = t < 95 or t >= 188
		e.y = e.base
		e.dir = 1 if player.x > e.x else -1
		if t == 95 and abs(player.x - e.x) < 600:
			Audio.play("splash", -8)
		return
	if e.k == "frog":
		e.jt = e.get("jt", 0) + 1
		var t: int = int(e.jt) % 130
		if t == 100:
			var dx: float = player.x - e.x
			e.jdir = (sign(dx) if dx != 0 else 1) if abs(dx) < 300 else (1 if e.x < (e.r[0] + e.r[1]) / 2.0 else -1)
		if t >= 100:
			var u := (t - 100) / 30.0
			e.leap = 1
			e.dir = e.jdir
			e.x = clamp(e.x + e.jdir * 2.6, e.r[0], e.r[1])
			e.y = e.base - sin(u * PI) * 80
		else:
			e.leap = 0
			e.y = e.base
		return
	if e.k == "bat":
		_bat(e)
		return
	if e.k == "spider":
		_spider(e)
		return
	if e.k == "mole":
		_mole(e)
		return
	if e.k == "owl":
		var st: int = e.get("st", 0)
		if st != 3 and X.scare(e.x, e.y):
			e.st = 3
			e.t = 0
			e.dir = -1 if player.x + player.w / 2 > e.x else 1
			Audio.play("dj", -8)
			return
		if st == 3:
			e.t += 1
			e.x = clamp(e.x + e.dir * 2.4, e.r[0], e.r[1])
			e.y -= 2.2 if e.t < 60 else 0.0
			if e.t > 220:
				e.st = 2
				e.t = 0
			return
		if st == 0:
			e.st = 0
			e.y = e.cy + sin(T * .05) * 3
			var dx: float = player.x + player.w / 2 - e.x
			if abs(dx) < 240 and player.y > e.y - 10 and player.dyingT == 0:
				e.st = 1
				e.t = 0
				e.sx = e.x
				e.sy = e.y
				e.tx = player.x + player.w / 2
				e.ty = player.y + 10
				e.dir = sign(dx) if dx != 0 else 1
		elif st == 1:
			e.t += 1
			var u: float = e.t / 80.0
			e.x = clamp(e.sx + (e.tx - e.sx) * min(1, u * 1.6), e.r[0], e.r[1])
			e.y = e.sy + (e.ty - e.sy) * sin(min(1, u) * PI)
			if e.t >= 80:
				e.st = 2
				e.t = 0
		else:
			e.t += 1
			e.x += (e.sx - e.x) * .04
			e.y += (e.cy - e.y) * .06
			if e.t > 140:
				e.st = 0
		return
	if FLY.has(e.k):
		e.x += e.dir * 1.8
		if e.x < e.r[0]:
			e.x = e.r[0]
			e.dir = 1
		if e.x > e.r[1]:
			e.x = e.r[1]
			e.dir = -1
		e.y = e.cy + sin(T * .05 + e.x * .02) * 30
		return
	# javali (anda e investe)
	var spd := 1.1
	if e.k == "boar":
		var dx2: float = player.x + player.w / 2 - e.x
		var dy2: float = player.y + player.h - e.base
		e.charge = abs(dx2) < 230 and abs(dy2) < 40 and dx2 * e.dir > 0
		if e.charge:
			spd = 2.7
	e.x += e.dir * spd
	if e.x < e.r[0]:
		e.x = e.r[0]
		e.dir = 1
	if e.x > e.r[1]:
		e.x = e.r[1]
		e.dir = -1
	e.y = e.base

## corvo: voa de um lado a outro e dá rasantes quando o Tomé passa embaixo
func _crow(e: Dictionary) -> void:
	var st: int = e.get("st", 0)
	var pc := Vector2(player.x + player.w / 2, player.y + player.h / 2)
	e.t = e.get("t", 0) + 1
	if st == 0:
		e.x += e.dir * 2.2
		if e.x < e.r[0]:
			e.x = e.r[0]
			e.dir = 1
		if e.x > e.r[1]:
			e.x = e.r[1]
			e.dir = -1
		e.y = e.cy + sin(T * .06 + e.x * .01) * 16
		if abs(pc.x - e.x) < 230 and pc.y > e.y + 40 and e.t > (160 if e.get("minion") else 90) and player.dyingT == 0:
			e.st = 1
			e.t = 0
			e.sx = e.x
			e.sy = e.y
			e.tx = pc.x + player.vx * 14
			e.ty = pc.y
			e.dir = 1 if e.tx > e.x else -1
			Audio.play("dj", -12)
	else:
		var u: float = e.t / 56.0
		e.x = clamp(e.sx + (e.tx - e.sx) * u * 1.6, e.r[0], e.r[1])
		e.y = e.sy + (e.ty - e.sy) * sin(min(1.0, u) * PI)
		if e.t >= 56:
			e.st = 0
			e.t = 0
			e.cy = e.get("base", e.cy)

## piranha: patrulha a água e dá botes quando o Tomé chega perto
func _piranha(e: Dictionary) -> void:
	var pc := Vector2(player.x + player.w / 2, player.y + player.h / 2)
	var d: Vector2 = pc - Vector2(e.x, e.y)
	if d.length() < 170 and player.swim and player.dyingT == 0:
		e.dir = 1 if d.x > 0 else -1
		e.x = clamp(e.x + sign(d.x) * 2.6, e.r[0], e.r[1])
		e.y += clamp(d.y, -1.6, 1.6)
	else:
		e.x += e.dir * 1.3
		if e.x < e.r[0]:
			e.x = e.r[0]
			e.dir = 1
		if e.x > e.r[1]:
			e.x = e.r[1]
			e.dir = -1
		e.y = lerpf(e.y, e.cy + sin(T * .05 + e.x * .02) * 26, .05)

## morcego: dorme pendurado; acorda quando o Tomé chega perto e foge da luz
func _bat(e: Dictionary) -> void:
	var st: int = e.get("st", 0)
	var pc := Vector2(player.x + player.w / 2, player.y + player.h / 2)
	e.cd = max(0, e.get("cd", 0) - 1)
	if st == 0:
		e.y = e.cy
		if e.cd == 0 and pc.distance_to(Vector2(e.x, e.y)) < 230 and player.dyingT == 0:
			e.st = 1
			e.t = 0
			Audio.play("dj", -12)
	elif st == 1:
		e.t += 1
		var to := (pc - Vector2(e.x, e.y))
		var v := to.normalized() * 2.3 + Vector2(0, sin(e.t * .25) * 2.2)
		e.x = clamp(e.x + v.x, e.r[0], e.r[1])
		e.y = clamp(e.y + v.y, e.cy, e.cy + 260)
		e.dir = 1 if v.x > 0 else -1
		if X.lit(e.x, e.y, 95.0) or X.scare(e.x, e.y) or e.t > 420:
			e.st = 2
			e.t = 0
	else:
		e.t += 1
		var home := Vector2(e.x0, e.cy)
		var d := home - Vector2(e.x, e.y)
		if d.length() < 4:
			e.x = e.x0
			e.y = e.cy
			e.st = 0
			e.cd = 150
		else:
			var v2 := d.normalized() * 3.6
			e.x += v2.x
			e.y += v2.y
			e.dir = 1 if v2.x > 0 else -1

## aranha: desce do teto num fio quando o Tomé passa por baixo
func _spider(e: Dictionary) -> void:
	var st: int = e.get("st", 0)
	var top: float = e.top + 26
	var low: float = e.base - 22
	e.cd = max(0, e.get("cd", 0) - 1)
	if st == 0:
		e.y = top + sin(T * .05 + e.x) * 3
		if e.cd == 0 and abs(player.x + player.w / 2 - e.x) < 70 and player.y > e.y and player.dyingT == 0:
			e.st = 1
	elif st == 1:
		e.y = min(low, e.y + 5.0)
		if e.y >= low:
			e.st = 2
			e.t = 0
	elif st == 2:
		e.t += 1
		if e.t > 55:
			e.st = 3
	else:
		e.y -= 1.6
		if e.y <= top:
			e.st = 0
			e.cd = 70
	e.dir = 1 if player.x > e.x else -1

## toupeira: anda escondida debaixo da terra (não dá para pisar), salta perto do Tomé,
## joga um torrão de terra e mergulha de novo. A de capacete só cai se o Pipoca puxá-la para fora.
func _mole(e: Dictionary) -> void:
	var st: int = e.get("st", 0)
	e.t = e.get("t", 0) + 1
	e.y = e.base
	var dx: float = player.x + player.w / 2 - e.x
	match st:
		0:
			if e.get("cd", 0) > 0:
				e.cd -= 1
			var dirm: int = (1 if dx > 0 else -1) if abs(dx) < 380 else int(e.dir)
			e.dir = dirm
			e.x = clamp(e.x + dirm * 1.4, e.r[0], e.r[1])
			if e.x <= e.r[0] or e.x >= e.r[1]:
				e.dir = -e.dir
			if abs(dx) < 120 and e.get("cd", 0) == 0 and abs(player.y + player.h - e.base) < 80:
				e.st = 1
				e.t = 0
		1:
			if e.t % 4 == 0:
				PARTS.append({"x": e.x + (rng.randf() - .5) * 26, "y": e.base - 2, "vx": (rng.randf() - .5) * 3, "vy": -2 - rng.randf() * 2, "life": 18, "col": Color("#7a5a3a")})
			if e.t > 26:
				e.st = 2
				e.t = 0
				e.dir = 1 if dx > 0 else -1
				Audio.play("stomp", -12)
		2:
			if e.t == 16 and abs(dx) < 360:
				var vx: float = clamp(dx / 38.0, -5.5, 5.5)
				COAL.append({"x": e.x + e.dir * 10, "y": e.base - 34, "vx": vx, "vy": -7.0, "b": 1, "life": 200, "rot": 0.0, "k": "dirt"})
				Audio.play("slide", -8)
			if e.t > 62:
				e.st = 3
				e.t = 0
		3:
			if e.t > 14:
				e.st = 0
				e.t = 0
				e.cd = 70
		5:
			# puxada para fora pelo Pipoca: de barriga para cima, tonta
			if e.t > 180:
				e.st = 3
				e.t = 0
		6:
			pass

func kill_enemy(e: Dictionary, how: String = "") -> void:
	if e.dead:
		return
	e.dead = 1
	e.dk = "flat" if (how == "stomp" and not FLY.has(e.k)) else "flip"
	e.ddy = 0.0
	e.dvy = -6.0
	burst(e.x, e.y - 12, 14, Color("#ccbbbb"))
	shake = max(shake, 5)
	hit_stop = 5 if how == "stomp" else 3
	Audio.play("stomp")
	Audio.vib(20)
	fx("fx_dust", e.x, e.y - 10, 18, .22)

func gain_coin(x: float, y: float, silent: bool = false) -> void:
	coins += 1
	coin_life += 1
	Audio.play("pen", -8)
	if not silent:
		burst(x, y, 8, Color("#f0cd72"))
		fx("fx_sparkle", x, y, 14, .14)
	if coin_life >= 100:
		coin_life -= 100
		lives += 1
		flash("100 lápis: +1 vida!")
		burst(player.x, player.y, 24, Color("#ffd76a"))

func break_crate(c: Dictionary) -> void:
	c.dead = true
	shake = max(shake, 5)
	fx("fx_pieces", c.x + c.w / 2, c.y + c.h / 2, 20, .35, -.4)
	burst(c.x + c.w / 2, c.y + c.h / 2, 16, Color("#b08a4e"))
	var it: String = c.get("item", "")
	if it == "armor":
		player.armor = 1
		flash("Armadura! Ela aguenta 1 golpe.")
	elif it == "heart":
		if player.hp < MAXHP:
			player.hp += 1
			flash("+1 coração.")
		else:
			for i in 5:
				gain_coin(c.x + c.w / 2, c.y - 10, true)
			flash("Vida cheia: +5 lápis.")
	else:
		var n: int = c.get("n", 0)
		for i in n:
			gain_coin(c.x + c.w / 2, c.y - 10)
		if not shown_crate:
			shown_crate = true
			flash("Caixa ★: +%d lápis." % n)

func hurt(d: int, from_x: float) -> void:
	if player.iframe > 0 or player.dyingT > 0:
		return
	if TR and TR.trapped != null and not player.get("dog"):
		return
	if player.get("dog"):
		M.dog_hurt()
		return
	if M.blocks(from_x):
		M.on_block(from_x)
		player.iframe = 20
		return
	var kb = func():
		player.iframe = 70
		shake = max(shake, 8)
		player.vx = (-1 if player.x + player.w / 2 < from_x else 1) * 5
		player.vy = -6
		player.slam = false
		player.puff = false
		player.cutOk = false
		player.vine = null
		player.vineCD = 20
		player.run = 0
		player.ladder = null
	if player.armor > 0:
		player.armor -= 1
		kb.call()
		burst(player.x + player.w / 2, player.y + player.h / 2, 14, Color("#c8d0dc"))
		flash("A armadura aguentou o golpe!")
		return
	player.hp -= d
	kb.call()
	Audio.play("hurt")
	Audio.vib(60)
	burst(player.x + player.w / 2, player.y + player.h / 2, 12, Color("#e07a6a"))
	if player.hp <= 0:
		die("Sem forças.")

func die(msg: String) -> void:
	if player.dyingT > 0 or not running:
		return
	if player.get("dog"):
		M.dog_hurt()
		return
	lives -= 1
	shake = 14
	burst(player.x + player.w / 2, player.y + player.h / 2, 22, Color("#cc5555"))
	Audio.play("die")
	Audio.vib(150)
	player.dieMsg = msg
	player.dyingT = 46
	player.vy = -9
	player.vx = 0
	player.iframe = 0
	player.vine = null
	player.puff = false
	player.slam = false
	player.ladder = null
	hit_stop = 8

func respawn() -> void:
	var msg: String = player.dieMsg
	if lives < 0:
		running = false
		game_over.emit()
		return
	iris_t = 30
	var sx: float = player.spawnX
	var sy: float = player.spawnY
	var armor: int = player.armor
	_reset_player(sx, sy)
	player.armor = armor
	player.iframe = 80
	time_left = int(L.get("time", 180)) * 60
	COAL.clear()
	if VIL and VIL.go and not VIL.gone and VIL.get("chase"):
		VIL.x = min(player.x + 420, VIL.gateX - 10)
	X.boss_reset()
	TR.reset_on_respawn()
	K.reset_on_respawn()
	X.breath = Extras.BREATH
	snap_camera()
	flash(msg + " Vidas: %d" % lives)

# ======================================================================
#  SALVAR
# ======================================================================
func save_checkpoint(k: int) -> void:
	var got_items: Array = []
	for it in ITEMS:
		if it.got:
			got_items.append(it.id)
	var locks: Array = []
	for l in LOCKS:
		locks.append(l.done)
	var coins_got: Array = []
	for c in COINS:
		if c.got:
			coins_got.append(c.ci)
	Save.save_run({"level": level_idx, "chk": k, "lives": lives, "inv": INV.duplicate(), "items": got_items, "locks": locks,
		"clues": CLUEGOT.keys(), "specs": SPECGOT.keys(), "drawn": DRAWN.keys(), "coins": coins_got, "coin_life": coin_life,
		"pen": STATS.pen, "lit": lantern_lit, "fires": CHK.filter(func(c): return c.on).map(func(c): return CHK.find(c)), "time": time_left, "x": X.save_data(), "m": M.save_data(), "tr": TR.save_data(),
		"nt": NT.save_data(), "k": K.save_data(), "rd": RD.save_data(), "rested": RESTED.keys()})

func restore_run(d: Dictionary) -> void:
	## Continua do ponto salvo: refaz a fase no estado da fogueira
	for c in d.get("clues", []):
		CLUEGOT[int(c)] = 1
	for s in d.get("specs", []):
		SPECGOT[s] = 1
	for k in d.get("drawn", []):
		DRAWN[k] = 1
	load_level(int(d.get("level", 0)))
	lives = int(d.get("lives", 3))
	INV = d.get("inv", []).duplicate()
	for it in ITEMS:
		if d.get("items", []).has(it.id):
			it.got = true
	var lk: Array = d.get("locks", [])
	for i in min(lk.size(), LOCKS.size()):
		if lk[i]:
			var l: Dictionary = LOCKS[i]
			var had: bool = INV.has(l.need)
			if not had:
				INV.append(l.need)
			var keep := INV.duplicate()
			use_lock(l)
			if l.kind == "dark":
				INV = keep
			for s in SWAMP:
				if s.get("drain"):
					s.y = s.y2
	shake = 0
	flash_t = 0
	for c in COINS:
		if d.get("coins", []).has(c.ci):
			c.got = true
	coin_life = int(d.get("coin_life", 0))
	STATS.pen = int(d.get("pen", 0))
	lantern_lit = d.get("lit", lantern_lit)
	X.restore(d.get("x", {}))
	M.restore(d.get("m", {}))
	TR.restore(d.get("tr", {}))
	NT.restore(d.get("nt", {}))
	K.restore(d.get("k", {}))
	RD.restore(d.get("rd", {}))
	for r in d.get("rested", []):
		RESTED[int(r)] = 1
	var k: int = int(d.get("chk", -1))
	if d.has("fires"):
		for i in d.fires:
			if int(i) < CHK.size():
				CHK[int(i)].on = true
	elif k >= 0 and k < CHK.size():
		CHK[k].on = true
	cur_chk = k
	if k >= 0 and k < CHK.size():
		_reset_player(CHK[k].x - 12, CHK[k].y - 34)
	snap_camera()
	time_left = int(d.get("time", time_left))
	flash("Você continua da última fogueira.")
