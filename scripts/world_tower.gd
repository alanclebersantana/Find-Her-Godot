extends RefCounted
class_name WorldTower
## Desenho da Torre no estilo Monument Valley: blocos geométricos em tons pastel, arcos,
## peças móveis com alças brilhando, a sala que gira e a torre da perspectiva.

const C := {
	"cream": [Color("#f4e6d3"), Color("#e6cdb6"), Color("#fff6ea")],
	"pink": [Color("#eab0ae"), Color("#d38f91"), Color("#f6cfcb")],
	"teal": [Color("#86c1b8"), Color("#62a39b"), Color("#b5e0d8")],
	"lilac": [Color("#bcaee0"), Color("#9b8cc8"), Color("#dcd2f3")],
	"gold": [Color("#ecc56d"), Color("#c99d3f"), Color("#f7e2a8")],
}
const LINE := Color(1, 1, 1, .35)
const SHADOW := Color(.35, .25, .35, .18)

static func draw(g: Game, T: int) -> void:
	var TW: Tower = g.TW
	if TW == null or TW.D.is_empty():
		return
	if g.cam + g.W < 12900:
		return
	for d in TW.D.get("deco", []):
		match d.k:
			"wall":
				_block(d.x, d.y, d.w, d.h, d.get("c", "lilac"))
			"arch":
				_arch(d.x, d.y, d.w, d.h)
	for s in TW.SOLS:
		_block(s.x, s.y, s.w, s.h, s.get("c", "cream"))
	for p in TW.PILLARS:
		if p.y < p.bottom - .5:
			_block(p.x, p.y, p.w, p.bottom - p.y, "gold")
			_glyph(p.x + p.w / 2, p.y + 18, T)
	for s in TW.SLIDERS:
		# trilho atrás do bloco
		Spr.rect(s.x + s.w / 2 - 3, s.stops.min() - 30, 6, s.bottom - s.stops.min() + 30, Color(.55, .45, .55, .35))
		_block(s.x, s.y, s.w, s.bottom - s.y, "lilac")
		_handle(Vector2(s.x + s.w / 2, s.y + 14), T, TW.drag.get("o") == s, true)
	for b in TW.BRIDGES:
		_bridge(b, T, TW.drag.get("o") == b)
	if not TW.ROOM.is_empty():
		_room(TW, T)
	if not TW.FEZ.is_empty():
		_fez(g, TW, T)

## bloco pastel: face da frente, faixa de cima clara, lateral à direita mais escura
static func _block(x: float, y: float, w: float, h: float, cn: String) -> void:
	var cc: Array = C.get(cn, C.cream)
	Spr.rect(x, y, w, h, cc[0])
	Spr.rect(x, y, w, 6, cc[2])
	Spr.rect(x + w - 8, y + 6, 8, h - 6, cc[1])
	# juntas de pedra
	var row := 0
	var yy: float = y + 34
	while yy < y + h - 4:
		Spr.seg(x + 2, yy, x + w - 10, yy, Color(1, 1, 1, .18), 1.5)
		var off: float = 26.0 if row % 2 == 0 else 52.0
		var xx: float = x + off
		while xx < x + w - 12:
			Spr.seg(xx, yy - 28, xx, yy, Color(1, 1, 1, .12), 1.5)
			xx += 52
		yy += 34
		row += 1
	Spr.rect(x, y + h - 4, w, 4, SHADOW)

static func _arch(x: float, y: float, w: float, h: float) -> void:
	# arcos ao fundo (decoração)
	var n := int(w / 100.0)
	for i in n:
		var ax: float = x + (i + .5) * w / n
		var r: float = w / n * .32
		Spr.rect(ax - r - 8, y + r, 8, h - r, Color(.96, .9, .84, .55))
		Spr.rect(ax + r, y + r, 8, h - r, Color(.96, .9, .84, .55))
		Spr.ring(ax, y + r, r + 4, Color(.96, .9, .84, .55), 8, PI, TAU)

## símbolo geométrico brilhando (as "runas" do Monument Valley)
static func _glyph(x: float, y: float, T: int) -> void:
	var a: float = .5 + sin(T * .08) * .25
	Spr.ring(x, y, 9, Color(1, 1, 1, a), 2)
	Spr.poly(PackedVector2Array([Vector2(x, y - 5), Vector2(x + 5, y + 4), Vector2(x - 5, y + 4)]), Color(1, 1, 1, a))

## alça que dá para arrastar: anel pulsando
static func _handle(p: Vector2, T: int, active: bool, vertical: bool) -> void:
	var r: float = 16 + sin(T * .12) * 3
	Spr.circle(p.x, p.y, 13, Color(1, 1, 1, .85 if active else .6))
	Spr.ring(p.x, p.y, r, Color(1, .95, .7, .9 if active else .55), 3)
	var c := Color("#9b8cc8")
	if vertical:
		Spr.poly(PackedVector2Array([Vector2(p.x - 5, p.y - 2), Vector2(p.x, p.y - 8), Vector2(p.x + 5, p.y - 2)]), c)
		Spr.poly(PackedVector2Array([Vector2(p.x - 5, p.y + 2), Vector2(p.x, p.y + 8), Vector2(p.x + 5, p.y + 2)]), c)
	else:
		Spr.ring(p.x, p.y, 5, c, 2.5, -PI * .8, PI * .4)

static func _bridge(b: Dictionary, T: int, active: bool) -> void:
	var a := deg_to_rad(b.ang)
	Spr.save()
	Spr.translate(b.px, b.py)
	Spr.rotate(a)
	Spr.rect(0, 0, b.len, 16, C.teal[0])
	Spr.rect(0, 0, b.len, 4, C.teal[2])
	Spr.rect(0, 12, b.len, 4, C.teal[1])
	for k in int(b.len / 40):
		Spr.seg(20 + k * 40, 2, 20 + k * 40, 14, Color(1, 1, 1, .25), 1.5)
	Spr.restore()
	# manivela (engrenagem) no pivô e alça na ponta
	Spr.circle(b.px, b.py + 8, 16, C.gold[0])
	for k in 8:
		var ka: float = k * TAU / 8 + a
		Spr.circle(b.px + cos(ka) * 16, b.py + 8 + sin(ka) * 16, 4, C.gold[1])
	Spr.circle(b.px, b.py + 8, 6, C.cream[2])
	var tip: Vector2 = Vector2(b.px, b.py) + Vector2(cos(a), sin(a)) * (b.len - 14) + Vector2(-sin(a), cos(a)) * 8
	_handle(tip, T, active, false)

# ---------- sala que gira ----------
static func _room(TW: Tower, T: int) -> void:
	var R: Dictionary = TW.ROOM
	var N: int = R.N
	var cs: float = Tower.CELL
	var ctr := Vector2(R.ox + N * cs / 2, R.oy + N * cs / 2)
	var ang: float = TW.room_angle()
	Spr.save()
	Spr.translate(ctr.x, ctr.y)
	Spr.rotate(ang)
	Spr.translate(-ctr.x, -ctr.y)
	# fundo da sala
	Spr.rect(R.ox, R.oy, N * cs, N * cs, Color(.86, .82, .95, .55))
	var grid: Array = R.grid
	for r in N:
		var row: String = grid[r]
		for c in N:
			if row[c] == "#":
				var edge: bool = r == 0 or c == 0 or r == N - 1 or c == N - 1
				var cc: Array = C.pink if edge else C.cream
				var x: float = R.ox + c * cs
				var y: float = R.oy + r * cs
				Spr.rect(x, y, cs, cs, cc[0])
				Spr.rect(x, y, cs, 4, cc[2])
				Spr.rect(x + cs - 4, y + 4, 4, cs - 4, cc[1])
	# manivela (só antes de girar)
	if R.rot == 0:
		var cr: Vector2 = TW._room_cell_center(R.crank[0], R.crank[1], 0)
		var fy: float = cr.y + cs / 2
		Spr.rect(cr.x - 4, fy - 30, 8, 30, C.gold[1])
		Spr.circle(cr.x, fy - 34, 12, C.gold[0])
		var ra: float = T * .05 + ang * 4
		Spr.seg(cr.x, fy - 34, cr.x + cos(ra) * 14, fy - 34 + sin(ra) * 14, C.gold[1], 4)
		Spr.circle(cr.x + cos(ra) * 14, fy - 34 + sin(ra) * 14, 4, C.cream[2])
		_glyph(cr.x, fy - 60, T)
	Spr.restore()

# ---------- torre da perspectiva (estilo Fez) ----------
static func _fez(g: Game, TW: Tower, T: int) -> void:
	var F: Dictionary = TW.FEZ
	var th: float = TW.fez_theta()
	var cx: float = TW.fez_cx(th)
	var ct := cos(th)
	var st := sin(th)
	var proj := func(x3: float, z3: float) -> float:
		return cx + x3 * ct + z3 * st
	# núcleo da torre: prisma quadrado; a face mais virada para a câmera é mais clara
	var core := 48.0
	var us: Array = []
	for cz in [[-core, -core], [core, -core], [core, core], [-core, core]]:
		us.append(proj.call(cz[0], cz[1]))
	var u0: float = us.min()
	var u1: float = us.max()
	var top := -60.0
	var bottom := 500.0
	# duas faces visíveis (divisa no canto mais próximo)
	var near_i := 0
	var best := -INF
	for i in 4:
		var c3: Array = [[-core, -core], [core, -core], [core, core], [-core, core]][i]
		# profundidade (para a câmera): -sin(θ)x + cos(θ)z ... o canto mais "na frente"
		var dpt: float = -(c3[0] * -st + c3[1] * ct)
		if dpt > best:
			best = dpt
			near_i = i
	var un: float = us[near_i]
	Spr.rect(u0, top, un - u0, bottom - top, C.lilac[1])
	Spr.rect(un, top, u1 - un, bottom - top, C.lilac[0])
	Spr.rect(un - 1.5, top, 3, bottom - top, Color(1, 1, 1, .55))
	for k in 9:
		Spr.seg(u0, top + 40 + k * 50, u1, top + 40 + k * 50, Color(1, 1, 1, .18), 2)
	Spr.rect(u0, top - 14, u1 - u0, 14, C.pink[0])
	Spr.poly(PackedVector2Array([Vector2(u0 - 6, top - 14), Vector2((u0 + u1) / 2, top - 70), Vector2(u1 + 6, top - 14)]), C.pink[1])
	# janelinhas
	for k in 4:
		var wy: float = top + 60 + k * 100
		if un - u0 > 18:
			Spr.rr((u0 + un) / 2 - 7, wy, 14, 24, 7, Color(.35, .25, .45, .55))
		if u1 - un > 18:
			Spr.rr((un + u1) / 2 - 7, wy, 14, 24, 7, Color(.35, .25, .45, .55))
	# plataformas presas ao núcleo por vigas
	var plats: Array = F.plats.duplicate()
	for i in plats.size():
		var pf: Dictionary = plats[i]
		var cxp: float = (pf.x0 + pf.x1) / 2
		var czp: float = (pf.z0 + pf.z1) / 2
		var ua: float = proj.call(pf.x0, pf.z0)
		var ub: float = proj.call(pf.x1, pf.z0)
		var uc: float = proj.call(pf.x1, pf.z1)
		var ud: float = proj.call(pf.x0, pf.z1)
		var lo: float = min(min(ua, ub), min(uc, ud))
		var hi: float = max(max(ua, ub), max(uc, ud))
		var uc0: float = proj.call(0, 0)
		var umid: float = proj.call(cxp, czp)
		# viga
		Spr.rect(min(uc0, umid) , pf.y + 6, abs(umid - uc0), 8, Color(.62, .52, .62, .5))
		var cn: String = ["teal", "lilac", "gold", "pink"][i % 4]
		var cc: Array = C[cn]
		Spr.rect(lo, pf.y, hi - lo, Tower.FEZ_H, cc[0])
		Spr.rect(lo, pf.y, hi - lo, 5, cc[2])
		Spr.rect(lo, pf.y + Tower.FEZ_H - 5, hi - lo, 5, cc[1])
		if i == plats.size() - 1 and F.has("exit"):
			# portinha no topo
			var dx: float = (lo + hi) / 2
			door_shape(dx, pf.y, T, abs(g.player.x + g.player.w / 2 - dx) < 40 and g.player._g == pf.sol)

# ---------- portas (dentro e fora da torre) ----------
static func door_shape(cx: float, by: float, T: int, near: bool) -> void:
	var w := 46.0
	var h := 74.0
	Spr.rect(cx - w / 2 - 8, by - h - 8, w + 16, h + 8, C.cream[0])
	Spr.ring(cx, by - h + w / 2, w / 2 + 8, C.cream[0], 16, PI, TAU)
	Spr.rect(cx - w / 2, by - h + w / 2, w, h - w / 2, Color("#5b4a7a"))
	Spr.circle(cx, by - h + w / 2, w / 2, Color("#5b4a7a"))
	Spr.glow(cx, by - h * .5, 38, Color(1, .9, .7, .35 + sin(T * .07) * .1))
	Spr.rect(cx - w / 2 - 8, by - 4, w + 16, 4, C.pink[1])
	_glyph(cx, by - h - 4, T)
	if near:
		Spr.text("⬆ ENTRAR", cx, by - h - 34 + sin(T * .15) * 3, 20, Color(1, .93, .7), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 4)

# ---------- fundo pastel ----------
static func sky(g: Game, w: float, h: float, T: int) -> void:
	Spr.vgrad(0, 0, w, h * .7, Color("#f7c6b4"), Color("#fbe3cf"))
	Spr.rect(0, h * .7, w, h * .3 + 4, Color("#fbe3cf"))
	Spr.glow(w * .72, h * .28, 120, Color(1, .95, .85, .55))
	Spr.circle(w * .72, h * .28, 38, Color(1, .96, .88, .9))
	# torres geométricas ao longe (paralaxe lenta)
	var off: float = -fmod(g.rcam * .12, 520.0)
	var cols := [Color("#e9b7b5"), Color("#b8d6cf"), Color("#cdbfe6")]
	var x: float = off - 520
	var k := 0
	while x < w + 520:
		for j in 3:
			var tx: float = x + j * 170 + (k % 2) * 40
			var th: float = 140 + ((k * 3 + j * 7) % 5) * 45
			var tw: float = 60 + ((k + j) % 3) * 18
			var c: Color = cols[(k + j) % 3]
			c.a = .75
			Spr.rect(tx, h - th, tw, th, c)
			Spr.poly(PackedVector2Array([Vector2(tx - 6, h - th), Vector2(tx + tw / 2, h - th - 40), Vector2(tx + tw + 6, h - th)]), c.darkened(.12))
			Spr.rr(tx + tw / 2 - 7, h - th + 30, 14, 22, 7, Color(1, 1, 1, .35))
		x += 520
		k += 1
	# nuvens
	for i in 4:
		var cx: float = fmod(i * 330.0 + T * .15 - g.rcam * .05, w + 300) - 150
		var cy: float = 60 + i * 38
		for j in 3:
			Spr.ellipse(cx + j * 26, cy - (6 if j == 1 else 0), 34, 14, Color(1, 1, 1, .7))
