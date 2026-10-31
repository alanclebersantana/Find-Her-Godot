extends "res://tests/rec/route2.gd"
## Os três chefes do Episódio 2 (Brutus na corrente, Morcego-Rei das lamparinas, Sapo-Rei das colmeias):
## teleporta para perto de cada arena e joga a luta inteira.
##   godot --headless --path . -s tests/ep2_bosses_test.gd

func _at(x: float, y: float) -> void:
	g.CINE = {}
	P = g.player
	P.x = x - P.w / 2
	P.y = y - P.h
	P.vx = 0.0
	P.vy = 0.0
	P.spawnX = P.x
	P.spawnY = P.y
	P.hp = 5
	g.snap_camera()
	await frame()

func _initialize() -> void:
	await _rec_setup(1)
	g.no_coal = true
	g.lives = 99
	for e in g.EN:
		e.dead = 99
	P = g.player
	var only: String = OS.get_environment("CHEFE")
	# ---- Brutus (no Ep. 2 o Pipoca não vem junto: o Tomé provoca do chão)
	if only == "" or only == "brutus":
		await _at(22980, 500)
		await S("Brutus", await brutus_fight())
		await S("Brutus desistiu", g.X.BOSS.done or g.X.BOSS.st == "down")
		await S("portão do quintal aberto", await walk_to(float(g.X.BOSS.x1) + 60))
	# ---- Morcego-Rei
	if only == "" or only == "morcego":
		g.lantern_lit = true
		await _at(float(g.L.hawk.x0) - 100, 500)
		await S("entra na caverna", await until({"R": true}, func(): return g.K.HAWK.active, 400))
		await S("vence o Morcego-Rei", await hawk_fight())
	# ---- Sapo-Rei
	if only == "" or only == "sapo":
		await _at(14680, -150)
		await S("primeira vitória-régia", await jump_to(14826))
		await S("entra na arena do Sapo-Rei", await until({}, func(): return g.K.FISH.active, 200))
		await S("vence o Sapo-Rei", await frog_fight())
	for l in log_lines:
		print(l)
	print("FALHAS: ", fails)
	quit()
