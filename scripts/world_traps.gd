extends RefCounted
class_name WorldTraps
## Desenho dos saltos e armadilhas (tudo por código, no mesmo traço de livro ilustrado do cenário).

const OUT := Color("#2a1a0e")
const WOOD := Color("#7a5232")
const WOOD_D := Color("#4e331d")
const STEEL := Color("#b9c2c9")
const STEEL_D := Color("#6c7680")

static func draw(g: Game, T: int) -> void:
	var TR: Traps = g.TR
	if TR == null:
		return
	var c0: float = g.cam - 220
	var c1: float = g.cam + g.W + 220
	for o in TR.T:
		var ox: float = o.get("bx", o.x)
		if ox < c0 - 400 or ox > c1 + 400:
			continue
		match o.k:
			"bounce": _bounce(g, TR, o, T)
			"flower": _flower(g, TR, o, T)
			"wind": _wind(o, T)
			"spikes": _spikes(TR, o, T)
			"roll": _roll(o)
			"axe": _axe(TR, o, T)
			"snap": _snap(o, T)
			"cage": _cage(o, T)
			"net": _net(o, T)
			"swing": _swing(TR, o, T)
			"hive": _hive(o, T)
			"sand": _sand_back(o, T)
			"web": _web(o, T)
			"gust": _gust(TR, o, T)
			"bridge": _bridge(o, T)
			"boulder": _boulder(g, o, T)
			"giant": _giant(o, T)
	_bobs(g, T)
	_ice_hits(g, T)
	_tunnel_ceiling(g, T)
	if not TR.PICK.is_empty():
		_pick(TR.PICK)

# ---------- cogumelo saltador ----------
static func _bounce(g: Game, TR: Traps, o: Dictionary, T: int) -> void:
	var sq: float = o.get("squash", 0.0)
	var x: float = o.x
	var y: float = o.y
	# inclina o chapéu para onde ele vai lançar
	var to = o.get("to")
	var tilt := 0.0
	if to is float or to is int:
		var nx: Dictionary = TR.T[int(to)]
		tilt = clamp((nx.x - x) / 900.0, -.35, .35)
	elif to is Array:
		tilt = clamp((float(to[0]) - x) / 900.0, -.35, .35)
	Spr.glow(x, y - 30, 46, Color(1, .75, .55, .25 + sin(T * .08 + x) * .08))
	Spr.ellipse(x, y + 1, 22, 4, Color(0, 0, 0, .25))
	# caule
	Spr.poly(PackedVector2Array([Vector2(x - 8, y), Vector2(x - 6, y - 24 + sq * 6), Vector2(x + 6, y - 24 + sq * 6), Vector2(x + 9, y)]), Color("#efe2c4"))
	Spr.seg(x - 8, y, x - 6, y - 22 + sq * 6, Color("#c9b48a"), 2)
	Spr.save()
	Spr.translate(x, y - 22 + sq * 6)
	Spr.rotate(tilt)
	Spr.scale(1 + sq * .35, 1 - sq * .4)
	var cap := PackedVector2Array()
	for i in 17:
		var a := PI + PI * i / 16.0
		cap.push_back(Vector2(cos(a) * 32, sin(a) * 22))
	var cc := Color("#e0563a") if o.get("c", "") != "azul" else Color("#4a8fd8")
	Spr.poly(cap, cc)
	Spr.ellipse(0, -1, 32, 4, cc.darkened(.35))
	for d in [[-16, -10, 5], [2, -16, 6], [17, -8, 4.5], [-4, -6, 3]]:
		Spr.circle(d[0], d[1], d[2], Color("#fbf3dc"))
	Spr.line(cap, OUT, 2)
	Spr.restore()

# ---------- flor-catapulta ----------
static func _flower(g: Game, TR: Traps, o: Dictionary, T: int) -> void:
	var x: float = o.x
	var y: float = o.y
	var pad: float = o.get("pad", 0.0)
	var py: float = y - 18 + pad * 12
	# caule e folhas
	Spr.line(PackedVector2Array([Vector2(x, y), Vector2(x - 4, y - 8), Vector2(x, py + 6)]), Color("#3f6a2a"), 6)
	Spr.ellipse(x - 16, y - 6, 14, 5, Color("#5c8d38"), .4)
	Spr.ellipse(x + 16, y - 5, 14, 5, Color("#5c8d38"), -.4)
	# pétalas (abrem mais quando dispara)
	var open: float = 1.0 - max(0.0, pad) * .5
	for i in 7:
		var a: float = PI + PI * i / 6.0
		var r: float = 24.0 * open + 6.0
		Spr.ellipse(x + cos(a) * r * .8, py + sin(a) * r * .45, 13, 6, Color("#f08cb6"), a)
	Spr.ellipse(x, py + 1, 27, 6, Color("#e2659a"))
	Spr.ellipse(x, py - 1, 22, 4, Color("#ffd35c"))
	# enquanto carrega, mostra o arco de para onde vai
	if o.st == "load":
		var tg: Array = o.to
		var v := TR.ballistic(Vector2(x, y - 18), Vector2(float(tg[0]), float(tg[1])), o.get("arc", 1.0))
		var p := Vector2(x, y - 18)
		var vel := Vector2(v.x, v.y)
		var n := int(v.z)
		for i in n:
			vel.y += Game.GRAV
			p += vel
			if i % 5 == 0:
				Spr.circle(p.x, p.y, 2.2, Color(1, .95, .8, .55 * pad))

# ---------- corrente de vento ----------
static func _wind(o: Dictionary, T: int) -> void:
	var x: float = o.x
	var y: float = o.y
	var w: float = o.w
	var h: float = o.h
	Spr.vgrad(x, y, w, h, Color(.85, .95, 1, 0), Color(.85, .95, 1, .1))
	for k in 7:
		var lx: float = x + w * (k + .5) / 7.0
		var ph: float = fmod(T * 2.4 + k * 53.0, h)
		var yy: float = y + h - ph
		var pts := PackedVector2Array()
		for j in 6:
			pts.push_back(Vector2(lx + sin(yy * .05 + j * .7 + k) * 8, yy - j * 9))
		Spr.line(pts, Color(1, 1, 1, .32 * (ph / h)), 2)
	# folhinhas subindo
	for k in 4:
		var fx: float = x + fmod(k * 37.0 + T * .3, w)
		var fy: float = y + h - fmod(T * 3.0 + k * 90.0, h)
		Spr.ellipse(fx + sin(T * .1 + k) * 6, fy, 5, 2, Color("#9ec46a"), T * .1 + k)
	# a fenda de onde sai o vento
	Spr.ellipse(x + w / 2, y + h + 2, w * .45, 5, Color(.1, .08, .06, .7))

# ---------- espinhos ----------
static func _spikes(TR: Traps, o: Dictionary, T: int) -> void:
	var h: float = TR.spike_h(o)
	var x: float = o.x
	var y: float = o.y
	var w: float = o.w
	var sh: float = 0.0
	if TR.spike_warn(o) and h < 1:
		sh = sin(T * 1.7) * 1.5
		if T % 6 == 0:
			game_dust(x + randf() * w, y)
	Spr.rect(x - 4, y - 4, w + 8, 6, Color("#3a3026"))
	var n := int(w / 16)
	for i in n:
		var sx: float = x + (i + .5) * w / n + sh
		var hh: float = max(h, 3.0)
		Spr.poly(PackedVector2Array([Vector2(sx - 7, y - 2), Vector2(sx, y - 2 - hh), Vector2(sx + 7, y - 2)]), STEEL)
		Spr.poly(PackedVector2Array([Vector2(sx, y - 2), Vector2(sx, y - 2 - hh), Vector2(sx + 7, y - 2)]), STEEL_D)
	Spr.rect(x - 6, y - 2, w + 12, 5, Color("#2a2018"))

static func game_dust(_x: float, _y: float) -> void:
	pass

# ---------- pedra rolando ----------
static func _roll(o: Dictionary) -> void:
	if o.get("snow"):
		# bola de neve rolando (fica parada à vista até disparar)
		if o.st == "done":
			return
		var Rs: float = o.get("r", 36.0)
		var bx: float = o.bx if o.has("bx") else float(o.x)
		var c := {"x": bx - Rs, "y": o.y - Rs * 2 + o.get("fy", 0.0), "w": Rs * 2, "h": Rs * 2}
		WorldNature.snowball(c, 0)
		return
	if o.st in ["idle", "done"]:
		return
	var R: float = o.get("r", 40.0)
	var cx: float = o.bx
	var cy: float = o.y - R + o.get("fy", 0.0)
	Spr.ellipse(cx, o.y + 2, R * .9, 6, Color(0, 0, 0, .3))
	Spr.circle(cx, cy, R, Color("#6b6a62"))
	Spr.circle(cx - R * .25, cy - R * .25, R * .55, Color("#7d7c73"))
	Spr.save()
	Spr.translate(cx, cy)
	Spr.rotate(o.rot)
	for k in 5:
		var a: float = k * 1.3
		Spr.seg(cos(a) * R * .2, sin(a) * R * .2, cos(a + .4) * R * .85, sin(a + .4) * R * .85, Color("#4a4943"), 3)
	Spr.ellipse(R * .3, -R * .5, 10, 5, Color(.36, .5, .22, .9))
	Spr.restore()
	Spr.ring(cx, cy, R, OUT, 3)

# ---------- machado-pêndulo ----------
static func _axe(TR: Traps, o: Dictionary, T: int) -> void:
	var b := TR.axe_blade(o)
	var a: float = o.get("ang", 0.0)
	# rastro do movimento
	for k in 3:
		var a2: float = a - sign(cos(TAU * (T + o.get("ph", 0)) / float(o.per))) * (k + 1) * .07
		var p2 := Vector2(o.x + sin(a2) * o.len, o.y + cos(a2) * o.len)
		Spr.circle(p2.x, p2.y, 16 - k * 3, Color(1, 1, 1, .06))
	if o.has("frame"):
		var fx: float = o.frame
		Spr.rect(fx - 7, o.y - 16, 14, 216, WOOD_D)
		Spr.rect(fx - 7, o.y - 16, 4, 216, WOOD)
		Spr.rr(fx - 10, o.y - 18, o.x - fx + 22, 12, 3, WOOD)
		Spr.seg(fx, o.y + 30, fx + 34, o.y - 8, WOOD_D, 6)
	Spr.seg(o.x, o.y, b.x, b.y, Color("#5a4632"), 5)
	Spr.circle(o.x, o.y, 8, Color("#3a3026"))
	Spr.circle(o.x, o.y, 3, STEEL)
	Spr.save()
	Spr.translate(b.x, b.y)
	Spr.rotate(-a)
	# lâmina em meia-lua
	var bl := PackedVector2Array()
	for i in 11:
		var t: float = -1.2 + 2.4 * i / 10.0
		bl.push_back(Vector2(sin(t) * 30, cos(t) * 16 + 4))
	for i in range(10, -1, -1):
		var t2: float = -1.2 + 2.4 * i / 10.0
		bl.push_back(Vector2(sin(t2) * 20, cos(t2) * 6 - 2))
	Spr.poly(bl, STEEL)
	Spr.line(bl, STEEL_D, 2)
	Spr.rect(-5, -14, 10, 14, WOOD_D)
	Spr.restore()

# ---------- galho que quebra ----------
static func _snap(o: Dictionary, T: int) -> void:
	if o.st == "fall" and o.fy > 500:
		return
	var sh: float = sin(T * 2.1) * 2.0 if o.st == "crack" else 0.0
	Spr.save()
	Spr.translate(o.x + o.w / 2 + sh, o.y + 8 + o.get("fy", 0.0))
	if o.st == "fall":
		Spr.rotate(o.fy * .004)
	var w: float = o.w
	Spr.rr(-w / 2, -8, w, 15, 6, Color("#6e4a2c"))
	Spr.rect(-w / 2 + 4, -8, w - 8, 3, Color("#8e6a44"))
	for k in 3:
		Spr.seg(-w / 2 + 12 + k * w * .3, -6, -w / 2 + 20 + k * w * .3, 5, Color("#3e2a18"), 1.5)
	# trinca que aparece quando vai quebrar
	if o.st != "idle":
		Spr.line(PackedVector2Array([Vector2(-4, -8), Vector2(3, -2), Vector2(-3, 3), Vector2(4, 7)]), Color("#1e140a"), 2.5)
	for k in 4:
		Spr.ellipse(-w / 2 + 10 + k * (w - 20) / 3.0, -10, 9, 4, Color("#5c8d38"), (k - 1.5) * .3)
	Spr.restore()

# ---------- jaula de caçador ----------
static func _cage(o: Dictionary, T: int) -> void:
	if o.st == "used":
		return
	var w: float = o.get("w", 64)
	var x: float = o.x
	var y: float = o.y + o.dy
	var top: float = y - 86
	var anchor := Vector2(x + w / 2, o.y - 300)
	# corda: poste → galho → jaula
	if o.has("post"):
		var px: float = o.post[0]
		var py: float = o.post[1]
		Spr.rr(px - 5, py - 46, 10, 48, 3, WOOD_D)
		Spr.rect(px - 7, py - 48, 14, 5, WOOD)
		Spr.seg(px, py - 36, anchor.x, anchor.y, Color("#c9b48a"), 2)
		Spr.circle(px, py - 36, 4, Color("#c9b48a"))
	Spr.seg(anchor.x, anchor.y, x + w / 2, top, Color("#c9b48a"), 2.5)
	Spr.circle(anchor.x, anchor.y, 5, Color("#3a3026"))
	# grades
	Spr.rect(x - 2, top - 6, w + 4, 8, WOOD)
	Spr.rect(x - 2, y - 6, w + 4, 6, WOOD_D)
	for k in 6:
		var bx: float = x + k * w / 5.0
		Spr.rect(bx - 2.5, top, 5, y - top, WOOD_D)
		Spr.rect(bx - 1, top, 2, y - top, WOOD)
	Spr.seg(x, top + 30, x + w, top + 30, WOOD_D, 3)

# ---------- rede de caçador ----------
static func _net(o: Dictionary, T: int) -> void:
	var fy: float = o.get("fy", 0.0)
	if fy > 600:
		return
	var x: float = o.x - 18
	var y: float = o.y + fy
	var w := 54.0
	var h: float = o.h
	var al: float = 1.0 if fy == 0 else clamp(1.0 - fy / 300.0, 0, 1)
	var c := Color(.82, .74, .55, al)
	if o.has("post") and o.st != "down":
		var px: float = o.post[0]
		var py: float = o.post[1]
		Spr.rr(px - 5, py - 46, 10, 48, 3, WOOD_D)
		Spr.seg(px, py - 36, x + w / 2, o.y - 6, Color("#c9b48a"), 2)
	Spr.rect(x - 4, o.y - 8, w + 8, 6, Color(.35, .25, .15, al))
	for i in 8:
		var u := i / 7.0
		Spr.seg(x + w * u, y, x + w * u + sin(T * .05 + i) * 2, y + h, c, 1.5)
	var rows := int(h / 14)
	for j in rows + 1:
		var yy: float = y + j * h / rows
		var pts := PackedVector2Array()
		for i in 8:
			pts.push_back(Vector2(x + w * i / 7.0 + sin(T * .05 + i) * 2 * (j / float(rows)), yy + (2.0 if i % 2 else -2.0)))
		Spr.line(pts, c, 1.5)

# ---------- picareta arremessada ----------
static func _pick(k: Dictionary) -> void:
	Spr.save()
	Spr.translate(k.x, k.y)
	if k.st == "stuck":
		Spr.scale(-1 if k.dir > 0 else 1, 1)
		# cabo saindo da parede (é o degrau)
		Spr.rr(0, -4, 34, 7, 3, WOOD)
		Spr.rect(0, -4, 34, 2, Color("#a87a4c"))
		Spr.poly(PackedVector2Array([Vector2(-2, -12), Vector2(6, -4), Vector2(6, 4), Vector2(-2, 12)]), STEEL_D)
	else:
		Spr.rotate(k.rot)
		Spr.rr(-3, -2, 6, 30, 3, WOOD)
		var hd := PackedVector2Array([Vector2(-20, 4), Vector2(-8, -3), Vector2(8, -3), Vector2(20, 4), Vector2(8, 1), Vector2(-8, 1)])
		Spr.poly(hd, STEEL)
		Spr.line(hd, STEEL_D, 1.5)
	Spr.restore()

# ---------- planta carnívora (inimigo) ----------
static func plant(e: Dictionary, T: int) -> void:
	# desenhada no referencial do inimigo (origem no chão, virada para e.dir)
	var lx: float = e.get("lx", 0.0)
	var st: int = e.get("st", 0)
	var stun: bool = e.get("stun", 0) > 0 and not e.dead
	var sway: float = sin(T * .06 + e.x) * 3.0
	var hx: float = 18 + lx + sway
	var hy: float = -48.0 + (16.0 if stun else 0.0)
	# folhas na base
	Spr.ellipse(-16, -4, 16, 6, Color("#3f6a2a"), .5)
	Spr.ellipse(14, -4, 16, 6, Color("#3f6a2a"), -.5)
	# caule em curva
	Spr.line(PackedVector2Array([Vector2(0, 0), Vector2(-6, -18), Vector2(hx * .4, -36 + (10.0 if stun else 0.0)), Vector2(hx - 10, hy + 6)]), Color("#4f7a2c"), 7)
	# boca
	var open: float = .15
	if st == 1:
		open = .9
	elif st == 2:
		open = .05
	elif st == 0:
		open = .25 + sin(T * .08) * .1
	if stun:
		open = .05
	Spr.save()
	Spr.translate(hx, hy)
	Spr.rotate(.6 if stun else 0.0)
	var top := PackedVector2Array()
	var bot := PackedVector2Array()
	for i in 9:
		var a: float = PI * i / 8.0
		top.push_back(Vector2(-cos(a) * 22, -sin(a) * 16 - open * 6))
		bot.push_back(Vector2(-cos(a) * 22, sin(a) * 14 + open * 6))
	Spr.ellipse(0, 0, 20, 4 + open * 10, Color("#b02a2a"))
	Spr.poly(top, Color("#6fae3c"))
	Spr.poly(bot, Color("#5c9a32"))
	# dentes
	for i in 5:
		var tx: float = -14 + i * 7
		Spr.poly(PackedVector2Array([Vector2(tx - 3, -open * 6), Vector2(tx, -open * 6 + 6), Vector2(tx + 3, -open * 6)]), Color("#fbf3dc"))
		Spr.poly(PackedVector2Array([Vector2(tx - 3, open * 6), Vector2(tx, open * 6 - 6), Vector2(tx + 3, open * 6)]), Color("#fbf3dc"))
	# pintinhas e olhos
	for d in [[-10, -10], [4, -13], [10, 9]]:
		Spr.circle(d[0], d[1], 2.5, Color("#e8d25a"))
	if stun:
		Spr.seg(-14, -18, -8, -12, OUT, 2)
		Spr.seg(-14, -12, -8, -18, OUT, 2)
	else:
		Spr.circle(-10, -18, 4, Color("#fbf3dc"))
		Spr.circle(-9, -18, 2, OUT)
	Spr.line(top, OUT, 1.5)
	Spr.line(bot, OUT, 1.5)
	Spr.restore()

static func _icicle(o: Dictionary, T: int) -> void:
	if o.st == "broken":
		return
	var ln: float = o.get("len", 46) * (o.grow if o.st == "idle" else 1.0)
	var sx: float = sin(T * 1.7) * 2.0 if o.st == "shake" else 0.0
	var y: float = o.y + o.fy
	var w: float = 24.0
	var pts := PackedVector2Array([Vector2(o.x - w / 2 + sx, y), Vector2(o.x + w / 2 + sx, y), Vector2(o.x + sx, y + ln)])
	Spr.poly(pts, Color(.82, .94, 1, .96))
	Spr.ci.draw_polyline(pts + PackedVector2Array([pts[0]]), Color(.35, .55, .75), 2, true)
	Spr.seg(o.x - 3 + sx, y + 3, o.x - 1 + sx, y + ln * .7, Color(1, 1, 1, .8), 2)
	if o.st == "shake" and (T / 4) % 2 == 0:
		Spr.seg(o.x - 12, y - 2, o.x + 12, y - 2, Color(1, 1, 1, .7), 2)

## por cima do Tomé: a superfície da areia movediça (esconde as pernas que afundaram)
static func draw_front(g: Game, T: int) -> void:
	var TR: Traps = g.TR
	if TR == null:
		return
	for o in TR.T:
		if o.k == "sand" and o.x < g.cam + g.W + 100 and o.x + o.w > g.cam - 100:
			_sand_front(o, T)

# ---------- tronco-pêndulo ----------
static func _swing(TR: Traps, o: Dictionary, T: int) -> void:
	var e := TR.swing_end(o)
	# galho grosso da árvore de onde ele pende
	Spr.rr(o.x - 80, o.y - 14, 160, 22, 8, WOOD_D)
	Spr.rr(o.x - 80, o.y - 14, 160, 8, 4, WOOD)
	Spr.ring(o.x - 80, o.y - 3, 10, OUT, 2)
	# rastro
	var dv: float = TR.swing_dir(o)
	for k in 3:
		Spr.rr(e.x - 44 - dv * (k + 1) * 12, e.y - 12, 88, 24, 10, Color(1, 1, 1, .05))
	# cordas
	for sx in [-30.0, 30.0]:
		Spr.seg(o.x + sx, o.y, e.x + sx, e.y - 8, Color("#c9a26a"), 3)
		Spr.circle(o.x + sx, o.y, 4, Color("#7a5a32"))
	# o tronco (sempre deitado)
	Spr.rr(e.x - 46, e.y - 13, 92, 26, 12, Color("#6b4626"))
	Spr.rr(e.x - 46, e.y - 13, 92, 9, 6, Color("#8a5e34"))
	for k in 3:
		Spr.seg(e.x - 30 + k * 26, e.y - 6, e.x - 18 + k * 26, e.y + 4, Color("#4e331d"), 2)
	Spr.ellipse(e.x + 44, e.y, 6, 12, Color("#c9a26a"))
	Spr.ring(e.x + 44, e.y, 4, Color("#8a6a42"), 1.5)
	Spr.rect(e.x - 26, e.y - 14, 6, 28, Color("#c9a26a"))
	Spr.rect(e.x + 22, e.y - 14, 6, 28, Color("#c9a26a"))

# ---------- colmeia e enxame ----------
static func _hive(o: Dictionary, T: int) -> void:
	var x: float = o.x
	var y: float = o.y
	var sh: float = sin(T * .9) * 2.0 if o.st == "angry" and o.t < 40 else 0.0
	# galho e cordinha
	Spr.rr(x - 70, y - 70, 140, 14, 6, WOOD_D)
	Spr.seg(x, y - 58, x + sh, y - 50, Color("#5a4632"), 3)
	# colmeia em gomos
	for k in 4:
		var w: float = [20.0, 26.0, 24.0, 16.0][k]
		Spr.ellipse(x + sh, y - 44 + k * 11, w, 8, Color("#d9a441").darkened(k * .05))
		Spr.ellipse(x + sh, y - 46 + k * 11, w, 3, Color("#f0c766"))
	Spr.ellipse(x + sh, y - 6, 6, 5, Color("#3a2410"))
	if o.st == "idle":
		for k in 3:
			var a: float = T * .07 + k * 2.1
			_bee(x + cos(a) * 30, y - 26 + sin(a * 1.3) * 16, T + k * 7)
	else:
		# o enxame: uma nuvem escura zunindo com abelhas em volta
		Spr.circle(o.sx, o.sy, 30 + sin(T * .3) * 3, Color(.15, .1, 0, .22))
		for k in 18:
			var a2: float = T * .23 + k * .9
			var r: float = 10 + (k % 5) * 6
			_bee(o.sx + cos(a2) * r, o.sy + sin(a2 * 1.4) * r * .7, T + k * 5)

static func _bee(x: float, y: float, t: int) -> void:
	Spr.ellipse(x, y, 6.5, 4.6, Color("#f2c230"))
	Spr.rect(x - 2, y - 4.5, 2.5, 9, Color("#2a1a0e"))
	Spr.rect(x + 2, y - 4, 2, 8, Color("#2a1a0e"))
	var wy: float = -4.0 - (3.0 if (t / 2) % 2 == 0 else 0.0)
	Spr.ellipse(x - 1, y + wy, 4.5, 3, Color(1, 1, 1, .75))
	Spr.ellipse(x + 3, y + wy, 3.5, 2.5, Color(1, 1, 1, .6))

# ---------- areia movediça ----------
static func _sand_back(o: Dictionary, T: int) -> void:
	var x: float = o.x
	var y: float = o.y
	Spr.rect(x, y - 2, o.w, 44, Color("#8a7448"))
	Spr.vgrad(x, y + 6, o.w, 40, Color("#7a643c"), Color("#4a3a20"))

static func _sand_front(o: Dictionary, T: int) -> void:
	var x: float = o.x
	var y: float = o.y
	var w: float = o.w
	var pts := PackedVector2Array()
	for i in 13:
		var px: float = x + w * i / 12.0
		pts.push_back(Vector2(px, y - 2 + sin(T * .05 + i * .9) * 1.5))
	pts.push_back(Vector2(x + w, y + 40))
	pts.push_back(Vector2(x, y + 40))
	Spr.poly(pts, Color("#a88c58"))
	for k in 4:
		var rx: float = x + 20 + fmod(k * 47.0 + T * .15, w - 40)
		Spr.ellipse(rx, y + 4, 14 + sin(T * .06 + k) * 4, 3, Color("#8a7448"))
	Spr.ellipse(x + 10, y + 1, 12, 3, Color("#c4a872"))
	Spr.seg(x, y - 1, x + w, y - 1, Color("#5e4a2a"), 2)

# ---------- teia de aranha ----------
static func _web(o: Dictionary, T: int) -> void:
	var x: float = o.x
	var y: float = o.y
	var w: float = o.w
	var h: float = o.h
	var cx: float = x + w / 2
	var cy: float = y + h * .45
	var c := Color(.94, .94, .97, .8)
	if o.cut:
		# fiapos pendurados
		if o.t < 200:
			for k in 4:
				var fx: float = x + 8 + k * (w - 16) / 3.0
				Spr.seg(fx, y, fx + sin(T * .05 + k) * 4, y + 26 + k % 2 * 10, Color(c.r, c.g, c.b, .5), 1)
		return
	# moldura entre os galhos
	Spr.seg(x, y, x + w, y, Color("#5a4632"), 4)
	Spr.seg(x, y, x - 4, y + h, Color("#5a4632"), 4)
	Spr.seg(x + w, y, x + w + 4, y + h, Color("#5a4632"), 4)
	var spokes := 9
	for k in spokes:
		var a: float = TAU * k / spokes
		Spr.seg(cx, cy, cx + cos(a) * w * .62, cy + sin(a) * h * .62, c, 1.3)
	for r in 5:
		var rr: float = (r + 1) / 5.0
		var ring := PackedVector2Array()
		for k in spokes + 1:
			var a2: float = TAU * k / spokes
			ring.push_back(Vector2(cx + cos(a2) * w * .5 * rr, cy + sin(a2) * h * .5 * rr))
		Spr.line(ring, c, 1.1)
	# a aranha descendo no fio
	var sy: float = y + 10 + (1.0 + sin(T * .03)) * 18
	Spr.seg(x + w - 14, y, x + w - 14, sy, Color(1, 1, 1, .5), 1)
	Spr.circle(x + w - 14, sy + 5, 6, Color("#2a1a2e"))
	for k in 4:
		Spr.seg(x + w - 14 - 5, sy + 3 + k * 2, x + w - 14 - 11, sy - 1 + k * 4, Color("#2a1a2e"), 1.5)
		Spr.seg(x + w - 14 + 5, sy + 3 + k * 2, x + w - 14 + 11, sy - 1 + k * 4, Color("#2a1a2e"), 1.5)
	Spr.circle(x + w - 16, sy + 4, 1.4, Color(1, .3, .3))

# ---------- rajadas de vento ----------
static func _gust(TR: Traps, o: Dictionary, T: int) -> void:
	var st: int = TR.gust_state(o)
	if st == 0:
		return
	var a: float = .2 if st == 1 else .55
	var n: int = 6 if st == 1 else 16
	for k in n:
		var sp: float = 9.0 if st == 2 else 5.0
		var lx: float = o.x + o.w - fmod(T * sp + k * 97.0, o.w + 120)
		var ly: float = o.y + fmod(k * 53.0, o.h)
		Spr.seg(lx, ly, lx + 40 + (k % 3) * 18, ly + 1, Color(1, 1, 1, a), 2)
		if k % 3 == 0:
			Spr.circle(lx - 6, ly + sin(T * .3 + k) * 4, 2.5, Color(1, 1, 1, a + .2))

# ---------- ponte de cordas ----------
static func _bridge(o: Dictionary, T: int) -> void:
	var y: float = o.y
	var x0: float = o.x
	var x1: float = o.x + o.w
	# postes nas duas pontas
	for px in [x0 - 10, x1 + 4]:
		Spr.rect(px, y - 60, 8, 76, WOOD_D)
		Spr.circle(px + 4, y - 60, 5, WOOD)
	# corrimão de corda (some atrás da frente que desabou)
	var ca: float = max(x0, o.get("front", x0)) if o.st != "idle" else x0
	if ca < x1:
		var pts := PackedVector2Array()
		var steps := 24
		for i in steps + 1:
			var xx: float = lerpf(ca, x1, i / float(steps))
			var sag: float = sin(PI * (xx - x0) / (x1 - x0)) * 14
			pts.push_back(Vector2(xx, y - 40 + sag))
		Spr.line(pts, Color("#c9a26a"), 3)
	if o.st != "idle" and o.get("front", x0) > x0:
		var fx: float = o.front
		Spr.seg(fx, y - 30, fx - 20, y + 60, Color("#c9a26a"), 2)
	for pl in o.planks:
		if pl.down and pl.fy > 600:
			continue
		var sh: float = 0.0
		if o.st == "go" and not pl.down and pl.x - o.front < 90:
			sh = sin(T * 1.3 + pl.x) * 1.5
		var py: float = y + pl.fy + sh + sin(PI * (pl.x + 20 - x0) / (x1 - x0)) * 6
		Spr.save()
		Spr.translate(pl.x + 20, py + 6)
		if pl.down:
			Spr.rotate(pl.fy * .01)
		Spr.rr(-19, -6, 38, 12, 3, Color("#8a5e34"))
		Spr.rect(-19, -6, 38, 3, Color("#a87a48"))
		Spr.seg(-12, -6, -12, 6, Color("#4e331d"), 1.5)
		Spr.seg(12, -6, 12, 6, Color("#4e331d"), 1.5)
		Spr.restore()

# ---------- bola de pedra gigante ----------
static func _boulder(g: Game, o: Dictionary, T: int) -> void:
	# buraco no teto de onde ela cai
	Spr.ellipse(o.x, o.y - 120, o.r * 1.1, 10, Color(.05, .04, .03))
	if o.st in ["idle", "done"]:
		if o.st == "done":
			for k in 6:
				Spr.ellipse(o.end - 40 + k * 22, o.y - 6 - (k % 2) * 8, 16, 10, Color("#6b6a62"))
		return
	var R: float = o.r
	var cx: float = o.bx
	var cy: float = o.by
	if o.st == "break":
		var k2: float = o.t / 30.0
		for i in 8:
			var a: float = i * TAU / 8.0
			Spr.circle(cx + cos(a) * R * k2 * 1.5, cy + sin(a) * R * .6 * k2 + k2 * k2 * 40, R * .35 * (1.0 - k2 * .5), Color("#6b6a62"))
		return
	Spr.ellipse(cx, o.y + 2, R * .95, 7, Color(0, 0, 0, .35))
	Spr.circle(cx, cy, R, Color("#6e6a5e"))
	Spr.circle(cx - R * .22, cy - R * .25, R * .62, Color("#837e70"))
	Spr.circle(cx - R * .35, cy - R * .4, R * .25, Color("#958f80"))
	Spr.save()
	Spr.translate(cx, cy)
	Spr.rotate(o.rot)
	for k in 7:
		var a3: float = k * .9
		Spr.seg(cos(a3) * R * .15, sin(a3) * R * .15, cos(a3 + .5) * R * .9, sin(a3 + .5) * R * .9, Color("#4a463e"), 3)
	for k in 5:
		var a4: float = k * 1.25 + .4
		Spr.ellipse(cos(a4) * R * .55, sin(a4) * R * .55, 9, 6, Color("#57534a"), a4)
	Spr.restore()
	Spr.ring(cx, cy, R, OUT, 3)

## caixas, carrinho e barricada do trecho da bola (somem quando ela passa)
static func _bobs(g: Game, T: int) -> void:
	var c0: float = g.cam - 200
	var c1: float = g.cam + g.W + 200
	for s in g.SOL:
		if not s.get("bob") or s.x > c1 or s.x + s.w < c0:
			continue
		match s.bob:
			"crate":
				_box(s.x, s.y, s.w, s.h)
			"crate2":
				_box(s.x, s.y + s.h / 2, s.w, s.h / 2)
				_box(s.x + 4, s.y, s.w - 8, s.h / 2)
			"cart":
				Spr.AB("mi_cart", s.x - 8, s.y + s.h - 70, s.w + 16, 70)
			"barricade":
				for k in 4:
					Spr.rr(s.x - 6, s.y + 6 + k * 28, s.w + 12, 20, 3, Color("#7a5232").darkened(k * .05))
					Spr.rect(s.x - 6, s.y + 6 + k * 28, s.w + 12, 4, Color("#9a7044"))
				Spr.seg(s.x - 4, s.y + 8, s.x + s.w + 4, s.y + s.h - 8, Color("#4e331d"), 4)
				Spr.text("PERIGO", s.x + s.w / 2, s.y + 60, 11, Color("#f0d070"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 3, Color(0, 0, 0, .8))

static func _box(x: float, y: float, w: float, h: float) -> void:
	Spr.rect(x, y, w, h, Color("#8a5e34"))
	Spr.rect(x + 3, y + 3, w - 6, h - 6, Color("#a07040"))
	Spr.seg(x + 3, y + 3, x + w - 3, y + h - 3, Color("#6b4626"), 3)
	Spr.seg(x + w - 3, y + 3, x + 3, y + h - 3, Color("#6b4626"), 3)
	Spr.ci.draw_rect(Rect2(x, y, w, h), OUT, false, 2.0)

# ---------- cogumelo gigante ----------
static func _giant(o: Dictionary, T: int) -> void:
	var x: float = o.x
	var base: float = o.y
	var top: float = o.cap
	var w: float = o.w
	var c: Color = Color(o.get("c", "#6a5acd"))
	var sw: float = 16.0 + w * .08
	# caule
	Spr.poly(PackedVector2Array([Vector2(x - sw * .7, base), Vector2(x - sw * .5, top + 10), Vector2(x + sw * .5, top + 10), Vector2(x + sw * .8, base)]), Color("#e8dcc4"))
	Spr.poly(PackedVector2Array([Vector2(x + sw * .1, base), Vector2(x + sw * .2, top + 10), Vector2(x + sw * .5, top + 10), Vector2(x + sw * .8, base)]), Color("#cbbd9f"))
	Spr.ellipse(x, top + 16, sw * .9, 6, Color("#cbbd9f"))
	# chapéu
	var cap := PackedVector2Array()
	for i in 21:
		var a := PI + PI * i / 20.0
		cap.push_back(Vector2(x + cos(a) * w * .56, top + 8 + sin(a) * w * .3))
	Spr.poly(cap, c)
	Spr.ellipse(x, top + 8, w * .56, 7, c.darkened(.35))
	for d in [[-.3, -.15, .07], [.05, -.22, .08], [.3, -.1, .06], [-.08, -.06, .05], [.18, -.04, .04]]:
		Spr.circle(x + d[0] * w, top + 8 + d[1] * w, d[2] * w, Color(1, 1, 1, .55))
	Spr.line(cap, OUT, 2)

## bloco de gelo que levou a patada: brilha e treme um instante
static func _ice_hits(g: Game, T: int) -> void:
	for s in g.SOL:
		if s.get("shk", 0) > 0:
			s.shk -= 1
			var d: float = sin(T * 2.3) * s.shk * .25
			Spr.rr(s.x + d, s.y, s.w, s.h + 4, 5, Color(.85, .95, 1, .55 * s.shk / 18.0))

## teto de rocha com escoras e lampiões apagados ao longo de todo o túnel da mina
static func _tunnel_ceiling(g: Game, T: int) -> void:
	var tn: Array = g.L.get("tunnel", [])
	if tn.size() < 2:
		return
	var ca: float = max(float(tn[0]), g.cam - 40)
	var cb: float = min(float(tn[1]), g.cam + g.W + 40)
	if ca >= cb:
		return
	var y0: float = 350.0
	Spr.rect(ca, y0, cb - ca, 30, Color("#3a2c20"))
	Spr.rect(ca, y0 + 26, cb - ca, 5, Color("#5a4632"))
	var bx0: float = floor(ca / 260.0) * 260.0
	while bx0 < cb:
		# só escora onde há chão firme embaixo (não em cima de buracos)
		var ok := false
		for s in g.SOL:
			if s.t == "ground" and abs(s.y - 500) < 2 and s.x <= bx0 and s.x + s.w >= bx0 + 12:
				ok = true
				break
		if ok:
			Spr.rect(bx0, y0 + 30, 12, 120, Color("#4e331d"))
			Spr.rect(bx0 - 14, y0 + 26, 40, 10, Color("#6b4626"))
			if int(bx0 / 260.0) % 2 == 0:
				# lampião apagado pendurado
				Spr.seg(bx0 + 22, y0 + 36, bx0 + 22, y0 + 50, Color("#2a2018"), 2)
				Spr.rr(bx0 + 16, y0 + 50, 12, 16, 3, Color("#5a5048"))
				Spr.rect(bx0 + 18, y0 + 54, 8, 8, Color(.25, .22, .18))
		bx0 += 260.0
