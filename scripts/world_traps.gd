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
			"hive": _hive(g, o, T)
			"sand": _sand_back(o, T)
			"web": _web(g, o, T)
			"gust": _gust(TR, o, T)
			"bridge": _bridge(o, T)
			"boulder": _boulder(g, o, T)
			"giant": _giant(o, T)
			"icicle": _icicle(g, o, T)
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
	# flor-catapulta pintada: aberta em repouso; carregando ela se fecha em botão e afunda
	var sq: float = max(0.0, pad)
	if sq > .35:
		var bw: float = 62.0 - sq * 8
		Spr.P("cat_bud", x, y + 3, bw, false, 0.0, Color(1, 1, 1))
	else:
		var ow: float = 76.0 * (1.0 - sq * .4)
		var hgt: float = Spr.PH("cat_open", ow) * (1.0 - sq * .5)
		Spr.PR("cat_open", x - ow / 2, y + 3 - hgt, ow, hgt)
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
	if o.get("smoke"):
		# fumaça quente da chaminé subindo (dá para planar em cima dela)
		Spr.vgrad(x, y, w, h, Color(.8, .8, .85, 0), Color(.8, .8, .85, .08))
		for k in 9:
			var u: float = fposmod(T * .006 + k / 9.0, 1.0)
			var sx: float = x + w / 2 + sin(u * 7.0 + k) * (6 + u * 18)
			var sy: float = y + h - u * h
			var r: float = 10 + u * 26
			Spr.circle(sx, sy, r, Color(.72, .72, .78, .32 * (1.0 - u)))
		return
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
	if Spr.has("p_spiketop"):
		# espetos de ferro pintados saindo pelas frestas da tábua (a tábua fica sempre no chão)
		var tw: float = w + 12.0
		var ns: int = max(1, int(round(tw / 110.0)))
		var sgw: float = tw / ns
		var rt: Array = Spr.AR["p_spiketop"]
		var rb: Array = Spr.AR["p_spikebase"]
		var full: float = 30.0
		var f: float = clamp(max(h, 0.0) / 26.0, 0.0, 1.0)
		for i in ns:
			var sx0: float = x - 6 + i * sgw + sh
			if f > .02:
				Spr.PB("spiketop", sx0, y + 1 - full * f, sgw, full * f, 0.0, f)
			var bh: float = sgw * rb[3] / rb[2]
			Spr.PR("spikebase", x - 6 + i * sgw, y - 4, sgw, bh)
		if h > 4:
			Spr.rr(x - 6, y - 2 - h - 3, w + 12, h + 6, 6, Color(1, .3, .2, .06 + .04 * sin(T * .1)))
		return
	Spr.rect(x - 4, y - 4, w + 8, 6, Color("#3a3026"))
	var n := int(w / 16)
	for i in n:
		var sx: float = x + (i + .5) * w / n + sh
		var hh: float = max(h, 3.0)
		Spr.poly(PackedVector2Array([Vector2(sx - 7, y - 2), Vector2(sx, y - 2 - hh), Vector2(sx + 7, y - 2)]), STEEL)
		Spr.poly(PackedVector2Array([Vector2(sx, y - 2), Vector2(sx, y - 2 - hh), Vector2(sx + 7, y - 2)]), STEEL_D)
	Spr.rect(x - 6, y - 2, w + 12, 5, Color("#2a2018"))
	# pontas brilhando de leve (perigo fácil de ver)
	if h > 4:
		var gl: float = .35 + .25 * sin(T * .1 + x)
		for i in n:
			var tx: float = x + (i + .5) * w / n + sh
			Spr.circle(tx, y - 2 - h + 2, 2.0, Color(1, .95, .85, gl))
		Spr.rr(x - 6, y - 2 - h - 3, w + 12, h + 6, 6, Color(1, .3, .2, .06 + .04 * sin(T * .1)))

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
	var w: float = TAU / float(o.per)
	var th: float = w * (T + o.get("ph", 0))
	var dirv: float = cos(th)
	# rastro em arco: a ponta da lâmina nos quadros anteriores (mais forte quando está rápido)
	var spd: float = abs(dirv)
	var trail := PackedVector2Array()
	for k in 10:
		var a2: float = o.amp * sin(th - w * k * 1.6)
		trail.push_back(Vector2(o.x + sin(a2) * (o.len + 18), o.y + cos(a2) * (o.len + 18)))
	for k in range(trail.size() - 1):
		Spr.seg(trail[k].x, trail[k].y, trail[k + 1].x, trail[k + 1].y, Color(1, 1, 1, .22 * spd * (1.0 - k / 10.0)), 10.0 - k * .8)
	# forca de madeira pintada (troncos)
	if o.has("frame"):
		var fx: float = o.frame
		Spr.PR("log", fx - 9, o.y - 18, 18, 520 - o.y, Color(.85, .8, .75), false)
		_beam_log(fx - 12, o.x + 16, o.y - 16, 16)
		Spr.seg(fx + 2, o.y + 36, fx + 38, o.y - 8, Color("#4a3220"), 7)
		Spr.seg(fx + 2, o.y + 36, fx + 38, o.y - 8, Color("#7a5634"), 3)
		Spr.circle(fx, o.y - 10, 4, STEEL)
	# haste de ferro e eixo
	Spr.seg(o.x, o.y, b.x, b.y, Color("#3a3026"), 7)
	Spr.seg(o.x, o.y, b.x, b.y, Color("#6a5a48"), 3)
	Spr.circle(o.x, o.y, 9, Color("#2a221c"))
	Spr.circle(o.x, o.y, 4, STEEL)
	Spr.save()
	Spr.translate(b.x, b.y)
	Spr.rotate(-a)
	# lâmina em meia-lua com fio brilhante e manchas de ferrugem
	var bl := PackedVector2Array()
	for i in 13:
		var t: float = -1.2 + 2.4 * i / 12.0
		bl.push_back(Vector2(sin(t) * 30, cos(t) * 16 + 4))
	for i in range(12, -1, -1):
		var t2: float = -1.2 + 2.4 * i / 12.0
		bl.push_back(Vector2(sin(t2) * 20, cos(t2) * 6 - 2))
	Spr.poly(bl, Color("#8a949e"))
	var edge := PackedVector2Array()
	for i in 13:
		var t3: float = -1.2 + 2.4 * i / 12.0
		edge.push_back(Vector2(sin(t3) * 29, cos(t3) * 15 + 3))
	Spr.line(edge, Color(.92, .96, 1, .9), 2.5)
	Spr.ellipse(-9, 6, 6, 3, Color(.55, .32, .18, .45))
	Spr.ellipse(10, 9, 4, 2, Color(.55, .32, .18, .4))
	Spr.line(bl, Color("#2a3038"), 2)
	Spr.rr(-6, -16, 12, 16, 3, Color("#4a3220"))
	Spr.rect(-6, -10, 12, 3, STEEL)
	Spr.restore()

## viga de tronco pintado deitada (de xa até xb, com altura h)
static func _beam_log(xa: float, xb: float, y: float, h: float) -> void:
	Spr.save()
	Spr.translate(xa, y + h)
	Spr.rotate(-PI / 2)
	Spr.PR("log", 0, 0, h, xb - xa, Color(.9, .85, .8), false)
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
	# galho pintado (tora fina com casca)
	WorldVehicles._hlog(-w / 2, w / 2, -8, 15)
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
	if Spr.has("p_cage"):
		# gaiola de ferro pintada (argola em cima presa na corda)
		Spr.PR("cage", x - 10, top - 30, w + 20, y - top + 34)
		return
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
	if Spr.has("p_net"):
		Spr.PR("net", x - 10, y - 14, w + 20, h + 14, Color(1, 1, 1, al))
		return
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
	if Spr.has("p_plant"):
		# planta carnívora pintada: a cabeça avança (bote), abre e fecha esticando a arte
		var opn: float = .25 + sin(T * .08) * .1
		if st == 1:
			opn = 1.0
		elif st == 2 or stun:
			opn = 0.0
		Spr.save()
		Spr.translate(sway * .5, 0)
		if stun:
			Spr.rotate(.25)
		Spr.translate(lx * .5, 0)
		Spr.scale(1.0 + lx * .004, 1.0 + opn * .08)
		Spr.P("plant", 4, 2, 92, true)
		Spr.restore()
		if stun:
			for k in 3:
				var a2 := T * .15 + TAU * k / 3.0
				Spr.text("★", hx + cos(a2) * 14, hy - 20 + sin(a2) * 4, 10, Color("#ffe27a"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 2)
		return
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

static func _icicle(g: Game, o: Dictionary, T: int) -> void:
	var ln: float = o.get("len", 46)
	var fl: float = o.get("floor", o.y + 300)
	var w: float = ln * .55
	# base de gelo presa no teto (fica mesmo quando o pingente cai, e de onde ele volta a crescer)
	Spr.ellipse(o.x, o.y + 2, w * .75, 7, Color("#9cc4e4"))
	Spr.ellipse(o.x, o.y, w * .7, 5, Color("#d8eeff"))
	if o.st == "broken":
		# pingente novo nascendo: um toquinho que vai aparecendo
		var gr: float = clamp(o.t / 150.0, 0, 1)
		if gr > .05:
			Spr.PR("icicle", o.x - w * .5 * gr, o.y, w * gr, ln * gr * .35)
		return
	var gk: float = o.grow if o.st == "idle" else 1.0
	var sx: float = sin(T * 1.9) * 2.5 if o.st == "shake" else 0.0
	var y: float = o.y + o.fy
	# sombra no chão: cresce enquanto ele treme e cai (mostra onde vai acertar)
	if o.st in ["shake", "fall"]:
		var sk: float = clamp(o.t / 60.0, 0, 1) if o.st == "shake" else clamp((y + ln - o.y) / (fl - o.y), 0, 1) * .5 + .5
		Spr.ellipse(o.x, fl + 1, 10 + 16 * sk, 4, Color(0, .05, .15, .25 + .3 * sk))
	# brilho frio em volta: é perigo, diferente dos pingentes do teto
	Spr.glow(o.x, y + ln * gk * .45, 26, Color(.6, .85, 1, .18 + (.2 if o.st == "shake" else 0.0)))
	if o.st == "fall":
		# rastro brilhante da queda
		for k in 4:
			Spr.seg(o.x - 3 + k * 2, y - 8 - k * 10, o.x - 3 + k * 2, y - 30 - k * 14, Color(.85, .95, 1, .35 - k * .07), 2)
	Spr.PR("icicle", o.x - w * .5 * gk + sx, y, w * gk, ln * gk)
	if o.st == "shake":
		# rachando: estalos brancos na base e lasquinhas caindo
		if (T / 4) % 2 == 0:
			Spr.seg(o.x - w * .4, y + 3, o.x - 2, y + 7, Color(1, 1, 1, .8), 1.5)
			Spr.seg(o.x + 2, y + 6, o.x + w * .4, y + 2, Color(1, 1, 1, .8), 1.5)
		if T % 6 == 0:
			g.PARTS.append({"x": o.x + randf_range(-w * .4, w * .4), "y": y + 6, "vx": randf_range(-.4, .4), "vy": 1.5, "life": 24, "col": Color(.85, .95, 1, .9)})

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
	# galho grosso da árvore de onde ele pende (tronco pintado)
	_beam_log(o.x - 84, o.x + 84, o.y - 14, 22)
	# rastro em arco do tronco
	var w: float = TAU / float(o.per)
	var th: float = w * (T + o.get("ph", 0))
	var spd: float = abs(cos(th))
	for k in range(1, 7):
		var a2: float = o.amp * sin(th - w * k * 2.0)
		var q := Vector2(o.x + sin(a2) * o.len, o.y + cos(a2) * o.len)
		Spr.rr(q.x - 44, q.y - 12, 88, 24, 11, Color(1, 1, 1, .07 * spd * (1.0 - k / 7.0)))
	# cordas trançadas
	for sx in [-30.0, 30.0]:
		Spr.seg(o.x + sx, o.y, e.x + sx, e.y - 8, Color("#7a5a32"), 4)
		Spr.seg(o.x + sx, o.y, e.x + sx, e.y - 8, Color("#d4ae74"), 2)
		Spr.circle(o.x + sx, o.y, 5, Color("#5a4026"))
	# o tronco pintado (sempre deitado), com as pontas cortadas
	Spr.save()
	Spr.translate(e.x - 46, e.y + 13)
	Spr.rotate(-PI / 2)
	Spr.PR("log", 0, 0, 26, 92)
	Spr.restore()
	Spr.P("logend0", e.x + 44, e.y + 13, 22)
	for sx2 in [-26.0, 24.0]:
		Spr.rect(e.x + sx2, e.y - 14, 5, 28, Color("#b58a52"))
		Spr.rect(e.x + sx2, e.y - 14, 5, 28, Color(0, 0, 0, .0))
		Spr.seg(e.x + sx2, e.y - 14, e.x + sx2 + 5, e.y + 14, Color("#7a5a32"), 1.5)

# ---------- colmeia e enxame ----------
static func _ground_at(g: Game, x: float, y: float) -> float:
	var best := 99999.0
	for so in g.SOL:
		if str(so.get("t", "")) in ["ground", "dirt", "cliff"] and x >= so.x and x <= so.x + so.w and so.y >= y and so.y < best:
			best = so.y
	return best if best < 99999.0 else y + 80.0

static func _hive(g: Game, o: Dictionary, T: int) -> void:
	var x: float = o.x
	var y: float = o.y
	var sh: float = sin(T * .9) * 2.0 if o.st == "angry" and o.t < 40 else 0.0
	# árvore de verdade: tronco no chão à esquerda e um galho comprido por cima do caminho
	var tx: float = o.get("tx", x - 72)
	var tw: float = o.get("tw", 92)
	if not o.has("gy"):
		o.gy = _ground_at(g, tx, y)
	var by: float = y - 72
	Spr.img(Spr.tex.tronco, tx - tw / 2, by - 150, tw, o.gy - by + 160)
	Spr.img(Spr.tex.galho, tx - 10, by - 22, 200, 50)
	# cordinha e a colmeia pintada (racha e escorre mel quando o enxame sai)
	Spr.seg(x, by + 14, x + sh, y - 52, Color("#5a4632"), 2.5)
	Spr.P("hive_broken" if o.st != "idle" else "hive", x + sh, y + 2, 46)
	if o.st == "idle":
		for k in 3:
			var a: float = T * .07 + k * 2.1
			_bee(x + cos(a) * 30, y - 26 + sin(a * 1.3) * 16, T + k * 7)
	else:
		# o enxame: uma nuvem escura zunindo com abelhas em volta
		Spr.circle(o.sx, o.sy, 30 + sin(T * .3) * 3, Color(.15, .1, 0, .18))
		for k in 16:
			var a2: float = T * .23 + k * .9
			var r: float = 10 + (k % 5) * 6
			_bee(o.sx + cos(a2) * r, o.sy + sin(a2 * 1.4) * r * .7, T + k * 5)

static func _bee(x: float, y: float, t: int) -> void:
	Spr.P("bee", x, y + 5 + (1.0 if (t / 2) % 2 == 0 else 0.0), 13, (t / 9) % 2 == 0)

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
static func _web(g: Game, o: Dictionary, T: int) -> void:
	var x: float = o.x
	var y: float = o.y
	var w: float = o.w
	var h: float = o.h
	var c := Color(.94, .94, .97, .8)
	# a teia fica presa entre dois troncos firmes, um de cada lado
	if not o.has("gy"):
		o.gy = _ground_at(g, x + w / 2, y + h - 10)
	var gy: float = o.gy
	Spr.img(Spr.tex.tronco, x - 42, y - 60, 52, gy - y + 70)
	Spr.img(Spr.tex.tronco, x + w - 8, y - 80, 46, gy - y + 90)
	if o.cut:
		# fiapos pendurados balançando
		if o.t < 200:
			for k in 4:
				var fx: float = x + 8 + k * (w - 16) / 3.0
				Spr.seg(fx, y, fx + sin(T * .05 + k) * 4, y + 26 + k % 2 * 10, Color(c.r, c.g, c.b, .5), 1)
		return
	# fios de ancoragem até o tronco, a pedra e o chão
	Spr.seg(x - 8, y - 6, x + 6, y + 8, c, 1.2)
	Spr.seg(x + w + 8, y + h - 14, x + w - 6, y + h - 22, c, 1.2)
	Spr.PR("web", x - 4, y - 4, w + 8, h + 8, Color(1, 1, 1, .92))
	# gotinhas brilhando
	for k in 3:
		Spr.circle(x + w * (.3 + k * .2), y + h * (.35 + (k % 2) * .25), 1.6, Color(.85, .95, 1, .5 + .4 * sin(T * .05 + k)))
	# a aranha pequena no canto, que sobe e desce um pouco
	var sy: float = y + 10 + (1.0 + sin(T * .03)) * 10
	Spr.seg(x + w - 14, y, x + w - 14, sy, Color(1, 1, 1, .5), 1)
	WorldExtras._pc("spider_hang", x + w - 14, sy + 8, 16)

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
	# postes nas duas pontas (estacas pintadas)
	for px in [x0 - 10, x1 + 4]:
		Spr.PR("stake", px - 2, y - 64, 12, 80)
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
		if Spr.has("p_plank"):
			Spr.PR("plank", -21, -7, 42, 14)
		else:
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
				Spr.P("peb%d" % (k % 3), o.end - 40 + k * 22, o.y + 2, 24 + (k % 2) * 10)
		return
	var R: float = o.r
	var cx: float = o.bx
	var cy: float = o.by
	if o.st == "break":
		var k2: float = o.t / 30.0
		for i in 8:
			var a: float = i * TAU / 8.0
			var rs: float = R * .7 * (1.0 - k2 * .5)
			Spr.PR("rock2", cx + cos(a) * R * k2 * 1.5 - rs / 2, cy + sin(a) * R * .6 * k2 + k2 * k2 * 40 - rs / 2, rs, rs)
		return
	Spr.ellipse(cx, o.y + 2, R * .95, 7, Color(0, 0, 0, .35))
	# rocha pintada girando (a mesma arte das pedras do jogo), com a luz sempre por cima
	Spr.save()
	Spr.translate(cx, cy)
	Spr.rotate(o.rot)
	Spr.PR("rock0", -R * 1.08, -R * 1.08, R * 2.16, R * 2.16)
	Spr.restore()
	Spr.glow(cx - R * .3, cy - R * .45, R * .7, Color(1, .95, .85, .08))

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
## altura da arte do saltador para a largura w (proporção da pintura)
static func _salt_h(w: float) -> float:
	var r: Array = Spr.AR["p_saltador0"]
	return w * r[3] / r[2]

static func _giant(o: Dictionary, T: int) -> void:
	var x: float = o.x
	var base: float = o.y
	var top: float = o.cap
	var w: float = o.w
	var c: Color = Color(o.get("c", "#6a5acd"))
	var bouncy: bool = o.has("to")
	if bouncy and Spr.has("p_saltador0"):
		_giant_spring(o, T)
		return
	if not bouncy:
		# os gigantes comuns ficam apagados: só os laranjas com mola chamam atenção
		c = c.darkened(.35)
	var sw: float = 16.0 + w * .08
	# caule: levemente curvo, com fibras, anel debaixo do chapéu; nos buracos ele nasce
	# de um bulbo com raízes e some numa névoa escura (não desce reto e liso)
	var deep: bool = base > 560
	var bend: float = (1.0 if sin(x * .37) > 0 else -1.0) * sw * (.9 + .5 * abs(sin(x * .013)))
	var L := PackedVector2Array()
	var Rr := PackedVector2Array()
	var n := 12
	for i in n + 1:
		var t: float = i / float(n)
		var yy: float = lerpf(top + 10, base, t)
		var cx: float = x + bend * sin(t * PI)
		var hw: float = sw * lerpf(.5, .8, t) + (sw * .45 * pow(t, 6.0) if not deep else 0.0)
		L.push_back(Vector2(cx - hw, yy))
		Rr.push_back(Vector2(cx + hw, yy))
	var body := L.duplicate()
	var rv := Rr.duplicate()
	rv.reverse()
	body.append_array(rv)
	Spr.poly(body, Color("#e2d4b8"))
	# sombra do lado direito e fibras verticais
	var sh := PackedVector2Array()
	for i in n + 1:
		sh.push_back(L[i].lerp(Rr[i], .62))
	var rv2 := Rr.duplicate()
	rv2.reverse()
	sh.append_array(rv2)
	Spr.poly(sh, Color("#bfae8e"))
	for f in 5:
		var u: float = .18 + f * .16
		var pts := PackedVector2Array()
		for i in n + 1:
			pts.push_back(L[i].lerp(Rr[i], u + sin(i * 1.3 + f) * .02))
		Spr.line(pts, Color(.45, .36, .25, .22), 1.3)
	Spr.line(L, Color(.25, .18, .12, .55), 1.6)
	Spr.line(Rr, Color(.25, .18, .12, .55), 1.6)
	# anel (saia) logo abaixo do chapéu
	Spr.ellipse(x + bend * .1, top + 22, sw * .95, 5, Color("#d8c8a6"))
	Spr.ellipse(x + bend * .1, top + 24, sw * .95, 3, Color(.3, .22, .15, .35))
	if deep:
		# some no fundo escuro do buraco com névoa
		var fy: float = max(top + 60, 560.0)
		Spr.vgrad(x - sw * 1.6, fy, sw * 3.2, base - fy + 4, Color(.04, .05, .1, 0), Color(.04, .05, .1, 1))
		for k in 3:
			var mx: float = x + sin(T * .01 + k * 2.0 + x) * 18
			Spr.ellipse(mx, fy + 60 + k * 18, sw * 2.2, 10, Color(.55, .65, .85, .1))
	else:
		# bulbo com raízes no chão
		Spr.ellipse(x, base - 3, sw * 1.3, 7, Color("#cbbd9f"))
		for r in [-1.0, -.4, .5, 1.0]:
			Spr.seg(x + r * sw * .7, base - 4, x + r * sw * 1.6, base + 3, Color("#8a7458"), 2.2)
		Spr.ellipse(x, base + 1, sw * 1.5, 4, Color(.2, .3, .12, .6))
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

## cogumelo gigante saltador: chapéu laranja com pintas amarelas, mola no caule, brilho, setas
## e o arco a lápis mostrando para onde ele lança
static func _giant_spring(o: Dictionary, T: int) -> void:
	var x: float = o.x
	var base: float = o.y
	var cap: float = o.cap
	var aw: float = o.w * 1.12
	var ah: float = _salt_h(aw)
	var sq: float = o.get("squash", 0.0)
	var atop: float = cap - ah * .05
	var abot: float = min(atop + ah, base + 4.0)
	# caule de baixo (nos cogumelos altos) até onde começa a mola
	if base > abot + 4:
		var sw: float = 14.0
		Spr.poly(PackedVector2Array([Vector2(x - sw, abot - 4), Vector2(x + sw, abot - 4), Vector2(x + sw * 1.3, base), Vector2(x - sw * 1.3, base)]), Color("#e2d4b8"))
		Spr.poly(PackedVector2Array([Vector2(x + 2, abot - 4), Vector2(x + sw, abot - 4), Vector2(x + sw * 1.3, base), Vector2(x + 4, base)]), Color("#bfae8e"))
		Spr.line(PackedVector2Array([Vector2(x - sw, abot - 4), Vector2(x - sw * 1.3, base)]), Color(.25, .18, .12, .55), 1.6)
		Spr.line(PackedVector2Array([Vector2(x + sw, abot - 4), Vector2(x + sw * 1.3, base)]), Color(.25, .18, .12, .55), 1.6)
		if base > 560:
			var fy: float = max(abot + 40, 560.0)
			Spr.vgrad(x - 30, fy, 60, base - fy + 4, Color(.04, .05, .1, 0), Color(.04, .05, .1, 1))
	else:
		Spr.ellipse(x, base + 1, aw * .32, 5, Color(0, 0, 0, .3))
	# brilho pulsando em volta do chapéu
	Spr.glow(x, cap + 10, aw * .75, Color(1, .6, .2, .22 + .08 * sin(T * .1 + x)))
	# amassa quando lança (troca para a pose achatada) e volta esticando
	if sq > .35 and Spr.has("p_saltador1"):
		Spr.P("saltador1", x, abot, aw)
	else:
		var st: float = 1.0 + sin(T * .12 + x) * .015 - sq * .2
		Spr.save()
		Spr.translate(x, abot)
		Spr.scale(1.0 + sq * .12, st)
		Spr.P("saltador0", 0, 0, aw)
		Spr.restore()
	# setinhas subindo em cima do chapéu ("pule aqui!")
	for k in 2:
		var u: float = fposmod(T * .02 + k * .5, 1.0)
		var ay: float = atop - 14 - u * 34
		var al: float = sin(u * PI) * .9
		Spr.line(PackedVector2Array([Vector2(x - 11, ay + 8), Vector2(x, ay), Vector2(x + 11, ay + 8)]), Color(1, .92, .4, al), 4)

## arco a lápis até o próximo cogumelo (desenhado na camada de brilho: aparece no escuro da noite)
static func giant_arc(o: Dictionary, T: int) -> void:
	var x: float = o.x
	var cap: float = o.cap
	var to = o.get("to")
	if to is Array:
		var tx: float = float(to[0])
		var ty: float = float(to[1])
		var dx: float = tx - x
		var dy: float = ty - cap
		var nn: float = clamp(abs(dx) / 4.4, 30.0, 72.0) * float(o.get("arc", 1.0))
		nn = max(nn, sqrt(2.0 * (max(0.0, -dy) + 60.0) / Game.GRAV) * 1.15)
		var vy0: float = (dy - Game.GRAV * nn * (nn + 1) / 2.0) / nn
		# pontinhos de lápis ao longo do caminho (correndo devagar, mostrando a direção)
		var i: float = 3.0 + fposmod(T * .12, 4.0)
		while i <= nn:
			var fx: float = x + dx / nn * i
			var fy: float = cap + vy0 * i + Game.GRAV * i * (i + 1) / 2.0
			var a: float = .95 - .4 * i / nn
			Spr.circle(fx, fy - 22, 4.6, Color(.2, .15, .1, a * .5))
			Spr.circle(fx, fy - 22, 3.4, Color(1, .95, .75, a))
			i += 4.0
		# setinha no fim, apontando para o próximo cogumelo
		var ex: float = x + dx / nn * (nn - 3.0)
		var ey: float = cap + vy0 * (nn - 3.0) + Game.GRAV * (nn - 3.0) * (nn - 2.0) / 2.0 - 22
		var dv := Vector2(dx / nn, vy0 + Game.GRAV * (nn - 3.0)).normalized()
		var nv := Vector2(-dv.y, dv.x)
		var tip := Vector2(ex, ey) + dv * 8.0
		Spr.poly(PackedVector2Array([tip, Vector2(ex, ey) - dv * 4.0 + nv * 7.0, Vector2(ex, ey) - dv * 4.0 - nv * 7.0]), Color(1, .93, .7, .6))

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
	# teto de rocha com a borda de baixo irregular e pontas (estalactites), sem régua
	var top := PackedVector2Array([Vector2(ca - 10, y0 - 400)])
	var bot := PackedVector2Array()
	var xx: float = floor(ca / 14.0) * 14.0 - 14
	while xx <= cb + 14:
		var d: float = 26 + 5 * sin(xx * .05) + 3 * sin(xx * .13 + 1.0)
		var r: float = fposmod(xx * .37, 1.0)
		if fposmod(xx, 98.0) < 14 and r > .3:
			d += 12 + r * 14
		bot.push_back(Vector2(xx, y0 + d))
		xx += 14
	for p in bot:
		top.push_back(p)
	top.push_back(Vector2(cb + 10, y0 - 400))
	Spr.poly(top, Color("#3a2c20"))
	Spr.line(bot, Color("#5a4632"), 3)
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
