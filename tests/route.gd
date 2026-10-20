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
	for k in ["L", "R", "J", "P", "S", "U"]:
		g.keys[k] = false
	for k in set:
		g.keys[k] = set[k]
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
	log_lines.append("%s %s: %s  [x=%d y=%d vidas=%d hp=%d]" % ["✗" if bad else "·", name, str(r), int(px()), int(P.y), g.lives, P.hp])

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
	S("entrou na sala", g.player.y > 800)
	S("gancho", walk_to(3190))
	walk_to(3200)
	jr(16, "R")
	S("vermelho", spec("vermelho"))
	S("volta à saída", walk_to(2955))
	press("U")
	frame({"U": true})
	hold({}, 20)
	S("saiu com ↑", g.player.y < 500)
	S("combina corda+gancho", g.try_combine("corda", "gancho") != "")
	walk_to(3560)
	S("caixa", jump_to(3615))
	S("vai ao barranco", walk_to(3860))
	use()
	S("corda presa", g.LOCKS[0].done)
	S("vai à corda", walk_to(3888))
	S("sobe a corda", climb_to("U", func(): return P.ladder == null and P.y < 100, 500))
	S("moita: pista 2 e amarelo", walk_to(4480))
	S("pistas=2 amarelo", n_clues() == 2 and spec("amarelo"))
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
	S("rasteja p/ dentro", crawl(7690))
	S("óleo", g.INV.has("oleo"))
	S("rasteja p/ fora", crawl(7830))
	S("escada da coruja", walk_to(8105))
	S("sobe", climb_to("U", func(): return P.ladder == null and P.onGround and P.y + P.h <= 42, 500))
	S("pavio", walk_to(8140))
	S("azul", walk_to(8010))
	S("pavio+azul", g.INV.has("pavio") and spec("azul"))
	walk_to(8105)
	S("desce", climb_to("S", func(): return P.onGround and P.y > 400, 600))
	S("combina óleo+pavio", g.try_combine("oleo", "pavio") != "")
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
	S("vilão", walk_to(9500))
	walk_to(9740)
	var sa = until({}, func(): return not g.running, 300)
	S("saída", sa is String and sa == "state")
	var nd: int = g.DRWS.filter(func(d): return d.got).size()
	S("final: pistas=%d esp=%d des=%d lápis=%d/%d tempo=%ds" % [n_clues(), g.SPECGOT.size(), nd, g.STATS.pen, g.STATS.penTotal, g.time_left / 60], n_clues() == 6 and g.SPECGOT.size() == 6 and nd == 2)
	for l in log_lines:
		print(l)
	print("FALHAS: %d" % fails)
	quit(1 if fails > 0 else 0)
