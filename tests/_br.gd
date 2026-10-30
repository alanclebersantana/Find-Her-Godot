extends "res://tests/ep2_bosses_test.gd"
func _initialize() -> void:
	g = load("res://scripts/game.gd").new()
	root.add_child(g)
	g.load_level(1)
	g.lives = 99
	for e in g.EN:
		e.dead = 99
	P = g.player
	_at(22980, 500)
	for i in 100:
		frame({"R": true})
	print("px=", px(), " st=", g.X.BOSS.st, " act=", g.X.BOSS.active)
	for s in g.SOL:
		if s.x < 23200 and s.x + s.w > 23050 and s.y < 500 and s.y + s.get("h", 0) > 400:
			print(s)
	quit()
