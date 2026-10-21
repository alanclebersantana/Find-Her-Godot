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
