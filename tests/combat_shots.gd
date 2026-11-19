extends SceneTree
## Capturas do pacote de ação (Combat) em /tmp/fh_shots/cb_*.png
##   VK_ICD_FILENAMES=/opt/lavapipe/lvp_icd.json xvfb-run -a godot --path . -s tests/combat_shots.gd
var main
var g

func snap(name: String) -> void:
	for i in 2:
		await process_frame
	root.get_texture().get_image().save_png("/tmp/fh_shots/cb_%s.png" % name)
	print("SHOT ", name, " act=", g.player.act, " actT=", g.player.actT, " swing=", g.M.swing_t, " combo=", g.CB.combo_i, " hits=", g.CB.hits, " st=", main.state, " run=", g.running)

func steps(n: int, keys: Dictionary = {}) -> void:
	for i in n:
		for k in ["L", "R", "J", "S", "U", "A", "G", "E"]:
			g.keys[k] = keys.get(k, false)
		g.step()
		await process_frame

func boar(x: float, y: float, v: String = "") -> Dictionary:
	var e := {"k": "boar", "x": x, "y": y, "r": [x - 200, x + 200], "dir": -1, "dead": 0, "base": y, "stun": 0, "leap": 0, "x0": x, "sx": x}
	g.CB.setup_enemy(e, v)
	g.EN.append(e)
	return e

func warp(x: float, y: float) -> void:
	g.debug_warp(x, y)
	g.snap_camera()
	g.flash_t = 0

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("/tmp/fh_shots")
	var SV = root.get_node("Save")
	for cid in ["cipo", "mergulho", "neve", "pipoca", "picareta", "cavalo", "mina", "toxico", "javali", "gaviao", "bagre", "urso", "vargas", "bola", "aviao", "jangada", "colmeia", "moinho", "telhados", "carrinho"]:
		SV.setv("comic", cid, true)
	SV.setv("opt", "tutorial", false)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 3:
		await process_frame
	main.start_level(false, 0)
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
	# só os passos deste roteiro andam o jogo (o desenho continua normal)
	main.set_physics_process(false)
	g.lives = 99
	g.auto_cine = true
	for e in g.EN:
		e.dead = 99
	# 1 · combo no javali elite (barra de vida e contador de combo)
	g.no_coal = true
	var X0 := 34560.0
	warp(X0, 500)
	await steps(20)
	var e1 := boar(X0 + 70, 500, "elite")
	e1.stun = 999
	e1.hp = 12
	g.player.face = 1
	g.keys["Gp"] = true
	await steps(9)
	await snap("1a_combo")
	g.keys["Gp"] = true
	await steps(18)
	await snap("1b_combo")
	g.keys["Gp"] = true
	await steps(26)
	await snap("1c_combo")
	await steps(30)
	# 2 · escudo, aviso e a defesa carregando
	e1.dead = 99
	var s := boar(X0 + 140, 500, "shield")
	s.wind = 10
	await steps(75, {"G": true})
	s.wind = 12
	s.stun = 0
	await snap("2_escudo_carga")
	await steps(1)
	await steps(10)
	await snap("3_giro")
	s.dead = 99
	# 4 · pedra na mão, barril com o pavio aceso
	g.CB.THR = []
	g.CB.add_thr("rock", g.player.x + 20, 500)
	var br: Dictionary = g.CB.add_thr("barrel", g.player.x + 160, 500)
	br.fuse = 40
	g.keys["Ap"] = true
	await steps(4)
	await snap("4_pedra_barril")
	await steps(70)
	await snap("5_explosao")
	# 6 · esquiva (rastro)
	await steps(30)
	g.keys["Ep"] = true
	await steps(6, {"R": true})
	await snap("6_esquiva")
	g.no_coal = false
	# 7 · arena da neve
	var a: Dictionary = g.CB.ARENAS[0]
	warp(float(a.x0) + 200, float(a.y))
	await steps(50)
	await snap("7_arena")
	for en in a.spawned:
		en.dead = 99
	await steps(60)
	await steps(70)
	await snap("8_arena_onda2")
	# 9 · Javali-Rei na fase 3 (aura, barra com as fases, pedras caindo)
	g.CB.on_respawn()
	var B: Dictionary = g.X.BOSS
	warp(float(B.trig) + 60, 500)
	await steps(260)
	B.hp = 1
	await steps(140)
	await snap("9_chefe_fase3")
	# 10 · loja na fogueira
	SV.setv("shop", "bank", 230)
	main._on_rest(1)
	for i in 30:
		await process_frame
	await snap("10_descanso")
	var root_rest = main.panel
	main._shop_panel(root_rest, func(): pass)
	for i in 10:
		await process_frame
	await snap("11_loja")
	SV.setv("shop", "bank", 0)
	quit()
