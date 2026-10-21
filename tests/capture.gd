extends SceneTree
## Grava trechos de jogo para o vídeo promocional (sem HUD).
## Uso: godot --path . --write-movie /tmp/vid/<seg>.avi --fixed-fps 30 -s tests/capture.gd -- <seg>
var main
var g
var P: Dictionary

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
