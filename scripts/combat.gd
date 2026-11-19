extends RefCounted
class_name Combat
## Pacote "plataforma de ação" (sem arte nova: tudo com as poses, bichos e objetos que o jogo já tem):
##  1. picareta: combo de 3 golpes (4 com a melhoria), golpe carregado (segurar a defesa e soltar),
##     golpe no ar para baixo com área de dano, contra-ataque (defesa na hora certa) e esquiva rápida;
##  2. sensação do golpe: pausa curta, tremor, empurrão, piscada branca, câmera lenta e contador de combo;
##  3. inimigos com vida, aviso piscando antes do ataque, versões elite / grande / com escudo e
##     arenas trancadas com ondas de inimigos;
##  4. objetos como armas: pedras e caixas para arremessar, barris de pólvora, lanterna que ofusca
##     e caixas de empurrar que esmagam;
##  5. chefes com fases (cor, velocidade e um ataque a mais conforme a vida baixa);
##  6. progressão: melhorias compradas com lápis na fogueira e nota (S/A/B) por trecho.

var g  # Game

# ---------------------------------------------------------------- golpes
const CHARGE_FULL := 44     # quadros de defesa segurada até o golpe carregado ficar pronto
var combo_i := 0            # golpe atual da sequência (0, 1, 2 e, com a melhoria, 3)
var combo_q := false        # apertou GOLPE durante o golpe: emenda o próximo
var combo_win := 0          # quadros depois do golpe em que um novo toque ainda emenda
var sw_dur := 22            # duração do golpe atual
var sw_kind := "hit"        # "hit", "fin" (último do combo) ou "spin" (carregado)
var charge := 0
var charge_ready := false
var was_guard := false
var parry_fx := 0
# ---------------------------------------------------------------- esquiva
var dodge_t := 0
var dodge_dir := 1
var dodge_cd := 0
var ghosts: Array = []
# ---------------------------------------------------------------- combo (contador)
var hits := 0
var hits_t := 0
var hits_pop := 0.0
# ---------------------------------------------------------------- arenas
var ARENAS: Array = []
var arena = null
var arena_msg_t := 0
# ---------------------------------------------------------------- objetos
var THR: Array = []
var held = null
var BOOMS: Array = []
# ---------------------------------------------------------------- chefes
var PHASE := {}
var STONES: Array = []
var stone_cd := 0
# ---------------------------------------------------------------- nota por trecho
var tr := {}
var GRADES: Array = []
var banked_pen := 0

## vida de cada bicho (a picareta tira 1; o pisão tira 1; o mergulho 2; o golpe final 2; o carregado 3)
const HP := {"boar": 3, "frog": 2, "squirrel": 2, "crow": 2, "bat": 2, "fly": 1, "spider": 2, "owl": 2,
	"piranha": 1, "leech": 2, "plant": 2, "mole": 2}
const GROUND := ["boar", "frog", "squirrel"]
const CAN_BIG := ["boar", "frog", "crow", "bat", "spider", "squirrel"]

func _init(game) -> void:
	g = game

# ======================================================================
#  CARREGAR A FASE
# ======================================================================
func load_level() -> void:
	combo_i = 0
	combo_q = false
	combo_win = 0
	charge = 0
	charge_ready = false
	dodge_t = 0
	dodge_cd = 0
	ghosts = []
	hits = 0
	hits_t = 0
	held = null
	THR = []
	BOOMS = []
	STONES = []
	PHASE = {}
	arena = null
	GRADES = []
	banked_pen = 0
	new_trecho()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7331 + int(g.level_idx) * 101
	var ep: int = int(g.level_idx)
	var p_elite: float = [.18, .26, .34][min(ep, 2)]
	var p_big: float = [.10, .15, .20][min(ep, 2)]
	var p_shield: float = [.30, .40, .50][min(ep, 2)]
	for e in g.EN:
		setup_enemy(e, "")
		# o primeiro trecho do Episódio 1 fica com os bichos comuns (o jogador ainda está aprendendo)
		if ep == 0 and float(e.x) < 8000.0:
			continue
		if not HP.has(e.k) or e.k in ["piranha", "leech", "plant", "mole"]:
			continue
		var r1: float = rng.randf()
		var r2: float = rng.randf()
		var r3: float = rng.randf()
		if e.k in GROUND and r3 < p_shield:
			setup_enemy(e, "shield")
		elif e.k in CAN_BIG and r2 < p_big:
			setup_enemy(e, "big")
		elif r1 < p_elite:
			setup_enemy(e, "elite")
	# pedras soltas pelo caminho, perto dos bichos que andam no chão (para arremessar)
	for e in g.EN:
		if not e.k in GROUND:
			continue
		var rx: float = float(e.r[0]) - 150.0
		var fy: float = g.floor_under(rx, float(e.base) - 40.0)
		if abs(fy - float(e.base)) < 3:
			add_thr("rock", rx, fy)
	ARENAS = []
	for a in g.L.get("arenas", []):
		var o: Dictionary = a.duplicate(true)
		o.st = "idle"
		o.wave = 0
		o.gate = 0.0
		o.t = 0
		o.spawned = []
		ARENAS.append(o)

## vida e variação de um bicho ("" comum, "elite" vermelho e rápido, "big" maior, "shield" com escudo)
func setup_enemy(e: Dictionary, v: String) -> void:
	var hp: int = int(HP.get(e.k, 1))
	e.erase("elite")
	e.erase("sc")
	e.erase("shield")
	match v:
		"elite":
			e.elite = 1
			hp *= 2
		"big":
			e.sc = 1.4
			hp += 3
		"shield":
			e.shield = 1
			hp += 1
	e.hp = hp
	e.hp0 = hp
	e.hitT = 0
	e.kbv = 0.0

func add_thr(k: String, x: float, y: float, extra: Dictionary = {}) -> Dictionary:
	var o := {"k": k, "x": x, "y": y, "vx": 0.0, "vy": 0.0, "st": "ground", "rot": 0.0, "t": 0, "fuse": 0, "x0": x, "y0": y}
	o.merge(extra, true)
	THR.append(o)
	return o

# ======================================================================
#  ANTES DA FÍSICA
# ======================================================================
func pre() -> void:
	var p: Dictionary = g.player
	if combo_win > 0:
		combo_win -= 1
	if dodge_cd > 0 and dodge_t == 0:
		dodge_cd -= 1
	if parry_fx > 0:
		parry_fx -= 1
	if hits_t > 0:
		hits_t -= 1
		if hits_t == 0:
			hits = 0
	hits_pop = max(0.0, hits_pop - .08)
	# esquiva rápida (botão próprio): um tranco curto para o lado, sem tomar golpe
	if g.pressed("E"):
		try_dodge()
	# segurando um objeto: escada, cipó, água ou rastejar soltam
	if held != null and (p.ladder or p.vine or p.swim or p.crouch or p.get("dog") or p.dyingT > 0 or p.get("bar")):
		drop_held(false)

func can_act() -> bool:
	var p: Dictionary = g.player
	return not p.ladder and not p.vine and not p.swim and not p.get("bar") and not p.get("dog") and not p.get("isis") and p.dyingT == 0 and p.get("mantleT", 0) <= 0

func try_dodge() -> void:
	var p: Dictionary = g.player
	if dodge_t > 0 or dodge_cd > 0 or not can_act() or p.crouch:
		return
	var d: int = int(p.face)
	if g.kd("R"):
		d = 1
	elif g.kd("L"):
		d = -1
	dodge_dir = d
	p.face = d
	dodge_t = 14
	g.M.swing_t = 0
	if p.get("act", "") in ["swing", "spin"]:
		p.actT = 0
	p.guard = false
	p.slam = false
	p.puff = false
	Audio.play("slide", -4, 1.15)
	Audio.vib(15)
	g.burst(p.x + p.w / 2, p.y + p.h - 4, 8, Color("#e9dbb8"))
	if p.onGround:
		Polish.part("ringw", p.x + p.w / 2, p.y + p.h - 2, 0, 0, 14, Color(1, 1, 1, .35), {"size": 70.0})

## o tranco da esquiva (antes de mover o corpo)
func dodge_phys() -> void:
	if dodge_t <= 0:
		return
	var p: Dictionary = g.player
	var u: float = 1.0 - dodge_t / 14.0
	p.vx = dodge_dir * lerpf(10.0, 4.5, u * u)
	if not p.onGround:
		p.vy = min(p.vy, 1.2)
	p.puff = false
	if Engine.get_physics_frames() % 2 == 0:
		ghosts.append({"x": p.x + p.w / 2, "y": p.y + p.h, "f": p.face, "a": 1.0, "n": "pai_run1" if dodge_t % 4 < 2 else "pai_run2"})
	dodge_t -= 1
	if dodge_t == 0:
		dodge_cd = 22

func dodging() -> bool:
	return dodge_t > 0

# ======================================================================
#  PICARETA: COMBO, CARREGADO, CONTRA-ATAQUE
# ======================================================================
func max_combo() -> int:
	return 4 if int(Save.getv("shop", "combo", 0)) > 0 else 3

func force() -> int:
	return int(Save.getv("shop", "forca", 0))

## começa um golpe (chamado pela Mech): emenda o combo se ainda está na janela
func start_swing(chain: bool) -> void:
	var p: Dictionary = g.player
	if chain:
		combo_i += 1
	else:
		combo_i = 0
	var last: int = max_combo() - 1
	if combo_i > last:
		combo_i = 0
	combo_q = false
	if combo_i == last and combo_i > 0:
		sw_kind = "fin"
		sw_dur = 28
	else:
		sw_kind = "hit"
		sw_dur = 22 if combo_i == 0 else 18
	if p.swim:
		sw_dur += 4
	g.M.swing_t = sw_dur
	g.M.swing_hit = {}
	p.act = "swing"
	p.actT = sw_dur
	p.swd = sw_dur
	p.swk = combo_i
	p.fin = sw_kind == "fin"
	# cada golpe dá um passinho para a frente (o combo anda junto)
	if p.onGround and combo_i > 0:
		p.vx = p.face * (3.0 if sw_kind == "fin" else 2.4)
	Audio.play("slide", -8 if sw_kind == "hit" else -4, randf_range(1.3, 1.45) + combo_i * .07)

func start_spin() -> void:
	var p: Dictionary = g.player
	sw_kind = "spin"
	sw_dur = 30
	combo_i = 0
	g.M.swing_t = sw_dur
	g.M.swing_hit = {}
	p.act = "spin"
	p.actT = sw_dur
	p.swd = sw_dur
	p.swk = 0
	p.fin = false
	p.guard = false
	charge = 0
	charge_ready = false
	g.shake = max(g.shake, 4)
	Audio.play("slide", -2, 1.0)
	Audio.play("unlock", -10, .7)
	Audio.vib(30)
	Polish.part("ringw", p.x + p.w / 2, p.y + p.h / 2, 0, 0, 20, Color(1, .9, .6, .6), {"size": 190.0})

## quadros em que o golpe atual acerta
func swing_active() -> bool:
	var e: int = sw_dur - int(g.M.swing_t)
	match sw_kind:
		"fin":
			return e >= 10 and e <= 20
		"spin":
			return e >= 5 and e <= 25
	return e >= 6 and e <= 14

func swing_box() -> Dictionary:
	var p: Dictionary = g.player
	var cx: float = p.x + p.w / 2
	match sw_kind:
		"fin":
			return g.R(cx + 2 if p.face > 0 else cx - 84, p.y - 26, 82, p.h + 34)
		"spin":
			return g.R(cx - 86, p.y - 24, 172, p.h + 34)
	return g.R(cx + 2 if p.face > 0 else cx - 58, p.y - 10, 56, p.h + 16)

## defesa segurada: vai carregando o golpe; soltou com ele pronto, sai o giro
func guard_step(hold_g: int, holding: bool) -> void:
	var p: Dictionary = g.player
	if p.get("guard", false):
		charge += 1
		if charge == CHARGE_FULL:
			charge_ready = true
			Audio.play("unlock", -8, 1.5)
			Audio.vib(20)
			g.burst(p.x + p.w / 2 + p.face * 16, p.y + 10, 12, Color("#ffe08a"))
		if charge > CHARGE_FULL and g.T % 5 == 0:
			Polish.part("spark", p.x + p.w / 2 + randf_range(-18, 18), p.y + randf_range(-6, 30), 0, -.8, 24, Color(1, .88, .4), {"g": 0.0})
	elif not holding and was_guard and charge_ready and can_act() and held == null:
		start_spin()
	if not p.get("guard", false) and not holding:
		charge = 0
		charge_ready = false
	was_guard = p.get("guard", false)

## contra-ataque: a defesa levantada bem na hora do golpe atordoa quem bateu
func try_parry(from_x: float) -> bool:
	var p: Dictionary = g.player
	if not p.get("guard", false) or not g.M.blocks(from_x):
		return false
	var win: int = 12 + (10 if int(Save.getv("shop", "defesa", 0)) > 0 else 0)
	if g.M.hold_g - 14 > win:
		return false
	parry_fx = 24
	p.iframe = 30
	g.hit_stop = 8
	g.slowmo = max(g.slowmo, 16)
	g.shake = max(g.shake, 6)
	Audio.play("unlock", -2, 1.6)
	Audio.vib(40)
	var cx: float = p.x + p.w / 2 + p.face * 18
	Polish.impact(cx, p.y + 12, Color(1, .95, .6), 10, 34.0)
	Polish.part("txt", cx, p.y - 30, 0, -1.2, 46, Color(1, .92, .5), {"txt": "CONTRA!", "g": .02, "size": 24.0})
	var best = null
	var bd := 150.0
	for e in g.EN:
		if e.dead:
			continue
		var d: float = abs(float(e.x) - from_x) + abs(float(e.y) - (p.y + p.h / 2)) * .5
		if d < bd:
			bd = d
			best = e
	if best != null:
		best.stun = max(int(best.stun), 110)
		best.dizzyT = 110
		best.kbv = p.face * 6.0
		best.hitT = 8
	# o golpe que veio de frente devolve parte da força: o Tomé não é empurrado
	charge = CHARGE_FULL - 6
	return true

## a picareta acertou um bicho (chamado pela Mech)
func swing_enemy(e: Dictionary) -> void:
	var p: Dictionary = g.player
	var dmg: int = 1 + force()
	var how := "hit"
	if sw_kind == "fin":
		dmg = 2 + force()
		how = "fin"
	elif sw_kind == "spin":
		dmg = 3 + force()
		how = "spin"
	hit_enemy(e, dmg, how, 1.0 if float(e.x) > p.x + p.w / 2 else -1.0)
	if held == null and sw_kind != "spin":
		# acertar emenda o próximo golpe com mais folga
		combo_win = max(combo_win, 16)

# ======================================================================
#  DANO NOS BICHOS
# ======================================================================
func hit_enemy(e: Dictionary, dmg: int, how: String, dir: float) -> void:
	if e.dead:
		return
	if not e.has("hp"):
		setup_enemy(e, "")
	var p: Dictionary = g.player
	# escudo de tábuas: de frente segura a picareta; só o golpe carregado e as explosões quebram
	if e.get("shield", 0) > 0 and how in ["hit", "fin", "rock", "crate"]:
		var front: bool = (p.x + p.w / 2 - float(e.x)) * float(e.dir) > 0
		if front:
			Audio.play("unlock", -6, .8)
			Audio.vib(15)
			g.burst(float(e.x) + float(e.dir) * 22, float(e.y) - 20, 10, Color("#e8c890"))
			Polish.impact(float(e.x) + float(e.dir) * 22, float(e.y) - 20, Color(1, .9, .7), 6, 18.0)
			e.kbv = dir * 3.0
			e.stun = max(int(e.stun), 10)
			if how in ["hit", "fin"]:
				p.vx = -p.face * 3.0
			if not g.L.get("_shield_tip", false):
				g.L["_shield_tip"] = true
				g.tip("Escudo de tábuas! Pule por cima e bata nas costas — ou segure GOLPE (defesa) até brilhar e solte: o golpe carregado quebra o escudo.", 260)
			return
	if e.get("shield", 0) > 0 and how in ["spin", "boom", "barrel", "crush"]:
		e.shield = 0
		Audio.play("door", -6, 1.6)
		for i in 8:
			Polish.part("chip", float(e.x) + float(e.dir) * 20, float(e.y) - 20, randf_range(-4, 4), -randf_range(2, 6), 70, Color("#9a7040") if i % 2 == 0 else Color("#6a4a2a"), {"gy": float(e.get("base", e.y)), "size": randf_range(3, 5)})
		g.flash("O escudo quebrou!", 90)
	e.hp = int(e.hp) - dmg
	count_hit(e)
	if int(e.hp) <= 0:
		g.kill_enemy(e, "stomp" if how in ["stomp", "slam"] else "hit")
		if how in ["fin", "spin", "boom"]:
			e.dvy = -8.0
			e.dvx = dir * 4.5
		return
	# sobreviveu: piscada branca, empurrão, tonto um instante
	if how == "hit" and not g.L.get("_combo_tip", false):
		g.L["_combo_tip"] = true
		g.tip("Esse aguenta mais de um golpe! Aperte GOLPE (⛏) várias vezes seguidas: combo de 3 golpes — o último empurra longe.", 240)
	e.hitT = 8
	var kb: float = {"hit": 2.0, "fin": 9.0, "spin": 8.0, "slam": 6.0, "stomp": 1.5, "rock": 5.0, "crate": 6.0, "boom": 10.0}.get(how, 4.0)
	if e.get("sc"):
		kb *= .6
	e.kbv = dir * kb
	e.stun = max(int(e.stun), 26 if how in ["fin", "spin", "boom"] else 18)
	e.erase("wind")
	e.charge = false
	g.hit_stop = max(g.hit_stop, 4 if how in ["fin", "spin"] else 3)
	g.shake = max(g.shake, 5 if how in ["fin", "spin"] else 3)
	g.shake_dir = Vector2(dir, -.2)
	Polish.impact(float(e.x), float(e.y) - 18, Color(1, .96, .82), 7, 22.0 if how != "fin" else 30.0)
	Audio.play("stomp", -6, 1.15 + randf() * .1)
	Audio.vib(18)
	g.burst(float(e.x), float(e.y) - 14, 8, Color("#ffffff"))

func count_hit(e: Dictionary) -> void:
	hits += 1
	hits_t = 110
	hits_pop = 1.0
	tr.best = max(int(tr.get("best", 0)), hits)
	if hits >= 3 and hits % 5 == 0:
		Audio.play("dj", -8, 1.0 + .05 * min(hits, 20))

# ======================================================================
#  DEPOIS DA FÍSICA
# ======================================================================
func post() -> void:
	var p: Dictionary = g.player
	tr.t = int(tr.get("t", 0)) + 1
	for gh in ghosts:
		gh.a -= .09
	ghosts = ghosts.filter(func(gh): return gh.a > 0)
	_enemies_post()
	_throwables()
	_arenas()
	_bosses()
	_stones()
	for b in BOOMS:
		b.t += 1
	BOOMS = BOOMS.filter(func(b): return b.t < 24)
	if arena_msg_t > 0:
		arena_msg_t -= 1

func _enemies_post() -> void:
	var p: Dictionary = g.player
	var focus: bool = g.X != null and g.X.focus
	var pcx: float = p.x + p.w / 2
	for e in g.EN:
		if e.dead:
			continue
		if int(e.get("hitT", 0)) > 0:
			e.hitT -= 1
		if int(e.get("blindCD", 0)) > 0:
			e.blindCD -= 1
		var kv: float = float(e.get("kbv", 0.0))
		if abs(kv) > .05:
			var lo: float = float(e.r[0]) - (0.0 if e.k in GROUND else 60.0)
			var hi: float = float(e.r[1]) + (0.0 if e.k in GROUND else 60.0)
			e.x = clamp(float(e.x) + kv, min(lo, float(e.x)), max(hi, float(e.x)))
			e.kbv = kv * .8
		else:
			e.kbv = 0.0
		if abs(float(e.x) - pcx) > 900:
			continue
		if not g.L.get("_warn_tip", false) and abs(float(e.x) - pcx) < 300 and warn(e):
			g.L["_warn_tip"] = true
			g.tip("Quando o bicho pisca e mostra o \"!\", ele vai atacar: pule, ESQUIVE (botão da bota com a seta) ou segure GOLPE para se defender.", 240)
		# lanterna concentrada: o facho ofusca os bichos (ficam tontos, a hora de bater)
		if focus and int(e.get("blindCD", 0)) == 0 and not e.k in ["owl", "bat", "leech", "plant", "mole", "piranha"] and g.X.scare(float(e.x), float(e.y) - 14):
			e.stun = max(int(e.stun), 75)
			e.dizzyT = 75
			e.blindCD = 260
			Polish.part("txt", float(e.x), float(e.y) - 50, 0, -1.0, 40, Color(1, .95, .6), {"txt": "ofuscado!", "g": .02, "size": 16.0})
			Audio.play("unlock", -14, 1.8)
		# elite: anda um terço mais rápido
		if e.get("elite") and int(e.stun) <= 0 and g.T % 3 == 0:
			g.update_enemy(e)
	# caixas de empurrar caindo esmagam quem está embaixo
	if g.M:
		for c in g.M.PUSH:
			if float(c.get("vy", 0.0)) > 3.0:
				for e in g.EN:
					if not e.dead and Game.hit(c, g.ebox(e)):
						hit_enemy(e, 6, "crush", 1.0)

## aviso: o bicho está prestes a atacar (o desenho pisca e mostra o "!")
static func warn(e: Dictionary) -> bool:
	if e.dead or int(e.get("stun", 0)) > 0:
		return false
	match e.k:
		"boar":
			return int(e.get("wind", 0)) > 0
		"fly", "crow", "bat":
			return int(e.get("st", 0)) == 5
		"mole":
			return int(e.get("st", 0)) == 1
		"frog":
			var t: int = int(e.get("jt", 0)) % 130
			return t >= 76 and t < 100
		"squirrel":
			return int(e.get("st", 0)) == 1
		"owl":
			return int(e.get("st", 0)) == 1 and int(e.get("t", 0)) < 14
	return false

# ======================================================================
#  OBJETOS: PEDRAS, CAIXAS E BARRIS
# ======================================================================
## ✦ USAR perto de uma pedra, caixa pequena ou barril: levanta; com algo na mão: põe no chão
func use() -> bool:
	var p: Dictionary = g.player
	if not can_act() or p.crouch:
		return false
	if held != null:
		drop_held(true)
		return true
	if not p.onGround:
		return false
	var cx: float = p.x + p.w / 2
	var feet: float = p.y + p.h
	var best = null
	var bd := 46.0
	for o in THR:
		if o.st != "ground":
			continue
		var d: float = abs(float(o.x) - cx)
		if d < bd and abs(float(o.y) - feet) < 40:
			bd = d
			best = o
	if best == null:
		for c in g.CR:
			if c.dead or c.t != "break" or c.get("lote"):
				continue
			if abs(c.x + c.w / 2 - cx) < 44 and abs(c.y + c.h - feet) < 8:
				# a caixa pequena vira objeto de mão (some do chão; quebra onde cair)
				c.dead = true
				c.lifted = true
				g.blockers_dirty()
				best = add_thr("crate", c.x + c.w / 2, c.y + c.h, {"item": c.get("item", ""), "n": int(c.get("n", 0))})
				break
	if best == null:
		return false
	held = best
	best.st = "held"
	Audio.play("climb", -6, 1.2)
	if not g.L.get("_thr_tip", false):
		g.L["_thr_tip"] = true
		g.tip("Na mão! GOLPE (⛏) arremessa — com ↑ joga mais alto. ✦ USAR põe no chão.", 220)
	return true

func drop_held(gentle: bool) -> void:
	if held == null:
		return
	var p: Dictionary = g.player
	var o: Dictionary = held
	held = null
	o.st = "fly"
	o.x = p.x + p.w / 2 + p.face * (16 if gentle else 0)
	o.y = p.y + 4
	o.vx = p.face * 1.0
	o.vy = 0.0
	o.soft = true

func throw_held() -> void:
	if held == null:
		return
	var p: Dictionary = g.player
	var o: Dictionary = held
	held = null
	o.st = "fly"
	o.soft = false
	o.x = p.x + p.w / 2 + p.face * 10
	o.y = p.y - 10
	o.vx = p.face * 10.5 + p.vx * .4
	o.vy = -8.5 if g.kd("U") else -3.6
	o.t = 0
	if o.k == "barrel":
		o.fuse = max(int(o.fuse), 1)
	p.act = "throw1"
	p.actT = 14
	Audio.play("slide", -4, 1.0)
	Audio.vib(15)

func holding() -> bool:
	return held != null

func _throwables() -> void:
	var p: Dictionary = g.player
	for o in THR.duplicate():
		o.t += 1
		match o.st:
			"held":
				o.x = p.x + p.w / 2
				o.y = p.y - 26
				o.rot = lerpf(float(o.rot), 0.0, .3)
				if o.k == "barrel" and int(o.fuse) > 0:
					_fuse(o)
			"fly":
				o.vy = min(float(o.vy) + .45, 14.0)
				var nx: float = float(o.x) + float(o.vx)
				var ny: float = float(o.y) + float(o.vy)
				o.rot += float(o.vx) * .06
				var box: Dictionary = g.R(nx - 12, ny - 22, 24, 22)
				var wall := false
				for s in g.near_blockers():
					if s.get("oneway") or s.get("crate"):
						continue
					if Game.hit(box, s):
						wall = true
						break
				if not o.get("soft", false):
					for e in g.EN:
						if e.dead:
							continue
						if Game.hit(box, g.ebox(e)):
							_thr_hit(o, e)
							break
					if o.st != "fly":
						continue
				var fl: float = g.floor_under(nx, float(o.y) - 30.0)
				if wall:
					if float(o.vy) > 0 and abs(fl - ny) < 30 and fl > float(o.y) - 30:
						ny = fl
					else:
						o.vx = -float(o.vx) * .35
						nx = float(o.x)
				if ny >= fl and float(o.vy) >= 0:
					ny = fl
					_land(o, ny)
				o.x = nx
				o.y = ny
				if ny > float(g.L.get("bottom", 2000)) + 300:
					THR.erase(o)
			"ground":
				if o.k == "barrel" and int(o.fuse) > 0:
					_fuse(o)
				# o golpe da picareta acende o pavio do barril
				if o.k == "barrel" and int(o.fuse) == 0 and g.M.swing_t > 0 and swing_active() and Game.hit(swing_box(), g.R(o.x - 20, o.y - 50, 40, 50)):
					o.fuse = 1
					Audio.play("fire", -8, 1.4)
					g.tip("O pavio acendeu! Corra — ou levante (✦) e arremesse!", 160)

func _fuse(o: Dictionary) -> void:
	o.fuse = int(o.fuse) + 1
	if int(o.fuse) % 10 == 0:
		Audio.play("unlock", -16, 2.0)
	if int(o.fuse) > 100:
		if held == o:
			held = null
		explode(float(o.x), float(o.y) - 24)
		THR.erase(o)

func _land(o: Dictionary, gy: float) -> void:
	match o.k:
		"rock":
			if float(o.vy) > 3.0 and not o.get("soft", false):
				Audio.play("stomp", -14, 1.6)
				o.vy = -float(o.vy) * .3
				o.vx = float(o.vx) * .5
				g.burst(o.x, gy, 4, Color("#b7a77f"))
			else:
				o.st = "ground"
				o.vx = 0.0
				o.vy = 0.0
				o.y = gy
		"crate":
			if o.get("soft", false) and float(o.vy) < 6.0:
				_crate_back(o, gy)
			else:
				_crate_break(o, gy)
		"barrel":
			if o.get("soft", false) and int(o.fuse) == 0:
				o.st = "ground"
				o.vx = 0.0
				o.vy = 0.0
				o.y = gy
			else:
				explode(float(o.x), gy - 24)
				THR.erase(o)

func _crate_back(o: Dictionary, gy: float) -> void:
	var c := {"t": "break", "x": float(o.x) - 19, "y": gy - 38, "w": 38, "h": 38, "vy": 0.0, "dead": false, "shake": 0, "crate": 1, "ox": float(o.x) - 19, "oy": gy - 38}
	if o.get("item", "") != "":
		c.item = o.item
	c.n = int(o.get("n", 0))
	g.CR.append(c)
	g.blockers_dirty()
	THR.erase(o)

func _crate_break(o: Dictionary, gy: float) -> void:
	var c := {"t": "break", "x": float(o.x) - 19, "y": gy - 38, "w": 38, "h": 38, "dead": false, "n": int(o.get("n", 0))}
	if o.get("item", "") != "":
		c.item = o.item
	g.break_crate(c)
	THR.erase(o)

func _thr_hit(o: Dictionary, e: Dictionary) -> void:
	var d: float = 1.0 if float(o.vx) >= 0 else -1.0
	match o.k:
		"rock":
			hit_enemy(e, 2 + force(), "rock", d)
			o.vx = -float(o.vx) * .3
			o.vy = -3.0
			o.soft = true
		"crate":
			hit_enemy(e, 3 + force(), "crate", d)
			_crate_break(o, float(o.y))
			o.st = "gone"
		"barrel":
			explode(float(o.x), float(o.y) - 10)
			THR.erase(o)
			o.st = "gone"

## barril de pólvora explodindo: derruba bichos, quebra escudos, caixas e rochas rachadas
func explode(x: float, y: float) -> void:
	BOOMS.append({"x": x, "y": y, "t": 0})
	g.shake = max(g.shake, 12)
	g.shake_dir = Vector2(0, 1)
	g.hit_stop = max(g.hit_stop, 5)
	Audio.play("thunder", -4, 1.6)
	Audio.play("stomp", 0, .55)
	Audio.vib(80)
	Polish.impact(x, y, Color(1, .8, .4), 12, 60.0)
	Polish.smoke_cloud(x, y + 20)
	for i in 16:
		g.PARTS.append({"x": x, "y": y, "vx": randf_range(-5, 5), "vy": -randf_range(2, 7), "life": 30, "col": Color(1, .6, .2), "ember": 1})
	g.burst(x, y, 24, Color("#ffb04a"))
	var R := 140.0
	for e in g.EN:
		if e.dead:
			continue
		if Vector2(float(e.x) - x, float(e.y) - 16 - y).length() < R:
			hit_enemy(e, 4 + force(), "boom", 1.0 if float(e.x) > x else -1.0)
	for c in g.CR:
		if not c.dead and c.t == "break" and Vector2(c.x + c.w / 2 - x, c.y + c.h / 2 - y).length() < R:
			g.break_crate(c)
	if g.X:
		for c in g.X.CRACKS:
			if not g.X.broken.has(c.id) and c.get("kind") != "slam" and Vector2(c.x + c.w / 2 - x, c.y + c.h / 2 - y).length() < R:
				g.X.break_crack(c, true)
	for o in THR.duplicate():
		if o.k == "barrel" and o.st == "ground" and int(o.fuse) == 0 and Vector2(float(o.x) - x, float(o.y) - y).length() < R:
			o.fuse = 86
	var p: Dictionary = g.player
	if Vector2(p.x + p.w / 2 - x, p.y + p.h / 2 - y).length() < 100:
		g.hurt(1, x)

# ======================================================================
#  ARENAS TRANCADAS
# ======================================================================
func _arenas() -> void:
	var p: Dictionary = g.player
	var pcx: float = p.x + p.w / 2
	var feet: float = p.y + p.h
	for a in ARENAS:
		match a.st:
			"idle":
				# (os testes automáticos sem inimigos não entram nas arenas)
				if g.no_coal or p.dyingT > 0 or p.get("dog") or p.get("isis") or not can_act():
					continue
				if pcx > float(a.x0) + 90 and pcx < float(a.x1) - 90 and abs(feet - float(a.y)) < 40 and p.onGround:
					_arena_start(a)
			"fight":
				a.t += 1
				a.gate = min(1.0, float(a.gate) + .06)
				var alive := 0
				for e in a.spawned:
					if not e.dead:
						alive += 1
				if alive == 0 and a.t > 40:
					a.wave += 1
					if a.wave >= a.waves.size():
						_arena_win(a)
					else:
						a.t = 0
						_spawn_wave(a)
			"won":
				a.gate = max(0.0, float(a.gate) - .05)

func _arena_start(a: Dictionary) -> void:
	arena = a
	a.st = "fight"
	a.wave = 0
	a.t = 0
	a.gate = 0.0
	_gates(a, true)
	Audio.play("roar", -10, .9)
	g.shake = max(g.shake, 6)
	g.flash_tut("ARENA! Vença as ondas de inimigos.", "ARENA! As saídas fecharam: vença as ondas de inimigos. Combo (⛏ ⛏ ⛏), esquiva, pedras e barris ajudam!", 200)
	arena_msg_t = 120
	_spawn_wave(a)
	for k in a.get("rocks", []):
		var fy: float = g.floor_under(float(a.x0) + float(k), float(a.y) - 40)
		add_thr("rock", float(a.x0) + float(k), fy, {"arena": 1})
	for k in a.get("barrels", []):
		var fy2: float = g.floor_under(float(a.x0) + float(k), float(a.y) - 40)
		add_thr("barrel", float(a.x0) + float(k), fy2, {"arena": 1})

func _spawn_wave(a: Dictionary) -> void:
	var gy: float = float(a.y)
	var w: Array = a.waves[int(a.wave)]
	var x0: float = float(a.x0)
	var x1: float = float(a.x1)
	var i := 0
	for d in w:
		var k: String = d[0]
		var x: float = x0 + float(d[1])
		var v: String = d[2] if d.size() > 2 else ""
		var e := {"k": k, "x": x, "y": gy, "r": [x0 + 50.0, x1 - 50.0], "dir": -1 if x > (x0 + x1) / 2.0 else 1, "dead": 0, "base": gy, "stun": 30, "leap": 0, "x0": x, "sx": x, "arena": 1}
		match k:
			"crow":
				e.cy = gy - 230.0
				e.y = e.cy
			"bat":
				# (bem mais baixo que nas cavernas: perto do Tomé ele acorda e vem)
				e.cy = gy - 170.0
				e.y = e.cy
			"fly":
				e.cy = gy - 150.0
				e.y = e.cy
			"spider":
				e.top = gy - 300.0
				e.y = e.top + 26.0
				e.r = [x, x]
		setup_enemy(e, v)
		g.EN.append(e)
		a.spawned.append(e)
		# chega com uma nuvem de poeira (caindo do alto, como os vigias do Vargas)
		Polish.smoke_cloud(x, float(e.y))
		g.burst(x, float(e.y) - 10, 10, Color("#e9dbb8"))
		e.startT = g.T + i * 6
		i += 1
	Audio.play("door", -10, .8)
	if int(a.wave) > 0:
		Polish.part("txt", (x0 + x1) / 2.0, gy - 260, 0, -.6, 70, Color(1, .9, .5), {"txt": "ONDA %d/%d" % [int(a.wave) + 1, a.waves.size()], "g": 0.0, "size": 28.0})

func _arena_win(a: Dictionary) -> void:
	a.st = "won"
	arena = null
	_gates(a, false)
	var p: Dictionary = g.player
	Audio.play("special", -4)
	Audio.vib(60)
	Polish.celebrate(p.x + p.w / 2, p.y)
	Polish.loot_arc((float(a.x0) + float(a.x1)) / 2.0, float(a.y) - 120, 12, float(a.y))
	var bonus := 25
	bank_add(bonus)
	var msg := "Arena vencida! +%d lápis para as melhorias" % bonus
	if p.hp < g.max_hp:
		p.hp += 1
		msg += " e +1 coração"
	g.flash(msg + ".", 220)
	tr.arenas = int(tr.get("arenas", 0)) + 1
	for o in THR.duplicate():
		if o.get("arena") and o.st == "ground":
			THR.erase(o)

func _gates(a: Dictionary, on: bool) -> void:
	var idl: String = "arena%dL" % ARENAS.find(a)
	var idr: String = "arena%dR" % ARENAS.find(a)
	for s in g.SOL.duplicate():
		if s.get("id") in [idl, idr]:
			g.SOL.erase(s)
			if g.K:
				g.K.sink_gate(s)
	if on:
		var top: float = float(a.y) - 340
		g.SOL.append({"t": "kinggate", "x": float(a.x0) - 24, "y": top, "w": 24, "h": float(a.y) - top, "id": idl})
		g.SOL.append({"t": "kinggate", "x": float(a.x1), "y": top, "w": 24, "h": float(a.y) - top, "id": idr})
	g.blockers_dirty()

## morreu (ou voltou à fogueira): a arena em andamento recomeça do zero
func on_respawn() -> void:
	dodge_t = 0
	held = null
	charge = 0
	charge_ready = false
	hits = 0
	hits_t = 0
	STONES = []
	for a in ARENAS:
		if a.st == "fight":
			for e in a.spawned:
				g.EN.erase(e)
			a.spawned = []
			a.st = "idle"
			a.gate = 0.0
			_gates(a, false)
	arena = null
	for o in THR.duplicate():
		if o.get("arena"):
			THR.erase(o)
		elif o.st != "ground":
			THR.erase(o)

func arena_left() -> int:
	if arena == null:
		return 0
	var n := 0
	for e in arena.spawned:
		if not e.dead:
			n += 1
	return n

# ======================================================================
#  CHEFES COM FASES
# ======================================================================
static func phase_of(hp: int, mx: int) -> int:
	if mx <= 1:
		return 1
	var lost: int = mx - hp
	return clampi(1 + int(lost * 3 / mx), 1, 3)

const GROUND_BOSS := ["javali", "bear", "salamandra", "guardiao", "vargas"]

func _bosses() -> void:
	var bl: Array = Polish.bosses()
	for bb in bl:
		var r: Dictionary = bb.ref
		var key: String = str(bb.kind) + str(bb.name)
		var ph: int = phase_of(int(bb.hp), int(bb.max))
		var old: int = int(PHASE.get(key, 1))
		if ph > old:
			PHASE[key] = ph
			_phase_change(bb, ph)
		elif ph < old:
			PHASE[key] = ph
		if ph < 2 or bb.weak or int(bb.hp) <= 0 or not g.CINE.is_empty():
			continue
		# mais rápido a cada fase (passos extras de lógica do chefe; nunca na hora de bater nele)
		var every: int = 7 if ph == 2 else 4
		if g.T % every != 0:
			continue
		_boss_extra_step(bb)
	# chefe vencido ou fora da luta: zera as fases
	if bl.is_empty() and not PHASE.is_empty():
		PHASE = {}
		STONES = []

func _boss_extra_step(bb: Dictionary) -> void:
	var r: Dictionary = bb.ref
	match str(bb.kind):
		"javali":
			if r.st in ["intro", "wait", "down", "gone", "hurt", "stun"]:
				return
			g.X._boss()
		"hawk":
			if r.st in ["intro", "wait", "down", "gone", "hurt", "stuck"]:
				return
			g.K._hawk()
		"bear":
			if r.st in ["intro", "wait", "down", "gone", "hurt", "dizzy"]:
				return
			g.K._bear()
		"fish":
			if r.st in ["intro", "wait", "down", "gone", "hurt", "tired"]:
				return
			g.K._fish()
		"vargas", "enguia", "salamandra", "guardiao":
			if r.st in ["intro", "wait", "down", "gone", "hurt", "stun", "cool", "stuck", "fight0", "tired"]:
				return
			var B3 = g.K.B3
			if B3 == null:
				return
			match str(bb.kind):
				"vargas":
					B3._vargas(r)
				"enguia":
					B3._eel(r)
				"salamandra":
					B3._sal(r)
				"guardiao":
					B3._gua(r)

func _phase_change(bb: Dictionary, ph: int) -> void:
	var x: float = float(bb.x)
	var y: float = float(bb.y)
	Polish.roar(x, y)
	g.shake = max(g.shake, 8)
	Audio.play("roar", -6, 1.1 if ph == 2 else .9)
	Polish.part("txt", x, y - 90, 0, -.7, 80, Color(1, .55, .3) if ph == 2 else Color(1, .25, .2), {"txt": "FASE %d!" % ph, "g": 0.0, "size": 30.0})
	var r: Dictionary = bb.ref
	if r.has("red"):
		r.red = 24
	if g.no_coal:
		return
	# fase 3: um ataque a mais
	if ph == 3:
		match str(bb.kind):
			"hawk":
				_minion(bb, "bat" if r.get("skin", "") == "bat" else "crow")
			"fish":
				_minion(bb, "fly")
				_minion(bb, "fly")
		if str(bb.kind) in GROUND_BOSS:
			stone_cd = 60
			g.flash_tut("Fase 3: pedras caindo!", "Fase 3: o chefe está furioso e as pedras começam a cair do alto — fique de olho nas sombras no chão!", 160)

func _minion(bb: Dictionary, k: String) -> void:
	var gy: float = float(bb.gy)
	var r: Dictionary = bb.ref
	var x0: float = float(r.get("x0", float(bb.x) - 400))
	var x1: float = float(r.get("x1", float(bb.x) + 400))
	var x: float = clamp(float(bb.x) + randf_range(-200, 200), x0 + 60, x1 - 60)
	var e := {"k": k, "x": x, "y": gy - 240, "cy": gy - {"fly": 150.0, "bat": 170.0}.get(k, 240.0), "r": [x0 + 40, x1 - 40], "dir": 1, "dead": 0, "base": gy, "stun": 30, "leap": 0, "x0": x, "sx": x, "minion": 1}
	setup_enemy(e, "")
	g.EN.append(e)
	Polish.smoke_cloud(x, gy - 240)

func _stones() -> void:
	var bl: Array = Polish.bosses()
	var p: Dictionary = g.player
	var on := false
	var gy := 500.0
	var x0 := 0.0
	var x1 := 0.0
	for bb in bl:
		if str(bb.kind) in GROUND_BOSS and phase_of(int(bb.hp), int(bb.max)) >= 3 and int(bb.hp) > 0:
			on = true
			gy = float(bb.gy)
			var r: Dictionary = bb.ref
			x0 = float(r.get("x0", float(bb.x) - 500))
			x1 = float(r.get("x1", float(bb.x) + 500))
	if on and not g.no_coal and g.CINE.is_empty():
		stone_cd -= 1
		if stone_cd <= 0:
			stone_cd = 130
			var sx: float = clamp(p.x + p.w / 2 + randf_range(-140, 140), x0 + 40, x1 - 40)
			STONES.append({"x": sx, "gy": g.floor_under(sx, gy - 60), "y": g.cam_y - 60, "vy": 0.0, "t": 0, "st": "warn"})
	for s in STONES.duplicate():
		s.t += 1
		if s.st == "warn":
			if s.t > 50:
				s.st = "fall"
		elif s.st == "fall":
			s.vy = min(float(s.vy) + .7, 18.0)
			s.y += s.vy
			if Game.hit(p, g.R(s.x - 14, s.y - 26, 28, 26)):
				g.hurt(1, s.x)
			if float(s.y) >= float(s.gy):
				s.y = s.gy
				s.st = "done"
				s.t = 0
				g.shake = max(g.shake, 4)
				Audio.play("stomp", -10, .9)
				g.burst(s.x, s.gy, 10, Color("#b7a77f"))
				# a pedra que caiu fica no chão: dá para arremessar no chefe... ou guardar
				var n := 0
				for o in THR:
					if o.k == "rock":
						n += 1
				if n < 6:
					add_thr("rock", s.x, s.gy, {"arena": 1})
		if s.st == "done":
			STONES.erase(s)

# ======================================================================
#  LOJA (lápis guardados) E NOTA POR TRECHO
# ======================================================================
const SHOP := [
	["forca", "Mais força", "A picareta e as pedras tiram 1 de vida a mais.", [80, 160]],
	["combo", "Combo de 4 golpes", "Um quarto golpe no combo, e o último fica mais forte.", [120]],
	["defesa", "Defesa maior", "Fica mais fácil acertar o contra-ataque.", [100]],
	["vida", "Mais um coração", "Um coração a mais na vida.", [100, 200]],
]

static func bank() -> int:
	return int(Save.getv("shop", "bank", 0))

static func bank_add(n: int) -> void:
	Save.setv("shop", "bank", max(0, bank() + n))

## lápis pegos desde o último salvamento vão para a carteira das melhorias
func bank_pen() -> void:
	var pen: int = int(g.STATS.pen)
	if pen > banked_pen:
		bank_add(pen - banked_pen)
	banked_pen = pen

static func level_of(id: String) -> int:
	return int(Save.getv("shop", id, 0))

static func cost_of(id: String) -> int:
	for s in SHOP:
		if s[0] == id:
			var lv: int = level_of(id)
			return int(s[3][lv]) if lv < s[3].size() else -1
	return -1

static func buy(id: String) -> bool:
	var c: int = cost_of(id)
	if c < 0 or bank() < c:
		return false
	Save.setv("shop", "bank", bank() - c)
	Save.setv("shop", id, level_of(id) + 1)
	return true

func new_trecho() -> void:
	var p = g.player
	tr = {"t": 0, "dmg": 0, "deaths": 0, "best": 0, "x0": float(p.x) if p is Dictionary and p.has("x") else 0.0, "arenas": 0}

func trecho_grade(x_end: float) -> Dictionary:
	var dist: float = max(1500.0, x_end - float(tr.get("x0", 0.0)))
	var par: float = dist * 2.2
	var t: float = float(tr.get("t", 0))
	var sc := 92.0
	if t > par:
		sc -= min(24.0, floor((t - par) / (par * .25)) * 8.0)
	sc -= 8.0 * int(tr.get("dmg", 0))
	sc -= 20.0 * int(tr.get("deaths", 0))
	sc += min(8.0, max(0, int(tr.get("best", 0)) - 2) * 1.0)
	sc += 3.0 * int(tr.get("arenas", 0))
	var gr := "B"
	if sc >= 90:
		gr = "S"
	elif sc >= 75:
		gr = "A"
	return {"g": gr, "score": sc, "best": int(tr.get("best", 0)), "dmg": int(tr.get("dmg", 0)), "t": t}

## fogueira grande: fecha a nota do trecho
func on_rest_fire() -> void:
	var p: Dictionary = g.player
	var r: Dictionary = trecho_grade(p.x)
	GRADES.append(r.g)
	var extra := ""
	if int(r.best) >= 3:
		extra = " · combo máx. x%d" % int(r.best)
	g.note("Trecho concluído — nota %s%s" % [r.g, extra])
	Polish.part("txt", p.x + p.w / 2, p.y - 60, 0, -.6, 90, Color(1, .88, .4), {"txt": "NOTA " + str(r.g), "g": 0.0, "size": 30.0})
	new_trecho()

## fim do episódio: nota do último trecho e a média do episódio
func final_grades() -> Array:
	var p: Dictionary = g.player
	var r: Dictionary = trecho_grade(p.x)
	GRADES.append(r.g)
	new_trecho()
	return GRADES.duplicate()

static func avg_grade(arr: Array) -> String:
	if arr.is_empty():
		return "B"
	var s := 0.0
	for x in arr:
		s += {"S": 3.0, "A": 2.0, "B": 1.0}.get(x, 1.0)
	s /= arr.size()
	if s >= 2.6:
		return "S"
	if s >= 1.7:
		return "A"
	return "B"

func save_data() -> Dictionary:
	var ar: Array = []
	for a in ARENAS:
		ar.append(a.st == "won")
	return {"ar": ar, "gr": GRADES.duplicate(), "bp": banked_pen}

func restore(d) -> void:
	if not (d is Dictionary):
		return
	var ar: Array = d.get("ar", [])
	for i in min(ar.size(), ARENAS.size()):
		if ar[i]:
			ARENAS[i].st = "won"
	GRADES = d.get("gr", [])
	banked_pen = int(d.get("bp", int(g.STATS.pen)))
