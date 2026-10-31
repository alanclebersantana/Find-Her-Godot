#!/usr/bin/env python3
"""Gera tests/rec/*.gd: cópias dos robôs de rota/chefes que GRAVAM vídeo enquanto jogam.
Cada chamada de função do robô vira `await`, e frame() passa a desenhar um quadro de vez em quando
(trechos de REC_LEN passos a cada REC_EVERY passos). Uso:
  python3 tools/promo/rec/mkrec.py
  REC_OUT=/tmp/vid3/ep1 godot --path . --resolution 2560x1440 --write-movie /tmp/vid3/ep1.avi --fixed-fps 30 -s tests/rec/route.gd
"""
import os, re
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
T = os.path.join(ROOT, 'tests')
FILES = ['route', 'route2', 'route3', 'ep2_bosses_test', 'ep3_bosses_test']
src = {f: open(os.path.join(T, f + '.gd')).read() for f in FILES}
names = set()
for s in src.values():
    names |= set(re.findall(r'^func (\w+)\(', s, re.M))
names.discard('_initialize')
pat = re.compile(r'(?<![\w.])(super\.)?(' + '|'.join(sorted(names, key=len, reverse=True)) + r')\(')

SETUP = '''
# ---------------------------------------------------------------- gravação (gerado por mkrec.py)
var main
var rec_steps := 0
var rec_acc := 0.0
var rec_n := 0
var posf: FileAccess
var REC_EVERY := int(OS.get_environment("REC_EVERY")) if OS.get_environment("REC_EVERY") != "" else 2600
var REC_LEN := int(OS.get_environment("REC_LEN")) if OS.get_environment("REC_LEN") != "" else 330
var REC_SKIP := int(OS.get_environment("REC_SKIP")) if OS.get_environment("REC_SKIP") != "" else 0

func _rec_setup(lvl: int) -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 3:
		await process_frame
	var sv = root.get_node("Save")
	for id in ["cipo", "mergulho", "neve", "pipoca", "picareta", "cavalo", "mina", "toxico", "javali", "gaviao", "bagre", "urso", "vargas", "bola", "aviao", "jangada", "colmeia", "carrinho", "moinho", "telhados"]:
		sv.setv("comic", id, true)
	sv.setv("opt", "tut_asked", true)
	main.start_level(false, lvl)
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
	main.set_physics_process(false)
	main.hud_layer.visible = false
	# o robô joga sozinho: nada de telas do main (pista, fogueira, resultados, Isis...) por cima do jogo
	for sg in g.get_signal_list():
		for cn in g.get_signal_connection_list(sg.name):
			var cb: Callable = cn.callable
			if cb.get_object() == main:
				g.disconnect(sg.name, cb)
	main.rec_zoom = float(OS.get_environment("REC_ZOOM")) if OS.get_environment("REC_ZOOM") != "" else 1.3
	main.cam_zoom = main.rec_zoom
	g.lives = 99
	g.auto_cine = true
	posf = FileAccess.open(OS.get_environment("REC_OUT") + ".pos", FileAccess.WRITE)

func _rstep() -> void:
	Interp.restore()
	g.step()
	g.slowmo = 0   # quem tira a câmera lenta é o main (desligado aqui); senão as faixas de cinema ficam
	rec_steps += 1
	var mx := OS.get_environment("REC_MAXX")
	if mx != "" and g.player.x > float(mx):
		print("REC_MAXX: fim em x=%d" % int(g.player.x))
		if posf:
			posf.close()
		quit()
		await process_frame
		return
	if rec_steps % 3000 == 0 and OS.get_environment("REC_DBG") != "":
		print("step %d x=%d y=%d cine=%s st=%s boss=%s" % [rec_steps, int(g.player.x), int(g.player.y), str(g.CINE.keys()), str(main.state), str(g.X.BOSS.get("st", ""))])
	var ph: int = (rec_steps - REC_SKIP) % REC_EVERY
	if rec_steps >= REC_SKIP and ph < REC_LEN:
		rec_acc += 30.0 / 44.0
		if rec_acc >= 1.0:
			rec_acc -= 1.0
			g.ip_div = 1
			g.ip_phase = 1
			g.flash_t = 0
			main.hud_layer.visible = false
			for c in main.ui_layer.get_children():
				if c.has_method("_end"):
					c._end()
			var vs: Vector2 = main.get_viewport().get_visible_rect().size
			var z: float = g.camera.zoom.x
			var c0: Vector2 = g.camera.position
			var u: float = (g.player.x + 12 - c0.x) * z / vs.x
			var v: float = (g.player.y + 20 - c0.y) * z / vs.y
			if posf:
				posf.store_line("%d %d %.4f %.4f %d %d" % [rec_n, int((rec_steps - REC_SKIP) / REC_EVERY), u, v, int(g.player.x), int(g.player.y)])
			rec_n += 1
			await process_frame
'''

FRAME_OLD = '''	g.step()
	while not g.CINE.is_empty():
		g.step()'''
FRAME_NEW = '''	await _rstep()
	while not g.CINE.is_empty():
		await _rstep()'''
os.makedirs(os.path.join(T, 'rec'), exist_ok=True)
for f, s in src.items():
    s = s.replace('extends "res://tests/', 'extends "res://tests/rec/')
    out = []
    for line in s.split('\n'):
        st = line.lstrip()
        if st.startswith('func ') or st.startswith('#') or st.startswith('##'):
            out.append(line)
            continue
        cut = line.find('func(')
        head, tail = (line, '') if cut < 0 else (line[:cut], line[cut:])
        head = pat.sub(lambda m: 'await ' + (m.group(1) or '') + m.group(2) + '(', head)
        head = head.replace('await await ', 'await ')
        out.append(head + tail)
    s = '\n'.join(out)
    s = re.sub(r'g = load\("res://scripts/game.gd"\).new\(\)\n\troot.add_child\(g\)\n\tg.load_level\((\d)\)',
               r'await _rec_setup(\1)', s)
    if f == 'route':
        assert FRAME_OLD in s
        s = s.replace(FRAME_OLD, FRAME_NEW)
        s += SETUP
    open(os.path.join(T, 'rec', f + '.gd'), 'w').write(s)
print('ok', len(names), 'funções')
