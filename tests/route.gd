extends SceneTree
## Teste automático: joga a Fase 1 inteira, do começo à saída da mina, pegando as 6 pistas,
## os 6 lápis especiais e os 2 desenhos. Uso:
##   godot --headless --path . -s tests/route.gd            (sem inimigos)
##   godot --headless --path . -s tests/route.gd -- inimigos (com inimigos)

var g
var P: Dictionary
var log_lines: Array = []
var fails := 0

func frame(set: Dictionary = {}) -> void:
	for k in ["L", "R", "J", "P", "S", "U", "A"]:
		g.keys[k] = false
	for k in set:
		g.keys[k] = set[k]
	g.step()
	while not g.CINE.is_empty():
		g.step()

func press(k: String) -> void:
	g.keys[k + "p"] = true

func px() -> float:
	return P.x + P.w / 2

func ok() -> bool:
	return g.running

func S(name: String, r) -> void:
	P = g.player
	var bad: bool = (r is String and r != "" and not r.begins_with("ok")) or (r is bool and r == false)
	if bad:
		fails += 1
	log_lines.append("%s %s: %s  [x=%d y=%d vidas=%d hp=%d %s]" % ["✗" if bad else "·", name, str(r), int(px()), int(P.y), g.lives, P.hp, P.dieMsg])

func walk_to(x: float, mx: int = 1500):
	var last := px()
	var stuck := 0
	for i in mx:
		P = g.player
		if not ok():
			return "state"
		if abs(px() - x) < 6 and P.onGround:
			for j in 10:
				frame()
			return true
		frame({"R" if x > px() else "L": true})
		P = g.player
		if abs(px() - last) < .05:
			stuck += 1
		else:
			stuck = 0
		last = px()
		if stuck > 50:
			return "stuck@%d,%d" % [int(px()), int(P.y)]
	return "timeout@%d" % int(px())

func wait_ground(set: Dictionary = {}, mx: int = 700):
	for i in mx:
		P = g.player
		if not ok():
			return "state"
		if P.onGround:
			return true
		frame(set)
	return "air"

func hold(set: Dictionary, n: int):
	for i in n:
		if not ok():
			return "state"
		frame(set)
	return true

func until(set: Dictionary, cond: Callable, mx: int = 900):
	for i in mx:
		P = g.player
		if not ok():
			return "state"
		if cond.call():
			return true
		frame(set)
	return "timeout@%d,%d" % [int(px()), int(P.y)]

func hop(dir: String, ndir: int, h: int = 16):
	press("J")
	for i in h:
		frame({"J": true, dir: true} if i < ndir else {"J": true})
	return wait_ground()

func djump(dir: String):
	var d := {dir: true}
	press("J")
	for i in 16:
		frame({"J": true, dir: true})
	for i in 30:
		P = g.player
		if P.vy >= -.5:
			break
		frame(d)
	press("J")
	for i in 16:
		frame({"J": true, dir: true})
	return wait_ground(d)

func jump_to(x: float, dbl: bool = false, mx: int = 200):
	press("J")
	var used := false
	for i in mx:
		P = g.player
		if not ok():
			return "state"
		var d := {}
		if px() < x - 5:
			d = {"R": true}
		elif px() > x + 5:
			d = {"L": true}
		if dbl and not used and i > 14 and P.vy > -1:
			press("J")
			used = true
		var s := d.duplicate()
		s["J"] = i < 16 or (dbl and i < 34)
		frame(s)
		P = g.player
		if P.onGround and i > 3:
			return true
	return "air"

func crawl(x: float, mx: int = 600):
	var dir := "R" if x > px() else "L"
	for i in mx:
		if not ok():
			return "state"
		if (px() >= x) if dir == "R" else (px() <= x):
			for j in 4:
				frame()
			return true
		frame({"S": true, dir: true})
	return "timeout@%d,%d" % [int(px()), int(g.player.y)]

func climb_to(dir: String, cond: Callable, mx: int = 600):
	for i in mx:
		P = g.player
		if cond.call():
			return true
		frame({dir: true})
	return "timeout y=%d lad=%s" % [int(g.player.y), str(g.player.ladder != null)]

func use():
	press("A")
	frame()
	hold({}, 6)
	return true

func down():
	press("S")
	frame({"S": true})
	hold({}, 40)
	return true

func jr(n: int, dir: String):
	press("J")
	hold({"J": true, dir: true}, n)
	return wait_ground({dir: true})

func wall_climb():
	var dir := "R"
	press("J")
	hold({"J": true, dir: true}, 10)
	for i in 18:
		P = g.player
		until({dir: true}, func(): return g.player.wsl > 0 or g.player.onGround, 90)
		P = g.player
		if P.onGround:
			return P.y + P.h <= 102
		press("J")
		frame({"J": true})
		dir = "L" if dir == "R" else "R"
		hold({"J": true}, 6)
	return "wall@%d,%d" % [int(px()), int(P.y)]

func on_perch() -> bool:
	return P.onGround and P.y + P.h <= 372

func boss_fight():
	for it in 60:
		P = g.player
		var b: Dictionary = g.X.BOSS
		if b.done or b.st == "flee":
			hold({}, 120)
			return true
		if not ok():
			return "state"
		if b.st == "stun":
			jump_to(b.x, true)
			hold({}, 2)
		elif not on_perch():
			walk_to(3175)
			jump_to(3175, true)
		else:
			until({}, func(): return g.X.BOSS.st == "stun" or g.X.BOSS.st == "flee" or not on_perch(), 900)
	return "hp=%d st=%s" % [g.X.BOSS.hp, g.X.BOSS.st]

func n_clues() -> int:
	return g.CLUEGOT.size()

func spec(c: String) -> bool:
	return g.SPECGOT.has(c)

func _initialize() -> void:
	g = load("res://scripts/game.gd").new()
	root.add_child(g)
	g.load_level(0)
	var with_en := OS.get_cmdline_user_args().has("inimigos")
	if not with_en:
		g.no_coal = true
		for e in g.EN:
			e.dead = 99
	P = g.player
	S("pista 1", walk_to(600))
	S("pistas=%d" % n_clues(), n_clues() == 1)
	S("abaixa sob as toras", crawl(870))
	S("vai à escada", walk_to(1105))
	S("sobe a escada", climb_to("U", func(): return P.y + P.h <= 228, 400))
	walk_to(1200)
	S("corda", g.INV.has("corda"))
	S("volta à escada", walk_to(1105))
	S("sobe ao telhado", climb_to("U", func(): return P.ladder == null and P.y < 100, 300))
	hold({}, 10)
	S("laranja", spec("laranja"))
	S("desce", climb_to("S", func(): return P.onGround and P.y > 400, 500))
	walk_to(1470)
	S("caixa ★", hop("R", 5))
	S("empurra a caixa", until({"R": true}, func(): return g.M.PUSH[0].x >= 1799 and g.M.PUSH[0].y >= 449, 700))
	S("portão abriu", until({}, func(): return g.M.GATES[0].open > .85, 200))
	S("pula a caixa", jump_to(1940, true))
	S("sob o galho", walk_to(1990))
	S("salto duplo ao galho", djump("R"))
	walk_to(2180)
	S("galho alto", jump_to(2330, true))
	S("corre", walk_to(2455))
	press("J")
	hold({"J": true, "R": true}, 16)
	S("agarra cipó", until({"R": true}, func(): return P.vine != null, 80))
	for i in 500:
		P = g.player
		if P.vine == null:
			break
		var v: Dictionary = P.vine
		frame({"R": true} if v.om > 0 else {"L": true})
		if v.th > .95 and v.om > 0:
			break
	press("J")
	frame({"R": true})
	for i in 14:
		frame({"R": true})
	press("J")
	hold({"J": true, "R": true}, 14)
	S("pousa", wait_ground({"R": true}))
	S("desenho 1", g.DRWS.filter(func(d): return d.got).size() == 1)
	S("anda até o tronco oco", walk_to(2958))
	down()
	hold({}, 90)
	S("entrou na sala", g.player.y > 800 and g.player.warp.is_empty())
	S("gancho", walk_to(3190))
	walk_to(3200)
	jr(16, "R")
	S("vermelho", spec("vermelho"))
	S("parede falsa", walk_to(2690))
	S("sala secreta 1", g.X.found.has("s1"))
	S("volta à saída", walk_to(2955))
	press("U")
	frame({"U": true})
	hold({}, 80)
	S("saiu com ↑", g.player.y < 500 and g.player.warp.is_empty())
	S("combina corda+gancho", g.try_combine("corda", "gancho") != "")
	S("arena do javali", walk_to(3360))
	S("javali apareceu", g.X.boss_active())
	S("sobe no galho", jump_to(3175, true))
	S("venceu o javali", boss_fight())
	walk_to(3560)
	S("caixa", jump_to(3615))
	S("vai ao barranco", walk_to(3860))
	use()
	S("corda presa", g.LOCKS[0].done)
	S("vai à corda", walk_to(3888))
	S("sobe a corda", climb_to("U", func(): return P.ladder == null and P.y < 100, 500))
	S("rocha rachada", walk_to(3950))
	press("G")
	hold({}, 26)
	S("golpe quebrou a rocha", g.X.broken.has("rock1"))
	S("cachorro amarrado", walk_to(4050))
	use()
	S("Pipoca solto", g.X.dog_free())
	S("portão alto", walk_to(4130))
	hold({}, 20)
	press("D")
	frame()
	S("controla o Pipoca", g.M.ctrl)
	S("Pipoca pela portinhola até a placa", walk_to(4226))
	S("portão abriu", until({}, func(): return g.M.GATES[1].open > .85, 200))
	press("D")
	frame()
	S("de volta ao Tomé", not g.M.ctrl and g.X.DOG.st == "stay")
	S("toca", walk_to(4290))
	use()
	S("Pipoca buscou o desenho", until({}, func(): return g.DRWS[2].got, 700))
	S("moita: pista 2 e amarelo", walk_to(4480))
	S("pistas=2 amarelo", n_clues() == 2 and spec("amarelo"))
	S("poço entre paredes", walk_to(4640))
	S("pulo na parede", wall_climb())
	walk_to(4585)
	hold({"R": true}, 8)
	S("desce pelo poço", wait_ground())
	S("desce do platô", walk_to(4760))
	walk_to(4830)
	S("armadura", jump_to(4889))
	S("beira da ilha", walk_to(4985))
	S("vitória-régia 1", jump_to(5086))
	S("vr 2", jump_to(5226))
	S("vr 3", jump_to(5356))
	S("tronco molhado", jump_to(5500))
	S("ponta do tronco", walk_to(5610))
	S("ilha 2", jump_to(5740))
	S("lama até o poço", walk_to(5925))
	S("cai no poço", until({"R": true}, func(): return P.ladder != null or P.y > 700, 200))
	S("desce a escada", climb_to("S", func(): return P.onGround and P.y > 800, 400))
	S("gruta", walk_to(6160))
	S("engrenagem e pista 3", g.INV.has("engrenagem") and n_clues() == 3)
	S("pula na água", until({"L": true}, func(): return P.swim, 400))
	S("mergulha", until({"L": true, "S": true}, func(): return px() < 5650 and P.y > 990, 400))
	S("túnel", until({"L": true}, func(): return px() < 5560, 300))
	S("bolsão de ar", until({"U": true}, func(): return P.y < 962, 300))
	press("J")
	hold({"J": true, "L": true}, 14)
	S("borda", wait_ground({"L": true}))
	S("sala secreta 2", g.X.found.has("s2"))
	hold({"R": true}, 30)
	S("volta mergulhando", until({"R": true, "S": true}, func(): return px() > 5600 and P.y > 1000, 400))
	S("sai do túnel", until({"R": true}, func(): return px() > 5790, 400))
	S("sobe", until({"U": true, "R": true}, func(): return P.y < 912, 300))
	press("J")
	hold({"J": true, "R": true}, 16)
	S("fora da água", wait_ground({"R": true}))
	S("fôlego ok", g.lives >= 3)
	walk_to(6160)
	S("volta à escada", walk_to(5960))
	S("sobe", climb_to("U", func(): return P.y + P.h <= 504, 400))
	S("sai do poço", jump_to(6050))
	walk_to(6100)
	S("pula o brejo", jump_to(6230))
	S("ilha 3", walk_to(6300))
	S("sobe a rede", climb_to("U", func(): return P.ladder == null and P.y + P.h <= 152, 400))
	S("galho: manivela + verde", walk_to(6430))
	S("manivela_q", g.INV.has("manivela_q") and spec("verde"))
	walk_to(6320)
	S("desce", climb_to("S", func(): return P.onGround and P.y > 400, 500))
	S("combina engrenagem+manivela", g.try_combine("engrenagem", "manivela_q") != "")
	S("comporta", walk_to(6440))
	use()
	S("escoa", until({}, func(): return g.SWAMP.filter(func(s): return s.get("id") == "canal")[0].y >= 639, 400))
	S("passa a comporta", walk_to(6528))
	S("pedra 1", jump_to(6620))
	S("pedra 2", jump_to(6760))
	walk_to(6790)
	S("pedrinha (pista 4)", until({"R": true}, func(): return P.onGround and P.y > 520, 100))
	S("pistas=4", n_clues() == 4)
	S("pedra 3", jump_to(6900))
	S("margem", jump_to(7060))
	S("noite", walk_to(7150))
	S("caixa", jump_to(7215))
	S("porta do galpão", walk_to(7470))
	hold({}, 20)
	press("D")
	frame()
	S("Pipoca", g.M.ctrl)
	S("Pipoca entra pela portinhola", walk_to(7700))
	S("óleo", g.INV.has("oleo"))
	S("Pipoca sai", walk_to(7470))
	press("D")
	frame()
	S("Tomé", not g.M.ctrl)
	S("telhado do galpão", jump_to(7545, true))
	S("desce do telhado", walk_to(7840))
	S("escada da coruja", walk_to(8105))
	S("sobe", climb_to("U", func(): return P.ladder == null and P.onGround and P.y + P.h <= 42, 500))
	S("pavio", walk_to(8140))
	S("azul", walk_to(8010))
	S("pavio+azul", g.INV.has("pavio") and spec("azul"))
	walk_to(8105)
	S("desce", climb_to("S", func(): return P.onGround and P.y > 400, 600))
	S("combina óleo+pavio", g.try_combine("oleo", "pavio") != "")
	S("laje do X", walk_to(7910))
	use()
	S("quebrou a laje", g.X.broken.has("slab"))
	S("desce na câmara", climb_to("S", func(): return P.onGround and P.y > 800, 500))
	S("espelho do chão", walk_to(7790))
	use()
	walk_to(7780)
	press("J")
	for i in 40:
		frame({"J": true})
		if i == 16:
			press("J")
	wait_ground()
	S("espelhos girados", g.X.MIRRORS[0].s == 1 and g.X.MIRRORS[1].s == 1)
	walk_to(7850)
	frame({"L": true})
	S("facho no cristal", hold({"A": true}, 60))
	S("grades abertas", g.X.opened.has("cdoor"))
	var rg = walk_to(7598)
	S("lápis dourado %s" % str(rg), g.X.GOLD.got)
	walk_to(7985)
	S("plataforma de luz 1", jump_to(7995) is bool and P.y + P.h < 850)
	S("pl. 2", jump_to(8060) is bool and P.y + P.h < 795)
	S("pl. 3", jump_to(7988) is bool and P.y + P.h < 740)
	S("sala secreta 3", g.X.found.has("s3"))
	S("desce", until({"L": true}, func(): return P.onGround and P.y > 850, 300))
	S("escada da laje", walk_to(7910))
	S("sobe", climb_to("U", func(): return P.ladder == null and P.onGround and P.y < 480, 500))
	walk_to(8105)
	S("cogumelo", until({"R": true}, func(): return P.vy < -15, 300))
	var dj := false
	for i in 200:
		P = g.player
		if not dj and P.vy > -1:
			press("J")
			dj = true
		frame({"R": px() < 8470, "J": dj and i < 60})
		P = g.player
		if dj and P.onGround:
			break
	S("quica + pulo duplo", g.player.y < 130)
	S("desenho 2", walk_to(8540))
	walk_to(8640)
	S("desce do galho", until({}, func(): return P.onGround and P.y > 400, 200))
	S("entrada do túnel", walk_to(8650))
	use()
	S("barreira aberta", g.LOCKS[2].done)
	S("túnel", walk_to(8890))
	S("rasteja", crawl(9050))
	S("escada do nicho", walk_to(9250))
	S("desce", climb_to("S", func(): return P.onGround and P.y > 700, 500))
	S("pista 5", walk_to(9090))
	walk_to(9280)
	S("rasteja divisória", crawl(9360))
	S("pistas=6 e roxo", n_clues() == 6 and spec("roxo"))
	S("volta", crawl(9260))
	S("sobe", climb_to("U", func(): return P.ladder == null and P.onGround and P.y < 480, 500))
	walk_to(8105)
	S("vilão foge", walk_to(9600))
	S("perseguição começou", g.VIL.go)
	walk_to(9930)
	S("1º buraco", jump_to(10100))
	walk_to(10220)
	S("desliza sob a viga", crawl(10350))
	walk_to(10585)
	S("2º buraco", jump_to(10790, true))
	walk_to(10850)
	S("pula o carrinho parado", jump_to(11000, true))
	walk_to(11070)
	S("tábua 1", jump_to(11160))
	S("tábua 2", jump_to(11290))
	S("tábua 3", jump_to(11420))
	S("chão", jump_to(11530))
	walk_to(11670)
	S("viga 2", crawl(11800))
	S("vilão entrou na mina", until({"R": true}, func(): return g.VIL.gone or px() > 12100, 900))
	S("vilão entrou", until({}, func(): return g.VIL.gone, 400))
	walk_to(12215)
	var sa = until({}, func(): return not g.running, 300)
	S("saída", sa is String and sa == "state")
	var nd: int = g.DRWS.filter(func(d): return d.got).size()
	S("segredos %d/3 dourado=%s chefe=%s" % [g.X.found.size(), str(g.X.GOLD.got), str(g.X.BOSS.done)], g.X.found.size() == 3 and g.X.GOLD.got and g.X.BOSS.done)
	S("final: pistas=%d esp=%d des=%d lápis=%d/%d tempo=%ds" % [n_clues(), g.SPECGOT.size(), nd, g.STATS.pen, g.STATS.penTotal, g.time_left / 60], n_clues() == 6 and g.SPECGOT.size() == 6 and nd == 3)
	for l in log_lines:
		print(l)
	print("FALHAS: %d" % fails)
	quit(1 if fails > 0 else 0)
