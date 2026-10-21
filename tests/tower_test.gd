extends SceneTree
## Teste da Torre (Monument Valley): entra pela porta do pântano, resolve as 4 salas e volta.
## Uso: godot --headless -s tests/tower_test.gd

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


func up():
	press("U")
	frame({"U": true})
	hold({}, 80)
	return true

func z() -> String:
	return "" if g.TW.zone == null else g.TW.zone.id

func _initialize() -> void:
	g = load("res://scripts/game.gd").new()
	root.add_child(g)
	g.load_level(0)
	g.no_coal = true
	for e in g.EN:
		e.dead = 99
	g.player.x = 4740
	g.player.y = 466
	g.snap_camera()
	P = g.player
	S("na porta da torre", walk_to(4776))
	up()
	S("sala A", z() == "A")
	S("perto da ponte", walk_to(13240))
	S("arrasta: pega a ponta da ponte", g.TW.drag_begin(Vector2(13300, 330), 0))
	for i in 10:
		g.TW.drag_move(Vector2(13300 + i * 18, 330 + i * 16))
		frame()
	g.TW.drag_end()
	hold({}, 40)
	S("ponte deitada (arrastando)", g.TW.BRIDGES[0].on)
	S("atravessa a ponte", walk_to(13560))
	S("em cima do bloco", walk_to(13700))
	S("arrasta o bloco", g.TW.drag_begin(Vector2(13700, 520), 1))
	for i in 12:
		g.TW.drag_move(Vector2(13700, 520 - i * 10))
		frame()
	g.TW.drag_end()
	hold({}, 30)
	use()
	hold({}, 40)
	S("bloco subiu", g.player.y + g.player.h <= 302)
	S("pula para o terraço", jump_to(13790))
	S("empurra a caixa", until({"R": true}, func(): return g.M.PLATES.back().on, 400))
	hold({}, 60)
	S("pilar subiu", g.TW.PILLARS[0].y <= 151)
	S("volta ao pilar", walk_to(13860))
	S("sobe no pilar", jump_to(13795, true))
	S("no alto do pilar", g.player.y + g.player.h <= 152)
	up()
	S("sala B", z() == "B")
	S("pula na sala", jump_to(14600))
	S("manivela", walk_to(14740))
	use()
	hold({}, 70)
	S("sala girou", g.TW.ROOM.rot == 1)
	S("sai pela direita", walk_to(15080))
	up()
	S("sala C", z() == "C")
	S("vai à primeira plataforma", walk_to(16560))
	S("sobe na 1ª", jump_to(16560, true))
	S("na 1ª", g.player.onGround and g.player.y + g.player.h <= 342)
	use()
	hold({}, 45)
	S("girou 1", g.TW.FEZ.view == 1)
	S("sobe na 2ª", jump_to(px(), true))
	S("na 2ª", g.player.onGround and g.player.y + g.player.h <= 182)
	use()
	hold({}, 45)
	S("girou 2", g.TW.FEZ.view == 2)
	S("sobe na 3ª", jump_to(px(), true))
	S("na 3ª", g.player.onGround and g.player.y + g.player.h <= 22)
	up()
	S("sala D (topo)", z() == "D")
	walk_to(17410)
	press("G")
	hold({}, 30)
	S("pega os lápis", walk_to(17520))
	S("porta de saída", walk_to(17624))
	up()
	S("de volta ao pântano", z() == "" and abs(px() - 4830) < 40)
	for l in log_lines:
		print(l)
	print("FALHAS: %d" % fails)
	quit()
