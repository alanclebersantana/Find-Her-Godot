extends RefCounted
class_name Vehicles
## Os dois passeios automáticos novos (no mesmo espírito da cavalgada):
##  JANGADA  na corredeira entre o pântano e a neve: a correnteza leva sozinha; PULAR salta pedras,
##           troncos e as quedas-d'água (na beirada); ↓ abaixa sob os galhos.
##  BIPLANO  no período do Céu: o Tomé acha o avião na pista antes do precipício, decola e voa sobre
##           o vale; ↑ sobe, ↓ desce, desviando dos bandos de pássaros, gaviões e nuvens de tempestade.
## Cada batida custa um coração; sem corações, o passeio recomeça do começo.

var g
var RA := {}            # dados da jangada (L.raft)
var SL := {}            # dados do trenó (L.sled)
var sled_done := false
var PL := {}            # dados do biplano (L.plane)
var mode := ""          # "" | "raft" | "plane"
var hx := 0.0
var hy := 0.0
var vy := 0.0
var spd := 0.0
var duck := false
var stumble := 0
var jbuf := 0
var tries := 0
var raft_done := false
var plane_done := false
var phase := ""         # avião: "taxi", "fly", "land", "stop"
var tilt := 0.0
var OBS: Array = []
var RAFT_SOL := {}

func _init(game) -> void:
	g = game

func load_level() -> void:
	mode = ""
	raft_done = false
	plane_done = false
	RA = g.L.get("raft", {}).duplicate(true)
	SL = g.L.get("sled", {}).duplicate(true)
	sled_done = false
	PL = g.L.get("plane", {}).duplicate(true)
	RAFT_SOL = {}
	if not RA.is_empty():
		_dock_raft()
	if not PL.is_empty():
		PL.px = float(PL.x)
		PL.py = float(PL.y)

func active() -> bool:
	return mode != ""

## a jangada volta para o cais (chão de verdade: pular nela também embarca)
func _dock_raft() -> void:
	RA.px = float(RA.x)
	if RAFT_SOL.is_empty():
		RAFT_SOL = {"t": "raftsol", "x": 0.0, "y": 0.0, "w": 76.0, "h": 12.0, "oneway": 1, "raft": 1}
		g.SOL.append(RAFT_SOL)
	RAFT_SOL.x = RA.px - 38.0
	RAFT_SOL.y = water_y(RA.px) - 8.0

## cerca na margem do fim do rio: depois da corredeira não dá para voltar para a água
func _end_fence() -> void:
	for s in g.SOL:
		if s.get("id") == "raftfence":
			return
	g.SOL.append({"t": "raftfence", "x": float(RA.x1) - 8.0, "y": -400.0, "w": 16.0, "h": 900.0, "id": "raftfence"})

## voltou da morte (ou da fogueira): passeio interrompido é cancelado e o veículo volta ao ponto de saída
func on_respawn() -> void:
	var was: String = mode
	auto_cd = 120
	if mode != "":
		mode = ""
		stumble = 0
		duck = false
		vy = 0.0
		crashT = 0
	if not RA.is_empty():
		if raft_done:
			_drop_raft_sol()
			RA.px = float(RA.x1) - 90
			_end_fence()
		else:
			_dock_raft()
	if not PL.is_empty() and not plane_done:
		PL.px = float(PL.x)
		PL.py = float(PL.y)
	if was == "sled" or was == "plane" or was == "raft":
		if g.X.DOG.get("st", "") == "ride":
			g.X.DOG.st = "follow"

# ======================================================================
#  ÁGUA DA CORREDEIRA
# ======================================================================
## nível da água em x (cada queda-d'água desce 40 px)
func water_y(x: float) -> float:
	var y: float = RA.y
	for f in RA.get("falls", []):
		if x >= f:
			y += 40.0
	return y

## chegou do lado do avião: abre o quadrinho (só na primeira vez) e, depois do toque, embarca sozinho
func check_plane() -> void:
	if near_plane() and g.player.onGround and g.player.dyingT == 0:
		g.want_comic("aviao")
		_start_plane()

## chegou no trenó / carrinho: abre o quadrinho (só na primeira vez) e já parte, sem botão
var auto_cd := 0
func check_sled() -> void:
	if auto_cd > 0:
		auto_cd -= 1
		return
	# só quando ele anda até o trenó (voltando da fogueira parado ao lado, não parte sozinho)
	if near_sled() and g.player.onGround and g.player.dyingT == 0 and abs(g.player.vx) > .5 and (g.kd("R") or g.kd("L")) \
			and abs(float(g.player.x + g.player.w / 2) - float(SL.x)) < 40:
		if is_cart():
			g.want_comic("carrinho")
		_start_sled()

## caiu no rio sem estar na jangada: a correnteza leva
func check_river() -> void:
	if RA.is_empty() or mode == "raft":
		return
	var p: Dictionary = g.player
	var pcx0: float = p.x + p.w / 2
	# pulou do barranco para o rio: a jangada desliza até onde ele vai cair (sempre cai em cima dela)
	if not raft_done and not RAFT_SOL.is_empty() and p.dyingT == 0 and not p.get("dog"):
		var zone_a: float = float(RA.x0)
		var zone_b: float = float(RA.x0) + 440.0
		if not p.onGround and pcx0 > zone_a - 10 and pcx0 < zone_b and p.vy > -3.0:
			var tx: float = clamp(pcx0 + p.vx * 6.0, zone_a + 46.0, zone_b - 50.0)
			RA.px = move_toward(RA.px, tx, 18.0)
			RAFT_SOL.x = RA.px - 38.0
			RAFT_SOL.y = water_y(RA.px) - 8.0
		# já caiu na água dessa área (andou para fora do barranco, por exemplo): a jangada pega ele
		if pcx0 > zone_a and pcx0 < zone_b and p.y + p.h > water_y(pcx0) - 10:
			RA.px = clamp(pcx0, zone_a + 46.0, zone_b - 50.0)
			p.y = water_y(RA.px) - 8.0 - p.h
			p.vy = 0.0
			g.want_comic("jangada")
			_start_raft()
			return
	# pousou em cima da jangada: embarca e a corredeira começa
	if not RAFT_SOL.is_empty() and p.onGround and p._g == RAFT_SOL and not p.get("dog") and p.dyingT == 0:
		g.want_comic("jangada")
		_start_raft()
		return
	var pcx: float = p.x + p.w / 2
	if pcx > RA.x0 and pcx < RA.x1 and p.y + p.h > water_y(pcx) + 12 and p.dyingT == 0:
		g.die("A correnteza te levou! Suba na jangada (✦).")
	# o precipício do Céu
	for c in g.L.get("chasms", []):
		if pcx > c[0] and pcx < c[1] and p.y > c[2] and p.dyingT == 0:
			g.die("Você caiu no precipício.")

# ======================================================================
#  USAR
# ======================================================================
func near_raft() -> bool:
	if RA.is_empty() or raft_done or mode != "":
		return false
	var p: Dictionary = g.player
	return abs(p.x + p.w / 2 - RA.px) < 120 and abs(p.y + p.h - 500) < 60 and not p.get("dog")

func near_plane() -> bool:
	if PL.is_empty() or plane_done or mode != "":
		return false
	var p: Dictionary = g.player
	return abs(p.x + p.w / 2 - PL.px) < 150 and abs(p.y + p.h - PL.y) < 70 and not p.get("dog")

func near_sled() -> bool:
	if SL.is_empty() or sled_done or mode != "":
		return false
	var p: Dictionary = g.player
	return abs(p.x + p.w / 2 - float(SL.x)) < 90 and abs(p.y + p.h - float(SL.y)) < 50 and not p.get("dog")

func use() -> bool:
	if near_sled():
		if is_cart():
			g.want_comic("carrinho")
		_start_sled()
		return true
	if near_raft():
		g.want_comic("jangada")
		_start_raft()
		return true
	if near_plane():
		g.want_comic("aviao")
		_start_plane()
		return true
	return false

func _common_start() -> void:
	var p: Dictionary = g.player
	p.hp = Game.MAXHP
	p.vine = null
	p.ladder = null
	p.bar = null
	p.crouch = false
	p.h = 34
	p.sink = 0.0
	stumble = 0
	jbuf = 0
	duck = false
	vy = 0.0
	if not g.X.DOG.is_empty() and g.X.dog_free():
		g.X.DOG.st = "ride"

func _start_raft() -> void:
	mode = "raft"
	_drop_raft_sol()
	_common_start()
	OBS = []
	for o in RA.get("obs", []):
		var d: Dictionary = o.duplicate()
		d.hit = false
		OBS.append(d)
	hx = max(float(RA.x), float(RA.get("px", RA.x)))
	hy = water_y(hx)
	spd = .6
	_place_player()
	Audio.play("splash", -4)
	g.flash_tut("Segure firme!", "Corredeira! PULAR salta pedras e troncos boiando (e as quedas, na beirada). ↓ abaixa sob galhos, troncos caídos, pontes e redes.", 260)

## TRENÓ: descida comprida num morro de neve (trilha própria, longe do mapa). A velocidade segue a
## descida; PULAR salta pedras, troncos e rachaduras; ↓ abaixa sob galhos; ← freia; → inclina e acelera.
## Batida: perde um coração e segue descendo (sem coração nenhum: volta para a fogueira).
var su := 0.0          # posição na trilha
var sdv := 0.0         # quanto o chão desce por quadro (para decolar das rampas)
var sang := 0.0        # inclinação do trenó
var crashT := 0
var srest := 0.0       # onde recomeça depois de bater
var lean := false
var brake := false
var sboard := 0        # embarcando no trenó: empurra, senta e escorrega (a tela fecha e abre lá no morro)
var sfin := 0          # chegou no monte de neve: a tela fecha antes de voltar para o mapa
var vg_t0 := -1        # carrinho: quadro em que o Vargas parou no fim dos trilhos e saltou com a Isis
const VG_STOP := 850.0  # o Vargas chega ao fim dos trilhos quando o Tomé ainda está esta distância atrás
const SBOARD := 40

func sled_y(u: float) -> float:
	var pts: Array = SL.get("pts", [])
	for i in pts.size() - 1:
		var a: Array = pts[i]
		var b: Array = pts[i + 1]
		if u >= a[0] and u <= b[0]:
			var t: float = (u - float(a[0])) / (float(b[0]) - float(a[0]))
			t = (1.0 - cos(t * PI)) * .5
			return lerpf(float(a[1]), float(b[1]), t)
	if pts.is_empty():
		return float(SL.y)
	return float(pts[-1][1]) if u > float(pts[-1][0]) else float(pts[0][1])

## o mesmo passeio do trenó, nos trilhos da mina (Episódio 2): carrinho em vez de trenó
func is_cart() -> bool:
	return str(SL.get("skin", "")) == "cart"

func sled_tx0() -> float:
	return float(SL.get("tx0", 82000))

func _start_sled() -> void:
	mode = "sled"
	_common_start()
	OBS = []
	for o in SL.get("obs", []):
		var d: Dictionary = o.duplicate()
		d.hit = false
		d.x = sled_tx0() + float(d.u)
		OBS.append(d)
	srest = 40.0
	sboard = SBOARD
	sfin = 0
	vg_t0 = -1
	su = 0.0
	hx = float(SL.x)
	hy = float(SL.y)
	spd = 0.0
	vy = 0.0
	sang = 0.0
	crashT = 0
	_place_player()
	Audio.play("slide", -6)

func _sled_go() -> void:
	_sled_place(40.0, 3.0)
	g.snap_camera()
	g.set_cam(hx - g.W * .26, hy * .6 + sled_y(su + 300.0) * .4 - g.H * .56)
	g.iris_t = 30
	Audio.play("slide")
	if is_cart():
		g.flash_tut("Carrinho!", "Nos trilhos! PULAR salta pedras e buracos nos trilhos. ↓ abaixa sob as vigas. ← freia, → acelera.", 240)
	else:
		g.flash_tut("Trenó!", "Descendo o morro! PULAR salta pedras, troncos e rachaduras. ↓ abaixa sob galhos. ← freia, → acelera.", 240)

func _sled_place(u: float, v: float) -> void:
	su = u
	hx = sled_tx0() + su
	hy = sled_y(su)
	vy = 0.0
	spd = v
	sdv = 0.0
	sang = 0.0
	crashT = 0
	duck = false
	_place_player()

func _sled_step() -> void:
	var p: Dictionary = g.player
	if sboard > 0:
		# senta no trenó e começa a escorregar devagar; a tela fecha e abre já na descida
		sboard -= 1
		if sboard < SBOARD - 12:
			spd = move_toward(spd, 2.4, .1)
		hx += spd
		hy = float(SL.y)
		if sboard == 0:
			_sled_go()
		return
	if sfin > 0:
		sfin -= 1
		if sfin == 0:
			_finish_sled()
		return
	if crashT > 0:
		# bateu: o trenó balança um pouco, mas segue descendo
		crashT -= 1
	# o que foi atingido: pedra quebra, tora sai rolando, galho cai
	for o in OBS:
		if o.hit and o.get("ft", -1) >= 0 and o.ft < 90:
			o.ft += 1
	var gy: float = sled_y(su)
	var on_ground: bool = hy >= gy - 1.0
	lean = g.kd("R")
	brake = g.kd("L")
	# a velocidade acompanha a descida (e as subidinhas seguram)
	var slope: float = (sled_y(su + 4.0) - sled_y(su - 4.0)) / 8.0
	if on_ground:
		spd += .3 * sin(atan(slope)) - .004 * spd
		if lean:
			spd += .045
		if brake:
			spd -= .11
		spd = clamp(spd, 2.2 if su < float(SL.get("len", 4650)) - 200 else 0.0, 8.0)
	if g.pressed("J"):
		jbuf = 9
	elif jbuf > 0:
		jbuf -= 1
	if jbuf > 0 and on_ground:
		jbuf = 0
		vy = sdv - 8.2
		on_ground = false
		Audio.play("jump", -6)
		g.burst(hx - 20, hy, 8, Color(.97, .98, 1))
	duck = g.kd("S") and on_ground
	var nu: float = su + spd
	var ngy: float = sled_y(nu)
	if on_ground:
		var dv: float = ngy - gy
		# o chão "some" embaixo (fim de rampa): decola com a velocidade de subida que tinha
		if dv - sdv > .9 and sdv < 0:
			vy = sdv
			hy = gy
			on_ground = false
		else:
			sdv = dv
			hy = ngy
			vy = 0.0
	if not on_ground:
		vy += .45
		hy += vy
		if hy >= ngy:
			if vy > 5:
				g.burst(hx, ngy, 14, Color(.97, .98, 1))
				Audio.step("stone" if is_cart() else "snow", -6)
				g.shake = max(g.shake, 3)
			hy = ngy
			vy = 0.0
			sdv = ngy - gy
	su = nu
	hx = sled_tx0() + su
	var want: float = atan(sdv / max(spd, .1)) if hy >= ngy - 1 else atan(vy / max(spd, .1)) * .7
	sang = lerpf(sang, want, .25)
	# neve espirrando dos esquis (no carrinho: faíscas das rodas)
	if hy >= ngy - 1 and g.T % 2 == 0:
		for k in 2:
			if is_cart():
				if spd > 5.5 and randf() < .5:
					g.PARTS.append({"x": hx - 24 + k * 40, "y": hy - 2, "vx": -spd * .3 - randf() * 2.0, "vy": -randf_range(.5, 2.5), "life": 12, "col": Color(1, .75 + randf() * .2, .3, 1)})
			else:
				g.PARTS.append({"x": hx - 28, "y": hy - 2, "vx": -spd * .35 - randf() * 1.5, "vy": -randf_range(1.0, 3.0) - spd * .1, "life": 22, "col": Color(.97, .98, 1, .95)})
	if brake and hy >= ngy - 1 and g.T % 3 == 0:
		g.PARTS.append({"x": hx + 20, "y": hy - 3, "vx": spd * .2, "vy": -2.0, "life": 18, "col": Color(.9, .95, 1, .9)})
	# obstáculos
	var b := box()
	for o in OBS:
		if o.hit or o.x + 120 < hx - 80 or o.x - 60 > hx + 80:
			continue
		var oy: float = sled_y(float(o.u))
		var bad := false
		match o.k:
			"rock":
				bad = Game.hit(b, g.R(o.x - 18, oy - 26, 36, 26))
			"log":
				bad = Game.hit(b, g.R(o.x - 30, oy - 20, 60, 20))
			"branch":
				bad = Game.hit(b, g.R(o.x - 40, oy - 72, 90, 26))
			"crack":
				bad = hy >= sled_y(su) - 1 and hx > o.x + 14 and hx < o.x + float(o.w) - 14
			"bump":
				if hy >= sled_y(su) - 1 and abs(hx - o.x) < 6 and spd > 4:
					vy = -3.5
					hy -= 2
					g.shake = max(g.shake, 2)
		if bad:
			o.hit = true
			_hurt_sled(o)
	_coins(b)
	if SL.get("vargas") and vg_t0 < 0 and su >= float(SL.get("len", 4650)) - VG_STOP:
		vg_t0 = g.T
	if su >= float(SL.get("len", 4650)) - 200:
		# freia sozinho no fim e para no monte de neve
		spd = move_toward(spd, 0.0, .18)
		if spd <= .3:
			sfin = 30

func _hurt_sled(o: Dictionary = {}) -> void:
	var p: Dictionary = g.player
	o.ft = 0
	crashT = 30
	g.shake = 7
	g.hit_stop = 4
	Audio.play("hurt")
	Audio.vib(70)
	g.burst(hx + 10, hy - 20, 20, Color(.97, .98, 1))
	match o.get("k", ""):
		"rock":
			# a pedra se parte em pedaços
			spd *= .6
			vy = -3.5
			Audio.play("stomp", -4)
			for k in 10:
				g.PARTS.append({"x": o.x, "y": sled_y(float(o.u)) - 14, "vx": randf_range(-1.0, 5.0), "vy": randf_range(-6.0, -2.0), "life": 40, "col": Color("#7d7a74")})
		"log":
			# a tora sai rolando morro abaixo, na frente
			spd *= .65
			vy = -3.0
		"crack":
			# caiu na rachadura e sai pulando do outro lado
			spd *= .7
			vy = -7.5
			hy -= 2
		"branch":
			# bateu a cabeça no galho: o galho quebra e cai
			spd *= .7
			Audio.play("stomp", -4)
	if p.iframe > 0:
		return
	p.iframe = 70
	p.hp -= 1
	if p.hp <= 0:
		tries += 1
		g.die("O carrinho descarrilou! PULAR salta, ↓ abaixa, ← freia." if is_cart() else "O trenó capotou! Volta da fogueira — PULAR salta, ↓ abaixa, ← freia.")

func _finish_sled() -> void:
	var p: Dictionary = g.player
	mode = ""
	sled_done = true
	p.x = float(SL.x1) + 6
	p.y = float(SL.y) - p.h - 2
	p.vx = 3.0
	p.vy = -5.0
	p.onGround = false
	p.hp = max(p.hp, 1)
	if g.X.DOG.get("st", "") == "ride":
		g.X.DOG.st = "follow"
		g.X.DOG.x = p.x - 40
		g.X.DOG.y = float(SL.y)
	g.burst(p.x, float(SL.y) - 10, 24, Color(.97, .98, 1))
	Audio.play("splash", -10)
	g.iris_t = 30
	g.snap_camera()
	if is_cart():
		g.flash(str(SL.get("endMsg", "O carrinho parou no fim dos trilhos.")), 200)
	else:
		g.flash("Que descida! O trenó parou no monte de neve, lá embaixo do morro.", 180)

var pb := 0              # avião: quadros do embarque
var bx0 := 0.0
var by0 := 0.0
const PBOARD := 70

func _start_plane() -> void:
	mode = "plane"
	_common_start()
	OBS = []
	for o in PL.get("obs", []):
		var d: Dictionary = o.duplicate()
		d.hit = false
		d.t = 0
		d.st = "wait"
		d.ox = float(d.x)
		d.oy = float(d.y)
		OBS.append(d)
	hx = float(PL.x)
	hy = float(PL.y)
	spd = 0.0
	phase = "board"
	pb = 0
	var p: Dictionary = g.player
	bx0 = p.x + p.w / 2
	by0 = p.y + p.h
	tilt = 0.0
	_place_player()

## o Tomé acompanha o veículo (para câmera, lápis e o resto do jogo)
func _place_player() -> void:
	var p: Dictionary = g.player
	if mode == "raft":
		p.x = hx - p.w / 2
		p.y = hy - 8 - p.h + (12 if duck else 0)
	elif mode == "sled":
		p.x = hx - p.w / 2
		p.y = hy - 10 - p.h
	else:
		p.x = hx - p.w / 2 - 10
		p.y = hy - 40 - p.h
	p.vx = spd
	p.vy = vy
	p.onGround = (mode == "raft" and hy >= water_y(hx) - 1) or (mode == "sled" and hy >= sled_y(su) - 1)
	p.face = 1

# ======================================================================
#  PASSO
# ======================================================================
func step() -> void:
	g.T += 1
	if mode == "raft":
		_raft_step()
	elif mode == "sled":
		_sled_step()
	elif mode == "plane":
		_plane_step()
	var p: Dictionary = g.player
	if p.iframe > 0:
		p.iframe -= 1
	if mode != "":
		_place_player()

func box() -> Dictionary:
	if mode == "sled":
		var st: float = hy - (30 if duck else 52)
		return g.R(hx - 28, st, 56, hy - st)
	if mode == "raft":
		var top: float = hy - (34 if duck else 50)
		return g.R(hx - 30, top, 60, hy - top)
	return g.R(hx - 50, hy - 46, 100, 40)

func _raft_step() -> void:
	if stumble > 0:
		stumble -= 1
		spd = move_toward(spd, 2.0, .4)
	else:
		# chegando na margem do fim: a jangada vai perdendo a velocidade até encostar
		# (só depois do último obstáculo, para os pulos continuarem com a mesma velocidade)
		var last_o: float = 0.0
		for o in OBS:
			last_o = max(last_o, float(o.x))
		var slow0: float = max(last_o + 140.0, float(RA.x1) - 70.0 - 420.0)
		var want_s: float = float(RA.spd) * clamp(1.0 - (hx - slow0) / max(60.0, float(RA.x1) - 70.0 - slow0) * .7, .3, 1.0)
		spd = move_toward(spd, want_s, .08 if want_s >= spd else .12)
	var wl: float = water_y(hx)
	var on_water: bool = hy >= wl - 1
	if g.pressed("J"):
		jbuf = 9
	elif jbuf > 0:
		jbuf -= 1
	if jbuf > 0 and on_water and stumble < 20:
		jbuf = 0
		vy = -10.5
		Audio.play("jump", -4)
		g.burst(hx - 20, wl, 10, Color(.8, .9, 1))
	duck = g.kd("S") and on_water
	# queda-d'água logo à frente: se não pulou, a jangada despenca e bate
	var nxt: float = hx + spd
	for f in RA.get("falls", []):
		if hx < f and nxt >= f and on_water:
			_hurt_raft("queda")
	vy += .42 if (vy < 0 and g.kd("J")) else .6
	hy += vy
	hx = nxt
	wl = water_y(hx)
	if hy >= wl:
		if vy > 4:
			Audio.play("splash", -8)
			g.burst(hx, wl, 12, Color(.85, .93, 1))
			g.WV.splash(hx, wl, min(9.0, vy * .9))
		hy = wl
		vy = 0.0
	# rastro da jangada na água
	if hy >= wl - 1 and g.T % 5 == 0:
		g.WV.splash(hx - 36, wl, 1.2, false)
	# balanço da água
	if hy >= wl - 1 and g.T % 4 == 0:
		g.PARTS.append({"x": hx - 34, "y": wl + 2, "vx": -spd * .4, "vy": -1.2, "life": 16, "col": Color(.9, .96, 1, .8)})
	var b := box()
	for o in OBS:
		if o.hit or o.x + 120 < hx - 80 or o.x > hx + 80:
			continue
		var oy: float = water_y(o.x)
		var bad := false
		match o.k:
			"rock":
				bad = Game.hit(b, g.R(o.x + 8, oy - 34, 44, 40))
			"log":
				bad = Game.hit(b, g.R(o.x + 6, oy - 18, 70, 20))
			"branch":
				bad = Game.hit(b, g.R(o.x + 4, oy - 104, 90, 18))
			# obstáculos de abaixar (↓): passam na altura do Tomé em pé; abaixado ele passa por baixo
			"lowbranch", "trunk", "bridge", "net", "vinebranch":
				var dw: float = DUCK_W.get(o.k, 110)
				bad = Game.hit(b, g.R(o.x, oy - 96, dw, 53))
		if bad:
			o.hit = true
			_hurt_raft(o.k)
	_coins(b)
	if hx >= float(RA.x1) - 70:
		_finish_raft()

## largura do que se passa abaixado na corredeira
const DUCK_W := {"lowbranch": 100.0, "trunk": 130.0, "bridge": 170.0, "net": 110.0, "vinebranch": 130.0}

func _hurt_raft(_k: String) -> void:
	var p: Dictionary = g.player
	stumble = 40
	spd = 1.5
	vy = -5.0
	g.shake = 5
	g.hit_stop = 4
	Audio.play("hurt")
	Audio.play("splash", -4)
	Audio.vib(60)
	g.burst(hx + 20, hy - 30, 12, Color("#e07a6a"))
	if p.iframe > 0:
		return
	p.iframe = 50
	p.hp -= 1
	if p.hp <= 0:
		tries += 1
		g.iris_t = 30
		g.flash("A jangada virou! De novo — PULAR para saltar, ↓ para abaixar.", 220)
		_start_raft()
		# a câmera volta junto (antes atravessava o rio inteiro deslizando até o começo)
		g.snap_camera()

func _drop_raft_sol() -> void:
	if not RAFT_SOL.is_empty():
		g.SOL.erase(RAFT_SOL)
		RAFT_SOL = {}

func _finish_raft() -> void:
	var p: Dictionary = g.player
	mode = ""
	raft_done = true
	_drop_raft_sol()
	_end_fence()
	RA.px = float(RA.x1) - 90
	p.x = float(RA.x1) + 10
	p.y = 500 - p.h - 4
	p.vx = 2.0
	p.vy = -4.0
	p.onGround = false
	p.hp = max(p.hp, 1)
	if g.X.DOG.get("st", "") == "ride":
		g.X.DOG.st = "door"
		g.X.DOG.x = p.x - 30
		g.X.DOG.y = 500.0
	Audio.play("splash", -6)
	g.flash("Terra firme! Que corredeira...", 200)

# ---------- avião ----------
func _plane_step() -> void:
	var p: Dictionary = g.player
	match phase:
		"board":
			# o Tomé sobe na cabine, o motor pega e o avião começa a andar
			pb += 1
			if pb == 30:
				Audio.play("roar", -10)
			if pb > 34 and g.T % 4 == 0:
				g.fx("fx_dust", hx - 60, hy - 4, 14, .14, -.2)
			if pb >= PBOARD:
				phase = "taxi"
				g.flash_tut("Decolar!", "No ar: ↑ sobe, ↓ desce. Desvie dos pássaros e das nuvens de tempestade.", 220)
		"taxi":
			spd = min(spd + .06, float(PL.spd))
			hx += spd
			hy = float(PL.y)
			if g.T % 3 == 0:
				g.fx("fx_dust", hx - 50, hy - 4, 14, .14, -.2)
			if hx > float(PL.edge):
				phase = "fly"
				vy = 1.5
				g.note("Voando!")
		"fly":
			spd = move_toward(spd, float(PL.spd), .05)
			var up: bool = (g.kd("U") or g.kd("J")) and stumble < 25
			var dn: bool = g.kd("S") and stumble < 25
			var want: float = -4.2 if up else (4.2 if dn else .35)
			vy = move_toward(vy, want, .22)
			hy = clamp(hy + vy, float(PL.top), float(PL.low))
			hx += spd
			tilt = lerpf(tilt, vy * .06, .2)
			_plane_obs()
			if hx >= float(PL.x1) - 900:
				phase = "land"
		"land":
			# desce sozinho até a clareira
			var gy: float = float(PL.land)
			# desce na medida certa para tocar o chão um pouco antes do fim
			var left: float = max(8.0, (float(PL.x1) - 260.0 - hx) / max(spd, 1.0))
			vy = move_toward(vy, (gy - hy) / left, .3)
			hy = min(gy, hy + vy)
			hx += spd
			tilt = lerpf(tilt, vy * .05, .2)
			if hx > float(PL.x1) - 260 or hy >= gy - .5:
				hy = gy
				spd = move_toward(spd, 0.0, .12)
				tilt = lerpf(tilt, 0.0, .2)
				if g.T % 3 == 0:
					g.fx("fx_dust", hx - 50, hy - 4, 14, .14, -.2)
			if spd <= 0.0 and hy >= gy:
				_finish_plane()
	if stumble > 0:
		stumble -= 1
	if phase == "fly":
		_coins(box())

func _plane_obs() -> void:
	var b := box()
	for o in OBS:
		if o.x - hx > 900 or o.x - hx < -400:
			continue
		o.t += 1
		match o.k:
			"flock":
				o.x = o.ox - o.t * 1.2
				o.y = o.oy + sin(o.t * .05) * 16
				for i in int(o.get("n", 5)):
					var bx: float = o.x + (i % 3) * 34 - (i / 3) * 14
					var by: float = o.y + (i / 3) * 26 + (i % 3) * 6
					if not o.hit and Game.hit(b, g.R(bx - 12, by - 8, 24, 16)):
						o.hit = true
						_hurt_plane()
			"hawk":
				# avisa (!), mergulha até a altura em que o avião estava e varre a faixa voando reto
				match o.st:
					"wait":
						if o.x - hx < 820:
							o.st = "warn"
							o.t = 0
							o.ty = hy - 26
					"warn":
						if o.t > 60:
							o.st = "dive"
							o.t = 0
							o.vx = -120.0 / 30.0
							o.vy = (o.ty - o.y) / 30.0
					"dive":
						o.x += o.vx
						o.y += o.vy
						if o.t >= 30:
							o.st = "sweep"
							o.t = 0
							o.y = o.ty
					"sweep":
						o.x -= 4.5
						if o.t > 120:
							o.st = "gone"
				if o.st in ["dive", "sweep"] and not o.hit and Game.hit(b, g.R(o.x - 22, o.y - 12, 44, 24)):
					o.hit = true
					_hurt_plane()
			"cloud":
				if not o.hit and Game.hit(b, g.R(o.x + 20, o.y + 14, o.w - 40, o.h - 28)):
					o.hit = true
					g.flash_t = 0
					_hurt_plane()

func _hurt_plane() -> void:
	var p: Dictionary = g.player
	stumble = 40
	vy = 2.5
	g.shake = 6
	g.hit_stop = 4
	Audio.play("hurt")
	Audio.play("thunder", -10)
	Audio.vib(60)
	g.burst(hx + 30, hy - 30, 14, Color("#e07a6a"))
	if p.iframe > 0:
		return
	p.iframe = 50
	p.hp -= 1
	if p.hp <= 0:
		tries += 1
		g.iris_t = 30
		g.flash("O avião rodopiou! De novo — ↑ sobe, ↓ desce.", 220)
		_start_plane()
		# recomeça já no ar, logo depois do precipício
		phase = "fly"
		hx = float(PL.edge) + 20
		hy = float(PL.y) + 30
		vy = 0.0
		spd = float(PL.spd)
		_place_player()
		g.snap_camera()

func _finish_plane() -> void:
	var p: Dictionary = g.player
	mode = ""
	plane_done = true
	PL.px = hx
	PL.py = hy
	p.x = hx - 110
	p.y = hy - p.h - 4
	p.vx = 0.0
	p.vy = -5.0
	p.onGround = false
	p.hp = max(p.hp, 1)
	if g.X.DOG.get("st", "") == "ride":
		g.X.DOG.st = "door"
		g.X.DOG.x = p.x - 30
		g.X.DOG.y = hy
	Audio.play("stomp", -8)
	g.flash("Pouso perfeito! A mina fica logo ali.", 220)

func _coins(b: Dictionary) -> void:
	for c in g.coins_near(hx - 120, hx + 120):
		if not c.got and abs(c.x - hx) < 90 and Game.hit(b, g.R(c.x - 15, c.y - 15, 30, 30)):
			c.got = true
			g.STATS.pen += 1
			g.gain_coin(c.x, c.y)

func save_data() -> Dictionary:
	return {"raft": raft_done, "plane": plane_done, "sled": sled_done, "ppx": PL.get("px", 0.0), "ppy": PL.get("py", 0.0)}

func restore(d: Dictionary) -> void:
	raft_done = d.get("raft", false)
	sled_done = d.get("sled", false)
	plane_done = d.get("plane", false)
	if raft_done and not RA.is_empty():
		RA.px = float(RA.x1) - 90
		_drop_raft_sol()
		_end_fence()
	if plane_done and not PL.is_empty():
		PL.px = d.get("ppx", PL.x1)
		PL.py = d.get("ppy", PL.land)
