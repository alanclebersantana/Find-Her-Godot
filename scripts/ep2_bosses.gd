extends RefCounted
class_name Ep2Bosses
## Os chefes do Episódio 2, com mecânicas próprias (nada repetido do Ep. 1):
##  - BRUTUS (quintal da vila): late e raspa a pata (aviso) e investe reto até o muro; o Tomé pula por
##    cima (ou sobe numa banca). Bateu no muro, fica tonto: pulo na cabeça. Acordado, morde quem chega
##    perto ou pula nele. 4 pulos na cabeça e ele foge.
##  - MORCEGO-REI (caverna da mina): no escuro ele some; só ataca quando o Tomé está longe da luz
##    (chiado e olhos vermelhos avisam o rasante). O Tomé sobe nas plataformas e acende as 3 lamparinas
##    (✦ USAR perto delas). Cada uma acesa encolhe o escuro; com as 3 acesas ele fica ofuscado e cai.
##  - SAPO-REI (lago do moinho): sentado numa vitória-régia gigante, lança a língua grudenta (uma mira
##    brilha antes). Três colmeias pendem sobre as vitórias-régias: parado na frente de uma, desvie no
##    último instante e a língua gruda na colmeia; as abelhas atacam o sapo, que fica tonto — pule na
##    cabeça dele. 3 colmeias, 3 pulos. Puxado pela língua, o Tomé cai na água e perde um coração.
## As funções são estáticas: o estado fica nos dicionários de sempre (X.BOSS, K.HAWK, K.FISH).

# ======================================================================
#  BRUTUS: investe, bate no muro, fica tonto -> pulo na cabeça (4 vezes)
# ======================================================================
const BR_HITS := 4

static func brutus_setup(b: Dictionary, L: Dictionary) -> void:
	b.maxhp = BR_HITS
	b.hp = BR_HITS
	b.cd = 70
	b.sulk = false

## caixa de dano: o corpo do cão
static func brutus_box(g, b: Dictionary) -> Dictionary:
	return g.R(b.x - 70, b.y - 88, 140, 88)

## a cabeça (onde o pulo vale)
static func brutus_head(g, b: Dictionary) -> Dictionary:
	return g.R(b.x - 80, b.y - 112, 160, 50)

static func brutus_step(g, X) -> void:
	var b: Dictionary = X.BOSS
	var p: Dictionary = g.player
	var pcx: float = p.x + p.w / 2
	var feet: float = p.y + p.h
	if b.red > 0:
		b.red -= 1
	for k in ["hitT", "landT"]:
		if b.get(k, 0) > 0:
			b[k] -= 1
	var fury: int = BR_HITS - int(b.hp)       # a cada pulo levado ele fica mais rápido
	var wall_l: float = float(b.x0) + 90.0
	var wall_r: float = float(b.x1) - 90.0
	match b.st:
		"idle":
			b.t += 1
			b.cd -= 1
			b.dir = 1 if pcx > b.x else -1
			# o Tomé no ar logo acima: abocanha para cima (não deixa pular na cabeça acordado)
			if int(b.get("snapcd", 0)) > 0:
				b.snapcd -= 1
			if p.dyingT == 0 and not p.onGround and int(b.get("snapcd", 0)) <= 0 and abs(pcx - b.x) < 120 and feet < b.y - 60 and feet > b.y - 260 and p.vy > -3.0:
				b.st = "snap"
				b.t = 0
			# perto e na frente dele, no chão: tenta morder
			elif p.dyingT == 0 and abs(pcx - b.x) < 150 and feet > b.y - 60 and b.cd < 40 and sign(pcx - b.x) == float(b.dir):
				b.st = "bite"
				b.t = 0
			elif b.cd <= 0 and p.dyingT == 0:
				b.st = "paw"
				b.t = 0
		"bite":
			b.t += 1
			if b.t == 12:
				Audio.play("bark", -2)
				b.barkT = 10
				# a mordida: na frente da boca
				var mb: Dictionary = g.R(b.x + b.dir * 40 - 50, b.y - 110, 100, 90)
				if p.dyingT == 0 and Game.hit(p, mb):
					g.hurt(1, b.x)
			if b.get("barkT", 0) > 0:
				b.barkT -= 1
			if b.t > 30:
				b.st = "paw"
				b.t = 0
		"snap":
			# salta abocanhando para cima
			b.t += 1
			if b.t == 6:
				Audio.play("bark", -2, 1.2)
				b.barkT = 10
				b.hop = 1.0
			if b.t >= 6 and b.t <= 16:
				var sb: Dictionary = g.R(b.x - 60, b.y - 230, 120, 140)
				if p.dyingT == 0 and p.iframe == 0 and Game.hit(p, sb):
					g.hurt(1, b.x)
					p.vy = -6.0
					p.vx = 7.0 if pcx > b.x else -7.0
			if b.get("barkT", 0) > 0:
				b.barkT -= 1
			b.hop = max(0.0, float(b.get("hop", 0.0)) - .08)
			if b.t > 26:
				b.st = "idle"
				b.t = 0
				b.cd = max(int(b.cd), 20)
				b.snapcd = 50
		"paw":
			# raspa a pata e late: AVISO da investida (hora de se preparar para pular)
			b.t += 1
			b.dir = 1 if pcx > b.x else -1
			if b.t % 9 == 0:
				g.fx("fx_dust", b.x - b.dir * 50, 494, 16, .14, -.3)
				Audio.play("slide", -12)
			if b.t % 14 == 1:
				Audio.play("bark", -6)
			if b.t > 26 - fury * 3:
				b.st = "charge"
				b.t = 0
				b.spd = 2.0
				# às vezes é finta: freia antes do muro e volta (a partir do 1º pulo levado)
				b.fake = fury >= 1 and randf() < .35 + fury * .08
				Audio.play("roar", -14)
				Polish.roar(b.x + b.dir * 60, b.y - 60)
		"charge":
			# corre reto até o muro do quintal (não freia): o Tomé pula por cima
			b.t += 1
			b.spd = min(b.spd + .45 + fury * .05, 8.5 + fury * .6)
			b.x += b.dir * b.spd
			if g.T % 4 == 0:
				g.fx("fx_dust", b.x - b.dir * 60, 494, 14, .16, -.25)
			var to_wall: float = (wall_r - b.x) if b.dir > 0 else (b.x - wall_l)
			if b.get("fake", false) and to_wall < 190:
				# FINTA: crava as patas e para antes do muro, já virando para o Tomé
				b.st = "skid"
				b.t = 0
				Audio.play("slide", -4, .7)
			if (b.dir < 0 and b.x <= wall_l) or (b.dir > 0 and b.x >= wall_r):
				b.x = clamp(b.x, wall_l, wall_r)
				b.st = "stun"
				b.t = 0
				b.hitT = 16
				g.shake = max(g.shake, 14)
				Audio.play("stomp", -2)
				Audio.vib(80)
				g.burst(b.x + b.dir * 70, b.y - 60, 16, Color("#b7a77f"))
				if not g.L.get("_br_tonto", false):
					g.L["_br_tonto"] = true
					g.flash_tut("Bateu no muro! PULE NA CABEÇA!", "O Brutus bateu no muro e ficou tonto: pule na cabeça dele agora!", 200)
		"skid":
			b.t += 1
			b.spd = max(0.0, b.spd - 1.1)
			b.x = clamp(b.x + b.dir * b.spd, wall_l, wall_r)
			if g.T % 3 == 0:
				g.fx("fx_dust", b.x + b.dir * 40, 494, 16, .18, -.3)
			if b.t > 18:
				b.st = "idle"
				b.t = 0
				b.cd = 16
				b.dir = 1 if pcx > b.x else -1
				if not g.L.get("_br_fake", false):
					g.L["_br_fake"] = true
					g.tip("Finta! O Brutus freou antes do muro. Só pule na cabeça quando ele BATER e ficar tonto.", 220)
		"stun":
			# tonto, com estrelinhas: a janela do pulo na cabeça (cada vez mais curta)
			b.t += 1
			if b.t > 110 - fury * 22:
				b.st = "idle"
				b.t = 0
				b.cd = 50 - fury * 6
		"hurt":
			b.t += 1
			var kb: float = b.get("kb", 0.0)
			if kb > .1:
				b.x = clamp(b.x + kb, wall_l, wall_r)
				b.kb = kb * .86
			if b.t > 34:
				b.st = "idle"
				b.t = 0
				b.cd = 40 - fury * 6
		"down":
			b.t += 1
			if b.t == 1:
				Audio.play("bark", -10, .7)
			if b.t > 150:
				b.done = true
				b.active = false
	if p.dyingT > 0 or p.get("dog") or b.st == "down":
		return
	var hb := brutus_head(g, b)
	var bb := brutus_box(g, b)
	# pulo na cabeça
	if p.vy > .5 and Game.hit(p, hb) and feet - hb.y < 34:
		p.y = hb.y - p.h - 1
		p.cutOk = false
		if b.st == "stun":
			p.vy = -9.0
			# o pulo o joga para o lado do meio do quintal (não fica quicando em cima dele)
			p.vx = 6.0 if b.dir < 0 else -6.0
			_brutus_hit(g, X, b)
			b.snapcd = 60
		else:
			# acordado ele não deixa: abocanha para cima
			p.vy = -7.0
			p.vx = 7.0 if pcx > b.x else -7.0
			b.barkT = 10
			Audio.play("bark", -2)
			g.hurt(1, b.x)
			if not g.L.get("_br_bite", false):
				g.L["_br_bite"] = true
				g.tip("Acordado o Brutus morde quem pula nele! Espere ele bater no muro e ficar tonto.", 220)
		return
	if b.st in ["charge", "skid"] and Game.hit(p, bb):
		g.hurt(1, b.x)

static func _brutus_hit(g, X, b: Dictionary) -> void:
	b.hp -= 1
	b.red = 30
	b.hitT = 16
	g.hit_stop = 6
	g.shake = max(g.shake, 12)
	Audio.play("stomp", 0)
	Audio.play("bark", -4, 1.4)
	Audio.vib(110)
	g.burst(b.x, b.y - 100, 18, Color("#ffd76a"))
	if b.hp <= 0:
		_brutus_win(g, X, b)
		return
	b.st = "hurt"
	b.t = 0
	b.kb = -b.dir * 5.0
	var n: int = int(b.hp)
	g.flash("Toma! Falta%s %d pulo%s na cabeça." % ["m" if n > 1 else "", n, "s" if n > 1 else ""], 150)

## (o mergulho no chão do quintal não faz mais nada na luta)
static func brutus_slam(g, cx: float, feet: float) -> bool:
	return false

static func _brutus_win(g, X, b: Dictionary) -> void:
	b.st = "down"
	b.t = 0
	b.sulk = false
	b.hp = 0
	Polish.final_blow()
	Polish.loot_arc(b.x, b.y - 80, 12, 500.0)
	X._gate_on(false)
	if str(b.get("open", "")) != "":
		for so in g.SOL.duplicate():
			if so.get("id", "") == b.open:
				g.SOL.erase(so)
				if g.K:
					g.K.sink_gate(so)
		g.blockers_dirty()
	for i in 12:
		g.gain_coin(b.item[0], b.item[1] - 20, true)
	Audio.play("door", -4)
	g.flash("O Brutus desistiu e fugiu com o rabo entre as pernas! O portão do quintal abriu.", 280)
	if X.DOG.get("st", "") == "bait":
		X.DOG.st = "follow"
		X._resync()

## Pipoca na luta do Brutus: fica no canto do quintal e late para provocar a investida
static func pipoca_bait(g, X) -> void:
	var D: Dictionary = X.DOG
	var b: Dictionary = X.BOSS
	# fica do lado de fora do portão do quintal, latindo para o Brutus (torcendo pelo Tomé)
	var spot: float = float(b.x0) - 80.0
	var arrived: bool = X._run_to(spot, 500.0, 5.5)
	if not arrived:
		return
	D.face = 1
	D.moving = false
	if int(D.t) % 150 == 0:
		X._bark()

# ======================================================================
#  MORCEGO-REI: as lamparinas
# ======================================================================
const LAMP_R := 210.0      # raio da luz de uma lamparina acesa (o morcego não entra)
const BAT_OFF := 142.0     # o corpo do morcego fica esse tanto acima de HAWK.y (por causa do desenho)

static func bat_setup(h: Dictionary, L: Dictionary) -> void:
	h.lamps = []
	for l in L.hawk.get("lamps", []):
		h.lamps.append({"x": float(l[0]), "y": float(l[1]), "lit": false, "k": 0.0, "dot": null})
	h.maxhp = max(1, h.lamps.size())
	h.hp = h.maxhp
	h.cd = 100
	h.snuffs = 0
	h.stal = []
	h.stalT = 160
	h.gx = (float(h.x0) + float(h.x1)) / 2.0
	h.gyy = float(h.gy) - 300.0

static func bat_center(h: Dictionary) -> Vector2:
	return Vector2(h.x, h.y - BAT_OFF)

static func bat_box(g, h: Dictionary) -> Dictionary:
	var c := bat_center(h)
	return g.R(c.x - 46, c.y - 46, 92, 92)

## centro da luz de uma lamparina
static func lamp_light(l: Dictionary) -> Vector2:
	return Vector2(l.x, l.y - 74)

static func lit_at(h: Dictionary, pt: Vector2, r: float = LAMP_R) -> bool:
	for l in h.get("lamps", []):
		if l.lit and pt.distance_to(lamp_light(l)) < r:
			return true
	return false

static func bat_step(g, K) -> void:
	var h: Dictionary = K.HAWK
	if h.is_empty() or h.done:
		_lamp_lights(g, h)
		return
	var p: Dictionary = g.player
	var pc := Vector2(p.x + p.w / 2, p.y + p.h / 2)
	var feet: float = p.y + p.h
	var gy: float = h.gy
	if h.red > 0:
		h.red -= 1
	if h.get("landT", 0) > 0:
		h.landT -= 1
	_lamp_lights(g, h)
	# visível só perto da luz (lamparina acesa ou a lanterna do Tomé); no escuro, um vulto
	var bc := bat_center(h)
	var seen: bool = lit_at(h, bc, LAMP_R + 20.0) or bc.distance_to(pc) < 200.0 or not g.CINE.is_empty() or h.st in ["wait", "dazzle", "fall", "down", "flee"]
	h.vis = move_toward(float(h.get("vis", 1.0)), 1.0 if seen else .14, .06)
	var unlit := 0
	for l in h.lamps:
		if not l.lit:
			unlit += 1
	if int(h.get("snuffT", 0)) > 0:
		h.snuffT -= 1
	_stalactites(g, h, pc)
	match h.st:
		"wait":
			if pc.x > h.trig and pc.x < h.x1 and feet <= gy + 4 and feet > gy - 300 and p.dyingT == 0:
				h.active = true
				h.st = "lurk"
				h.t = 0
				h.cd = 100
				h.snuffs = 0
				h.stal = []
				h.stalT = 160
				for l0 in h.lamps:
					l0.lit = false
				h.x = h.x1 - 160.0
				h.y = gy - 330.0 + BAT_OFF
				h.hp = h.maxhp
				K._gate("hawkL", true, Rect2(h.x0 - 24, gy - 260, 24, 260))
				K._gate("hawkR", true, Rect2(h.x1, gy - 260, 24, 260))
				Audio.play("thunder", -8)
				if h.get("seen", false):
					# voltou da fogueira: sem a apresentação de novo, a luta recomeça direto
					g.flash("O Morcego-Rei de novo: acenda as lamparinas!", 140)
					return
				h.seen = true
				g.start_cine("morcego", (h.x0 + h.x1) / 2.0, gy - 160, 250,
					[[150, 245, "TOMÉ", "Um morcego gigante! No escuro eu nem vejo ele... Se eu acender as lamparinas da caverna, ele não tem onde se esconder.", "tome"]],
					[60, 150, "MORCEGO-REI", "o dono das profundezas"])
			return
		"lurk":
			h.t += 1
			h.cd -= 1
			# procura um canto escuro perto do Tomé, lá no alto (fica longe das lamparinas acesas)
			if h.t % 80 == 1 or lit_at(h, Vector2(h.gx, h.gyy), LAMP_R + 40.0):
				var best := Vector2(h.gx, h.gyy)
				var bs := -1e9
				for i in 14:
					var cx: float = lerpf(float(h.x0) + 70.0, float(h.x1) - 70.0, i / 13.0)
					for cy in [gy - 360.0, gy - 290.0, gy - 230.0]:
						var q := Vector2(cx, cy)
						if lit_at(h, q, LAMP_R + 50.0):
							continue
						var sc: float = -abs(cx - pc.x) * .6 + randf() * 140.0
						if sc > bs:
							bs = sc
							best = q
				h.gx = best.x
				h.gyy = best.y
			var c := bat_center(h)
			var to := Vector2(h.gx, h.gyy + sin(h.t * .05) * 14.0)
			var nc: Vector2 = c + (to - c).limit_length(3.6)
			if abs(nc.x - c.x) > .3:
				h.dir = 1 if nc.x > c.x else -1
			h.x = nc.x
			h.y = nc.y + BAT_OFF
			if h.cd <= 0 and p.dyingT == 0:
				var lit_l: Array = h.lamps.filter(func(o): return o.lit)
				if lit_at(h, pc) and not lit_l.is_empty() and int(h.snuffs) < 2 and int(h.get("snuffT", 0)) <= 0:
					# o Tomé está na luz: vai APAGAR a lamparina acesa mais longe dele
					var far: Dictionary = lit_l[0]
					for o in lit_l:
						if abs(float(o.x) - pc.x) > abs(float(far.x) - pc.x):
							far = o
					h.st = "snuff"
					h.t = 0
					h.tl = far
					Audio.play("roar", -8, 2.0)
					if not g.L.get("_bat_snuff", false):
						g.L["_bat_snuff"] = true
						g.flash_tut("Ele vai APAGAR a lamparina!", "O Morcego-Rei vai soprar uma lamparina acesa com as asas! Corra até ela para espantá-lo.", 220)
				elif not lit_at(h, pc):
					h.st = "warn"
					h.t = 0
					Audio.play("roar", -8, 2.4)
					Audio.vib(20)
				else:
					h.cd = 50
					if not g.L.get("_bat_light", false):
						g.L["_bat_light"] = true
						g.note("Na luz das lamparinas o Morcego-Rei não chega perto!")
		"warn":
			# chiado e olhos vermelhos: ele vai dar o rasante
			h.t += 1
			h.dir = 1 if pc.x > h.x else -1
			var wt: int = 22 if unlit <= 1 else 30
			if h.t == wt:
				var c2 := bat_center(h)
				h.s0 = c2
				h.s1 = pc + Vector2(0, -4)
				var ex: float = clamp(h.s1.x + (h.s1.x - c2.x), float(h.x0) + 60.0, float(h.x1) - 60.0)
				h.s2 = Vector2(ex, c2.y)
				h.st = "swoop"
				h.t = 0
				Audio.play("slide", -2, .8)
		"swoop":
			h.t += 1
			var n: float = 30.0 if unlit <= 1 else 36.0
			var u: float = clamp(h.t / n, 0.0, 1.0)
			var s0: Vector2 = h.s0
			var s1: Vector2 = h.s1
			var s2: Vector2 = h.s2
			var q2 := Vector2(lerpf(s0.x, s2.x, u), lerpf(s0.y, s2.y, u) + (s1.y - s0.y) * sin(PI * u))
			h.dir = 1 if s2.x > s0.x else -1
			h.x = q2.x
			h.y = q2.y + BAT_OFF
			if lit_at(h, q2, LAMP_R - 30.0):
				# entrou na luz: dá meia-volta guinchando
				h.st = "recoil"
				h.t = 0
				Audio.play("roar", -10, 2.8)
				g.burst(q2.x, q2.y, 10, Color("#ffe9a0"))
				if not g.L.get("_bat_recoil", false):
					g.L["_bat_recoil"] = true
					g.note("A luz espantou o Morcego-Rei!")
			elif p.dyingT == 0 and Game.hit(p, bat_box(g, h)):
				g.hurt(1, h.x)
			if u >= 1.0 and h.st == "swoop":
				h.st = "lurk"
				h.t = 0
				h.cd = 50 if unlit <= 1 else 75
				# às vezes emenda um segundo rasante
				if randf() < .35:
					h.cd = 12
		"snuff":
			# voa até a lamparina e bate as asas em cima dela: se o Tomé chegar perto, foge
			h.t += 1
			var tl: Dictionary = h.tl
			var lc: Vector2 = lamp_light(tl) + Vector2(0, -70)
			var c3 := bat_center(h)
			var nc3: Vector2 = c3 + (lc - c3).limit_length(7.0)
			h.dir = 1 if lc.x > c3.x else -1
			h.x = nc3.x
			h.y = nc3.y + BAT_OFF
			if c3.distance_to(lc) < 20:
				h.blow = int(h.get("blow", 0)) + 1
				if g.T % 6 == 0:
					g.PARTS.append({"x": lc.x + (randf() - .5) * 60, "y": lc.y + 40, "vx": (randf() - .5) * 3, "vy": 1.5 + randf(), "life": 24, "col": Color(.8, .75, .6, .7)})
			if pc.distance_to(lamp_light(tl)) < 150.0 and p.dyingT == 0:
				h.st = "recoil"
				h.t = 0
				h.blow = 0
				h.snuffT = 200
				Audio.play("roar", -10, 2.8)
				g.note("Você espantou o Morcego-Rei da lamparina!")
			elif int(h.get("blow", 0)) > 80:
				tl.lit = false
				h.blow = 0
				h.snuffs = int(h.snuffs) + 1
				h.snuffT = 260
				h.hp = 0
				for o in h.lamps:
					if not o.lit:
						h.hp += 1
				Audio.play("slide", -4, .5)
				g.burst(lamp_light(tl).x, lamp_light(tl).y, 10, Color(.5, .5, .5))
				g.flash("O Morcego-Rei APAGOU uma lamparina! Acenda de novo.", 180)
				h.st = "lurk"
				h.t = 0
				h.cd = 60
			elif h.t > 400:
				h.st = "lurk"
				h.t = 0
				h.cd = 60
		"recoil":
			h.t += 1
			h.y -= 4.0
			h.x -= h.dir * 2.0
			if h.t > 26:
				h.st = "lurk"
				h.t = 0
				h.cd = 60
		"dazzle":
			# tudo aceso: ofuscado, bate as asas sem rumo e despenca
			h.t += 1
			h.x += sin(h.t * .5) * 3.0
			h.red = 6
			if h.t > 70:
				h.st = "fall"
				h.t = 0
				h.vy = 0.0
		"fall":
			h.t += 1
			h.vy = float(h.get("vy", 0.0)) + .5
			h.y = min(gy, h.y + h.vy)
			if h.y >= gy:
				h.st = "down"
				h.t = 0
				h.landT = 12
				g.shake = 12
				g.shake_dir = Vector2(0, 1)
				Audio.play("stomp", -4)
				g.burst(h.x, gy, 16, Color("#cdbfa6"))
				Polish.loot_arc(h.x, gy - 60, 10, gy)
				for i in 10:
					g.gain_coin(h.x, gy - 40, true)
		"down":
			h.t += 1
			h.y = gy
			if h.t > 150:
				h.st = "flee"
				h.t = 0
				Audio.play("dj", -8)
		"flee":
			h.t += 1
			h.x += min(6.0, .5 + h.t * .12)
			h.y -= min(4.5, .3 + h.t * .09)
			if h.t > 120:
				h.done = true
				h.active = false
				Polish.smoke_cloud(h.x, h.y - 40)

## Morcego-Rei no molde do Gavião-Rei: aqui só o que é da caverna (as lamparinas acendendo, o vulto no
## escuro e as estalactites); o resto da luta é a do Gavião (Kings._hawk)
static func bat_extras(g, K) -> void:
	var h: Dictionary = K.HAWK
	if h.is_empty():
		return
	_lamp_lights(g, h)
	if h.done:
		return
	if h.red > 0:
		h.red -= 1
	var p: Dictionary = g.player
	var pc := Vector2(p.x + p.w / 2, p.y + p.h / 2)
	var bc := bat_center(h)
	var seen: bool = lit_at(h, bc, LAMP_R + 20.0) or bc.distance_to(pc) < 220.0 or not g.CINE.is_empty() or h.st in ["wait", "stuck", "flee", "dive"]
	h.vis = move_toward(float(h.get("vis", 1.0)), 1.0 if seen else .18, .06)
	if int(h.get("snuffT", 0)) > 0:
		h.snuffT -= 1
	_stalactites(g, h, pc)

## estalactites que despencam do teto da caverna perto do Tomé (com aviso: poeira e sombra)
static func _stalactites(g, h: Dictionary, pc: Vector2) -> void:
	var st: Array = h.get("stal", [])
	var fight: bool = h.get("active", false) and h.st in ["circle", "mark", "dive", "stuck", "rise"]
	if fight:
		h.stalT = int(h.get("stalT", 160)) - 1
		if int(h.stalT) <= 0:
			h.stalT = 120 + randi() % 70
			var sx: float = clamp(pc.x + (randf() - .5) * 120.0, float(h.x0) + 40.0, float(h.x1) - 40.0)
			st.append({"x": sx, "y": float(h.gy) - 470.0, "vy": 0.0, "t": 0, "st": "warn"})
			h.stal = st
	var p: Dictionary = g.player
	for s in st.duplicate():
		s.t += 1
		if s.st == "warn":
			if s.t % 5 == 0:
				g.PARTS.append({"x": s.x + (randf() - .5) * 16, "y": s.y + 30, "vx": 0.0, "vy": 2.0, "life": 30, "col": Color(.6, .55, .48)})
			if s.t > 46:
				s.st = "fall"
		elif s.st == "fall":
			s.vy = min(float(s.vy) + .7, 16.0)
			s.y += s.vy
			if p.dyingT == 0 and p.iframe == 0 and Game.hit(p, g.R(s.x - 12, s.y - 10, 24, 46)):
				g.hurt(1, s.x)
				s.st = "gone"
			# para nas plataformas ou no chão
			var land: float = float(h.gy)
			for so in g.SOL:
				if so.t == "plat" and s.x > so.x and s.x < so.x + so.w and float(so.y) >= s.y - 4 and float(so.y) < land:
					land = float(so.y)
			if s.y + 40 >= land:
				s.st = "gone"
				g.burst(s.x, land - 4, 10, Color(.62, .58, .52))
				Audio.play("stomp", -14, 1.4)
		if s.st == "gone" or not fight:
			st.erase(s)

## luz das lamparinas no mapa de luz (acende aos poucos e tremula)
static func _lamp_lights(g, h: Dictionary) -> void:
	if h.is_empty():
		return
	var mn = g.get_parent()
	for l in h.get("lamps", []):
		var on: bool = l.lit or h.get("done", false)
		l.k = move_toward(float(l.k), 1.0 if on else 0.0, .035)
		if l.k > 0.0 and l.dot == null and mn != null and mn.get("light_map") != null and mn.has_method("_light"):
			l.dot = mn._light(Color(1, .78, .42), LAMP_R + 30.0)
		if l.dot != null:
			l.dot.position = lamp_light(l)
			l.dot.energy = clamp(float(g.AMB.get("dark", 0.0)), 0.0, 1.0) * 1.3 * float(l.k) * (.94 + .06 * sin(g.T * .37 + l.x))

## lamparina apagada ao lado do Tomé (em pé na plataforma dela)
static func near_lamp(g, K):
	var h: Dictionary = K.HAWK
	if h.is_empty() or h.get("skin", "") != "bat" or not h.get("active", false) or h.get("done", false):
		return null
	if h.st in ["wait", "dive", "flee"]:
		return null
	var p: Dictionary = g.player
	if not p.onGround or p.get("dog"):
		return null
	var pcx: float = p.x + p.w / 2
	for l in h.lamps:
		if not l.lit and abs(pcx - float(l.x)) < 62.0 and abs(p.y + p.h - float(l.y)) < 12.0:
			return l
	return null

## ✦ USAR perto de uma lamparina: acende com a chama da lanterna
static func use_lamp(g, K) -> bool:
	var l = near_lamp(g, K)
	if l == null:
		return false
	l.lit = true
	Audio.play("fire", -2)
	Audio.play("special", -8)
	Audio.vib(60)
	g.burst(float(l.x), float(l.y) - 74, 18, Color("#ffcf6a"))
	var n := 0
	for o in K.HAWK.lamps:
		if o.lit:
			n += 1
	g.flash("A lamparina acendeu! Perto da luz dá para ver a sombra do mergulho dele (%d/%d)." % [n, K.HAWK.lamps.size()], 160)
	return true

# ======================================================================
#  SAPO-REI: a língua e as colmeias
# ======================================================================
const FR_REACH := 760.0    # alcance da língua
const FR_TSPD := 30.0      # velocidade da ponta da língua

static func frog_setup(f: Dictionary, L: Dictionary) -> void:
	var fd: Dictionary = L.fish
	f.pad = null
	# vitória-régia gigante [x, w, y] (é uma das "lily" da fase; achada quando as vitórias-régias carregam)
	f.pd = fd.get("pad", [float(fd.x1) - 300.0, 220.0, float(fd.y0) - 15.0])
	f.hives = []
	for hv in fd.get("hives", []):
		f.hives.append({"x": float(hv[0]), "y": float(hv[1]), "top": float(fd.get("hang", -330)), "st": "hang", "t": 0, "sx": 0.0, "sy": 0.0})
	f.maxhp = max(1, f.hives.size())
	f.hp = f.maxhp
	f.dir = -1
	f.tg = {"st": "", "t": 0}
	f.cd = 80
	frog_home(f)

static func frog_home(f: Dictionary) -> void:
	var pd: Array = f.get("pd", [0.0, 0.0, 0.0])
	f.x = float(pd[0]) + float(pd[1]) / 2.0 + 20.0
	f.y = float(pd[2])

static func _find_pad(g, f: Dictionary) -> void:
	var pd: Array = f.get("pd", [])
	for o in g.LILY:
		if pd.size() > 0 and abs(float(o.x) - float(pd[0])) < 2:
			f.pad = o

## boca do sapo (de onde sai a língua)
static func frog_mouth(f: Dictionary) -> Vector2:
	return Vector2(f.x + f.dir * 112.0, f.y - 66.0)

static func frog_box(g, f: Dictionary) -> Dictionary:
	# tonto, ele fica achatado na folha (língua de fora): dá para pular na cabeça vindo de uma vitória-régia
	if f.get("st", "") in ["dizzy", "hurt"]:
		return g.R(f.x - 92, f.y - 74, 184, 74)
	return g.R(f.x - 92, f.y - 112, 184, 112)

static func frog_step(g, K) -> void:
	var f: Dictionary = K.FISH
	if f.is_empty() or f.done:
		return
	var p: Dictionary = g.player
	var pc := Vector2(p.x + p.w / 2, p.y + p.h / 2)
	var feet: float = p.y + p.h
	if f.red > 0:
		f.red -= 1
	if f.get("hitT", 0) > 0:
		f.hitT -= 1
	if f.get("pad") == null:
		_find_pad(g, f)
	if f.get("pad") != null and f.st not in ["down"]:
		f.y = float(f.pad.y)
	var tg: Dictionary = f.tg
	_hives_step(g, f)
	match f.st:
		"wait":
			if pc.x > f.trig and pc.x < f.x1 and feet < float(f.y0) + 10.0 and feet > float(f.y0) - 140.0 and p.dyingT == 0 and not p.get("dog"):
				f.active = true
				f.st = "idle"
				f.t = 0
				f.cd = 90
				f.hp = f.maxhp
				frog_home(f)
				K._gate("fishL", true, Rect2(f.x0 - 24, f.y0 - 330, 24, f.y1 - f.y0 + 330))
				K._gate("fishR", true, Rect2(f.x1, f.y0 - 330, 24, f.y1 - f.y0 + 330))
				Audio.play("thunder", -8)
				if f.get("seen", false):
					# já viu a apresentação (voltou da fogueira): a luta recomeça direto
					g.flash("O Sapo-Rei de novo: engane a língua com as colmeias!", 140)
					return
				f.seen = true
				g.start_cine("sapo", f.x - 60.0, f.y - 80.0, 250,
					[[150, 245, "TOMÉ", "Um sapo do tamanho de uma carroça! Essa língua gruda em tudo... e se ela grudar numa daquelas colmeias?", "tome"]],
					[60, 150, "SAPO-REI", "o dono do lago do moinho"])
			return
		"idle":
			f.t += 1
			f.cd -= 1
			if abs(pc.x - f.x) > 40:
				f.dir = 1 if pc.x > f.x else -1
			var near: bool = pc.distance_to(frog_mouth(f)) < FR_REACH and pc.x > f.x0 - 10 and p.dyingT == 0
			if f.cd <= 0 and near:
				f.st = "aim"
				f.t = 0
				tg.tgt = pc
				Audio.play("roar", -12, 1.6)
		"aim":
			# a mira brilha no Tomé; nos últimos quadros ela trava (é a hora de desviar)
			f.t += 1
			var aim_t: int = 40 if f.hp <= 1 else 52
			if f.t < aim_t - 18:
				tg.tgt = (tg.tgt as Vector2).lerp(pc, .3)
			if f.t >= aim_t:
				f.st = "tongue"
				f.t = 0
				tg.st = "out"
				tg.tip = frog_mouth(f)
				Audio.play("slide", -4, 1.4)
		"tongue":
			f.t += 1
			_tongue_step(g, K, f, tg, p)
		"dizzy":
			# as abelhas atacam: olhos girando, língua de fora — hora de pular na cabeça
			f.t += 1
			if f.t % 24 == 0:
				Audio.play("climb", -16, 1.6)
			if f.t > 300:
				# passou a tontura: as abelhas voltam para a colmeia (ela volta para o lugar)
				for hv in f.hives:
					if hv.st == "swarm":
						hv.st = "home"
						hv.t = 0
				f.st = "idle"
				f.t = 0
				f.cd = 70
				g.note("As abelhas voltaram para a colmeia. Tente de novo!")
		"hurt":
			f.t += 1
			if f.t > 40:
				f.st = "idle"
				f.t = 0
				f.cd = 80
		"down":
			# vencido: dá um pulo para trás, cai no lago e some lá no fundo
			f.t += 1
			if f.t < 30:
				f.x -= f.dir * 3.0
				f.y = float(f.pd[2]) - sin(f.t / 30.0 * PI) * 70.0
			else:
				f.y += .6
			if f.t == 30:
				Audio.play("splash")
				g.burst(f.x, float(f.y0), 20, Color(.7, .85, .9))
			if f.t > 90:
				f.done = true
				f.active = false
	# contato: encostar no sapo (sem estar tonto) machuca; tonto, um pulo na cabeça vale um golpe
	if p.dyingT == 0 and not p.get("dog") and f.st not in ["down", "wait"]:
		var fb := frog_box(g, f)
		if Game.hit(p, fb):
			if f.st == "dizzy" and p.vy > .8 and feet - fb.y < 34:
				_frog_stomp(g, K, f, p)
			elif f.st not in ["dizzy", "hurt"]:
				g.hurt(1, f.x)

static func _tongue_step(g, K, f: Dictionary, tg: Dictionary, p: Dictionary) -> void:
	var mouth := frog_mouth(f)
	match tg.st:
		"out":
			var tip: Vector2 = tg.tip
			var d: Vector2 = (tg.tgt as Vector2) - tip
			tip += d.limit_length(FR_TSPD)
			tg.tip = tip
			# pegou o Tomé no caminho?
			if p.dyingT == 0 and p.iframe == 0 and not p.get("dog") and Game.hit(p, g.R(tip.x - 14, tip.y - 14, 28, 28)):
				tg.st = "grab"
				tg.t = 0
				p.vx = 0.0
				p.vy = 0.0
				Audio.play("spring", -4, .6)
				return
			if d.length() <= FR_TSPD:
				tg.tip = tg.tgt
				# chegou na mira: tem colmeia ali?
				var hit_hive = null
				for hv in f.hives:
					if hv.st == "hang" and (tg.tip as Vector2).distance_to(Vector2(hv.x, hv.y - 25)) < 42.0:
						hit_hive = hv
				if hit_hive != null:
					tg.st = "stuck"
					tg.t = 0
					tg.hive = hit_hive
					hit_hive.st = "stuck"
					g.shake = max(g.shake, 6)
					Audio.play("stomp", -10, 1.4)
					g.burst(hit_hive.x, hit_hive.y - 25, 10, Color("#e8c26a"))
				else:
					tg.st = "back"
					tg.t = 0
		"stuck":
			# grudou na colmeia: puxa, a colmeia solta do cipó e vem junto até a boca
			tg.t += 1
			var hv: Dictionary = tg.hive
			if tg.t > 14:
				var tip2: Vector2 = tg.tip
				tip2 += (mouth - tip2).limit_length(16.0)
				tg.tip = tip2
				hv.st = "pulled"
				hv.sx = tip2.x
				hv.sy = tip2.y + 25.0
				if tip2.distance_to(mouth) < 18.0:
					# a colmeia bateu na cara do sapo: enxame em cima dele
					hv.st = "swarm"
					hv.t = 0
					tg.st = ""
					f.st = "dizzy"
					f.t = 0
					f.red = 20
					g.shake = max(g.shake, 8)
					Audio.play("roar", -6, 1.3)
					g.burst(mouth.x, mouth.y, 16, Color("#e8c26a"))
					if not g.L.get("_frog_dizzy", false):
						g.L["_frog_dizzy"] = true
						g.flash_tut("As abelhas atacaram! Pule na cabeça dele!", "As abelhas atacaram o Sapo-Rei e ele ficou tonto! Pule na cabeça dele agora!", 220)
		"back":
			var tip3: Vector2 = tg.tip
			tip3 += (mouth - tip3).limit_length(FR_TSPD + 6.0)
			tg.tip = tip3
			if tip3.distance_to(mouth) < FR_TSPD + 6.0:
				tg.st = ""
				f.st = "idle"
				f.t = 0
				f.cd = 70 if f.hp > 1 else 50
		"grab":
			# puxou o Tomé: arrasta até a boca e cospe no lago (perde um coração)
			tg.t += 1
			var tip4: Vector2 = tg.tip
			tip4 += (mouth - tip4).limit_length(20.0)
			tg.tip = tip4
			p.x = tip4.x - p.w / 2
			p.y = tip4.y - p.h / 2
			p.vx = 0.0
			p.vy = 0.0
			p.onGround = false
			if tip4.distance_to(mouth) < 24.0 or tg.t > 50:
				tg.st = ""
				f.st = "idle"
				f.t = 0
				f.cd = 150
				# cuspido de volta numa vitória-régia pequena (antes caía no fundo do lago e ficava
				# preso lá embaixo sem ar): cai em cima dela, molhado, e perde um coração
				var land = null
				var bd := 1e9
				for l in g.LILY:
					if l.get("big") or l.st != 0:
						continue
					var lc: float = float(l.x) + float(l.w) / 2.0
					var dd: float = abs(lc - (f.x - 330.0))
					if lc < f.x - 120.0 and dd < bd:
						bd = dd
						land = l
				Audio.play("splash")
				g.burst(mouth.x, mouth.y, 14, Color(.7, .85, .9))
				if land != null:
					p.x = float(land.x) + float(land.w) / 2.0 - p.w / 2
					p.y = float(land.y) - p.h - 60.0
				else:
					p.x = f.x + f.dir * 190.0 - p.w / 2
					p.y = float(f.y0) - p.h - 60.0
				p.vy = 1.0
				g.hurt(1, f.x)
				if not g.L.get("_frog_grab", false):
					g.L["_frog_grab"] = true
					g.note("Quando a mira brilhar, fique na frente de uma colmeia e desvie no último instante!")

static func _frog_stomp(g, K, f: Dictionary, p: Dictionary) -> void:
	p.vy = Game.STOMP * 1.1
	p.y = frog_box(g, f).y - p.h - 1
	p.cutOk = false
	p.airJumps = 1
	f.hp -= 1
	f.red = 30
	f.hitT = 16
	g.hit_stop = 6
	g.shake = 12
	Audio.play("stomp")
	Audio.play("roar", -8, 1.2)
	Audio.vib(80)
	g.burst(f.x, f.y - 110, 18, Color("#9fe07a"))
	# a colmeia usada acaba; as abelhas somem
	for hv in f.hives:
		if hv.st == "swarm":
			hv.st = "gone"
	if f.hp <= 0:
		f.st = "down"
		f.t = 0
		Polish.final_blow()
		K._gate("fishR", false, Rect2())
		K._gate("fishL", false, Rect2())
		for k in 10:
			g.gain_coin(f.x, f.y - 60, true)
		g.player.hp = Game.MAXHP
		Audio.play("door", -4)
		g.flash("O Sapo-Rei fugiu para o fundo do lago! O caminho está livre.", 260)
	else:
		f.st = "hurt"
		f.t = 0
		g.flash("Pulou na cabeça! Falta%s %d." % ["m" if f.hp > 1 else "", f.hp], 140)

static func _hives_step(g, f: Dictionary) -> void:
	for hv in f.get("hives", []):
		hv.t += 1
		match hv.st:
			"swarm":
				# o enxame zunindo em volta da cabeça do sapo
				hv.sx = lerpf(hv.sx, f.x + f.dir * 30.0, .15)
				hv.sy = lerpf(hv.sy, f.y - 100.0, .15)
			"home":
				# as abelhas levam a colmeia de volta para o cipó
				hv.sx = lerpf(hv.sx, hv.x, .06)
				hv.sy = lerpf(hv.sy, hv.y, .06)
				if Vector2(hv.sx, hv.sy).distance_to(Vector2(hv.x, hv.y)) < 4.0:
					hv.st = "hang"

## morreu/voltou à fogueira: a luta recomeça do zero
static func on_respawn(g, K) -> void:
	var h: Dictionary = K.HAWK
	if not h.is_empty() and h.get("skin", "") == "bat" and not h.done:
		for l in h.get("lamps", []):
			l.lit = false
		h.hp = h.maxhp
		h.cd = 150
	var f: Dictionary = K.FISH
	if not f.is_empty() and f.get("skin", "") == "frog" and not f.done:
		for hv in f.get("hives", []):
			hv.st = "hang"
		f.hp = f.maxhp
		f.tg = {"st": "", "t": 0}
		frog_home(f)
