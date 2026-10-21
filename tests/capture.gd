extends SceneTree
## Grava trechos de jogo para o vídeo promocional (sem HUD).
## Uso: godot --path . --write-movie /tmp/vid/<seg>.avi --fixed-fps 30 -s tests/capture.gd -- <seg>
var main
var g
var P: Dictionary
var nf := 0

func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 3:
		await process_frame
	var sv = root.get_node("Save")
	for id in ["cipo", "mergulho", "neve", "pipoca", "picareta", "cavalo", "mina", "toxico", "javali", "gaviao", "bagre", "urso", "vargas"]:
		sv.setv("comic", id, true)
	main.start_level(false)
	await process_frame
	if main.panel and main.panel.has_meta("ok"):
		main.panel.get_meta("ok").call()
		await process_frame
	for c in main.ui_layer.get_children():
		if c.has_method("_end"):
			c._end()
	await process_frame
	if main.panel and main.panel.has_meta("ok"):
		main.panel.get_meta("ok").call()
	g = main.game
	g.lives = 99
	g.clue_opened.disconnect(main._on_clue)
	var seg: String = OS.get_cmdline_user_args()[0]
	await call(seg)
	quit()

func put(x: float, y: float) -> void:
	g.CINE = {}
	g.player.x = x - 12
	g.player.y = y - 34
	g.player.vx = 0
	g.player.vy = 0
	g.player.vine = null
	g.player.ladder = null
	g.player.spawnX = g.player.x
	g.player.spawnY = g.player.y
	g.snap_camera()
	P = g.player

func hide_ui() -> void:
	main.hud_layer.visible = false

## roda n quadros do vídeo; keys(i) devolve as teclas apertadas no quadro i
func run(n: int, keys: Callable) -> void:
	for i in n:
		hide_ui()
		g.flash_t = 0
		var k: Dictionary = keys.call(i)
		for kk in ["L", "R", "J", "S", "U", "A", "G"]:
			var down: bool = k.get(kk, false)
			if down and not g.keys.get(kk, false):
				g.keys[kk + "p"] = true
			g.keys[kk] = down
		for kk in k:
			if kk.ends_with("p"):
				g.keys[kk] = true
		g.player.hp = 5
		await process_frame

func kill_enemies() -> void:
	for e in g.EN:
		e.dead = 99

# ---------- trechos ----------
func manha() -> void:
	kill_enemies()
	put(2470, 430)
	await run(120, func(i): return {})

func flor() -> void:
	kill_enemies()
	put(3775, 440)
	await run(110, func(i): return {})

func javali() -> void:
	kill_enemies()
	put(4960, 500)
	var b: Dictionary = g.X.BOSS
	b.active = true
	b.st = "paw"
	b.t = 0
	b.x = 5380.0
	b.y = 500.0
	b.dir = -1
	b.hp = b.maxhp
	g.X._gate_on(true)
	var st := {"j": -1}
	await run(120, func(i):
		var bb: Dictionary = g.X.BOSS
		var px: float = g.player.x + 12
		if st.j < 0 and bb.st == "charge" and abs(bb.x - px) < 190:
			st.j = i
		if st.j >= 0:
			var k: int = i - st.j
			return {"Jp": k == 0 or k == 12, "J": k < 26}
		return {})

func cipos() -> void:
	kill_enemies()
	put(18700, 300)
	var v: Dictionary = g.VINES[1]
	g.player.vine = v
	g.player.vr = 210.0
	v.om = .028
	v.th = -.3
	await run(150, func(i):
		var pv = g.player.vine
		var d := {}
		if pv:
			d = {"R": true} if pv.om > 0 else {"L": true}
			if pv.th > .3 and pv.om > 0:
				d["Jp"] = true
		return d)

func gaviao() -> void:
	kill_enemies()
	put(13900, 500)
	var h: Dictionary = g.K.HAWK
	h.active = true
	h.st = "mark"
	h.t = 0
	h.tx = 13900.0
	h.x = 13900.0
	h.y = h.gy - 300.0
	g.K._gate("hawkL", true, Rect2(h.x0 - 24, h.gy - 260, 24, 260))
	g.K._gate("hawkR", true, Rect2(h.x1, h.gy - 260, 24, 260))
	await run(140, func(i):
		var hh: Dictionary = g.K.HAWK
		if hh.st == "stuck":
			var dx: float = hh.x - (g.player.x + 12)
			if abs(dx) > 40:
				return {"R": dx > 0, "L": dx < 0}
			g.player.face = 1 if dx > 0 else -1
			return {"Gp": i % 20 == 0}
		return {"L": i > 6 and i < 40})

func bagre() -> void:
	kill_enemies()
	put(23700, 850)
	g.NT.helmet = true
	g.NT.harpoon = true
	var f: Dictionary = g.K.FISH
	f.active = true
	f.st = "suck"
	f.t = 0
	f.x = 23700 + 330.0
	f.y = 850.0
	f.dir = -1
	await run(100, func(i): return {"L": i > 10 and i < 70, "U": i % 18 < 6})

func gelo() -> void:
	kill_enemies()
	put(30130, 868)
	await run(110, func(i): return {"R": i > 4 and i < 95, "Jp": i == 30 or i == 68, "J": (i > 30 and i < 42) or (i > 68 and i < 80)})

func cavalo() -> void:
	kill_enemies()
	put(33200, 500)
	g.RD._start()
	g.RD.hx = 33200.0
	g.RD.spd = 5.2
	g.snap_camera()
	await run(150, func(i):
		var d := {}
		for o in g.RD.OBS:
			var dx: float = o.x - g.RD.hx
			if dx < -140 or dx > 220:
				continue
			if o.k in ["log", "rock", "gap"] and dx < 80 and dx > 34 and g.RD.hy >= 500:
				d["Jp"] = true
				d["J"] = true
			if o.k in ["branch", "rope"] and dx < 130:
				d["S"] = true
			break
		return d)

func urso() -> void:
	kill_enemies()
	put(43150, 500)
	var b: Dictionary = g.K.BEAR
	b.active = true
	b.st = "walk"
	b.t = 40
	b.x = 43450.0
	b.dir = -1
	b.hp = 2
	g.K._gate("bearL", true, Rect2(b.x0 - 24, b.gy - 260, 24, 260))
	g.K._gate("bearR", true, Rect2(b.x1, b.gy - 260, 24, 260))
	await run(200, func(i):
		var bb: Dictionary = g.K.BEAR
		var px: float = g.player.x + 12
		var dx: float = px - bb.x
		match bb.st:
			"rear", "slam":
				if abs(dx) < 245:
					return {"R" if dx > 0 else "L": true}
			"dizzy":
				var tx: float = bb.x + (90.0 if dx > 0 else -90.0)
				if abs(tx - px) > 6:
					return {"R": tx > px, "L": tx < px}
				g.player.face = -1 if dx > 0 else 1
				return {"Gp": i % 26 == 0}
		return {})

func noite() -> void:
	kill_enemies()
	put(52500, 500)
	g.lantern_lit = true
	g.VIL.go = true
	g.VIL.x = 52880.0
	await run(110, func(i): return {"R": true, "Jp": i == 45, "J": i > 45 and i < 58})

# ---------- ajudantes assíncronos (um passo de física por chamada, como o bot da rota) ----------
func fr(set: Dictionary = {}) -> void:
	hide_ui()
	g.flash_t = 0
	g.player.hp = 5
	for k in ["L", "R", "J", "S", "U", "A", "G"]:
		g.keys[k] = false
	for k in set:
		g.keys[k] = set[k]
	await physics_frame
	P = g.player
	nf += 1
	if nf % 60 == 0:
		print("f%d x=%d y=%d st=%s" % [nf, int(px()), int(g.player.y), str(main.state)])
	if nf > 1500:
		quit()

func press(k: String) -> void:
	g.keys[k + "p"] = true

func px() -> float:
	return g.player.x + g.player.w / 2

func hold(set: Dictionary, n: int) -> void:
	for i in n:
		await fr(set)

func until(set: Dictionary, cond: Callable, mx: int = 900) -> void:
	for i in mx:
		if cond.call():
			return
		await fr(set)

func wait_ground(set: Dictionary = {}, mx: int = 300) -> void:
	await until(set, func(): return g.player.onGround, mx)

func walk_to(x: float, mx: int = 900) -> void:
	for i in mx:
		if abs(px() - x) < 6 and g.player.onGround:
			return
		await fr({"R" if x > px() else "L": true})

func jump_to(x: float, dbl: bool = false, mx: int = 200) -> void:
	press("J")
	var used := false
	for i in mx:
		var d := {}
		if px() < x - 5:
			d = {"R": true}
		elif px() > x + 5:
			d = {"L": true}
		if dbl and not used and i > 14 and g.player.vy > -1:
			press("J")
			used = true
		d["J"] = i < 16 or (dbl and i < 34)
		await fr(d)
		if g.player.onGround and i > 3:
			return

func crawl(x: float, mx: int = 600) -> void:
	var dir := "R" if x > px() else "L"
	for i in mx:
		if (px() >= x) if dir == "R" else (px() <= x):
			return
		await fr({"S": true, dir: true})

func climb(dir: String, cond: Callable, mx: int = 600) -> void:
	await until({dir: true}, cond, mx)

func crevice() -> void:
	var dir := "R"
	press("J")
	await hold({"J": true, dir: true}, 10)
	for i in 24:
		await until({dir: true}, func(): return g.player.wsl > 0 or g.player.onGround, 90)
		if g.player.onGround:
			return
		press("J")
		await fr({"J": true})
		dir = "L" if dir == "R" else "R"
		await hold({"J": true}, 6)

func swing_off() -> void:
	for i in 600:
		var v = g.player.vine
		if v == null:
			break
		await fr({"R": true} if v.om > 0 else {"L": true})
		if v.th > .35 and v.om > 0:
			break
	press("J")
	await fr()

func vine_hop(next_vine) -> void:
	await swing_off()
	if next_vine == null:
		await wait_ground()
	else:
		await until({}, func(): return g.player.vine == next_vine or g.player.onGround, 120)

func grab_vine(v) -> void:
	press("J")
	for i in 120:
		if g.player.vine == v:
			return
		if i == 16:
			press("J")
		await fr({"J": i < 40, "R": true})

# ---------- trechos da versão 2 (mais jogabilidade) ----------
func fenda() -> void:
	kill_enemies()
	put(6640, 500)
	await hold({}, 20)
	await crawl(6830)
	await crevice()
	await walk_to(7000)
	await hold({}, 20)

func copas() -> void:
	kill_enemies()
	put(7960, -10)
	await hold({}, 15)
	await jump_to(8050)
	await walk_to(8105)
	await jump_to(8260, true)
	await walk_to(8305)
	await jump_to(8435)
	await jump_to(8600, true)
	await walk_to(8665)
	await jump_to(8760)
	await walk_to(8780)
	await until({}, func(): return g.player.onGround and g.player.y + g.player.h <= -250, 400)
	await walk_to(9075)
	await jump_to(9230)
	await walk_to(9290)
	await jump_to(9405)
	await jump_to(9570, true)
	await hold({}, 20)

func regias() -> void:
	kill_enemies()
	put(17180, 500)
	await hold({}, 10)
	await walk_to(17280)
	for x in [17406, 17556, 17706, 17870]:
		await jump_to(x)
	await walk_to(17980)
	for x in [18126, 18276, 18426, 18550]:
		await jump_to(x)
	await walk_to(18630)
	await grab_vine(g.VINES[1])
	await vine_hop(g.VINES[2])
	await vine_hop(g.VINES[3])
	await vine_hop(null)
	await walk_to(19750)

func corda() -> void:
	kill_enemies()
	put(19900, 500)
	await hold({}, 10)
	await walk_to(19990)
	await grab_vine(g.VINES[4])
	await swing_off()
	await until({}, func(): return g.player.get("bar") != null, 120)
	await until({"R": true}, func(): return px() > 21040, 600)
	press("J")
	await fr()
	await wait_ground()
	await walk_to(21200)

func mergulho() -> void:
	kill_enemies()
	put(15440, 500)
	await hold({}, 10)
	await until({"R": true, "S": true}, func(): return px() > 15750 and g.player.y > 600, 300)
	await until({"R": true}, func(): return px() > 16700, 600)

func bolaneve() -> void:
	kill_enemies()
	put(25560, 500)
	await hold({}, 10)
	await jump_to(25680, true)
	await until({"R": true}, func(): return g.NT.SNOWB[0].x + g.NT.SNOWB[0].w >= 26047, 900)
	await jump_to(25970)
	await jump_to(26110, true)
	await walk_to(26400)

func gelofino() -> void:
	kill_enemies()
	put(26870, 500)
	await hold({}, 6)
	for i in 2:
		var x: float = [27130.0, 27650.0][i]
		await walk_to(x)
		var o: Dictionary = g.TR.by_kind("roll")[1 + i]
		await until({}, func(): return o.st == "go" and o.bx - px() < 85, 400)
		press("J")
		await hold({"J": true}, 16)
		await wait_ground()
		await hold({}, 6)
	await walk_to(28095)
	for x in [28151, 28231, 28311, 28365]:
		await jump_to(x)
	await walk_to(28470)

func tunel() -> void:
	kill_enemies()
	put(50130, 500)
	g.lantern_lit = true
	await hold({}, 10)
	await crawl(50300)
	await walk_to(50405)
	await jump_to(50510)
	await jump_to(50660)
	await walk_to(50700)
	await jump_to(50900)
	await walk_to(51035)
	await jump_to(51110)
	await jump_to(51200)
	await jump_to(51300)
	await walk_to(51340)
	await crawl(51490)
	await walk_to(51700)

func cogumelo() -> void:
	kill_enemies()
	put(49520, 500)
	g.lantern_lit = true
	await hold({}, 10)
	await until({"R": true}, func(): return g.player.vy < -15, 300)
	var dj := false
	for i in 200:
		if not dj and g.player.vy > -1:
			press("J")
			dj = true
		await fr({"R": px() < 49670, "J": dj and i < 60})
		if dj and g.player.onGround:
			break
	await walk_to(49840)
	await until({}, func(): return g.player.onGround and g.player.y > 400, 200)
	await hold({}, 20)
