extends SceneTree
## Teste automático: joga a Fase 1 inteira, do começo à saída da mina, pegando as 6 pistas,
## os 6 lápis especiais e os 2 desenhos. Uso:
##   godot --headless --path . -s tests/route.gd            (sem inimigos)
##   godot --headless --path . -s tests/route.gd -- inimigos (com inimigos)

var g
var P: Dictionary
var log_lines: Array = []
var fails := 0
var rests: Array = []

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

## sobe a fenda pulando de parede em parede; termina em pé lá em cima
func crevice_climb():
	var dir := "R"
	press("J")
	hold({"J": true, dir: true}, 10)
	for i in 24:
		P = g.player
		until({dir: true}, func(): return g.player.wsl > 0 or g.player.onGround, 90)
		P = g.player
		if P.onGround:
			return P.y + P.h <= -14 or "chão y=%d" % int(P.y + P.h)
		press("J")
		frame({"J": true})
		dir = "L" if dir == "R" else "R"
		hold({"J": true}, 6)
	return "fenda@%d,%d" % [int(px()), int(P.y)]

func hawk_fight():
	var h: Dictionary = g.K.HAWK
	var mid: float = (h.x0 + h.x1) / 2.0
	for it in 3000:
		P = g.player
		if not ok():
			return "state"
		if h.done or h.st == "flee":
			hold({}, 60)
			return true
		match h.st:
			"mark", "dive":
				var tx: float = h.tx - 230 if h.tx > mid else h.tx + 230
				frame({"R" if tx > px() else "L": true} if abs(tx - px()) > 10 else {})
			"stuck":
				var side: float = -1.0 if px() < h.x else 1.0
				var tx2: float = h.x + side * 44
				if abs(tx2 - px()) > 6:
					frame({"R" if tx2 > px() else "L": true})
				else:
					P.face = -int(side)
					press("G")
					hold({}, 24)
			_:
				frame()
	return "hp=%d st=%s" % [h.hp, h.st]

## pula de um cipó para o próximo (solta no auge do balanço para a frente)
func vine_hop(next_vine, mx: int = 600):
	for i in mx:
		P = g.player
		if not ok():
			return "state"
		if P.vine == null:
			break
		var v: Dictionary = P.vine
		frame({"R": true} if v.om > 0 else {"L": true})
		if v.th > .35 and v.om > 0:
			break
	press("J")
	frame()
	if next_vine == null:
		return wait_ground()
	return until({}, func(): return g.player.vine == next_vine or g.player.get("bar") != null or g.player.onGround, 120)

## pula da beirada até agarrar um cipó (com pulo duplo)
func grab_vine(v):
	press("J")
	for i in 120:
		P = g.player
		if P.vine == v:
			return true
		if i == 16:
			press("J")
		frame({"J": i < 40, "R": true})
	return "sem cipó"

func fish_fight():
	var f: Dictionary = g.K.FISH
	for it in 6000:
		P = g.player
		if not ok():
			return "state"
		if f.done or f.st == "down":
			hold({}, 30)
			return true
		var pc := Vector2(px(), P.y + P.h / 2)
		var d := {}
		match f.st:
			"tired":
				var pts: Array = g.K.scale_pts()
				var tgt = null
				for i in 4:
					if f.scales[i]:
						tgt = pts[i]
						break
				if tgt == null:
					frame()
					continue
				var want_x: float = tgt.x - 230 if pc.x < f.x else tgt.x + 230
				want_x = clamp(want_x, f.x0 + 30, f.x1 - 30)
				if abs(want_x - pc.x) > 30:
					d["R" if want_x > pc.x else "L"] = true
				var hy: float = P.y + 14
				if hy > tgt.y + 6:
					d["U"] = true
				elif hy < tgt.y - 6:
					d["S"] = true
				P.face = 1 if tgt.x > pc.x else -1
				if abs(hy - tgt.y) < 22 and g.NT.harp_cd == 0 and abs(tgt.x - pc.x) < 380:
					g.keys["Gp"] = true
			"aim", "charge":
				var midy: float = (f.y0 + f.y1) / 2.0
				if f.y > midy:
					d["U"] = true
				else:
					d["S"] = true
			"suck":
				d["L" if f.x > pc.x else "R"] = true
			_:
				var want: float = f.x - 300 if pc.x < f.x else f.x + 300
				want = clamp(want, f.x0 + 40, f.x1 - 40)
				if abs(want - pc.x) > 20:
					d["R" if want > pc.x else "L"] = true
		frame(d)
	return "hp=%d st=%s" % [f.hp, f.st]

## bola de neve rolando na direção do Tomé: anda até disparar e pula por cima quando ela chega
func dodge_roll(x: float, i: int):
	walk_to(x)
	var o: Dictionary = g.TR.by_kind("roll")[1 + i]
	var r = until({}, func(): return o.st == "go" and o.bx - px() < 85, 400)
	if r != true:
		return "não rolou: " + str(r) + " st=" + o.st
	press("J")
	hold({"J": true}, 16)
	wait_ground()
	hold({}, 10)
	return o.bx < px() - 20 or "bola em %d" % int(o.bx)

## corre (dois toques em →) até x
func run_to(x: float):
	frame({"R": true})
	frame({})
	for i in 300:
		P = g.player
		if px() >= x:
			return true
		frame({"R": true})
	return "timeout@%d" % int(px())

func ride():
	var RD = g.RD
	for it in 4000:
		if not RD.riding:
			return RD.done
		var d := {}
		for o in RD.OBS:
			var dx: float = o.x - RD.hx
			if dx < -140 or dx > 220:
				continue
			if o.k in ["log", "rock", "gap"] and dx < 74 and dx > 30 and RD.hy >= 500:
				press("J")
				d["J"] = true
			if o.k in ["branch", "rope"] and dx < 130:
				d["S"] = true
			if dx > -40 or o.k in ["branch", "rope"]:
				break
		frame(d)
	return "não terminou x=%d" % int(RD.hx)

func _to_bar():
	for i in 600:
		P = g.player
		if P.vine == null:
			break
		var v: Dictionary = P.vine
		frame({"R": true} if v.om > 0 else {"L": true})
		if v.th > .35 and v.om > 0:
			break
	press("J")
	frame()
	return until({}, func(): return g.player.get("bar") != null, 120)

func on_perch() -> bool:
	return P.onGround and P.y + P.h <= 397

func boss_fight():
	for it in 60:
		P = g.player
		var b: Dictionary = g.X.BOSS
		if b.done or b.st == "down":
			hold({}, 160)
			return true
		if not ok():
			return "state"
		if on_perch():
			# espera ele se afastar e desce de novo
			until({}, func(): return g.X.BOSS.st == "idle" or g.X.BOSS.st == "down", 600)
			if g.X.BOSS.st == "down":
				continue
			walk_to(4925)
			until({}, func(): return P.onGround and P.y + P.h >= 494, 60)
		walk_to(4825)
		# no chão: ele investe; pula para o galho quando chega perto
		until({}, func(): return g.X.BOSS.st == "charge" and abs(g.X.BOSS.x - px()) < 330, 400)
		jump_to(4825, true)
		hold({}, 4)
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
	g.rest_reached.connect(func(n):
		rests.append(n)
		print("REST ", n, " T=", g.T)
		g.running = true)
	S("pista 1", walk_to(600))
	S("pistas=%d" % n_clues(), n_clues() == 1)
	S("abaixa sob as toras", crawl(870))
	walk_to(980)
	S("pedra 1 da escada", jump_to(1060))
	S("pedra 2 da escada", jump_to(1170))
	S("alto da escada de pedras", jump_to(1300))
	walk_to(1570)
	walk_to(1625)
	S("caixa no buraco da placa", until({"R": true}, func(): return g.M.PUSH[4].x >= 1879 and g.M.PUSH[4].y >= 449, 900))
	S("portão 3 abriu", until({}, func(): return g.M.GATES[2].open > .85, 200))
	S("pula a caixa 3", jump_to(1915))
	S("passa o portão 3", walk_to(2065))
	S("cipó do riacho", grab_vine(g.VINES[5]))
	S("outra margem do riacho", vine_hop(null))
	S("vai à escada", walk_to(2755))
	S("sobe a escada", climb_to("U", func(): return P.y + P.h <= 228, 400))
	walk_to(2850)
	S("corda", g.INV.has("corda"))
	S("volta à escada", walk_to(2755))
	S("sobe ao telhado", climb_to("U", func(): return P.ladder == null and P.y < 100, 300))
	hold({}, 10)
	S("laranja", spec("laranja"))
	S("desce", climb_to("S", func(): return P.onGround and P.y > 400, 500))
	walk_to(3120)
	S("caixa ★", hop("R", 5))
	S("empurra a caixa", until({"R": true}, func(): return g.M.PUSH[0].x >= 3449 and g.M.PUSH[0].y >= 449, 700))
	S("portão abriu", until({}, func(): return g.M.GATES[0].open > .85, 200))
	S("pula a caixa", jump_to(3590, true))
	S("sob o galho", walk_to(3640))
	S("salto duplo ao galho", djump("R"))
	walk_to(3830)
	S("galho alto", jump_to(3980, true))
	S("corre", walk_to(4105))
	press("J")
	hold({"J": true, "R": true}, 16)
	S("agarra cipó", until({"R": true}, func(): return P.vine != null, 80))
	for i in 500:
		P = g.player
		if P.vine == null:
			break
		var v: Dictionary = P.vine
		frame({"R": true} if v.om > 0 else {"L": true})
		if v.th > .35 and v.om > 0:
			break
	press("J")
	frame()
	S("pousa", wait_ground())
	S("desenho 1", g.DRWS.filter(func(d): return d.got).size() == 1)
	S("anda até o tronco oco", walk_to(4608))
	down()
	hold({}, 90)
	S("entrou na sala", g.player.y > 800 and g.player.warp.is_empty())
	S("gancho", walk_to(4840))
	walk_to(4850)
	jr(16, "R")
	S("vermelho", spec("vermelho"))
	S("parede falsa", walk_to(4340))
	S("sala secreta 1", g.X.found.has("s1"))
	S("volta à saída", walk_to(4605))
	press("U")
	frame({"U": true})
	hold({}, 80)
	S("saiu com ↑", g.player.y < 500 and g.player.warp.is_empty())
	S("combina corda+gancho", g.try_combine("corda", "gancho") != "")
	S("arena do javali", walk_to(5010))
	S("javali apareceu", g.X.boss_active())
	S("sobe no galho", jump_to(4825, true))
	S("venceu o javali", boss_fight())
	walk_to(5210)
	S("caixa", jump_to(5265))
	S("vai ao barranco", walk_to(5510))
	use()
	S("corda presa", g.LOCKS[0].done)
	S("vai à corda", walk_to(5538))
	S("sobe a corda", climb_to("U", func(): return P.ladder == null and P.y < 100, 500))
	S("rocha rachada", walk_to(5600))
	press("G")
	hold({}, 26)
	S("golpe quebrou a rocha", g.X.broken.has("rock1"))
	S("cachorro amarrado", walk_to(5700))
	use()
	S("Pipoca solto", g.X.dog_free())
	S("portão alto", walk_to(5780))
	hold({}, 20)
	press("D")
	frame()
	S("controla o Pipoca", g.M.ctrl)
	S("Pipoca pela portinhola até a placa", walk_to(5876))
	S("portão abriu", until({}, func(): return g.M.GATES[1].open > .85, 200))
	press("D")
	frame()
	S("de volta ao Tomé", not g.M.ctrl and g.X.DOG.st == "stay")
	S("toca", walk_to(5940))
	use()
	S("Pipoca buscou o desenho", until({}, func(): return g.DRWS[2].got, 700))
	S("moita: pista 2 e amarelo", walk_to(6130))
	S("pistas=2 amarelo", n_clues() == 2 and spec("amarelo"))
	S("desce do platô", walk_to(6500))
	S("fogueira grande 1", rests.has(1))
	walk_to(6610)
	S("rasteja para a fenda", crawl(6830))
	S("sobe a fenda pulando nas paredes", crevice_climb())
	S("topo da fenda", walk_to(6950))
	S("gavião-rei apareceu", until({"R": true}, func(): return g.K.HAWK.active, 200))
	S("venceu o gavião-rei", hawk_fight())
	walk_to(7900)
	S("galho 1 das copas", jump_to(8050))
	walk_to(8105)
	S("galho 2", jump_to(8260, true))
	walk_to(8305)
	S("galho rachado 1", jump_to(8435))
	S("galho 3", jump_to(8600, true))
	walk_to(8665)
	S("flor das copas", jump_to(8760))
	walk_to(8780)
	S("lançado ao galho alto", until({}, func(): return P.onGround and P.y + P.h <= -250, 400))
	walk_to(9075)
	S("desce ao galho 4", jump_to(9230))
	walk_to(9290)
	S("galho rachado 2", jump_to(9405))
	S("galho 5", jump_to(9570, true))
	S("desce ao chão", walk_to(9700))
	walk_to(9800)
	walk_to(10160)
	hold({}, 20)
	press("D")
	frame()
	S("Pipoca no portão da tarde", g.M.ctrl)
	S("Pipoca até a placa", walk_to(10350))
	S("portão 4 abriu", until({}, func(): return g.M.GATES[3].open > .85, 200))
	press("D")
	frame()
	S("Tomé passa o portão 4", walk_to(10540))
	walk_to(10585)
	S("sobe a torre", climb_to("U", func(): return P.ladder == null and P.onGround and P.y + P.h <= 64, 500))
	walk_to(10918)
	S("desce a torre", climb_to("S", func(): return P.onGround and P.y > 400, 500))
	walk_to(11010)
	S("caixa no buraco da placa 5", until({"R": true}, func(): return g.M.PUSH[5].x >= 11349 and g.M.PUSH[5].y >= 449, 900))
	S("portão 5 abriu", until({}, func(): return g.M.GATES[4].open > .85, 200))
	S("pula a caixa 5", jump_to(11385))
	S("passa o portão 5", walk_to(11600))
	walk_to(11910)
	walk_to(11980)
	S("armadura", jump_to(12039))
	S("beira da ilha", walk_to(12135))
	S("vitória-régia 1", jump_to(12236))
	S("vr 2", jump_to(12376))
	S("vr 3", jump_to(12506))
	S("tronco molhado", jump_to(12650))
	S("ponta do tronco", walk_to(12760))
	S("ilha 2", jump_to(12890))
	S("lama até o poço", walk_to(13075))
	S("cai no poço", until({"R": true}, func(): return P.ladder != null or P.y > 700, 200))
	S("desce a escada", climb_to("S", func(): return P.onGround and P.y > 800, 400))
	S("gruta", walk_to(13310))
	S("engrenagem e pista 3", g.INV.has("engrenagem") and n_clues() == 3)
	S("pula na água", until({"L": true}, func(): return P.swim, 400))
	S("mergulha", until({"L": true, "S": true}, func(): return px() < 12800 and P.y > 990, 400))
	S("túnel", until({"L": true}, func(): return px() < 12710, 300))
	S("bolsão de ar", until({"U": true}, func(): return P.y < 962, 300))
	press("J")
	hold({"J": true, "L": true}, 14)
	S("borda", wait_ground({"L": true}))
	S("sala secreta 2", g.X.found.has("s2"))
	hold({"R": true}, 30)
	S("volta mergulhando", until({"R": true, "S": true}, func(): return px() > 12750 and P.y > 1000, 400))
	S("sai do túnel", until({"R": true}, func(): return px() > 12940, 400))
	S("sobe", until({"U": true, "R": true}, func(): return P.y < 912, 300))
	press("J")
	hold({"J": true, "R": true}, 16)
	S("fora da água", wait_ground({"R": true}))
	S("fôlego ok", g.lives >= 3)
	walk_to(13310)
	S("volta à escada", walk_to(13110))
	S("sobe", climb_to("U", func(): return P.y + P.h <= 504, 400))
	S("sai do poço", jump_to(13200))
	walk_to(13250)
	S("pula o brejo", jump_to(13380))
	S("ilha 3", walk_to(13450))
	S("fogueira grande 2", rests.has(2))
	S("sobe a rede", climb_to("U", func(): return P.ladder == null and P.y + P.h <= 152, 400))
	S("galho: manivela + verde", walk_to(13580))
	S("manivela_q", g.INV.has("manivela_q") and spec("verde"))
	walk_to(13470)
	S("desce", climb_to("S", func(): return P.onGround and P.y > 400, 500))
	S("combina engrenagem+manivela", g.try_combine("engrenagem", "manivela_q") != "")
	S("comporta", walk_to(13590))
	use()
	S("escoa", until({}, func(): return g.SWAMP.filter(func(s): return s.get("id") == "canal")[0].y >= 639, 400))
	S("passa a comporta", walk_to(13678))
	S("pedra 1", jump_to(13770))
	S("pedra 2", jump_to(13910))
	walk_to(13940)
	S("pedrinha (pista 4)", until({"R": true}, func(): return P.onGround and P.y > 520, 100))
	S("pistas=4", n_clues() >= 4)
	S("pedra 3", jump_to(14050))
	S("margem do pântano", jump_to(14210))
	walk_to(14335)
	S("mergulha", until({"R": true, "S": true}, func(): return px() > 14550 and P.y > 600, 300))
	S("atravessa o túnel d'água", until({"R": true}, func(): return px() > 15720, 1200))
	S("respirou nas bolhas", g.lives >= 3)
	S("sobe", until({"U": true, "R": true}, func(): return P.y < 515, 300))
	S("sai da água", jump_to(15910))
	walk_to(16080)
	S("régia 1", jump_to(16206))
	S("régia 2", jump_to(16356))
	S("régia 3", jump_to(16506))
	S("tronco boiando", jump_to(16670))
	walk_to(16780)
	S("régia 4", jump_to(16926))
	S("régia 5", jump_to(17076))
	S("régia 6", jump_to(17226))
	S("margem do lamaçal", jump_to(17350))
	walk_to(17430)
	S("cipó 1", grab_vine(g.VINES[1]))
	S("cipó 2", vine_hop(g.VINES[2]))
	S("cipó 3", vine_hop(g.VINES[3]))
	S("outra margem", vine_hop(null))
	S("vivo no lamaçal", g.lives >= 3 and px() > 18350)
	walk_to(18790)
	S("cipó da ribanceira", grab_vine(g.VINES[4]))
	S("agarra a corda", _to_bar())
	S("anda pendurado", until({"R": true}, func(): return px() > 19840, 600))
	press("J")
	frame()
	S("solta na margem", wait_ground())
	walk_to(20135)
	S("mergulho 2", until({"R": true, "S": true}, func(): return px() > 20400 and P.y > 600, 300))
	S("túnel d'água 2", until({"R": true}, func(): return px() > 21420, 1200))
	S("sobe do mergulho 2", until({"U": true, "R": true}, func(): return P.y < 515, 300))
	S("sai do mergulho 2", jump_to(21610))
	S("lago", walk_to(21820))
	for i in 600:
		P = g.player
		if g.NT.helmet and g.NT.harpoon:
			break
		var tx: float = 22200.0 if not g.NT.harpoon else 22080.0
		frame({"R": px() < tx - 4, "L": px() > tx + 4, "S": P.y < 836, "U": P.y > 846})
	S("capacete e arpão", g.NT.helmet and g.NT.harpoon)
	S("bagre-rei apareceu", until({"R": true}, func(): return g.K.FISH.active, 300))
	S("venceu o bagre-rei", fish_fight())
	S("corrente de bolhas", until({"R": true}, func(): return px() > 23510, 600))
	S("subiu na corrente", until({"R": true}, func(): return P.onGround and P.y < 480, 400))
	S("fogueira grande 3", walk_to(23810) and rests.has(3))
	walk_to(24350)
	S("pula a pedra", jump_to(24480, true))
	S("empurra a bola de neve", until({"R": true}, func(): return g.NT.SNOWB[0].x + g.NT.SNOWB[0].w >= 24847, 900))
	S("bola cresceu", g.NT.SNOWB[0].w > 75)
	S("sobe na bola", jump_to(24770))
	S("paredão", jump_to(24910, true))
	S("gelo", walk_to(25500))
	walk_to(25670)
	S("bola rolando 1", dodge_roll(25930, 0))
	S("bola rolando 2", dodge_roll(26450, 1))
	walk_to(26895)
	S("gelo fino 1", jump_to(26951))
	S("gelo fino 2", jump_to(27031))
	S("gelo fino 3", jump_to(27111))
	S("depois do gelo", jump_to(27165))
	S("pedra da bola 2", jump_to(27275))
	S("empurra a bola 3", until({"R": true}, func(): return g.NT.SNOWB[2].x + g.NT.SNOWB[2].w >= 27407, 900))
	S("sobe na bola 3", jump_to(27380))
	S("2º paredão", jump_to(27450, true))
	walk_to(27545)
	S("vila", walk_to(28200))
	walk_to(28400)
	S("desce na caverna de gelo", climb_to("S", func(): return P.onGround and P.y > 800, 500))
	walk_to(28810)
	S("bloco de gelo 1", jump_to(28890))
	S("desce do bloco 1", jump_to(29020))
	walk_to(29230)
	S("bloco de gelo 2", jump_to(29310))
	S("desce do bloco 2", jump_to(29440))
	walk_to(29910)
	S("sobe da caverna", climb_to("U", func(): return P.ladder == null and P.onGround and P.y < 480, 500))
	walk_to(30060)
	walk_to(30250)
	S("carroça", jump_to(30405))
	S("empurra a bola 2", until({"R": true}, func(): return g.NT.HOLES[0].filled, 900))
	S("cavalo", walk_to(31060))
	use()
	S("cavalgada começou", until({}, func(): return g.RD.riding, 400))
	S("cavalgada", ride())
	S("sem tropeço", g.RD.tries == 0)
	S("fogueira grande 4", walk_to(41650) and rests.has(4))
	S("margem", walk_to(41730))
	var axe: Dictionary = g.TR.by_kind("axe")[0]
	S("espera o machado", until({}, func(): g.TR.axe_blade(axe); return axe.ang < -.9, 300))
	S("corre sob o machado", run_to(41980))
	S("noite", walk_to(41985))
	S("caixa", jump_to(42015))
	if px() < 42040:
		jump_to(42080, true)
	walk_to(42260)
	S("desce no poço da mina", climb_to("S", func(): return P.onGround and P.y > 820, 500))
	walk_to(42480)
	S("viga do poço", crawl(42620))
	walk_to(42770)
	S("carrinho do poço", jump_to(42960))
	walk_to(43175)
	S("tábua do poço 1", jump_to(43240))
	S("tábua do poço 2", jump_to(43325))
	S("depois das tábuas", jump_to(43420))
	walk_to(44100)
	S("viga 2 do poço", crawl(44250))
	walk_to(44470)
	S("sobe do poço", climb_to("U", func(): return P.ladder == null and P.onGround and P.y < 480, 500))
	walk_to(44620)
	S("porta do galpão", walk_to(44870))
	hold({}, 20)
	press("D")
	frame()
	S("Pipoca", g.M.ctrl)
	S("Pipoca entra pela portinhola", walk_to(45100))
	S("óleo", g.INV.has("oleo"))
	S("Pipoca sai", walk_to(44870))
	press("D")
	frame()
	S("Tomé", not g.M.ctrl)
	S("telhado do galpão", jump_to(44945, true))
	S("desce do telhado", walk_to(45240))
	S("escada da coruja", walk_to(45505))
	S("sobe", climb_to("U", func(): return P.ladder == null and P.onGround and P.y + P.h <= 42, 500))
	S("pavio", walk_to(45540))
	S("azul", walk_to(45410))
	S("pavio+azul", g.INV.has("pavio") and spec("azul"))
	walk_to(45505)
	S("desce", climb_to("S", func(): return P.onGround and P.y > 400, 600))
	S("combina óleo+pavio", g.try_combine("oleo", "pavio") != "")
	S("laje do X", walk_to(45310))
	use()
	S("quebrou a laje", g.X.broken.has("slab"))
	S("desce na câmara", climb_to("S", func(): return P.onGround and P.y > 800, 500))
	S("espelho do chão", walk_to(45190))
	use()
	walk_to(45180)
	press("J")
	for i in 40:
		frame({"J": true})
		if i == 16:
			press("J")
	wait_ground()
	S("espelhos girados", g.X.MIRRORS[0].s == 1 and g.X.MIRRORS[1].s == 1)
	walk_to(45250)
	frame({"L": true})
	S("facho no cristal", hold({"A": true}, 60))
	S("grades abertas", g.X.opened.has("cdoor"))
	var rg = walk_to(44998)
	S("lápis dourado %s" % str(rg), g.X.GOLD.got)
	walk_to(45385)
	S("plataforma de luz 1", jump_to(45395) is bool and P.y + P.h < 850)
	S("pl. 2", jump_to(45460) is bool and P.y + P.h < 795)
	S("pl. 3", jump_to(45388) is bool and P.y + P.h < 740)
	S("sala secreta 3", g.X.found.has("s3"))
	S("desce", until({"L": true}, func(): return P.onGround and P.y > 850, 300))
	S("escada da laje", walk_to(45310))
	S("sobe", climb_to("U", func(): return P.ladder == null and P.onGround and P.y < 480, 500))
	walk_to(45505)
	S("rede de caçador", walk_to(45570))
	press("D")
	frame()
	S("Pipoca (rede)", g.M.ctrl)
	S("Pipoca no poste", walk_to(45565))
	press("A")
	hold({}, 8)
	S("rede caiu", g.TR.by_kind("net")[0].st == "down")
	press("D")
	frame()
	S("Tomé de novo", not g.M.ctrl)
	S("jaula prendeu", until({"R": true}, func(): return g.TR.trapped != null, 300))
	hold({}, 30)
	press("D")
	frame()
	S("Pipoca (jaula)", g.M.ctrl)
	S("Pipoca no poste da jaula", walk_to(45662))
	press("A")
	hold({}, 8)
	S("jaula abriu", g.TR.trapped == null)
	press("D")
	frame()
	S("Tomé livre", not g.M.ctrl)
	S("cogumelo", until({"R": true}, func(): return P.vy < -15, 300))
	var dj := false
	for i in 200:
		P = g.player
		if not dj and P.vy > -1:
			press("J")
			dj = true
		frame({"R": px() < 45870, "J": dj and i < 60})
		P = g.player
		if dj and P.onGround:
			break
	S("quica + pulo duplo", g.player.y < 130)
	S("desenho 2", walk_to(45940))
	walk_to(46040)
	S("desce do galho", until({}, func(): return P.onGround and P.y > 400, 200))
	S("entrada do túnel", walk_to(46050))
	use()
	S("barreira aberta", g.LOCKS[2].done)
	walk_to(46320)
	S("viga do túnel", crawl(46500))
	walk_to(46605)
	S("tábua podre", jump_to(46710))
	S("depois da tábua", jump_to(46860))
	walk_to(46900)
	S("carrinho do túnel", jump_to(47100))
	walk_to(47235)
	S("tábuas 1", jump_to(47310))
	S("tábuas 2", jump_to(47400))
	S("fim das tábuas", jump_to(47500))
	walk_to(47540)
	S("viga 2 do túnel", crawl(47690))
	S("túnel", walk_to(47990))
	S("rasteja", crawl(48150))
	S("escada do nicho", walk_to(48350))
	S("desce", climb_to("S", func(): return P.onGround and P.y > 700, 500))
	S("roxo no nicho", walk_to(48160) and spec("roxo"))
	walk_to(48380)
	S("rasteja divisória", crawl(48445))
	S("pistas=6 (crachá)", n_clues() == 6)
	S("vilão ainda não", not g.VIL.go)
	walk_to(48480)
	S("sobe pela saída", climb_to("U", func(): return P.ladder == null and P.onGround and P.y < 480, 500))
	S("vilão foge", walk_to(48700))
	S("perseguição começou", g.VIL.go)
	walk_to(49030)
	S("1º buraco", jump_to(49200))
	walk_to(49320)
	S("desliza sob a viga", crawl(49450))
	walk_to(49685)
	S("2º buraco", jump_to(49890, true))
	walk_to(49950)
	S("pula o carrinho parado", jump_to(50100, true))
	walk_to(50170)
	S("tábua 1", jump_to(50260))
	S("tábua 2", jump_to(50390))
	S("tábua 3", jump_to(50520))
	S("chão", jump_to(50630))
	walk_to(50770)
	S("viga 2", crawl(50900))
	S("vilão entrou na mina", until({"R": true}, func(): return g.VIL.gone or px() > 51200, 900))
	S("vilão entrou", until({}, func(): return g.VIL.gone, 400))
	walk_to(51315)
	var sa = until({}, func(): return not g.running, 300)
	S("saída", sa is String and sa == "state")
	var nd: int = g.DRWS.filter(func(d): return d.got).size()
	S("segredos %d/3 dourado=%s chefe=%s" % [g.X.found.size(), str(g.X.GOLD.got), str(g.X.BOSS.done)], g.X.found.size() == 3 and g.X.GOLD.got and g.X.BOSS.done)
	print("FIM T=", g.T)
	S("final: pistas=%d esp=%d des=%d lápis=%d/%d tempo=%ds" % [n_clues(), g.SPECGOT.size(), nd, g.STATS.pen, g.STATS.penTotal, g.time_left / 60], n_clues() == 6 and g.SPECGOT.size() == 6 and nd == 3)
	for l in log_lines:
		print(l)
	print("FALHAS: %d" % fails)
	quit(1 if fails > 0 else 0)
