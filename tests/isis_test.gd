extends "res://tests/route.gd"
## Teste automático do epílogo do Episódio 2 (A fuga da Isis): sai do quarto pela fresta, passa
## escondida pelo lampião do Vargas, engatinha no buraco, vai pelas prateleiras e chega ao fim.
##   godot --headless --path . -s tests/isis_test.gd

var ended := false

## anda atrás do Vargas (sem passar na frente dele) até x
func follow_behind(w: Dictionary, x: float, mx: int = 1500):
	for i in mx:
		P = g.player
		if not ok():
			return "state"
		if px() >= x - 4:
			return true
		frame({"R": true} if px() < float(w.x) - 90 or float(w.dir) < 0 and px() < float(w.x) - 300 else {"S": true})
	return "timeout@%d" % int(px())

## espera escondida (abaixada) até o Vargas passar para a esquerda dela
func hide_until_passed(w: Dictionary, mx: int = 1600):
	for i in mx:
		P = g.player
		if not ok():
			return "state"
		if float(w.dir) < 0 and float(w.x) < px() - 60 and w.wait == 0:
			return true
		frame({"S": true})
	return "timeout"

func _initialize() -> void:
	g = load("res://scripts/game.gd").new()
	root.add_child(g)
	g.load_level(2)
	g.results_ready.connect(func(): ended = true)
	P = g.player
	S("é a Isis (h=%d)" % int(P.h), P.get("isis") == true and P.h == 26)
	wait_ground()
	for i in 5:
		frame()
	var y0: float = g.player.y
	press("J")
	var top: float = P.y
	for i in 60:
		frame({"J": true})
		top = min(top, g.player.y)
	S("pulo baixo (%d px)" % int(y0 - top), y0 - top < 80 and y0 - top > 52)
	wait_ground()
	S("passa pela fresta em pé", walk_to(640))
	S("lápis 1", g.VL.DROPS[0].done)
	var W1: Dictionary = g.VL.WATCH[0]
	S("caixote 1", walk_to(793))
	S("espera escondida ele ir para a direita", until({"S": true}, func(): return float(W1.dir) > 0 and float(W1.x) > 1100 and W1.wait == 0, 2400))
	S("vai atrás dele até o caixote", follow_behind(W1, 1365))
	S("escondida até ele passar", hide_until_passed(W1))
	S("não foi vista", g.VL.caught_n == 0)
	S("até o buraco", walk_to(1590))
	S("engatinha no buraco", crawl(1880))
	S("lápis 2", g.VL.DROPS[1].done)
	var W2: Dictionary = g.VL.WATCH[1]
	walk_to(1980)
	S("espera o Vargas ir para a direita", until({}, func(): return float(W2.dir) > 0 and float(W2.x) > 2450 and W2.wait == 0, 2400))
	S("prateleira 1", jump_to(2040))
	walk_to(2070)
	S("prateleira 2", jump_to(2130))
	walk_to(2160)
	S("prateleira alta", jump_to(2230))
	S("lá em cima", P.y + P.h < 370)
	S("anda lá em cima", walk_to(2560))
	S("lápis 3", g.VL.DROPS[2].done)
	S("espera ele voltar para a esquerda", until({}, func(): return float(W2.dir) < 0 and float(W2.x) < 2400 and W2.wait == 0, 2400))
	S("desce", walk_to(2900))
	S("não foi vista (2)", g.VL.caught_n == 0)
	until({"R": true}, func(): return int(g.VL.CATCH.get("t", -1)) >= 0, 400)
	S("o Vargas aparece", int(g.VL.CATCH.t) >= 0)
	for i in 300:
		if ended:
			break
		g.step()
	S("fim (pegou a Isis)", ended)
	for l in log_lines:
		print(l)
	print("FALHAS: %d" % fails)
	quit(1 if fails > 0 else 0)
