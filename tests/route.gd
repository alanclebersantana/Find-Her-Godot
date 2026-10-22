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

## pula e, no alto do pulo, aperta ↓ (mergulho) e espera bater no chão
func slam_here() -> void:
	press("J")
	frame({"J": true})
	for i in 40:
		frame({"J": true})
		if P.vy > -2:
			break
	press("S")
	frame()
	for i in 90:
		frame()
		if P.onGround or P.ladder != null or P.y > 600:
			break

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


## Urso-Rei: espera ele vir; quando se ergue, recua para fora da patada; tonto: picareta
func bear_fight():
	var b: Dictionary = g.K.BEAR
	for it in 9000:
		P = g.player
		if not ok():
			return "state"
		if b.done or b.st == "flee":
			hold({}, 60)
			return true
		var dx: float = px() - b.x
		if it % 30 == 0 and OS.get_environment("BEARDBG") != "":
			print("bear st=%s t=%d bx=%d px=%d hp=%d php=%d" % [b.st, b.t, int(b.x), int(px()), b.hp, P.hp])
		var away := "R" if dx > 0 else "L"
		var room_ok: bool = (px() < b.x1 - 120) if dx > 0 else (px() > b.x0 + 120)
		# onda do tremor chegando: pula
		var wave_near := false
		for w in b.get("waves", []):
			if abs(w.x - px()) < 70 and sign(px() - w.x) == w.d:
				wave_near = true
		if wave_near and P.onGround:
			press("J")
			frame({"J": true})
			continue
		match b.st:
			"rear", "slam":
				if abs(dx) < 245 and room_ok:
					frame({away: true})
				else:
					frame()
			"charge":
				if abs(dx) < 150 and P.onGround and sign(dx) == b.dir:
					djump(away)
				else:
					frame()
			"scrape", "skid", "rear2", "quake":
				frame()
			"dizzy":
				var side: float = -1.0 if dx < 0 else 1.0
				var tx: float = b.x + side * 90
				if abs(tx - px()) > 6:
					var before: float = px()
					frame({"R" if tx > px() else "L": true})
					if abs(px() - before) < .2 and P.onGround:
						jump_to(b.x)
				else:
					P.face = -int(side)
					press("G")
					hold({}, 26)
			"walk", "backoff", "back":
				var mid: float = (b.x0 + b.x1) * .5
				if abs(dx) < 260 and room_ok:
					frame({away: true})
				elif abs(px() - mid) > 200 and abs(dx) > 300:
					frame({"R" if mid > px() else "L": true})
				else:
					frame()
			_:
				frame()
	return "hp=%d st=%s" % [b.hp, b.st]

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
			if dx < -200 or dx > 260:
				continue
			# pula em cima da marca de cascos (o melhor ponto)
			if o.k in ["log", "rock", "gap", "fence"] and not o.hit and RD.hy >= 500:
				var tk: float = RD.takeoff_x(o)
				if RD.hx >= tk - 3 and RD.hx < tk + 6:
					press("J")
					d["J"] = true
			if o.k in ["branch", "rope"] and dx < 110 and dx > -130:
				d["S"] = true
			if dx > -40:
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

## a armadilha do tipo k mais perto de x
func trap_at(k: String, x: float) -> Dictionary:
	var best: Dictionary = {}
	for o in g.TR.T:
		if o.k == k and (best.is_empty() or abs(o.x - x) < abs(best.x - x)):
			best = o
	return best

## espera os espinhos acabarem de descer e atravessa andando
func cross_spikes(o: Dictionary, x_after: float):
	var per: int = o.get("per", 140)
	for i in 400:
		if (g.T + int(o.get("ph", 0))) % per == per / 2 + 8:
			break
		frame()
	return walk_to(x_after)

## tronco-pêndulo: espera ele subir para o lado de lá e passa correndo por baixo
func cross_swing(o: Dictionary, x_after: float):
	for i in 400:
		var th: float = fposmod(TAU * (g.T + o.get("ph", 0)) / float(o.per), TAU)
		if abs(th - deg_to_rad(215)) < .04:
			break
		frame()
	return run_to(x_after)

## corta a teia com a picareta (de frente para ela)
func cut_web(o: Dictionary):
	walk_to(o.x - 22)
	P.face = 1
	press("G")
	hold({}, 24)
	return o.cut or "teia inteira"

## pula num cogumelo saltador e deixa ele lançar até pousar
func bounce_to(bx: float):
	press("J")
	var launched := false
	for i in 300:
		P = g.player
		if not ok():
			return "state"
		if P.get("launchT", 0) > 0:
			launched = true
		var d := {}
		if not launched:
			if px() < bx - 4:
				d = {"R": true}
			elif px() > bx + 4:
				d = {"L": true}
			d["J"] = i < 16
		frame(d)
		P = g.player
		if launched and P.onGround:
			return true
	return "não foi lançado" if not launched else "air"

## corredeira: pula pedras, troncos e quedas; abaixa nos galhos
func ride_raft():
	var VH = g.VH
	for it in 4000:
		if VH.mode != "raft":
			return VH.raft_done
		var d := {}
		var wl: float = VH.water_y(VH.hx)
		for f in VH.RA.falls:
			var df: float = f - VH.hx
			if df > 4 and df < 40 and VH.hy >= wl - 1:
				press("J")
				d["J"] = true
		for o in VH.OBS:
			var dx: float = o.x - VH.hx
			if dx < -240 or dx > 220:
				continue
			if o.k in ["rock", "log"] and dx < 70 and dx > 26 and VH.hy >= wl - 1:
				press("J")
				d["J"] = true
			var dw: float = g.VH.DUCK_W.get(o.k, 0.0)
			if dw > 0 and dx < 120 and dx > -(dw + 36):
				d["S"] = true
			if dx > -40:
				break
		frame(d)
	return "não terminou x=%d" % int(VH.hx)

## subida da montanha: anda; perto de um precipício espera a rajada passar (abaixado) e pula
func climb_gusts(x_end: float):
	var chasms: Array = g.L.chasms
	for it in 3000:
		P = g.player
		if not ok():
			return "state"
		if px() >= x_end and P.onGround:
			return true
		var gusting := false
		for o in g.TR.T:
			if o.k == "gust" and g.TR.gust_state(o) > 0 and px() > o.x - 220 and px() < o.x + o.w + 40:
				gusting = true
		# degrau à frente?
		var step_up := false
		for s in g.SOL:
			if s.t == "ground" and s.x > px() and s.x - px() < 40 and s.y < P.y + P.h - 4 and P.onGround:
				step_up = true
		var edge := false
		for c in chasms:
			if c[0] - px() > 0 and c[0] - px() < 30 and P.onGround:
				edge = true
		if edge:
			if gusting:
				frame({"S": true})
				continue
			press("J")
			for i in 40:
				frame({"J": i < 18, "R": true})
				P = g.player
				if P.onGround and i > 4:
					break
			continue
		if step_up:
			press("J")
			for i in 30:
				frame({"J": i < 12, "R": true})
				P = g.player
				if P.onGround and i > 4:
					break
			continue
		if gusting and g.TR.T.any(func(o): return o.k == "gust" and g.TR.gust_state(o) == 2 and px() > o.x and px() < o.x + o.w):
			frame({"R": true})
		else:
			frame({"R": true})
	return "timeout@%d,%d" % [int(px()), int(P.y)]

## ponte que se solta: corre e pula os vãos
func bridge_run(o: Dictionary):
	var gaps: Array = []
	for gi in o.get("gaps", []):
		gaps.append(o.x + gi * 40.0)
	frame({"R": true})
	frame({})
	for it in 600:
		P = g.player
		if not ok():
			return "state"
		if px() > o.x + o.w + 40 and P.onGround:
			return true
		var d := {"R": true}
		for gx in gaps:
			if gx - px() > 0 and gx - px() < 34 and P.onGround:
				press("J")
		d["J"] = not P.onGround and P.vy < 0
		frame(d)
	return "timeout@%d,%d" % [int(px()), int(P.y)]

## voo: para cada grupo de obstáculos à frente calcula as alturas livres e vai para a mais perto
func _obs_box(o: Dictionary) -> Array:
	match o.k:
		"flock":
			return [o.x - 30, o.x + 90, o.y - 26, o.y + 64]
		"cloud":
			return [o.x + 10, o.x + o.w - 10, o.y + 8, o.y + o.h - 8]
		"hawk":
			if o.st == "gone":
				return []
			var ty: float = o.get("ty", o.y)
			if o.st in ["warn", "dive", "sweep"]:
				return [o.x - 400, o.x + 40, ty - 18, ty + 18]
			return []
	return []

func _free_spans(boxes: Array, top: float, low: float) -> Array:
	# alturas (hy) livres: a caixa do avião vai de hy-46 a hy-6
	var spans := [[top, low]]
	for bx in boxes:
		var cut0: float = bx[2] + 6 - 14
		var cut1: float = bx[3] + 46 + 14
		var out := []
		for sp in spans:
			if sp[1] < cut0 or sp[0] > cut1:
				out.append(sp)
			else:
				if sp[0] < cut0:
					out.append([sp[0], cut0])
				if sp[1] > cut1:
					out.append([cut1, sp[1]])
		spans = out
	return spans

func fly_plane():
	var VH = g.VH
	for it in 6000:
		if VH.mode != "plane":
			return VH.plane_done
		if VH.phase != "fly":
			frame()
			continue
		var groups := []
		var list := []
		for o in VH.OBS:
			var bx := _obs_box(o)
			if bx.is_empty() or bx[1] < VH.hx - 60 or bx[0] > VH.hx + 900:
				continue
			list.append(bx)
		list.sort_custom(func(a, b): return a[0] < b[0])
		for bx in list:
			if groups.is_empty() or bx[0] > groups.back()[0][0] + 120:
				groups.append([bx])
			else:
				groups.back().append(bx)
		var target: float = VH.hy
		if not groups.is_empty():
			var spans := _free_spans(groups[0], VH.PL.top + 10, VH.PL.low - 10)
			var nxt := []
			if groups.size() > 1:
				nxt = _free_spans(groups[1], VH.PL.top + 10, VH.PL.low - 10)
			var best := 1e9
			for sp in spans:
				for k in 9:
					var y: float = lerpf(sp[0], sp[1], k / 8.0)
					var c: float = abs(y - VH.hy)
					if not nxt.is_empty():
						var dn := 1e9
						for sp2 in nxt:
							dn = min(dn, 0.0 if (y >= sp2[0] and y <= sp2[1]) else min(abs(y - sp2[0]), abs(y - sp2[1])))
						c += dn * 2.0
					if c < best:
						best = c
						target = y
		var dd := {}
		if VH.hy > target + 5:
			dd["U"] = true
		elif VH.hy < target - 5:
			dd["S"] = true
		frame(dd)
	return "não terminou x=%d" % int(VH.hx)

## bola gigante: corre pulando os obstáculos e se abaixa no buraco do chão
func boulder_run(o: Dictionary):
	var obs: Array = []
	for sb in g.SOL:
		if sb.get("bob") and sb.bob != "barricade":
			obs.append(float(sb.x))
	for pit in g.L.pits:
		if pit[0] > o.x and pit[0] < o.end:
			obs.append(float(pit[0]))
	var niche: float = (o.niche[0] + o.niche[1]) / 2.0
	frame({})
	frame({"R": true})
	frame({})
	var jt := 0
	for it in 900:
		P = g.player
		if not ok():
			return "state"
		if px() > niche - 70:
			break
		for ox in obs:
			var ahead: float = ox - (px() + P.w / 2)
			if ahead > 20 and ahead < 64 and P.onGround and jt <= 0:
				press("J")
				jt = 14
		jt -= 1
		frame({"R": true, "J": jt > 0})
	# entra no buraco e se abaixa até a bola passar
	for it in 400:
		P = g.player
		if o.get("passed", false) or o.st in ["break", "done"]:
			break
		if px() > o.niche[0] + 14 and px() < o.niche[1] - 14 and P.onGround:
			frame({"S": true})
		else:
			frame({"R" if niche > px() else "L": true})
	hold({}, 30)
	return o.get("passed", false) or "bola: " + o.st

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
	walk_to(2525)
	S("espinhos da manhã", cross_spikes(trap_at("spikes", 2560), 2700))
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
	S("chão rachado", walk_to(4605))
	slam_here()
	S("mergulho quebrou o chão", g.X.broken.has("chao1"))
	walk_to(4610)
	S("desce a escada do esconderijo", climb_to("S", func(): return P.onGround and P.y > 800, 500))
	hold({}, 60)
	S("entrou na sala", g.player.y > 800)
	S("gancho", walk_to(4840))
	walk_to(4850)
	jr(16, "R")
	S("vermelho", spec("vermelho"))
	S("parede falsa", walk_to(4340))
	S("sala secreta 1", g.X.found.has("s1"))
	S("volta à escada", walk_to(4610))
	S("sobe com ↑", climb_to("U", func(): return P.ladder == null and P.onGround and P.y < 500, 500))
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
	S("tronco-pêndulo", cross_swing(trap_at("swing", 10010), 10290))
	S("passou o tronco", P.hp == 5)
	walk_to(10290)
	hold({}, 20)
	press("D")
	frame()
	S("Pipoca no portão da tarde", g.M.ctrl)
	S("Pipoca até a placa", walk_to(10470))
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
	S("pula o brejo", jump_to(13400))
	S("gavião-rei apareceu", until({"R": true}, func(): return g.K.HAWK.active, 300))
	S("venceu o gavião-rei", hawk_fight())
	S("ilha 3", walk_to(14650))
	S("fogueira grande 2", rests.has(2))
	S("sobe a rede", climb_to("U", func(): return P.ladder == null and P.y + P.h <= 152, 400))
	S("galho: manivela + verde", walk_to(14780))
	S("manivela_q", g.INV.has("manivela_q") and spec("verde"))
	walk_to(14670)
	S("desce", climb_to("S", func(): return P.onGround and P.y > 400, 500))
	S("combina engrenagem+manivela", g.try_combine("engrenagem", "manivela_q") != "")
	S("comporta", walk_to(14790))
	use()
	S("escoa", until({}, func(): return g.SWAMP.filter(func(s): return s.get("id") == "canal")[0].y >= 639, 400))
	S("passa a comporta", walk_to(14878))
	S("pedra 1", jump_to(14970))
	S("pedra 2", jump_to(15110))
	walk_to(15140)
	S("pedrinha (pista 4)", until({"R": true}, func(): return P.onGround and P.y > 520, 100))
	S("pistas=4", n_clues() >= 4)
	S("pedra 3", jump_to(15250))
	S("margem do pântano", jump_to(15340))
	S("abaixado sob a colmeia 2", crawl(15515))
	S("colmeia 2 quieta", trap_at("hive", 15465).st == "idle")
	walk_to(15595)
	S("mergulha", until({"R": true, "S": true}, func(): return px() > 15750 and P.y > 600, 300))
	S("atravessa o túnel d'água", until({"R": true}, func(): return px() > 16920, 1200))
	S("respirou nas bolhas", g.lives >= 3)
	S("sobe", until({"U": true, "R": true}, func(): return P.y < 515, 300))
	S("sai da água", jump_to(17110))
	walk_to(17280)
	S("régia 1", jump_to(17406))
	S("régia 2", jump_to(17556))
	S("régia 3", jump_to(17706))
	S("tronco boiando", jump_to(17870))
	walk_to(17980)
	S("régia 4", jump_to(18126))
	S("régia 5", jump_to(18276))
	S("régia 6", jump_to(18426))
	S("margem do lamaçal", jump_to(18550))
	walk_to(18630)
	S("cipó 1", grab_vine(g.VINES[1]))
	S("cipó 2", vine_hop(g.VINES[2]))
	S("cipó 3", vine_hop(g.VINES[3]))
	S("outra margem", vine_hop(null))
	S("vivo no lamaçal", g.lives >= 3 and px() > 19550)
	walk_to(19990)
	S("cipó da ribanceira", grab_vine(g.VINES[4]))
	S("agarra a corda", _to_bar())
	S("anda pendurado", until({"R": true}, func(): return px() > 21040, 600))
	press("J")
	frame()
	S("solta na margem", wait_ground())
	walk_to(21150)
	S("abaixado sob a colmeia 1", crawl(21265))
	S("colmeia 1 quieta", trap_at("hive", 21215).st == "idle")
	walk_to(21335)
	S("mergulho 2", until({"R": true, "S": true}, func(): return px() > 21600 and P.y > 600, 300))
	S("túnel d'água 2", until({"R": true}, func(): return px() > 22620, 1200))
	S("sobe do mergulho 2", until({"U": true, "R": true}, func(): return P.y < 515, 300))
	S("sai do mergulho 2", jump_to(22790))
	walk_to(22850)
	S("abaixado sob a colmeia 3", crawl(22968))
	S("colmeia 3 quieta", trap_at("hive", 22918).st == "idle")
	S("lago", walk_to(23020))
	for i in 600:
		P = g.player
		if g.NT.helmet and g.NT.harpoon:
			break
		var tx: float = 23400.0 if not g.NT.harpoon else 23280.0
		frame({"R": px() < tx - 4, "L": px() > tx + 4, "S": P.y < 836, "U": P.y > 846})
	S("capacete e arpão", g.NT.helmet and g.NT.harpoon)
	S("bagre-rei apareceu", until({"R": true}, func(): return g.K.FISH.active, 300))
	S("venceu o bagre-rei", fish_fight())
	S("corrente de bolhas", until({"R": true}, func(): return px() > 24710, 600))
	S("subiu na corrente", until({"R": true}, func(): return P.onGround and P.y < 480, 400))
	S("margem do rio", walk_to(25040))
	use()
	S("subiu na jangada", g.VH.mode == "raft")
	S("corredeira", ride_raft())
	S("jangada sem virar", g.VH.tries == 0)
	S("fogueira grande 3", walk_to(32380) and rests.has(3))
	walk_to(32750)
	S("pula a pedra", jump_to(32880, true))
	S("empurra a bola de neve", until({"R": true}, func(): return g.NT.SNOWB[0].x + g.NT.SNOWB[0].w >= 33247, 900))
	S("bola cresceu", g.NT.SNOWB[0].w > 75)
	S("sobe na bola", jump_to(33170))
	S("paredão", jump_to(33310, true))
	S("gelo", walk_to(33900))
	walk_to(34070)
	S("bola rolando 1", dodge_roll(34330, 0))
	S("bola rolando 2", dodge_roll(34850, 1))
	walk_to(35295)
	S("gelo fino 1", jump_to(35351))
	S("gelo fino 2", jump_to(35431))
	S("gelo fino 3", jump_to(35511))
	S("depois do gelo", jump_to(35565))
	S("pedra da bola 2", jump_to(35675))
	walk_to(35678)
	S("empurra a bola 3", until({"R": true}, func(): return g.NT.SNOWB[2].x + g.NT.SNOWB[2].w >= 35807, 900))
	S("sobe na bola 3", jump_to(35780))
	S("2º paredão", jump_to(35850, true))
	walk_to(35945)
	S("vila", walk_to(36600))
	walk_to(36800)
	S("desce na caverna de gelo", climb_to("S", func(): return P.onGround and P.y > 800, 500))
	walk_to(37210)
	S("bloco de gelo 1", jump_to(37290))
	S("desce do bloco 1", jump_to(37420))
	walk_to(37630)
	S("bloco de gelo 2", jump_to(37710))
	S("desce do bloco 2", jump_to(37840))
	walk_to(38310)
	S("sobe da caverna", climb_to("U", func(): return P.ladder == null and P.onGround and P.y < 480, 500))
	walk_to(38460)
	walk_to(38650)
	S("carroça", jump_to(38805))
	S("empurra a bola 2", until({"R": true}, func(): return g.NT.HOLES[0].filled, 900))
	S("cavalo", walk_to(39460))
	use()
	S("cavalgada começou", until({}, func(): return g.RD.riding, 400))
	S("cavalgada", ride())
	S("sem tropeço", g.RD.tries == 0)
	walk_to(49950)
	S("bloco baixo da clareira", jump_to(50110, true))
	S("clareira do urso", walk_to(50160))
	S("Urso-Rei", bear_fight())
	for bx in [50380.0, 50900.0, 51250.0]:
		if px() < bx:
			walk_to(bx - 30)
			jump_to(bx + 110)
	S("fogueira grande 4", walk_to(52650) and rests.has(4))
	S("subida da montanha", climb_gusts(55190))
	S("ponte de cordas", bridge_run(trap_at("bridge", 55220)))
	S("pista do avião", walk_to(56960))
	use()
	S("decolou", g.VH.mode == "plane")
	S("voo", fly_plane())
	S("avião sem rodopiar", g.VH.tries == 0)
	S("fogueira grande 5", walk_to(63840) and rests.has(5))
	S("margem", walk_to(64030))
	var axe: Dictionary = g.TR.by_kind("axe")[0]
	S("espera o machado", until({}, func(): g.TR.axe_blade(axe); return axe.ang < -.9, 300))
	S("corre sob o machado", run_to(64150))
	S("noite", walk_to(64285))
	S("espaço depois do machado", walk_to(64470))
	S("caixa", jump_to(64535))
	if px() < 64560:
		jump_to(64600, true)
	walk_to(64805)
	S("cogumelo saltador 1", bounce_to(64855))
	S("chapéu alto", P.y + P.h <= 232)
	S("cogumelo baixo", jump_to(65300))
	S("cogumelo saltador 2", bounce_to(65345))
	S("chapéu mais alto", P.y + P.h <= 152)
	S("desce de chapéu", jump_to(65825))
	S("fim do bosque", jump_to(66010))
	walk_to(66960)
	S("desce no poço da mina", climb_to("S", func(): return P.onGround and P.y > 820, 500))
	walk_to(67025)
	S("espinhos do poço", cross_spikes(trap_at("spikes", 67050), 67180))
	S("viga do poço", crawl(67320))
	walk_to(67470)
	S("carrinho do poço", jump_to(67660))
	walk_to(67875)
	S("tábua do poço 1", jump_to(67940))
	S("tábua do poço 2", jump_to(68025))
	S("depois das tábuas", jump_to(68120))
	walk_to(68800)
	S("viga 2 do poço", crawl(68950))
	walk_to(69170)
	S("sobe do poço", climb_to("U", func(): return P.ladder == null and P.onGround and P.y < 480, 500))
	walk_to(69320)
	S("porta do galpão", walk_to(69570))
	hold({}, 20)
	press("D")
	frame()
	S("Pipoca", g.M.ctrl)
	S("Pipoca entra pela portinhola", walk_to(69800))
	S("óleo", g.INV.has("oleo"))
	S("Pipoca sai", walk_to(69570))
	press("D")
	frame()
	S("Tomé", not g.M.ctrl)
	S("telhado do galpão", jump_to(69645, true))
	S("desce do telhado", walk_to(69940))
	S("escada da coruja", walk_to(70205))
	S("sobe", climb_to("U", func(): return P.ladder == null and P.onGround and P.y + P.h <= 42, 500))
	S("pavio", walk_to(70240))
	S("azul", walk_to(70110))
	S("pavio+azul", g.INV.has("pavio") and spec("azul"))
	walk_to(70205)
	S("desce", climb_to("S", func(): return P.onGround and P.y > 400, 600))
	S("combina óleo+pavio", g.try_combine("oleo", "pavio") != "")
	S("laje do X", walk_to(70010))
	use()
	S("quebrou a laje", g.X.broken.has("slab"))
	S("desce na câmara", climb_to("S", func(): return P.onGround and P.y > 800, 500))
	var rg = walk_to(69698)
	S("lápis dourado %s" % str(rg), g.X.GOLD.got)
	walk_to(70085)
	S("plataforma 1", jump_to(70095) is bool and P.y + P.h < 850)
	S("pl. 2", jump_to(70160) is bool and P.y + P.h < 795)
	S("pl. 3", jump_to(70088) is bool and P.y + P.h < 740)
	S("sala secreta 3", g.X.found.has("s3"))
	S("desce", until({"L": true}, func(): return P.onGround and P.y > 850, 300))
	S("escada da laje", walk_to(70010))
	S("sobe", climb_to("U", func(): return P.ladder == null and P.onGround and P.y < 480, 500))
	walk_to(70205)
	S("rede de caçador", walk_to(70270))
	press("D")
	frame()
	S("Pipoca (rede)", g.M.ctrl)
	S("Pipoca no poste", walk_to(70265))
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
	S("Pipoca no poste da jaula", walk_to(70362))
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
		frame({"R": px() < 70570, "J": dj and i < 60})
		P = g.player
		if dj and P.onGround:
			break
	S("quica + pulo duplo", g.player.y < 130)
	S("desenho 2", walk_to(70640))
	walk_to(70740)
	S("desce do galho", until({}, func(): return P.onGround and P.y > 400, 200))
	S("entrada do túnel", walk_to(70750))
	use()
	S("barreira aberta", g.LOCKS[2].done)
	walk_to(70925)
	use()
	walk_to(70985)
	use()
	S("portão das alavancas", until({}, func(): return g.EV.GATE.lift >= g.EV.GATE.h - 8, 200))
	S("passa o portão (sem abaixar)", walk_to(71305))
	S("tábua podre", jump_to(71410))
	S("depois da tábua", jump_to(71560))
	walk_to(71600)
	S("carrinho do túnel", jump_to(71800))
	walk_to(71935)
	S("tábuas 1", jump_to(72010))
	S("tábuas 2", jump_to(72100))
	S("fim das tábuas", jump_to(72200))
	walk_to(72240)
	S("viga 2 do túnel", crawl(72390))
	S("túnel da pedra", walk_to(72850))
	var bol: Dictionary = trap_at("boulder", 72700)
	S("a pedra caiu", until({"R": true}, func(): return bol.st != "idle", 200))
	S("fuga da pedra", boulder_run(bol))
	S("sem ser atropelado", P.hp == 5)
	S("sai do buraco", jump_to(74540))
	S("túnel", walk_to(74990))
	S("rasteja", crawl(75150))
	S("escada do nicho", walk_to(75350))
	S("desce", climb_to("S", func(): return P.onGround and P.y > 700, 500))
	S("roxo no nicho", walk_to(75160) and spec("roxo"))
	walk_to(75380)
	S("rasteja divisória", crawl(75445))
	S("pistas=6 (crachá)", n_clues() == 6)
	S("vilão ainda não", not g.VIL.go)
	walk_to(75480)
	S("sobe pela saída", climb_to("U", func(): return P.ladder == null and P.onGround and P.y < 480, 500))
	S("vilão foge", walk_to(75700))
	S("perseguição começou", g.VIL.go)
	walk_to(76030)
	S("1º buraco", jump_to(76200))
	walk_to(76320)
	S("desliza sob a viga", crawl(76450))
	walk_to(76685)
	S("2º buraco", jump_to(76890, true))
	walk_to(76950)
	S("pula o carrinho parado", jump_to(77100, true))
	walk_to(77170)
	S("tábua 1", jump_to(77260))
	S("tábua 2", jump_to(77390))
	S("tábua 3", jump_to(77520))
	S("chão", jump_to(77630))
	walk_to(77770)
	S("viga 2", crawl(77900))
	S("vilão entrou na mina", until({"R": true}, func(): return g.VIL.gone or px() > 78200, 900))
	S("vilão entrou", until({}, func(): return g.VIL.gone, 400))
	walk_to(78315)
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
