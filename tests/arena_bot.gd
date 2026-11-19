extends SceneTree
## Robô simples que luta nas arenas (sem tomar dano) para ver se todas as ondas dá para vencer só com
## a picareta: anda até o bicho vivo mais perto e bate; pula quando ele está no alto.
##   godot --headless --path . -s tests/arena_bot.gd
var g
var fails := 0

func _initialize() -> void:
	g = load("res://scripts/game.gd").new()
	root.add_child(g)
	g.auto_cine = true
	for lv in 3:
		g.load_level(lv)
		g.lives = 99
		for e in g.EN:
			e.dead = 99
		for ai in g.CB.ARENAS.size():
			var a: Dictionary = g.CB.ARENAS[ai]
			g.debug_warp(float(a.x0) + 150, float(a.y) - 34)
			var t := 0
			while a.st != "won" and t < 6000:
				t += 1
				var P: Dictionary = g.player
				P.iframe = 5
				P.hp = 5
				for k in ["L", "R", "J", "G", "U", "S", "A"]:
					g.keys[k] = false
				var best = null
				var bd := 1e9
				var pc := Vector2(P.x + P.w / 2, P.y + P.h / 2)
				for e in a.spawned:
					if e.dead:
						continue
					var d: float = abs(float(e.x) - pc.x) + abs(float(e.y) - pc.y) * .3
					if d < bd:
						bd = d
						best = e
				if best != null:
					var dx: float = float(best.x) - pc.x
					var dy: float = float(best.y) - pc.y
					if abs(dx) > 50:
						g.keys["R" if dx > 0 else "L"] = true
					else:
						P.face = 1 if dx > 0 else -1
						if t % 6 == 0:
							g.keys["Gp"] = true
					if dy < -70 and abs(dx) < 90 and P.onGround and t % 30 == 0:
						g.keys["Jp"] = true
						g.keys["J"] = true
				g.step()
				while not g.CINE.is_empty():
					g.step()
			var ok: bool = a.st == "won"
			if not ok:
				fails += 1
				var left: Array = []
				for e in a.spawned:
					if not e.dead:
						left.append("%s(%d,%d)" % [e.k, int(e.x), int(e.y)])
				print("✗ ep%d arena %s: st=%s onda=%d restam %s" % [lv + 1, a.name, a.st, int(a.wave), str(left)])
			else:
				print("· ep%d arena %s vencida em %d passos" % [lv + 1, a.name, t])
	print("FALHAS: %d" % fails)
	quit(1 if fails > 0 else 0)
