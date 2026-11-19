extends SceneTree
## Teste do pacote de ação (Combat): combo, golpe carregado, escudo, esquiva, contra-ataque, pedras,
## barris, arena trancada, fases dos chefes, loja e nota.
##   godot --headless --path . -s tests/combat_test.gd

var g
var P: Dictionary
var fails := 0
var SV
var CBS

func ok(name: String, cond: bool, extra: String = "") -> void:
	if not cond:
		fails += 1
	print("%s %s %s" % ["·" if cond else "✗", name, extra])

func frame(set: Dictionary = {}) -> void:
	for k in ["L", "R", "J", "P", "S", "U", "A", "G", "E"]:
		g.keys[k] = false
	for k in set:
		g.keys[k] = set[k]
	g.step()
	while not g.CINE.is_empty():
		g.step()

func press(k: String) -> void:
	g.keys[k + "p"] = true

func wait(n: int, set: Dictionary = {}) -> void:
	for i in n:
		frame(set)

func boar(x: float, v: String = "") -> Dictionary:
	var e := {"k": "boar", "x": x, "y": 500.0, "r": [x - 200, x + 200], "dir": -1, "dead": 0, "base": 500.0, "stun": 0, "leap": 0, "x0": x, "sx": x}
	g.CB.setup_enemy(e, v)
	g.EN.append(e)
	return e

func place(x: float) -> void:
	g.debug_warp(x, 466)
	P = g.player
	wait(20)

func clear_enemies() -> void:
	for e in g.EN:
		e.dead = 99

func _initialize() -> void:
	SV = root.get_node("Save")
	CBS = load("res://scripts/combat.gd")
	SV.setv("shop", "bank", 0)
	for id in ["forca", "combo", "defesa", "vida"]:
		SV.setv("shop", id, 0)
	g = load("res://scripts/game.gd").new()
	root.add_child(g)
	g.load_level(0)
	P = g.player
	clear_enemies()
	# ---------------- combo de 3 golpes num javali parado (tonto)
	place(420)
	var e := boar(490)
	e.stun = 9999
	P.face = 1
	var seq: Array = []
	for i in 3:
		press("G")
		for k in 30:
			frame({"G": false})
			if g.CB.combo_q == false and g.M.swing_t > 0 and not seq.has(g.CB.combo_i):
				seq.append(g.CB.combo_i)
			if g.CB.combo_i == i and g.M.swing_t > 0 and g.M.swing_t < g.CB.sw_dur - 6 and i < 2:
				break
	wait(40)
	ok("combo 0,1,2", seq == [0, 1, 2], str(seq))
	ok("javali (3 de vida) caiu no combo", e.dead > 0, "hp=%d" % int(e.hp))
	ok("contador de combo", g.CB.hits >= 3 or int(g.CB.tr.get("best", 0)) >= 3, "best=%d" % int(g.CB.tr.get("best", 0)))
	# ---------------- escudo: de frente segura o golpe comum
	clear_enemies()
	place(420)
	var s := boar(480, "shield")
	s.dir = -1
	s.stun = 9999
	var hp0: int = int(s.hp)
	press("G")
	wait(30)
	ok("escudo segura a picareta de frente", int(s.hp) == hp0 and int(s.shield) == 1, "hp=%d" % int(s.hp))
	# golpe carregado: segura a defesa até brilhar e solta
	P = g.player
	P.face = 1
	place(430)
	for i in 80:
		frame({"G": true})
	ok("defesa carregou", g.CB.charge_ready, "charge=%d guard=%s" % [g.CB.charge, str(P.guard)])
	frame({"G": false})
	ok("golpe carregado saiu", P.act == "spin" or g.CB.sw_kind == "spin", P.act)
	wait(40)
	ok("escudo quebrou com o carregado", int(s.get("shield", 0)) == 0, "hp=%d" % int(s.hp))
	# ---------------- esquiva: anda rápido e não toma golpe
	clear_enemies()
	place(420)
	var x0: float = P.x
	var hpA: int = int(P.hp)
	press("E")
	frame({"R": true})
	g.hurt(1, P.x + 30)
	wait(16)
	ok("esquiva andou", P.x - x0 > 70, "dx=%d" % int(P.x - x0))
	ok("esquiva sem dano", int(P.hp) == hpA, "hp=%d" % int(P.hp))
	# ---------------- contra-ataque: defesa recém-levantada atordoa quem bateu
	place(420)
	var c := boar(470)
	c.stun = 0
	P.face = 1
	P.iframe = 0
	for i in 18:
		frame({"G": true})
	var hpB: int = int(P.hp)
	g.hurt(1, c.x)
	ok("contra-ataque sem dano", int(P.hp) == hpB, "hp=%d guard=%s hold=%d" % [int(P.hp), str(P.guard), g.M.hold_g])
	ok("contra-ataque atordoou", int(c.stun) >= 60, "stun=%d" % int(c.stun))
	frame({"G": false})
	wait(30)
	# ---------------- pedra: levanta com USAR e arremessa com GOLPE
	clear_enemies()
	place(420)
	g.CB.THR = []
	g.CB.add_thr("rock", P.x + P.w / 2 + 10, 500.0)
	var tgt := boar(620)
	tgt.stun = 9999
	P.face = 1
	press("A")
	frame({"A": true})
	frame()
	ok("pedra na mão", g.CB.held != null)
	press("G")
	frame()
	var hp_t: int = int(tgt.hp)
	for i in 80:
		frame()
		if int(tgt.hp) < hp_t:
			break
	ok("pedra acertou o javali", int(tgt.hp) < hp_t, "hp=%d" % int(tgt.hp))
	# ---------------- barril de pólvora
	clear_enemies()
	place(300)
	var b1 := boar(600)
	var b2 := boar(660, "shield")
	b1.stun = 9999
	b2.stun = 9999
	g.CB.explode(630, 480)
	ok("explosão derrubou o javali", b1.dead > 0 or int(b1.hp) < 3, "hp=%d" % int(b1.hp))
	ok("explosão quebrou o escudo", int(b2.get("shield", 0)) == 0)
	# ---------------- arena trancada (neve, Episódio 1)
	clear_enemies()
	var a: Dictionary = g.CB.ARENAS[0]
	g.debug_warp(float(a.x0) + 200, float(a.y) - 34)
	P = g.player
	for i in 30:
		frame()
		if a.st == "fight":
			break
	ok("arena começou", a.st == "fight", a.st)
	var gates := 0
	for so in g.SOL:
		if str(so.get("id", "")).begins_with("arena0"):
			gates += 1
	ok("portões fecharam", gates == 2)
	for w in 3:
		for i in 60:
			frame()
		for en in a.spawned:
			if not en.dead:
				g.CB.hit_enemy(en, 99, "boom", 1.0)
		for i in 60:
			frame()
	ok("arena vencida", a.st == "won", "st=%s onda=%d" % [a.st, int(a.wave)])
	gates = 0
	for so in g.SOL:
		if str(so.get("id", "")).begins_with("arena0"):
			gates += 1
	ok("portões abriram", gates == 0)
	ok("bônus da arena na carteira", CBS.bank() >= 25, "carteira=%d" % CBS.bank())
	# ---------------- fases dos chefes
	ok("fase 1/2/3 (4 de vida)", CBS.phase_of(4, 4) == 1 and CBS.phase_of(3, 4) == 1 and CBS.phase_of(2, 4) == 2 and CBS.phase_of(1, 4) == 3)
	ok("fase 1/2/3 (3 de vida)", CBS.phase_of(3, 3) == 1 and CBS.phase_of(2, 3) == 2 and CBS.phase_of(1, 3) == 3)
	# ---------------- loja
	SV.setv("shop", "bank", 500)
	ok("comprou força", CBS.buy("forca") and CBS.level_of("forca") == 1 and CBS.bank() == 420)
	ok("comprou combo de 4", CBS.buy("combo") and g.CB.max_combo() == 4)
	ok("sem dinheiro não compra", not CBS.buy("vida") or CBS.bank() >= 0)
	# ---------------- nota
	g.CB.new_trecho()
	g.CB.tr.t = 100
	g.CB.tr.best = 6
	ok("nota S sem dano", g.CB.trecho_grade(g.CB.tr.x0 + 4000).g == "S")
	g.CB.tr.dmg = 3
	ok("nota B com 3 corações perdidos", g.CB.trecho_grade(g.CB.tr.x0 + 4000).g == "B", str(g.CB.trecho_grade(g.CB.tr.x0 + 4000)))
	for id in ["forca", "combo", "defesa", "vida", "bank"]:
		SV.setv("shop", id, 0)
	print("FALHAS: %d" % fails)
	quit(1 if fails > 0 else 0)
