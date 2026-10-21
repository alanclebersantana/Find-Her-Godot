extends RefCounted
class_name Tower
## A Torre (trecho no estilo Monument Valley), fora do mapa principal, ligada por portas:
##  - peças que se movem com o dedo (ou ✦ perto delas): ponte giratória e bloco que desliza
##  - pilar que sobe com peso na placa
##  - sala que gira 90° com a manivela (o que era parede vira chão)
##  - trecho de perspectiva (estilo Fez): ✦ gira a câmera em volta da torre e plataformas
##    que estavam longe ficam uma em cima da outra
## Cada sala tem seus próprios limites de câmera ("zones" no JSON da fase).

var g  # Game
var D := {}
var ZONES: Array = []
var zone = null
var SOLS: Array = []         # blocos fixos da torre (para desenhar)
var BRIDGES: Array = []
var SLIDERS: Array = []
var PILLARS: Array = []
var ROOM := {}
var FEZ := {}
var drag := {}
var anim := {}               # animação que congela o jogo (sala girando / perspectiva virando)
var told := {}

const CELL := 40.0
const FEZ_H := 22.0

func _init(game) -> void:
	g = game

func load_level() -> void:
	D = g.L.get("tower", {})
	ZONES = g.L.get("zones", [])
	zone = null
	SOLS = []
	BRIDGES = []
	SLIDERS = []
	PILLARS = []
	ROOM = {}
	FEZ = {}
	drag = {}
	anim = {}
	if D.is_empty():
		return
	for s in D.get("solids", []):
		var o: Dictionary = s.duplicate()
		o.t = "tw"
		o.tower = 1
		SOLS.append(o)
		g.SOL.append(o)
	for b in D.get("bridges", []):
		var o: Dictionary = b.duplicate(true)
		o.idx = int(b.get("start", 0))
		o.ang = float(o.states[o.idx])
		o.sol = {"t": "twb", "x": 0.0, "y": 0.0, "w": 0.0, "h": 16.0, "tower": 1}
		o.on = false
		BRIDGES.append(o)
	for s in D.get("sliders", []):
		var o: Dictionary = s.duplicate(true)
		o.idx = int(s.get("start", 0))
		o.y = float(o.stops[o.idx])
		o.ty = o.y
		o.sol = {"t": "twsl", "x": o.x, "y": o.y, "w": o.w, "h": o.bottom - o.y, "tower": 1}
		g.SOL.append(o.sol)
		SLIDERS.append(o)
	for p in D.get("pillars", []):
		var o: Dictionary = p.duplicate(true)
		o.y = float(o.low)
		o.sol = {"t": "twp", "x": o.x, "y": o.y, "w": o.w, "h": o.bottom - o.y, "tower": 1}
		g.SOL.append(o.sol)
		PILLARS.append(o)
	var r = D.get("room")
	if r is Dictionary:
		ROOM = r.duplicate(true)
		ROOM.rot = 0
		ROOM.grid0 = ROOM.grid.duplicate()
		ROOM.sols = []
		_room_build()
	var f = D.get("fez")
	if f is Dictionary:
		FEZ = f.duplicate(true)
		FEZ.view = 0
		FEZ.theta = 0.0
		FEZ.hid = 0.0
		FEZ.cx = float(f.cx)
		for p in FEZ.plats:
			p.sol = {"t": "twf", "x": 0.0, "y": float(p.y), "w": 0.0, "h": 14.0, "oneway": 1, "tower": 1, "fez": 1}
			g.SOL.append(p.sol)
		_fez_build()

# ======================================================================
#  ZONAS (cada sala da torre tem câmera própria)
# ======================================================================
func zone_at(x: float, y: float):
	for z in ZONES:
		if x >= z.x0 and x <= z.x1 and y >= z.y0 - 200 and y <= z.y1 + 200:
			return z
	return null

func in_tower() -> bool:
	return zone != null

func busy() -> bool:
	return not anim.is_empty()

# ======================================================================
#  ANTES DA FÍSICA: ✦ perto das peças, manivela, girar a perspectiva
# ======================================================================
func pre() -> void:
	var p: Dictionary = g.player
	zone = zone_at(p.x + p.w / 2, p.y + p.h / 2)
	if zone == null or p.get("dog"):
		return
	# saída no alto da torre da perspectiva (↑ em cima da última plataforma)
	if not FEZ.is_empty() and FEZ.has("exit") and p.onGround and p._g == FEZ.plats[FEZ.plats.size() - 1].sol and g.keys.get("Up", false):
		g.keys.Up = false
		g.start_warp({"x": p.x, "y": p.y, "w": p.w, "h": p.h, "to": FEZ.exit, "mode": "door", "label": FEZ.get("exit_label", "")})
		return
	if not g.keys.get("Ap", false):
		return
	var pc := Vector2(p.x + p.w / 2, p.y + p.h / 2)
	# manivela da sala que gira
	if not ROOM.is_empty() and ROOM.rot == 0 and p.onGround:
		var cr := _room_cell_center(ROOM.crank[0], ROOM.crank[1], 0)
		if pc.distance_to(cr) < 46:
			g.keys.Ap = false
			_room_start()
			return
	# perspectiva (estilo Fez): ✦ em qualquer lugar da sala da torre
	if not FEZ.is_empty() and zone.get("id", "") == FEZ.get("zone", "") and (p.onGround or p.ladder):
		g.keys.Ap = false
		_fez_start(1)
		return
	# ponte e bloco: ✦ perto da manivela / alça passa para a próxima posição
	for b in BRIDGES:
		if pc.distance_to(Vector2(b.px, b.py)) < 70:
			g.keys.Ap = false
			b.idx = (b.idx + 1) % b.states.size()
			Audio.play("unlock", -6)
			return
	for s in SLIDERS:
		if abs(pc.x - (s.x + s.w / 2)) < s.w / 2 + 50 and abs(pc.y - s.y) < 160:
			g.keys.Ap = false
			s.idx = (s.idx + 1) % s.stops.size()
			s.ty = float(s.stops[s.idx])
			Audio.play("unlock", -6)
			return

# ======================================================================
#  DEPOIS DA FÍSICA: peças se mexendo, pilares, perspectiva acompanhando o Tomé
# ======================================================================
func post() -> void:
	if D.is_empty():
		return
	var p: Dictionary = g.player
	for b in BRIDGES:
		if not (drag.get("o") == b):
			var tgt: float = float(b.states[b.idx])
			b.ang = move_toward(b.ang, tgt, 3.5)
		var flat: bool = abs(b.ang - float(b.states[b.get("flat", 1)])) < .5
		var was_on: bool = b.on
		b.on = flat
		if flat:
			var a := deg_to_rad(b.ang)
			var tip: Vector2 = Vector2(b.px, b.py) + Vector2(cos(a), sin(a)) * b.len
			b.sol.x = min(b.px, tip.x)
			b.sol.w = abs(tip.x - b.px)
			b.sol.y = b.py
			if not g.SOL.has(b.sol):
				g.SOL.append(b.sol)
			if not was_on:
				Audio.play("door", -6)
				g.shake = max(g.shake, 3)
		elif g.SOL.has(b.sol):
			g.SOL.erase(b.sol)
	for s in SLIDERS:
		var oy: float = s.y
		if not (drag.get("o") == s):
			s.y = move_toward(s.y, s.ty, 4.0)
		_set_block(s, oy)
	for pl in PILLARS:
		var on := false
		for pt in g.M.PLATES:
			if pt.get("gate", "") == pl.id and pt.on:
				on = true
		var oy2: float = pl.y
		pl.y = move_toward(pl.y, float(pl.high) if on else float(pl.low), 3.0)
		_set_block(pl, oy2)
	# perspectiva: ao pousar numa plataforma, a "profundidade" escondida do Tomé passa a ser a dela
	if not FEZ.is_empty():
		for pf in FEZ.plats:
			if p._g == pf.sol:
				var r := _fez_hidden_range(pf, FEZ.view)
				FEZ.hid = clamp(FEZ.hid, r.x, r.y)
		_fez_sync_player_u()
	# caiu do fundo de uma sala da torre
	if zone != null and p.y > zone.y1 + 60 and p.dyingT == 0:
		g.die("Você caiu da torre.")

## bloco que sobe/desce: carrega quem está em cima e empurra quem está embaixo
func _set_block(s: Dictionary, oy: float) -> void:
	var dy: float = s.y - oy
	s.sol.y = s.y
	s.sol.h = s.bottom - s.y
	if dy == 0:
		return
	var p: Dictionary = g.player
	if p._g == s.sol or (dy < 0 and p.onGround and abs(p.y + p.h - oy) < 2 and p.x + p.w > s.x and p.x < s.x + s.w):
		p.y += dy
	elif Game.hit(p, s.sol):
		p.y = s.sol.y - p.h
	for c in g.CR:
		if not c.dead and c.x + c.w > s.x + 2 and c.x < s.x + s.w - 2 and abs(c.y + c.h - oy) < 3:
			c.y += dy

# ======================================================================
#  ARRASTAR COM O DEDO
# ======================================================================
func handle_at(w: Vector2) -> Dictionary:
	if D.is_empty() or zone == null:
		return {}
	for b in BRIDGES:
		var a := deg_to_rad(b.ang)
		var tip: Vector2 = Vector2(b.px, b.py) + Vector2(cos(a), sin(a)) * b.len
		if _seg_dist(w, Vector2(b.px, b.py), tip) < 44:
			return b
	for s in SLIDERS:
		if w.x > s.x - 30 and w.x < s.x + s.w + 30 and w.y > s.y - 50 and w.y < s.y + 120:
			return s
	return {}

func drag_begin(w: Vector2, finger: int) -> bool:
	var o := handle_at(w)
	if o.is_empty():
		return false
	drag = {"o": o, "f": finger, "dy": w.y - o.get("y", 0.0)}
	Audio.play("climb", -8)
	if not told.has("drag"):
		told.drag = true
		g.note("Isso! Arraste e solte: a peça encaixa na posição mais próxima.")
	return true

func drag_move(w: Vector2) -> void:
	if drag.is_empty():
		return
	var o: Dictionary = drag.o
	if o.has("states"):
		var ang: float = rad_to_deg((w - Vector2(o.px, o.py)).angle())
		var lo: float = min(o.states.min(), o.states.max())
		var hi: float = max(o.states.min(), o.states.max())
		o.ang = clamp(ang, lo, hi)
	else:
		var lo2: float = o.stops.min()
		var hi2: float = o.stops.max()
		var oy: float = o.y
		o.y = clamp(w.y - drag.dy, lo2, hi2)
		_set_block(o, oy)

func drag_end() -> void:
	if drag.is_empty():
		return
	var o: Dictionary = drag.o
	if o.has("states"):
		var best := 0
		for i in o.states.size():
			if abs(float(o.states[i]) - o.ang) < abs(float(o.states[best]) - o.ang):
				best = i
		o.idx = best
	else:
		var best2 := 0
		for i in o.stops.size():
			if abs(float(o.stops[i]) - o.y) < abs(float(o.stops[best2]) - o.y):
				best2 = i
		o.idx = best2
		o.ty = float(o.stops[best2])
	Audio.play("unlock", -8)
	drag = {}

static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t: float = clamp((p - a).dot(ab) / max(1.0, ab.length_squared()), 0, 1)
	return p.distance_to(a + ab * t)

# ======================================================================
#  SALA QUE GIRA 90° (grade de blocos; a manivela gira tudo, inclusive o Tomé)
# ======================================================================
func _room_cell_center(c: int, r: int, rot: int) -> Vector2:
	var N: int = ROOM.N
	var cc := c
	var rr := r
	for i in rot:
		var nc: int = N - 1 - rr
		rr = cc
		cc = nc
	return Vector2(ROOM.ox + (cc + .5) * CELL, ROOM.oy + (rr + .5) * CELL)

func _room_build() -> void:
	for s in ROOM.sols:
		g.SOL.erase(s)
	ROOM.sols = []
	var N: int = ROOM.N
	var grid: Array = ROOM.grid
	for r in N:
		var row: String = grid[r]
		var c := 0
		while c < N:
			if row[c] == "#":
				var c2 := c
				while c2 + 1 < N and row[c2 + 1] == "#":
					c2 += 1
				var s := {"t": "twr", "x": ROOM.ox + c * CELL, "y": ROOM.oy + r * CELL, "w": (c2 - c + 1) * CELL, "h": CELL, "tower": 1, "room": 1}
				ROOM.sols.append(s)
				g.SOL.append(s)
				c = c2 + 1
			else:
				c += 1

## gira a grade 90° no sentido horário
func _room_rotate_grid() -> void:
	var N: int = ROOM.N
	var old: Array = ROOM.grid
	var out: Array = []
	for r in N:
		var row := ""
		for c in N:
			# novo (c, r) veio do antigo (c' = r, r' = N-1-c)
			row += old[N - 1 - c][r]
		out.append(row)
	ROOM.grid = out

func _room_start() -> void:
	var p: Dictionary = g.player
	var ctr := Vector2(ROOM.ox + ROOM.N * CELL / 2, ROOM.oy + ROOM.N * CELL / 2)
	anim = {"k": "room", "t": 0, "dur": 46, "ctr": ctr, "p0": Vector2(p.x + p.w / 2, p.y + p.h / 2)}
	p.vx = 0.0
	p.vy = 0.0
	Audio.play("door", -2)
	g.shake = max(g.shake, 4)

func _room_finish() -> void:
	_room_rotate_grid()
	ROOM.rot = (ROOM.rot + 1) % 4
	_room_build()
	var p: Dictionary = g.player
	var c: Vector2 = anim.ctr
	var v: Vector2 = anim.p0 - c
	var np: Vector2 = c + Vector2(-v.y, v.x)
	p.x = np.x - p.w / 2
	p.y = np.y - p.h / 2
	# acha o chão logo abaixo
	for i in 60:
		var r: Dictionary = g.R(p.x, p.y + 1, p.w, p.h)
		var hit := false
		for s in ROOM.sols:
			if Game.hit(r, s):
				hit = true
		if hit:
			break
		p.y += 1
	p.onGround = false
	g.shake = max(g.shake, 8)
	Audio.play("stomp", -4)
	if not told.has("room"):
		told.room = true
		g.flash("A sala girou: o que era parede virou chão!", 200)

func room_reset() -> void:
	if ROOM.is_empty() or ROOM.rot == 0:
		return
	ROOM.grid = ROOM.grid0.duplicate()
	ROOM.rot = 0
	_room_build()

# ======================================================================
#  PERSPECTIVA (estilo Fez)
# ======================================================================
## u = posição na tela ao longo da vista; vistas 0..3 a cada 90°
static func _u(x3: float, z3: float, view: int) -> float:
	match view:
		1: return z3
		2: return -x3
		3: return -z3
	return x3

## faixa do eixo escondido de uma plataforma na vista
func _fez_hidden_range(pf: Dictionary, view: int) -> Vector2:
	match view:
		1: return Vector2(-pf.x1, -pf.x0)
		2: return Vector2(-pf.z1, -pf.z0)
		3: return Vector2(pf.x0, pf.x1)
	return Vector2(pf.z0, pf.z1)

## posição 3D do Tomé a partir de (u na tela, eixo escondido)
func _fez_p3() -> Vector2:
	var p: Dictionary = g.player
	var u: float = p.x + p.w / 2 - FEZ.cx
	var h: float = FEZ.hid
	match int(FEZ.view):
		1: return Vector2(-h, u)
		2: return Vector2(-u, -h)
		3: return Vector2(h, -u)
	return Vector2(u, h)

func _fez_sync_player_u() -> void:
	pass

func _fez_build() -> void:
	for pf in FEZ.plats:
		var a := _u(pf.x0, pf.z0, FEZ.view)
		var b := _u(pf.x1, pf.z1, FEZ.view)
		pf.sol.x = FEZ.cx + min(a, b)
		pf.sol.w = abs(b - a)
		pf.sol.y = float(pf.y)

func _fez_start(dirv: int) -> void:
	var p3 := _fez_p3()
	anim = {"k": "fez", "t": 0, "dur": 34, "p3": p3, "v0": int(FEZ.view), "dir": dirv}
	g.player.vx = 0.0
	g.player.vy = 0.0
	Audio.play("dj", -4)
	if not told.has("fez"):
		told.fez = true
		g.flash("A torre girou! Olhando de outro lado, o que estava longe pode ficar ao alcance.", 220)

func _fez_finish() -> void:
	var p: Dictionary = g.player
	var p3: Vector2 = anim.p3
	FEZ.view = (int(anim.v0) + int(anim.dir) + 4) % 4
	FEZ.theta = FEZ.view * PI / 2
	var u := _u(p3.x, p3.y, FEZ.view)
	FEZ.cx = p.x + p.w / 2 - u
	match int(FEZ.view):
		1: FEZ.hid = -p3.x
		2: FEZ.hid = -p3.y
		3: FEZ.hid = p3.x
		_: FEZ.hid = p3.y
	_fez_build()

## θ contínuo para desenhar (inclusive durante a animação)
func fez_theta() -> float:
	if anim.get("k", "") == "fez":
		var u: float = clamp(anim.t / float(anim.dur), 0, 1)
		u = u * u * (3 - 2 * u)
		return (int(anim.v0) + u * int(anim.dir)) * PI / 2
	return FEZ.view * PI / 2

## centro da projeção durante a animação (o Tomé fica parado na tela)
func fez_cx(theta: float) -> float:
	if anim.get("k", "") == "fez":
		var p: Dictionary = g.player
		var p3: Vector2 = anim.p3
		return p.x + p.w / 2 - (p3.x * cos(theta) + p3.y * sin(theta))
	return FEZ.cx

# ======================================================================
#  ANIMAÇÕES QUE CONGELAM O JOGO
# ======================================================================
func anim_step() -> void:
	anim.t += 1
	var p: Dictionary = g.player
	if anim.k == "room":
		var u: float = clamp(anim.t / float(anim.dur), 0, 1)
		u = u * u * (3 - 2 * u)
		var a: float = u * PI / 2
		var v: Vector2 = anim.p0 - anim.ctr
		var np: Vector2 = anim.ctr + v.rotated(a)
		p.x = np.x - p.w / 2
		p.y = np.y - p.h / 2
		anim.ang = a
		if anim.t % 8 == 0:
			Audio.play("climb", -12)
		if anim.t >= anim.dur:
			_room_finish()
			anim = {}
	elif anim.k == "fez":
		if anim.t >= anim.dur:
			_fez_finish()
			anim = {}

func room_angle() -> float:
	return anim.get("ang", 0.0) if anim.get("k", "") == "room" else 0.0

# ======================================================================
#  RENASCER / CÂMERA
# ======================================================================
func on_respawn() -> void:
	drag = {}
	anim = {}
	var p: Dictionary = g.player
	if not ROOM.is_empty() and p.spawnX < ROOM.ox:
		room_reset()
	if not FEZ.is_empty() and FEZ.view != 0:
		FEZ.view = 0
		FEZ.cx = float(D.fez.cx)
		FEZ.hid = 0.0
		_fez_build()

func cam_rect() -> Rect2:
	return Rect2(zone.x0, zone.y0, zone.x1 - zone.x0, zone.y1 - zone.y0)
