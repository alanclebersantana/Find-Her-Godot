extends RefCounted
class_name WorldCombat
## Desenho do pacote de ação (ver Combat): arcos do combo e do giro, carga da defesa, rastro da esquiva,
## pedras / caixas / barris, explosões, pedras caindo nos chefes, aura das fases, escudo, vida e aviso
## dos bichos. Tudo por código, no traço do jogo (contorno escuro, cores quentes).

const INK := Color("#2a1708")

# ---------------------------------------------------------------- poses e arcos da picareta
static func swing_pose(p: Dictionary) -> String:
	var sd: float = float(p.get("swd", 22))
	var e: float = sd - float(p.actT)
	if p.get("act", "") == "spin":
		return "pai_throw1" if (int(e) / 4) % 2 == 0 else "pai_throw2"
	var first: bool = e < sd * .36
	if p.get("fin", false):
		first = e < sd * .45
	elif int(p.get("swk", 0)) % 2 == 1:
		# o segundo golpe volta de baixo para cima
		first = not first
	return "pai_throw1" if first else "pai_throw2"

## desenha o arco do golpe (combo, golpe final e giro); true = já desenhou
static func swing_arc(g: Game, p: Dictionary, T: int) -> bool:
	var sd: float = float(p.get("swd", 22))
	var e: float = sd - float(p.actT)
	var cx: float = p.x + p.w / 2
	var f: float = p.face
	var cy: float = p.y + 14
	if p.get("act", "") == "spin":
		if e < 4 or e > 27:
			return true
		var u: float = (e - 4) / 23.0
		var ang: float = u * TAU * 1.5
		var pts := PackedVector2Array()
		for i in 15:
			var a: float = ang - 2.4 + 2.4 * i / 14.0
			pts.push_back(Vector2(cx + cos(a) * 70, cy + 4 + sin(a) * 30))
		var al: float = 1.0 - u * .5
		Spr.ci.draw_polyline(pts, Color(1, .85, .45, .5 * al), 12, true)
		Spr.ci.draw_polyline(pts, Color(1, 1, .9, .95 * al), 4, true)
		Spr.ellipse(cx, p.y + p.h - 2, 70 * (.6 + .4 * u), 7, Color(1, .95, .8, .18 * al))
		var tip: Vector2 = pts[pts.size() - 1]
		Spr.glow(tip.x, tip.y, 30, Color(1, .9, .5, .4 * al))
		return true
	var fin: bool = p.get("fin", false)
	var w0: float = 10.0 if fin else 6.0
	var w1: float = 20.0 if fin else 14.0
	if e < w0 - 1 or e > w1 + 2:
		return true
	var k: float = clamp((e - (w0 - 1)) / (w1 - w0 + 1), 0, 1)
	var back: bool = int(p.get("swk", 0)) % 2 == 1 and not fin
	var a0 := -1.9
	var a1: float = lerpf(-1.6, 1.1, k)
	if back:
		a0 = 1.3
		a1 = lerpf(1.0, -1.7, k)
	if fin:
		a0 = -2.3
		a1 = lerpf(-2.0, 1.4, k)
	var rx := 62.0 if fin else 42.0
	var ry := 46.0 if fin else 34.0
	var pts2 := PackedVector2Array()
	for i in 13:
		var a2: float = lerpf(a0, a1, i / 12.0)
		pts2.push_back(Vector2(cx + f * cos(a2) * rx, cy + sin(a2) * ry))
	var fade: float = 1.0 - k * .5
	if fin:
		Spr.ci.draw_polyline(pts2, Color(1, .75, .3, .45 * fade), 13, true)
		Spr.ci.draw_polyline(pts2, Color(1, .98, .85, .95 * fade), 4.5, true)
	else:
		Spr.ci.draw_polyline(pts2, Color(1, .95, .8, .55 * fade), 7, true)
		Spr.ci.draw_polyline(pts2, Color(1, 1, 1, .9 * fade), 2.5, true)
	var tip2: Vector2 = pts2[pts2.size() - 1]
	if not Rig.ready("tome"):
		Spr.save()
		Spr.translate(tip2.x, tip2.y)
		Spr.rotate(a1 * f + (0.0 if f > 0 else PI))
		Spr.A("it_picareta", 0, 0, .34 if fin else .3, f < 0)
		Spr.restore()
	return true

## defesa segurada: o anel da carga vai enchendo; cheio, brilha dourado (solte para o golpe carregado)
static func charge_fx(g: Game, x: float, y: float, T: int) -> void:
	if g.CB == null:
		return
	var p: Dictionary = g.player
	var k: float = clamp(float(g.CB.charge) / Combat.CHARGE_FULL, 0.0, 1.0)
	if k <= .05:
		return
	var c := Vector2(p.x + p.w / 2, p.y + p.h / 2 - 2)
	if g.CB.charge_ready:
		var s: float = .5 + .5 * sin(T * .5)
		Spr.glow(c.x, c.y, 60 + 8 * s, Color(1, .85, .35, .35 + .2 * s))
		Spr.ci.draw_arc(c, 38, 0, TAU, 40, Color(1, .95, .6, .9), 3, true)
	else:
		Spr.ci.draw_arc(c, 38, -PI / 2, -PI / 2 + TAU * k, 40, Color(1, .9, .55, .75), 3, true)

# ---------------------------------------------------------------- camada de trás
static func boss_aura(g: Game, T: int) -> void:
	if g.CB == null:
		return
	for bb in Polish.bosses():
		var ph: int = Combat.phase_of(int(bb.hp), int(bb.max))
		if ph < 2 or int(bb.hp) <= 0:
			continue
		var s: float = .5 + .5 * sin(T * (.12 if ph == 2 else .25))
		var col := Color(1, .55, .15, .16 + .06 * s) if ph == 2 else Color(1, .15, .08, .2 + .12 * s)
		Spr.glow(float(bb.x), float(bb.y) - 30, 170 + 20 * s, col)

static func draw_back(g: Game, T: int) -> void:
	var CB: Combat = g.CB
	if CB == null:
		return
	# rastro da esquiva (silhuetas azuladas do Tomé)
	for gh in CB.ghosts:
		Spr.A_sil(gh.n, gh.x, gh.y, .56, gh.f < 0, Color(.72, .88, 1, .42 * gh.a))
	for o in CB.THR:
		if o.st == "held":
			continue
		if o.x < g.cam - 120 or o.x > g.cam + g.W + 120:
			continue
		_obj(o, T, o.st == "ground")
	for s in CB.STONES:
		if s.st == "warn" or s.st == "fall":
			var k: float = clamp(float(s.t) / 50.0, 0, 1) if s.st == "warn" else 1.0
			Spr.ellipse(s.x, s.gy, 10 + 14 * k, 4 + 2 * k, Color(0, 0, 0, .18 + .25 * k))
			if s.st == "warn" and (T / 5) % 2 == 0:
				Spr.ellipse(s.x, s.gy, 26, 7, Color(1, .3, .2, .18))
		if s.st == "fall":
			_rock(s.x, s.y, 1.2, float(s.t) * .2)

## pedra, caixa ou barril (no chão, voando ou na mão)
static func _obj(o: Dictionary, T: int, ground: bool) -> void:
	var x: float = o.x
	var y: float = o.y
	if ground:
		Spr.ellipse(x, y + 1, 16 if o.k == "rock" else 22, 4, Color(0, 0, 0, .22))
	match o.k:
		"rock":
			_rock(x, y, 1.0, float(o.rot))
			if ground and int(o.t) % 90 < 10:
				Spr.glow(x, y - 10, 22, Color(1, .95, .7, .15))
		"crate":
			Spr.save()
			Spr.translate(x, y - 19)
			Spr.rotate(float(o.rot))
			Spr.PR("crate_heart" if o.get("item", "") == "heart" else "crate", -22, -22, 44, 44)
			Spr.restore()
		"barrel":
			_barrel(x, y, float(o.rot), int(o.fuse), T)

static func _rock(x: float, y: float, sc: float, rot: float) -> void:
	Spr.save()
	Spr.translate(x, y - 10 * sc)
	Spr.rotate(rot)
	Spr.scale(sc, sc)
	var pts := PackedVector2Array([Vector2(-13, 3), Vector2(-10, -7), Vector2(-2, -11), Vector2(8, -9), Vector2(13, -1), Vector2(10, 8), Vector2(-4, 10), Vector2(-12, 8)])
	var ol := PackedVector2Array()
	for v in pts:
		ol.push_back(v * 1.18)
	Spr.poly(ol, INK)
	Spr.poly(pts, Color("#8d857a"))
	Spr.poly(PackedVector2Array([Vector2(-9, -5), Vector2(-2, -9), Vector2(6, -7), Vector2(1, -3)]), Color("#b9b0a2"))
	Spr.circle(5, 4, 2, Color("#6d665c"))
	Spr.restore()

static func _barrel(x: float, y: float, rot: float, fuse: int, T: int) -> void:
	Spr.save()
	Spr.translate(x, y - 25)
	Spr.rotate(rot)
	Spr.rr(-21, -25, 42, 50, 9, INK)
	Spr.rr(-18, -22, 36, 44, 7, Color("#8a5530"))
	Spr.rect(-18, -6, 36, 12, Color("#b8322a"))
	for k in 2:
		Spr.rect(-19, -18 + k * 30, 38, 5, Color("#4a4c52"))
	Spr.text("✸", 0, 5, 14, Color("#ffd76a"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b)
	# pavio
	Spr.seg(4, -24, 9, -34, Color("#3a2410"), 2.5)
	if fuse > 0:
		var s: float = .5 + .5 * sin(T * .9)
		Spr.glow(9, -35, 12 + 6 * s, Color(1, .7, .2, .6))
		Spr.circle(9, -35, 2.5, Color(1, .95, .6))
		if fuse > 60 and (T / 4) % 2 == 0:
			Spr.rr(-18, -22, 36, 44, 7, Color(1, .3, .2, .35))
	Spr.restore()

# ---------------------------------------------------------------- camada da frente
static func draw_front(g: Game, T: int) -> void:
	var CB: Combat = g.CB
	if CB == null:
		return
	if CB.held != null:
		var o: Dictionary = CB.held
		var p: Dictionary = g.player
		var hx: float = p.x + p.w / 2 + g.ip_off().x
		var hy: float = p.y - 26 + g.ip_off().y
		var oo: Dictionary = o.duplicate()
		oo.x = hx
		oo.y = hy
		_obj(oo, T, false)
	for b in CB.BOOMS:
		var u: float = b.t / 24.0
		Spr.glow(b.x, b.y, 80 + 160 * u, Color(1, .75, .3, .55 * (1.0 - u)))
		Spr.ci.draw_arc(Vector2(b.x, b.y), 30 + 130 * u, 0, TAU, 40, Color(1, .95, .7, .8 * (1.0 - u)), 6 * (1.0 - u) + 1, true)
		if b.t < 4:
			Spr.circle(b.x, b.y, 50, Color(1, 1, .9, .7))

# ---------------------------------------------------------------- bichos
## escudo de tábuas na frente do bicho
static func shield(e: Dictionary) -> void:
	var sc: float = float(e.get("sc", 1.0))
	var d: float = 1.0 if float(e.dir) > 0 else -1.0
	var sx: float = float(e.x) + d * 21 * sc
	var sy: float = float(e.y) - 19 * sc
	Spr.ellipse(sx, sy, 11 * sc, 19 * sc, INK)
	Spr.ellipse(sx, sy, 8.5 * sc, 16 * sc, Color("#9a6a35"))
	Spr.seg(sx - 3 * sc, sy - 14 * sc, sx - 3 * sc, sy + 14 * sc, Color("#5a3a1a"), 1.5)
	Spr.seg(sx + 3 * sc, sy - 14 * sc, sx + 3 * sc, sy + 14 * sc, Color("#5a3a1a"), 1.5)
	Spr.rect(sx - 8 * sc, sy - 7 * sc, 16 * sc, 3 * sc, Color("#4a4c52"))
	Spr.rect(sx - 8 * sc, sy + 5 * sc, 16 * sc, 3 * sc, Color("#4a4c52"))
	Spr.circle(sx, sy, 3.2 * sc, Color("#c8c4bc"))

## barrinha de vida em cima do bicho (só depois de levar o primeiro golpe)
static func hp_bar(e: Dictionary, ox: float, oy: float) -> void:
	var h0: int = int(e.get("hp0", 1))
	var h: int = int(e.get("hp", h0))
	if h0 <= 1 or h >= h0 or e.dead:
		return
	var sc: float = float(e.get("sc", 1.0))
	var top: float = float(e.y) - (52.0 if not Game.FLY.has(e.k) and not e.k in ["crow", "bat"] else 30.0) * sc + oy
	var w: float = 8.0 * h0 + 4
	var x0: float = float(e.x) + ox - w / 2
	Spr.rr(x0, top, w, 8, 3, Color(.15, .08, .05, .85))
	for i in h0:
		Spr.rr(x0 + 2 + i * 8, top + 2, 6, 4, 2, Color("#e0463a") if i < h else Color(.35, .25, .2, .7))

## "!" de aviso em cima dos bichos que não têm o seu próprio
static func warn_mark(e: Dictionary, ox: float, oy: float, T: int) -> void:
	if not Combat.warn(e) or e.k in ["crow", "bat", "fly"]:
		return
	var sc: float = float(e.get("sc", 1.0))
	var y: float = float(e.y) - 66 * sc + oy - abs(sin(T * .3)) * 4
	Spr.text("!", float(e.x) + ox, y, 26, Color("#ff5a3a") if (T / 3) % 2 == 0 else Color("#ffe08a"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 5)
