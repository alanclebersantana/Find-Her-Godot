extends RefCounted
class_name Village
## Perigos da vila dos mineiros (Episódio 2) — o motivo para andar pelos telhados:
##  vigias      patrulham a rua com o lampião; se o facho pega o Tomé lá embaixo, ele é levado de
##              volta à última fogueira
##  cães        cães de guarda na rua: correm atrás e mordem (tiram coração)
##  hotchims    chaminés quentes: queimam quem pisa em cima e soltam labaredas de tempos em tempos
##  tilefall    telhas que escorregam de um telhado alto e caem (avisam tremendo antes)
##  awnings     toldos de pano: quem cai em cima é jogado para o alto
## As telhas soltas que despencam quando o Tomé pisa são plataformas "crumble" com "tile".

var g
var no_catch := false   # (só para as fotos de teste)
var caught_n := 0       # quantas vezes o lampião pegou o jogador (para os testes)
var WATCH: Array = []
var DOGS: Array = []
var HOT: Array = []
var TILES: Array = []
var AWN: Array = []
var HIDES: Array = []     # fase da Isis: caixotes e barris; abaixada atrás deles o lampião não a vê
var DROPS: Array = []     # fase da Isis: lápis que ela deixa cair pelo caminho
var CATCH := {}           # fase da Isis: o Vargas a pega no fim do túnel
var told := {}

const CONE_LEN := 270.0
const CONE_ANG := .42

func _init(game) -> void:
	g = game

func load_level() -> void:
	told = {}
	HIDES = g.L.get("hides", []).duplicate(true)
	DROPS = []
	for d in g.L.get("drops", []):
		var o6: Dictionary = d.duplicate(true)
		o6.done = false
		DROPS.append(o6)
	CATCH = {}
	if g.L.has("isisCatch"):
		CATCH = g.L.isisCatch.duplicate(true)
		CATCH.t = -1
	WATCH = []
	for w in g.L.get("watchmen", []):
		var o: Dictionary = w.duplicate(true)
		o.x = float(o.x0) + 20.0
		o.dir = 1
		o.wait = 0
		o.t = 0
		WATCH.append(o)
	DOGS = []
	for d in g.L.get("dogs", []):
		var o2: Dictionary = d.duplicate(true)
		o2.x = float(o2.x)
		o2.x0 = o2.x
		o2.dir = -1
		o2.st = "idle"
		o2.t = 0
		o2.bark = 0
		DOGS.append(o2)
	HOT = []
	for h in g.L.get("hotchims", []):
		var o3: Dictionary = h.duplicate(true)
		HOT.append(o3)
	TILES = []
	for t in g.L.get("tilefall", []):
		var o4: Dictionary = t.duplicate(true)
		o4.y = float(o4.y0)
		o4.vy = 0.0
		o4.st = "wait"
		o4.t = int(o4.get("ph", 0))
		TILES.append(o4)
	AWN = []
	for a in g.L.get("awnings", []):
		var o5: Dictionary = a.duplicate(true)
		o5.sq = 0.0
		var s := {"t": "awning", "x": float(a.x), "y": float(a.y), "w": float(a.w), "h": 12.0, "oneway": 1, "awn": o5}
		g.SOL.append(s)
		o5.sol = s
		AWN.append(o5)

## fase da labareda da chaminé quente: 0 = calma, 1 = aviso (faíscas), 2 = fogo
func hot_phase(h: Dictionary) -> int:
	var per: int = int(h.get("per", 200))
	var u: float = float((g.T + int(h.get("ph", 0))) % per) / per
	if u < .55:
		return 0
	if u < .75:
		return 1
	return 2

func _street(p: Dictionary) -> bool:
	return p.y + p.h > 430.0

func pre() -> void:
	# portões que estão abrindo devagar (porteira destrancada com a chave)
	if g.M:
		for gt in g.M.GATES:
			if gt.get("unlocking") and float(gt.open) < 1.0:
				gt.open = move_toward(float(gt.open), 1.0, .012)
				g.blockers_dirty()
				if g.T % 10 == 0:
					Audio.play("door", -12, .8)
					g.burst(float(gt.x) + 10, float(gt.y) + float(gt.h) - float(gt.open) * float(gt.h), 4, Color(.6, .5, .4))

func post() -> void:
	var p: Dictionary = g.player
	if p.dyingT > 0 or not g.running:
		return
	if p.get("isis"):
		isis_step()
		if not g.running or int(CATCH.get("t", -1)) >= 0:
			return
	var pc := Vector2(p.x + p.w / 2, p.y + p.h / 2)
	# vigias
	for w in WATCH:
		w.t += 1
		if w.wait > 0:
			w.wait -= 1
			if w.wait == 0:
				w.dir = -w.dir
		else:
			w.x += w.dir * float(w.get("spd", 1.1))
			if w.x > float(w.x1) or w.x < float(w.x0):
				w.x = clamp(w.x, float(w.x0), float(w.x1))
				w.wait = 70
		if (w.get("any") or _street(p)) and p.iframe == 0 and not no_catch and not p.get("dog") and not hidden(p) and in_cone(w, pc):
			_caught(w)
			return
	# cães de guarda
	for d in DOGS:
		d.t += 1
		if d.bark > 0:
			d.bark -= 1
		var near: bool = _street(p) and abs(pc.x - d.x) < 300 and pc.x > float(d.r[0]) - 60 and pc.x < float(d.r[1]) + 60
		if near:
			if d.st != "chase":
				d.st = "chase"
				Audio.play("bark", -4)
				d.bark = 30
				if not told.has("dog"):
					told.dog = 1
					g.tip("Cão de guarda! Volte para cima pela escada ou pelo toldo.", 180)
			d.dir = 1 if pc.x > d.x else -1
			d.x = clamp(d.x + d.dir * 3.3, float(d.r[0]), float(d.r[1]))
			if g.T % 40 == 0:
				Audio.play("bark", -8)
				d.bark = 20
		else:
			d.st = "idle"
			d.x = move_toward(d.x, float(d.x0) + sin(d.t * .01) * 60.0, .8)
		if Game.hit(p, g.R(d.x - 22, 500 - 30, 44, 30)) and p.iframe == 0:
			g.hurt(1, d.x)
			Audio.play("bark", -2)
	# chaminés quentes
	var gs = p.get("_g")
	if gs is Dictionary and gs.get("hot") and p.onGround and p.iframe == 0:
		g.hurt(1, p.x + p.w / 2 - p.face * 20)
		p.vy = -8.5
		g.burst(p.x + p.w / 2, p.y + p.h, 10, Color(1, .5, .1))
		if not told.has("hot"):
			told.hot = 1
			g.tip("Chaminé quente! Pule por cima — e plane na fumaça para ir mais longe.", 200)
	for h in HOT:
		if hot_phase(h) == 2 and p.iframe == 0:
			var fx: float = float(h.x)
			if Game.hit(p, g.R(fx - 4, float(h.y) - 150, float(h.w) + 8, 150)):
				g.hurt(1, fx + float(h.w) / 2)
				p.vy = min(p.vy, -6.0)
	# telhas caindo
	for t in TILES:
		t.t += 1
		match t.st:
			"wait":
				if t.t >= int(t.get("per", 170)):
					t.st = "shake"
					t.t = 0
			"shake":
				if t.t >= 34:
					t.st = "fall"
					t.t = 0
					t.y = float(t.y0)
					t.vy = 0.0
			"fall":
				t.vy = min(t.vy + .5, 12.0)
				t.y += t.vy
				if Game.hit(p, g.R(float(t.x) - 16, t.y - 8, 32, 16)) and p.iframe == 0:
					g.hurt(1, float(t.x))
					_shatter(t)
				elif t.y >= float(t.y1):
					_shatter(t)
	# toldos: quem cai em cima é jogado para o alto
	for a in AWN:
		a.sq = max(0.0, float(a.sq) - .08)
		if gs is Dictionary and gs == a.sol and p.onGround:
			p.vy = -float(a.get("pow", 15.5))
			p.onGround = false
			p._g = null
			p.y -= 2
			p.airJumps = 1
			p.cutOk = false      # o pulo do toldo não é cortado ao soltar PULAR
			p.coyote = 0
			a.sq = 1.0
			Audio.play("spring", -4)
			if not told.has("awn"):
				told.awn = 1
				g.tip("Toldo de pano: pule em cima e ele joga você lá para cima!", 180)

func _shatter(t: Dictionary) -> void:
	t.st = "wait"
	t.t = 0
	for k in 6:
		g.PARTS.append({"x": float(t.x), "y": t.y, "vx": randf_range(-3, 3), "vy": randf_range(-5, -1), "life": 30, "col": Color("#b4502e")})
	Audio.play("stomp", -10)

func in_cone(w: Dictionary, pc: Vector2) -> bool:
	var lp := Vector2(float(w.x) + float(w.dir) * 16.0, 446.0)
	var v: Vector2 = pc - lp
	if v.length() > CONE_LEN or v.x * float(w.dir) < 0:
		return false
	return abs(v.angle_to(Vector2(float(w.dir), .12))) < CONE_ANG

## abaixada atrás de um caixote ou barril: o lampião não acha a Isis
func hidden(p: Dictionary) -> bool:
	if not p.crouch:
		return false
	var cx: float = p.x + p.w / 2
	for h in HIDES:
		if cx > float(h.x) + 4 and cx < float(h.x) + float(h.w) - 4:
			return true
	return false

## fase da Isis: lápis deixados no chão e o Vargas no fim do túnel
func isis_step() -> void:
	var p: Dictionary = g.player
	for d in DROPS:
		if not d.done and p.x > float(d.x) and p.onGround:
			d.done = true
			d.y = p.y + p.h
			Audio.play("coin", -6, .8)
			g.flash(str(d.get("msg", "A Isis deixou um lápis no chão: uma trilha para o papai.")), 170)
	if CATCH.is_empty():
		return
	if int(CATCH.t) < 0:
		if p.x > float(CATCH.x) and p.onGround:
			CATCH.t = 0
			CATCH.vx = float(CATCH.x) + 520.0
			Audio.play("door", -4, .6)
		return
	CATCH.t = int(CATCH.t) + 1
	# ela para; o Vargas sai da sombra e vem buscá-la
	g.keys.clear()
	p.vx = 0.0
	p.face = 1
	CATCH.vx = max(float(CATCH.vx) - 2.6, p.x + p.w + 26.0)
	if int(CATCH.t) == 40:
		g.flash("— Achei você, menina.", 200)
		Audio.play("hurt", -6, .7)
	if int(CATCH.t) == 150:
		g.running = false
		g.results_ready.emit()

func _caught(w: Dictionary) -> void:
	var p: Dictionary = g.player
	caught_n += 1
	Audio.play("hurt")
	Audio.vib(120)
	g.shake = 6
	g.iris_t = 30
	p.x = p.spawnX
	p.y = p.spawnY
	p.vx = 0.0
	p.vy = 0.0
	p.iframe = 60
	w.wait = 90
	if p.get("isis"):
		g.flash("O Vargas viu a Isis! Ela voltou correndo para trás. Abaixe-se atrás dos caixotes quando a luz vier.", 260)
	else:
		g.flash("Um vigia te pegou com o lampião! Você foi levado de volta. Fique longe da rua: vá pelos telhados.", 260)

# ======================================================================
#  DESENHO
# ======================================================================
func draw(T: int) -> void:
	var c0: float = g.cam - 300
	var c1: float = g.cam + g.W + 300
	for a in AWN:
		if float(a.x) > c1 or float(a.x) + float(a.w) < c0:
			continue
		_awning(a, T)
	for h in HOT:
		if float(h.x) > c1 or float(h.x) < c0:
			continue
		_hot(h, T)
	for t in TILES:
		if float(t.x) > c1 or float(t.x) < c0:
			continue
		_tile(t, T)
	for d in DOGS:
		if d.x > c1 or d.x < c0:
			continue
		_dog(d, T)
	for w in WATCH:
		if w.x > c1 or w.x < c0:
			continue
		if w.get("vargas"):
			vargas_fig(w.x, 500.0, float(w.dir), T, w.t if w.wait == 0 else 0)
		else:
			_watchman(w, T)
	for d in DROPS:
		if d.done:
			_pencil(float(d.x), float(d.y), str(d.get("c", "#e04a3a")))
	if not CATCH.is_empty() and int(CATCH.t) >= 0:
		vargas_fig(float(CATCH.vx), 500.0, -1.0, T, int(CATCH.t) if float(CATCH.vx) > g.player.x + g.player.w + 27 else 0)

## por cima da Isis: os caixotes e barris do esconderijo
func draw_front(T: int) -> void:
	var p: Dictionary = g.player
	for h in HIDES:
		var x: float = float(h.x)
		var w: float = float(h.w)
		if x > g.cam + g.W + 100 or x + w < g.cam - 100:
			continue
		var behind: bool = p.x + p.w > x and p.x < x + w
		var a: float = .72 if behind else 1.0
		var hh: float = float(h.get("h", 46))
		Spr.ellipse(x + w / 2, 501, w * .55, 5, Color(0, 0, 0, .35))
		if str(h.get("k", "crate")) == "barrel":
			Spr.rr(x, 500 - hh, w, hh, 12, Color(.38, .24, .12, a))
			Spr.rr(x + 4, 500 - hh + 3, w - 8, hh - 6, 10, Color(.5, .32, .16, a))
			for k in 2:
				Spr.rect(x, 500 - hh + 10 + k * (hh - 24), w, 5, Color(.25, .25, .28, a))
		else:
			Spr.PR("crate", x, 500 - hh, w, hh, Color(1, 1, 1, a))
		if behind and p.crouch:
			Spr.text("escondida", x + w / 2, 500 - hh - 12, 12, Color(.85, 1, .85, .9), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_i, 2)

func _pencil(x: float, y: float, c: String) -> void:
	Spr.save()
	Spr.translate(x, y - 4)
	Spr.rotate(-.12)
	Spr.scale(1.5, 1.5)
	Spr.rr(-14, -3, 24, 6, 2, Color(c))
	Spr.poly(PackedVector2Array([Vector2(10, -3), Vector2(17, 0), Vector2(10, 3)]), Color("#e8c890"))
	Spr.circle(16, 0, 1.2, Color(.2, .2, .2))
	Spr.restore()
	Spr.glow(x, y - 4, 16, Color(1, .95, .7, .25))

## o Vargas a pé: capacete de mineiro com lampião, bigode e capote
static func vargas_fig(x: float, y: float, d: float, T: int, wt: int) -> void:
	var st: float = sin(wt * .3) * 5.0 if wt > 0 else 0.0
	Spr.ellipse(x, y, 22, 4, Color(0, 0, 0, .35))
	var dark := Color("#2a2420")
	var coat := Color("#5a3a22")
	Spr.rr(x - 11 + st, y - 34, 10, 34, 3, dark)
	Spr.rr(x + 1 - st, y - 34, 10, 34, 3, dark)
	Spr.poly(PackedVector2Array([Vector2(x - 18, y - 30), Vector2(x - 14, y - 86), Vector2(x + 14, y - 86), Vector2(x + 20, y - 30)]), coat)
	Spr.rect(x - 17, y - 52, 36, 5, Color("#2a1a0e"))
	Spr.circle(x + d * 3, y - 96, 12, Color("#c99a78"))
	Spr.rr(x + d * 2 - (14.0 if d < 0 else 0.0), y - 92, 14, 4, 2, Color("#3a2a1e"))
	Spr.circle(x + d * 8, y - 99, 1.8, Color(0, 0, 0))
	Spr.rr(x - 12, y - 114, 26, 12, 6, Color("#6a5a3a"))
	Spr.rect(x - 14, y - 104, 30, 4, Color("#4a3e28"))
	Spr.circle(x + d * 12, y - 108, 4.5, Color(1, .9, .55))
	# braço com o lampião na frente
	Spr.seg(x + d * 6, y - 74, x + d * 16, y - 60, coat, 6)
	Spr.seg(x + d * 16, y - 64, x + d * 16, y - 56, Color(.2, .2, .2), 1.5)
	Spr.rr(x + d * 16 - 5, y - 57, 10, 12, 2, Color("#b08a3a"))
	Spr.circle(x + d * 16, y - 51, 3.5, Color(1, .92, .6))

## o facho do lampião (por cima do escuro)
func draw_glow(T: int) -> void:
	for w in WATCH:
		if w.x > g.cam + g.W + 400 or w.x < g.cam - 400:
			continue
		var lp := Vector2(float(w.x) + float(w.dir) * 16.0, 446.0)
		var dirv := Vector2(float(w.dir), .12).normalized()
		var pts := PackedVector2Array([lp])
		var cols := PackedColorArray([Color(1, .85, .45, .38)])
		for k in 9:
			var a: float = -CONE_ANG + 2.0 * CONE_ANG * k / 8.0
			pts.push_back(lp + dirv.rotated(a) * CONE_LEN)
			cols.push_back(Color(1, .85, .45, .0))
		Spr.ci.draw_polygon(pts, cols)
		Spr.glow(lp.x, lp.y, 46, Color(1, .8, .4, .5))

func _watchman(w: Dictionary, T: int) -> void:
	var x: float = float(w.x)
	var d: float = float(w.dir)
	var step: float = sin(w.t * .18) * 3.0 if w.wait == 0 else 0.0
	var dark := Color("#3a3a4a")
	var coat := Color("#5a4632")
	Spr.ellipse(x, 501, 20, 4, Color(0, 0, 0, .3))
	# pernas
	Spr.rr(x - 9 + step, 470, 8, 30, 3, dark)
	Spr.rr(x + 1 - step, 470, 8, 30, 3, dark)
	# capote
	Spr.poly(PackedVector2Array([Vector2(x - 14, 474), Vector2(x - 10, 428), Vector2(x + 10, 428), Vector2(x + 14, 474)]), coat)
	Spr.rect(x - 13, 452, 26, 4, Color("#4a3a22"))
	# cabeça e quepe
	Spr.circle(x + d * 2, 418, 9, Color("#c9a080"))
	Spr.circle(x + d * 6, 416, 1.6, Color(0, 0, 0))
	Spr.rr(x - 10, 404, 20, 9, 3, Color("#26304a"))
	Spr.rect(x - 10, 410, 20, 2, Color("#c8a040"))
	Spr.rect(x + d * 6 - (12.0 if d < 0 else 0.0), 411, 12, 3, Color("#26304a"))
	# botões e apito dourados
	for k in 3:
		Spr.circle(x + d * 2, 436 + k * 9, 1.6, Color("#e0c060"))
	# braço com o lampião levantado
	Spr.seg(x + d * 6, 434, x + d * 16, 440, coat, 6)
	Spr.seg(x + d * 16, 436, x + d * 16, 444, Color(.2, .2, .2), 1.5)
	Spr.rr(x + d * 16 - 5, 443, 10, 12, 2, Color("#b08a3a"))
	Spr.circle(x + d * 16, 449, 3.5, Color(1, .92, .6))
	# apito quando para
	if w.wait > 40:
		Spr.text("?", x, 392 + sin(T * .2) * 2, 16, Color(1, .9, .6), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 3)

func _dog(d: Dictionary, T: int) -> void:
	var run: bool = d.st == "chase"
	var fr: int = (T / (3 if run else 7)) % 4
	var ok := false
	Spr.ellipse(d.x, 501, 22, 4, Color(0, 0, 0, .3))
	Spr.save()
	Spr.translate(d.x, 500)
	Spr.scale(.42 * (-1.0 if d.dir < 0 else 1.0), .42)
	if Spr.has("dog%d" % fr):
		Spr.A_sil("dog%d" % fr, 0, 0, 1.0, false, Color("#2a2018"))
		ok = true
	Spr.restore()
	if not ok:
		Spr.rr(d.x - 20, 478, 40, 18, 7, Color("#2a2018"))
	# olhos vermelhos e coleira de pregos
	Spr.circle(d.x + d.dir * 16, 474, 2.2, Color(1, .25, .15))
	Spr.rect(d.x + d.dir * 8 - 4, 480, 8, 3, Color("#b03020"))
	if d.bark > 0:
		Spr.text("AU!", d.x + d.dir * 30, 452, 14, Color(1, .9, .6), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 3)

func _hot(h: Dictionary, T: int) -> void:
	var x: float = float(h.x)
	var w: float = float(h.w)
	var y: float = float(h.y)
	var ph: int = hot_phase(h)
	# a chaminé de ferro da forja: mais alta que as outras, com os tijolos em brasa
	var hh: float = float(h.get("h", 60))
	var bot: float = y + hh - 4
	Spr.rect(x - 3, y, w + 6, hh - 4, Color("#3a1810"))
	var row := 0
	var by: float = y + 6
	while by < bot - 2:
		var off: float = 0.0 if row % 2 == 0 else 8.0
		var bx: float = x - 1 - off
		while bx < x + w + 1:
			var a0: float = max(bx, x - 1)
			var a1: float = min(bx + 15, x + w + 1)
			if a1 > a0 + 2:
				var heat: float = clamp(1.0 - (by - y) / hh, 0, 1)
				Spr.rect(a0, by, a1 - a0 - 1, 7, Color(.55 + .35 * heat, .2 + .12 * heat, .1, 1))
			bx += 16
		by += 8
		row += 1
	Spr.rect(x - 6, y - 4, w + 12, 9, Color("#2a2a2e"))
	Spr.rect(x - 6, y - 4, w + 12, 3, Color("#5a5a60"))
	# boca da chaminé em brasa
	Spr.rect(x - 2, y - 2, w + 4, 6, Color(.9, .35, .1, .8 + .2 * sin(T * .3)))
	Spr.glow(x + w / 2, y, 30, Color(1, .45, .1, .45))
	if ph == 1:
		for k in 5:
			var u: float = fposmod(T * .05 + k * .2, 1.0)
			Spr.circle(x + w * (.2 + .15 * k) + sin(T * .3 + k) * 3, y - u * 60, 2, Color(1, .7, .2, 1.0 - u))
	elif ph == 2:
		for k in 7:
			var u2: float = fposmod(T * .08 + k / 7.0, 1.0)
			var fx: float = x + w / 2 + sin(T * .4 + k * 1.3) * w * .3
			var r: float = (1.0 - u2) * (w * .45) + 4
			Spr.circle(fx, y - u2 * 150, r, Color(1, .35 + .4 * u2, .05, .85 * (1.0 - u2)))
		Spr.glow(x + w / 2, y - 70, 80, Color(1, .5, .1, .4))

func _tile(t: Dictionary, T: int) -> void:
	var x: float = float(t.x)
	var c := Color("#b4502e")
	if t.st == "shake":
		var sx: float = sin(T * 1.5) * 2.0
		Spr.rr(x - 15 + sx, float(t.y0) - 8, 30, 12, 3, c)
		Spr.text("!", x, float(t.y0) - 22, 16, Color(1, .8, .4), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 3)
	elif t.st == "fall":
		Spr.save()
		Spr.translate(x, t.y)
		Spr.rotate(t.y * .05)
		Spr.rr(-15, -6, 30, 12, 3, c)
		Spr.rr(-15, -6, 30, 4, 2, Color("#d8704a"))
		Spr.restore()
	else:
		Spr.rr(x - 15, float(t.y0) - 8, 30, 12, 3, c)

func _awning(a: Dictionary, T: int) -> void:
	var x: float = float(a.x)
	var w: float = float(a.w)
	var y: float = float(a.y) + float(a.sq) * 6.0
	# armação presa na parede e o pano listrado
	var wallx: float = x + w if a.get("wall", "right") == "right" else x
	Spr.seg(wallx, y - 26, x + (0.0 if wallx > x else w), y + 4, Color("#4a3018"), 3)
	var n := 6
	for k in n:
		var x0: float = x + w * k / n
		var c := Color("#c0392b") if k % 2 == 0 else Color("#f0e0c0")
		Spr.poly(PackedVector2Array([Vector2(x0, y), Vector2(x0 + w / n, y), Vector2(x0 + w / n, y + 10), Vector2(x0, y + 10)]), c)
	for k in n:
		var cx: float = x + w * (k + .5) / n
		Spr.circle(cx, y + 11, w / n * .5, Color("#c0392b") if k % 2 == 0 else Color("#f0e0c0"))
	Spr.seg(x, y, x + w, y, Color("#3a2414"), 2)
