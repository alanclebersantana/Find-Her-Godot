extends Node2D
const WS = preload("res://scripts/world_static.gd")
## Tudo o que se mexe no mundo: escadas, cadeados, vitórias-régias, vilão, caixas, inimigos,
## o Tomé, poeira e faíscas. Redesenhado a cada quadro.

var game: Game
var T := 0
var pl_node: Node2D
var front_node: Node2D

class _Sub extends Node2D:
	var cb: Callable
	func _draw() -> void:
		cb.call(self)

func _ready() -> void:
	pl_node = _Sub.new()
	pl_node.cb = _draw_player_node
	var m := ShaderMaterial.new()
	m.shader = preload("res://scripts/depth.gdshader")
	pl_node.material = m
	add_child(pl_node)
	front_node = _Sub.new()
	front_node.cb = _draw_front_node
	add_child(front_node)

func _process(_d: float) -> void:
	queue_redraw()

func _draw() -> void:
	var __t := Time.get_ticks_usec()
	__draw_raw()
	Spr.pt("dyn", __t)

func __draw_raw() -> void:
	if game == null or not game.L:
		return
	var g := game
	T = g.T
	Spr.begin(self)
	var cx0: float = g.cam - 400
	var cx1: float = g.cam + g.W + 400
	# tábuas e galhos (atrás de tudo que se mexe: o Javali-Rei e os bichos passam na frente): afundam um pouquinho e balançam quando o Tomé pisa ou aterrissa
	for so in g.SOL:
		var st_: String = str(so.get("t", ""))
		if (st_ != "plat" and st_ != "branch") or so.x > cx1 or so.x + so.w < cx0:
			continue
		var dp: float = so.get("dip", 0.0)
		Spr.save()
		Spr.translate(0, dp)
		if st_ == "plat":
			WS.plat(so)
		else:
			WS.branch(so)
		Spr.restore()
	if g.MV:
		g.MV.draw(T)
	if g.VL:
		g.VL.draw(T)
	var __d__deco := Time.get_ticks_usec()
	_deco(g)
	WorldExtras.flowers(g, T)
	Spr.pt("d__deco", __d__deco)
	var __d__climb := Time.get_ticks_usec()
	_climb(g)
	Spr.pt("d__climb", __d__climb)
	var __d__locks := Time.get_ticks_usec()
	_locks(g)
	Spr.pt("d__locks", __d__locks)
	var __d__entrances := Time.get_ticks_usec()
	_entrances(g)
	Spr.pt("d__entrances", __d__entrances)
	var __d__lily_mud := Time.get_ticks_usec()
	_lily_mud(g)
	Spr.pt("d__lily_mud", __d__lily_mud)
	var __d_Extras_chalk := Time.get_ticks_usec()
	WorldExtras.chalk(g, T)
	Spr.pt("d_Extras_chalk", __d_Extras_chalk)
	var __d_Extras_footprints := Time.get_ticks_usec()
	WorldExtras.footprints(g)
	Spr.pt("d_Extras_footprints", __d_Extras_footprints)
	var __d_Extras_crawl := Time.get_ticks_usec()
	WorldExtras.crawl(g, T)
	Spr.pt("d_Extras_crawl", __d_Extras_crawl)
	var __d_Extras_solids := Time.get_ticks_usec()
	WorldExtras.solids(g, T)
	Spr.pt("d_Extras_solids", __d_Extras_solids)
	var __d_Extras_mech := Time.get_ticks_usec()
	WorldExtras.mech(g, T)
	Spr.pt("d_Extras_mech", __d_Extras_mech)
	if g.SL:
		g.SL.draw(T)
	var __d_Props_draw := Time.get_ticks_usec()
	WorldProps.draw(g, T)
	Spr.pt("d_Props_draw", __d_Props_draw)
	WorldLake.back(g, T)
	var __d_Traps_draw := Time.get_ticks_usec()
	WorldTraps.draw(g, T)
	Spr.pt("d_Traps_draw", __d_Traps_draw)
	var __d_Nature_draw := Time.get_ticks_usec()
	WorldNature.draw(g, T)
	Spr.pt("d_Nature_draw", __d_Nature_draw)
	var __d__ride_world := Time.get_ticks_usec()
	_ride_world(g)
	Spr.pt("d__ride_world", __d__ride_world)
	var __d_Vehicles_draw := Time.get_ticks_usec()
	WorldVehicles.draw(g, T)
	Spr.pt("d_Vehicles_draw", __d_Vehicles_draw)
	var __d_Extras_boss := Time.get_ticks_usec()
	WorldExtras.boss(g, T)
	Spr.pt("d_Extras_boss", __d_Extras_boss)
	var __d_Kings_draw := Time.get_ticks_usec()
	WorldKings.draw(g, T)
	Spr.pt("d_Kings_draw", __d_Kings_draw)
	if g.VIL and g.VIL.go and not g.VIL.gone:
		var v: Dictionary = g.VIL
		var f: int = (T / max(3, int(10 - v.get("spd", 3.3)))) % 2
		Spr.A("lia_scared", v.x + 44, v.y - 58, .5)
		Spr.A("vg_cart1" if f else "vg_cart2", v.x, v.y + 2, 1)
	_levers(g)
	for v in g.VINES:
		if v.x + v.len < cx0 or v.x - v.len > cx1:
			continue
		_vine(v)
	for s in g.SPR:
		_glow_mush(s.x, s.y, s.t)
	for c in g.CHK:
		if c.x < cx0 or c.x > cx1:
			continue
		_campfire(c)
	for c in g.CR:
		if not c.dead and c.t != "push" and c.x > cx0 and c.x < cx1:
			_crate(c)
	for e in g.EN:
		if e.dead > 50:
			continue
		if e.x < g.cam - 200 or e.x > g.cam + g.W + 200:
			continue
		var eo := g.e_off(e)
		Spr.edist(e)
		Spr.eturn(e)
		_enemy_fx_under(g, e, eo)
		Spr.save()
		Spr.translate(eo.x, eo.y)
		var st0: int = e.get("startT", -99)
		var hop_u: float = (g.T - st0) / 18.0
		if hop_u >= 0 and hop_u < 1:
			Spr.translate(0, -sin(hop_u * PI) * 12)
		# inimigo: contorno vermelho pulsando (mais forte quando o Tomé está perto) — os bichos
		# do cenário nunca têm isso
		if not e.dead and not (e.k == "leech" and e.get("hid", true)) and not (e.k == "mole" and e.get("st", 0) in [0, 1]):
			var pp: Dictionary = g.player
			var dn: float = clamp(1.0 - Vector2(pp.x + pp.w / 2 - e.x, pp.y + pp.h / 2 - e.y).length() / 420.0, 0, 1)
			var pul: float = .5 + .5 * sin(T * .14 + e.x * .01)
			var oa: float = (.35 + .5 * dn) * (.55 + .45 * pul)
			Spr.glow(e.x, e.y - 14, 46 + 10 * dn, Color(1, .15, .08, .10 + .12 * dn * pul))
			Spr.sil_c = Color(1, .12, .06, oa)
			for d in OUT8:
				Spr.save()
				Spr.translate(d.x * 2.6, d.y * 2.6)
				_enemy(e)
				Spr.restore()
			Spr.sil_c = Color(0, 0, 0, 0)
		_enemy(e)
		if not e.dead:
			_enemy_eyes(e)
		# clarão branco logo que leva o golpe
		if e.dead > 0 and e.dead <= 5:
			Spr.sil_c = Color(1, 1, 1, .9 * (1.0 - (e.dead - 1) / 5.0))
			_enemy(e)
			Spr.sil_c = Color(0, 0, 0, 0)
		Spr.restore()
		if e.get("dizzyT", 0) > 0 and not e.dead:
			e.dizzyT -= 1
			if e.stun > 0:
				dizzy(e.x + eo.x, e.y + eo.y - 46, T)
		_enemy_fx_over(g, e, eo, hop_u)
	Critters.draw(g, T)
	var __d_Extras_tocas := Time.get_ticks_usec()
	WorldExtras.tocas(g, T)
	Spr.pt("d_Extras_tocas", __d_Extras_tocas)
	if g.M and g.M.ctrl:
		var doff := g.ip_off()
		Spr.save()
		Spr.translate(doff.x, doff.y)
		WorldExtras.dog(g, T)
		Spr.restore()
	else:
		WorldExtras.dog(g, T)
	if not g.low_fx:
		_reflection(g)
	# o Tomé é desenhado num nó só dele (com o sombreado de volume) e o que fica na frente dele
	# (capim, faíscas, poeira) num terceiro nó por cima
	pl_node.queue_redraw()
	front_node.queue_redraw()

## nó do Tomé: volume com luz do sol (de cima, atrás) ou da lanterna (da frente)
func _draw_player_node(n: CanvasItem) -> void:
	var g := game
	if g == null or not g.L:
		return
	Spr.begin(n)
	var __d__player := Time.get_ticks_usec()
	var p: Dictionary = g.player
	var mat: ShaderMaterial = n.material
	var dark: float = g.AMB.dark
	if g.L.has("under") and p.y > g.L.under:
		dark = 1.0
	var face: float = 1.0 if p.face > 0 else -1.0
	if dark > .3:
		mat.set_shader_parameter("light_uv", Vector2(1.0, -.35).normalized())
		mat.set_shader_parameter("rim_col", Color(1, .78, .45))
		mat.set_shader_parameter("rim_amt", .4 * clamp((dark - .3) * 3.0, 0, 1))
	else:
		var tw: float = g.section_weights().get("tarde", 0.0)
		mat.set_shader_parameter("light_uv", Vector2(-.7 * face, -.75).normalized())
		mat.set_shader_parameter("rim_col", Color(1, .95, .8).lerp(Color(1, .74, .42), tw))
		mat.set_shader_parameter("rim_amt", .34)
	mat.set_shader_parameter("shade_amt", .55 if p.swim else .32)
	# cor do ambiente: mais quente no fim da tarde, mais azulada na neve e à noite
	var ws: Dictionary = g.section_weights()
	var env := Color(1, 1, 1)
	env = env.lerp(Color(1.03, .95, .86), ws.get("tarde", 0.0))
	env = env.lerp(Color(.94, .97, 1.04), ws.get("neve", 0.0))
	env = env.lerp(Color(.9, .94, 1.02), ws.get("noite", 0.0))
	env = env.lerp(Color(.92, .96, .94), ws.get("pantano", 0.0))
	n.self_modulate = env
	_player(g)
	_breath(g)
	Spr.pt("d__player", __d__player)

## nó da frente: o que passa por cima do Tomé
func _draw_front_node(n: CanvasItem) -> void:
	var g := game
	if g == null or not g.L:
		return
	Spr.begin(n)
	WorldNature.front_decor(g)
	if g.VL:
		g.VL.draw_front(T)
	var __d_Traps_draw_front := Time.get_ticks_usec()
	WorldTraps.draw_front(g, T)
	Spr.pt("d_Traps_draw_front", __d_Traps_draw_front)
	var __d_Extras_grass := Time.get_ticks_usec()
	WorldExtras.grass(g, T)
	Spr.pt("d_Extras_grass", __d_Extras_grass)
	for f in g.FXS:
		Spr.A(f.n, f.x, f.y, f.sc, false, 1.0 - float(f.t) / f.life)
	for p in g.PARTS:
		var c: Color = p.col
		var pa: float = c.a * clamp(p.life / 24.0, 0, 1)
		if p.get("ember"):
			# brasa: brilho alaranjado, ziguezagueando e esfriando para vermelho
			var ex: float = p.x + sin(p.life * .5 + p.y * .1) * 3
			var ec := Color(1, .85, .4).lerp(Color(1, .35, .1), 1.0 - clamp(p.life / 28.0, 0, 1))
			Spr.glow(ex, p.y, 7, Color(ec.r, ec.g, ec.b, pa * .5))
			Spr.circle(ex, p.y, 1.6, Color(ec.r, ec.g, ec.b, pa))
		elif p.has("ring"):
			# onda de choque do mergulho: anel de poeira se abrindo rente ao chão
			var u: float = 1.0 - p.life / 18.0
			Spr.ci.draw_arc(Vector2(p.x, p.y), p.ring * u, PI, TAU, 28, Color(1, .93, .75, .6 * (1.0 - u)), 3, true)
			Spr.ellipse(p.x, p.y, p.ring * u, 4, Color(1, .95, .8, .18 * (1.0 - u)))
		else:
			Spr.rect(p.x, p.y, 3, 3, Color(c.r, c.g, c.b, pa))

# ---------- cenário com estado ----------
var cabins: Array = []
func _deco(g: Game) -> void:
	var cam := g.cam
	# fumaça da chaminé da cabana
	if cabins.is_empty() or cabins[0] != g.L:
		cabins = [g.L]
		for so in g.L.solids:
			if so.t == "cabin":
				cabins.append(so)
	for ci_ in range(1, cabins.size()):
		var cb: Dictionary = cabins[ci_]
		if cb.x > cam + g.W + 300 or cb.x + 400 < cam:
			continue
		var chx: float = cb.x - 15 + 167
		var chy: float = cb.y + cb.h - 221 + 6
		for i in 9:
			var age: float = fposmod(T * .5 + i * 22.0, 198.0)
			var u: float = age / 198.0
			var sx: float = chx + u * 46 + sin(u * 6.0 + i) * 7
			var sy: float = chy - u * 170
			var sa: float = .5 * (1.0 - u) * min(1.0, u * 6.0)
			Spr.circle(sx, sy, 6 + u * 24, Color(.86, .86, .88, sa))
	var k := 0
	var pp: Dictionary = g.player
	var ppx: float = pp.x + pp.w / 2
	for x in g.L.get("cattails", []):
		if x > cam - 80 and x < cam + g.W + 80:
			# os juncos se curvam quando o Tomé passa e balançam com o vento
			var near: float = clamp(1.0 - abs(x - ppx) / 50.0, 0, 1) if abs(pp.y + pp.h - 512) < 60 else 0.0
			var bend: float = sign(x - ppx) * near * .35 + sin(T * .03 + x) * .04 + g.AMB.get("wind", 0.0) * .12
			Spr.save()
			Spr.translate(x, 512)
			Spr.rotate(bend)
			Spr.A("sw_cattail", 0, 0, .62 + (k % 3) * .1, k % 2 == 1)
			Spr.restore()
		k += 1
	# mina: trilhos (com pontes sobre os buracos), carrinho parado e porta
	var rx0: float = g.L.villain.x0 - 160 if g.L.has("villain") else 9380.0
	var rx1: float = g.L.spanX
	if g.L.has("rails"):
		rx0 = float(g.L.rails[0])
		rx1 = float(g.L.rails[1])
	if cam + g.W > rx0 and cam < rx1:
		var xa: float = max(rx0, floor((cam - 10) / 18) * 18)
		var xb: float = min(rx1, cam + g.W + 10)
		var x := xa
		while x < xb:
			var over_pit := false
			for pit in g.L.get("pits", []):
				if x > pit[0] and x < pit[1]:
					over_pit = true
			if over_pit:
				# cavalete de madeira pintada segurando o trilho sobre o buraco
				if int(x) % 72 < 18:
					Spr.PR("log", x - 2, 497, 10, 140, Color(.7, .62, .55))
					Spr.seg(x + 3, 520, x + 39, 590, Color("#3e2a18"), 4)
			else:
				# dormente de madeira com veio e prego
				Spr.rr(x - 1, 493, 14, 8, 2, Color("#4a3220"))
				Spr.rect(x, 494, 12, 2, Color("#6b4a2c"))
				Spr.circle(x + 6, 497, 1.2, Color(.6, .6, .62))
			x += 18
		# trilho de ferro: escuro embaixo, brilho em cima, emendas com chapas e rebites
		var ra: float = max(rx0, cam - 10)
		Spr.rect(ra, 491, xb - ra, 5, Color("#4c5058"))
		Spr.rect(ra, 491, xb - ra, 1.5, Color("#c9ced6"))
		var jx: float = floor(ra / 144.0) * 144.0
		while jx < xb:
			if jx > ra:
				Spr.rr(jx - 5, 489, 10, 8, 2, Color("#5e626a"))
				Spr.circle(jx - 2, 493, 1, Color(.85, .85, .9))
				Spr.circle(jx + 2, 493, 1, Color(.85, .85, .9))
			jx += 144
		var gx: float = g.DOOR.x - 60
		if g.L.door.get("kind", "") == "vault":
			if gx > cam - 300 and gx < cam + g.W + 300:
				_vault(g.DOOR.x + 30, 500)
		elif g.L.door.get("kind", "") == "exit":
			# saída do túnel: o luar entrando por uma abertura na rocha
			var ex: float = g.DOOR.x
			if ex > cam - 300 and ex < cam + g.W + 300:
				Spr.rect(ex - 90, 120, 300, 382, Color("#2a1d14"))
				for st in 9:
					Spr.ellipse(ex - 90, 140 + st * 42, 16, 24, Color("#3a2a1c"))
					Spr.ellipse(ex + 210, 150 + st * 42, 16, 24, Color("#3a2a1c"))
				Spr.rr(ex - 10, 330, 120, 172, 50, Color("#1a2a44"))
				Spr.rr(ex, 342, 100, 160, 44, Color("#3a5a86"))
				Spr.circle(ex + 66, 380, 12, Color(.95, .95, .85))
				for st in 5:
					Spr.circle(ex + 14 + st * 19, 360 + (st * 37) % 50, 1.4, Color(1, 1, 1, .8))
				Spr.glow(ex + 50, 430, 120, Color(.6, .75, 1, .25))
		elif gx > cam - 300 and gx < cam + g.W + 300:
			Spr.A("mi_cart_full", gx - 70, 502, .8)
			if g.VIL and g.VIL.go and not g.VIL.gone:
				Spr.AB("mi_door_open", gx, 500 - 221, 230, 221)
			else:
				Spr.AB("mi_door_closed", gx + 11, 500 - 207, 210, 207)
	# portão da comporta e parede escura do túnel
	for s in g.SOL:
		if s.t == "barrier":
			Spr.hgrad(s.x - 30, s.y - 20, 50, s.h + 20, Color(0, 0, 0, 0), Color(0, 0, 0, .95))

func _climb(g: Game) -> void:
	for z in g.CLIMB:
		if z.x + z.w < g.cam - 200 or z.x > g.cam + g.W + 200:
			continue
		if z.kind == "ladder":
			Spr.PV("ladder", z.x + z.w / 2 - 20, z.y - 4, 40, z.h + 4)
		elif z.kind == "net":
			Spr.strip_v("o_net", z.x - 3, z.y, z.w + 6, z.h)
		else:
			# corda trançada pintada, balançando de leve
			Spr.save()
			Spr.translate(sin(T * .04 + z.x) * 1.5, 0)
			Spr.PV("rope", z.x + z.w / 2 - 6, z.y, 12, z.h)
			Spr.restore()

func _locks(g: Game) -> void:
	for l in g.LOCKS:
		if l.kind == "hook":
			Spr.ellipse(l.ring[0] - 15, l.ring[1] + 41, 34, 6, Color(0, 0, 0, .28))
			Spr.P("rock_ring", l.ring[0] - 15, l.ring[1] + 43, 72)
			if l.done:
				Spr.A("it_gancho", l.ring[0], l.ring[1] + 4, .32)
		elif l.kind == "dam":
			# a comporta sobe enquanto o Tomé gira a manivela
			var lift: float = 0.0 if l.done else float(l.get("turn", 0.0)) * 70.0
			Spr.A("sw_gate_open" if l.done else "sw_gate", l.x + l.w + 25, 503 - lift, 1)
			if l.done or g.has_item(l.need) or float(l.get("turn", 0.0)) > 0.0:
				crank_post(l.x - 10, 500, float(l.get("turn", 0.0)) * TAU * 3.0 if not l.done else 0.0, T)
		if not l.done and g.player.nearL == l:
			var b := sin(T * .15) * 3
			var um: String = g.use_mode()
			var lbl: String = {"bag": "JUNTE NA MOCHILA", "check": "✔ USAR", "crank": "↻ GIRE A MANIVELA"}.get(um, "✦ USAR" if g.has_item(l.need) else "?")
			Spr.text(lbl, l.x + l.w / 2, l.y - 14 + b, 18, Color("#ffecaa"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 4)
	# portas de manivela
	for c in g.CRANKS:
		if float(c.x) < g.cam - 200 or float(c.x) > g.cam + g.W + 200:
			continue
		crank_post(float(c.x), float(c.y), float(c.turn) * TAU * 3.0, T)

## poste com engrenagem e a manivela girando (ângulo a)
static func crank_post(x: float, gy: float, a: float, T: int) -> void:
	if Spr.has("p_crankpost") and Spr.has("p_crankarm"):
		# poste de madeira com a engrenagem (pintado) e a manivela girando em volta do eixo
		var rp: Array = Spr.AR["p_crankpost"]
		var k: float = 72.0 / rp[3]
		var pw: float = rp[2] * k
		var left: float = x - pw * .52
		var top: float = gy + 3 - rp[3] * k
		Spr.PR("crankpost", left, top, pw, rp[3] * k)
		# centro da engrenagem na pintura: (237, 275) de 455x696
		var hub := Vector2(left + 237.0 / 455.0 * pw, top + 275.0 / 696.0 * rp[3] * k)
		var ra: Array = Spr.AR["p_crankarm"]
		var ka: float = 62.0 / ra[2]
		Spr.save()
		Spr.translate(hub.x, hub.y)
		Spr.rotate(a)
		Spr.PR("crankarm", -37.0 / 620.0 * ra[2] * ka, -225.0 / 354.0 * ra[3] * ka, ra[2] * ka, ra[3] * ka)
		Spr.restore()
		return
	Spr.PR("stake", x - 6, gy - 70, 12, 72, Color(.85, .8, .75))
	var hub := Vector2(x, gy - 56)
	for k in 8:
		var aa: float = a * .5 + k * TAU / 8.0
		Spr.circle(hub.x + cos(aa) * 15, hub.y + sin(aa) * 15, 4, Color("#5e626a"))
	Spr.circle(hub.x, hub.y, 15, Color("#6e727a"))
	Spr.circle(hub.x, hub.y, 6, Color("#3a3c40"))
	var tip := hub + Vector2(cos(a), sin(a)) * 22
	Spr.seg(hub.x, hub.y, tip.x, tip.y, Color("#3a3c40"), 4)
	Spr.rr(tip.x - 3, tip.y - 10, 6, 12, 3, Color("#8a5e34"))



func _entrances(g: Game) -> void:
	var p: Dictionary = g.player
	for e in g.ENTR:
		if e.get("exit"):
			var cx: float = e.x + e.w / 2
			var top: float = e.y + e.h - 200
			var pts := PackedVector2Array([Vector2(cx - 18, top), Vector2(cx + 18, top), Vector2(cx + 46, e.y + e.h), Vector2(cx - 46, e.y + e.h)])
			Spr.ci.draw_polygon(pts, PackedColorArray([Color(1, .88, .59, .55), Color(1, .88, .59, .55), Color(1, .88, .59, .08), Color(1, .88, .59, .08)]))
			Spr.PV("ladder", cx - 20, top, 40, 200)
			Spr.text("⬆ SAIR", cx, e.y - 24 + sin(T * .15) * 4, 22, Color(1, .91, .66, .6 + sin(T * .12) * .35), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 4)
			continue
		var de: float = abs(p.x + p.w / 2 - (e.x + e.w / 2))
		if e.get("label", "") != "" and p.nearE != e and de < 320 and abs(p.y + p.h - (e.y + e.h)) < 80:
			Spr.text("⬇", e.x + e.w / 2, e.y - 62 + sin(T * .15) * 6, 34, Color(1, .93, .67, .55 + sin(T * .12) * .35), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 5)
		if p.nearE == e:
			Spr.text("↓", e.x + e.w / 2, e.y - 6 + sin(T * .15) * 3, 22, Color("#ffecaa"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 4)

func _lily_mud(g: Game) -> void:
	for p in g.LILY:
		if p.st == 2:
			continue
		Spr.ABb("sw_lily_sink" if (p.t > 25 or p.st == 1) else "sw_lily", p.x + p.w / 2, p.y + 22, p.w + 16)
	for m in g.MUD:
		Spr.strip_at("sw_mud", m.x, m.x, m.x + m.w, m.y - 8, 22)

func _vine(v: Dictionary) -> void:
	# cipó flexível: curva com o embalo (a ponta fica para trás) e enverga quando o Tomé agarra
	var p: Dictionary = game.player
	var held: bool = p.vine == v
	var r: float = p.vr if held else v.len
	var pts := PackedVector2Array()
	var dir := Vector2(sin(v.th), cos(v.th))
	var nrm := Vector2(dir.y, -dir.x)
	var bow: float = -v.om * r * 1.4 + v.get("bend", 0.0) * 7.0 * sin(T * .45)
	var N := 14
	for i in N + 1:
		var u := i / float(N)
		var q: Vector2 = Vector2(v.x, v.y) + dir * r * u + nrm * bow * sin(u * PI) * (1.0 if held else u)
		pts.push_back(q)
	# pedaço que sobra abaixo das mãos fica balançando solto
	if held and v.len - r > 6:
		var end: Vector2 = pts[N]
		var a2: float = v.th * .55 - v.om * 5.0
		var d2 := Vector2(sin(a2), cos(a2))
		for i in range(1, 7):
			var u2 := i / 6.0
			pts.push_back(end + d2 * (v.len - r) * u2 + Vector2(sin(T * .07 + u2 * 3) * 2 * u2, 0))
	# cipó pintado (folhas e nós da arte) seguindo a curva: um pedaço da textura em cada trecho
	var r_ = Spr.AR.get("p_vine")
	if r_ != null:
		var tex: Texture2D = Spr.atlas_tex(r_)
		var vw: float = 16.0
		var th: float = vw * r_[3] / r_[2]
		var acc := 0.0
		for i in range(1, pts.size()):
			var a: Vector2 = pts[i - 1]
			var b: Vector2 = pts[i]
			var L2: float = a.distance_to(b)
			if L2 < .5:
				continue
			var v0: float = fmod(acc, th) / th
			var v1: float = v0 + L2 / th
			Spr.save()
			Spr.translate(a.x, a.y)
			Spr.rotate(atan2(b.y - a.y, b.x - a.x) - PI / 2)
			var sy0: float = r_[1] + r_[3] * v0
			var sh_: float = r_[3] * min(1.0 - v0, v1 - v0)
			Spr.ci.draw_texture_rect_region(tex, Rect2(-vw / 2, 0, vw, L2 + .8), Rect2(r_[0], sy0, r_[2], max(1.0, sh_)), Color(1, 1, 1, Spr.alpha))
			Spr.restore()
			acc += L2
	# o cipó continua subindo até as copas (não fica pendurado no nada)
	Spr.PV("vine", v.x - 8, v.y - 520, 16, 522)

func _glow_mush(x: float, y: float, t: int) -> void:
	Spr.glow(x, y - 34, 70, Color(.47, .78, 1, .35))
	Spr.A("mu_1" if t > 5 else ("mu_2" if t > 0 else "mu_0"), x, y + 2, 1)

func _campfire(c: Dictionary) -> void:
	if c.has("rest"):
		# fogueira grande: troncos de assento dos dois lados e fogo alto, sempre acesa (chama o Tomé)
		Spr.glow(c.x, c.y - 30, 110 + sin(T * .2) * 6, Color(1, .7, .3, .4))
		for lx in c.get("seats", []):
			var sx: float = sign(lx - c.x)
			Spr.ellipse(lx, c.y + 1, 40, 5, Color(0, 0, 0, .3))
			Spr.rr(lx - 36, c.y - 15, 72, 16, 8, Color("#3a2414"))
			Spr.rr(lx - 34, c.y - 14, 68, 13, 7, Color("#8a5a32"))
			Spr.seg(lx - 24, c.y - 9, lx + 14, c.y - 9, Color("#5a3820"), 2)
			Spr.ellipse(lx + sx * 32, c.y - 7, 5, 7, Color("#d8b07a"))
			Spr.ring(lx + sx * 32, c.y - 7, 3, Color("#8a5a32"), 1.5)
		if T % 3 == 0:
			game.PARTS.append({"x": c.x + (randf() - .5) * 24, "y": c.y - 40, "vx": (randf() - .5) * .8, "vy": -1.8, "life": 28, "col": Color("#ffcf6a"), "ember": true})
		Spr.A("o_fire_on", c.x, c.y + 4, 1.25)
		if not game.RESTED.has(c.rest) and (T / 20) % 2 == 0:
			Spr.text("▼", c.x, c.y - 100 + sin(T * .1) * 4, 20, Color("#ffe0a0"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 4)
		return
	if c.on:
		Spr.glow(c.x, c.y - 20, 60, Color(1, .75, .35, .35))
		if T % 5 == 0:
			game.PARTS.append({"x": c.x + (randf() - .5) * 14, "y": c.y - 26, "vx": (randf() - .5) * .6, "vy": -1.4, "life": 22, "col": Color("#ffcf6a"), "ember": true})
	Spr.A("o_fire_on" if c.on else "o_fire_off", c.x, c.y + 4, .8)

func _crate(c: Dictionary) -> void:
	var o := (randf() - .5) * 4 if c.shake else 0.0
	var it: String = c.get("item", "coin")
	var w: float = c.w + 6
	Spr.ellipse(c.x + c.w / 2, c.y + c.h + 1, w * .5, 4, Color(0, 0, 0, .25))
	if it == "heart":
		# coração entalhado brilhando de leve
		Spr.glow(c.x + c.w / 2 + o, c.y + c.h / 2, c.w * .7, Color(1, .4, .4, .12 + .06 * sin(T * .08)))
		Spr.PR("crate_heart", c.x - 3 + o, c.y - 3, w, c.h + 6)
	else:
		Spr.PR("crate", c.x - 3 + o, c.y - 3, w, c.h + 6, Color(.86, .92, 1.08) if it == "armor" else Color.WHITE)
		if it == "armor":
			Spr.circle(c.x + c.w / 2 + o, c.y + c.h / 2, 7, Color(.25, .3, .4, .8))
			Spr.circle(c.x + c.w / 2 + o, c.y + c.h / 2, 5, Color(.65, .8, 1, .9))
	if c.get("item") == "heart" and game.player.hp >= Game.MAXHP:
		Spr.rect(c.x, c.y, c.w, c.h, Color(0, 0, 0, .25))

# ---------- inimigos ----------
const NO_SHADOW := {"spider": 1, "leech": 1, "plant": 1, "piranha": 1, "mole": 1}
## sombra no chão e o "susto" quando vê o Tomé chegando
func _enemy_fx_under(g: Game, e: Dictionary, eo: Vector2) -> void:
	if e.dead:
		return
	if not Game.FLY.has(e.k) and not NO_SHADOW.has(e.k):
		Spr.ellipse(e.x + eo.x, e.y + 3, 24, 4.5, Color(0, 0, 0, .24))
	if not e.has("seen"):
		var p: Dictionary = g.player
		if abs(p.x + p.w / 2 - e.x) < 300 and abs(p.y + p.h - e.y) < 180:
			e.seen = true
			e.startT = g.T

const OUT8 := [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1), Vector2(.7, .7), Vector2(-.7, .7), Vector2(.7, -.7), Vector2(-.7, -.7)]
## estados em que o bicho começa um ataque (aparece o "!" vermelho antes)
const ATK := {"crow": [5], "squirrel": [1], "spider": [1], "bat": [1], "owl": [1], "mole": [2]}
## nomes para a dica do primeiro encontro
const EN_NAME := {"crow": "Corvo", "bat": "Morcego", "fly": "Mosca", "spider": "Aranha", "squirrel": "Esquilo bravo",
	"frog": "Sapo", "piranha": "Piranha", "leech": "Sanguessuga", "boar": "Javali", "owl": "Coruja brava", "mole": "Toupeira"}
## olhos vermelhos brilhando (posição na arte de cada bicho, olhando para a direita)
const EYES := {"crow": [Vector2(17, -13)], "squirrel": [Vector2(28, -25)], "bat": [Vector2(8, 5), Vector2(13, 5)],
	"spider": [Vector2(-3, 3), Vector2(3, 3)], "fly": [Vector2(13, 2)], "frog": [Vector2(-5, -38), Vector2(6, -38)], "boar": [Vector2(25, -28)],
	"piranha": [Vector2(13, -8)]}

func _enemy_eyes(e: Dictionary) -> void:
	var ey: Array = EYES.get(e.k, [])
	if ey.is_empty() or (e.k == "bat" and e.get("st", 0) == 0):
		return
	var f: float = 1.0 if e.dir > 0 else -1.0
	var b: float = .75 + .25 * sin(T * .2 + e.x)
	var oy: float = e.get("eyeY", 0.0)
	for v in ey:
		var x: float = e.x + v.x * f
		var y: float = e.y + v.y + oy
		Spr.glow(x, y, 9, Color(1, .1, .05, .55 * b))
		Spr.circle(x, y, 2.4, Color(1, .2, .1, b))
		Spr.circle(x - .6, y - .6, .9, Color(1, .9, .8, b))

## "!" vermelho (viu o Tomé / vai atacar) e estrelinhas girando quando está tonto
func _enemy_fx_over(g: Game, e: Dictionary, eo: Vector2, hop_u: float) -> void:
	if e.dead:
		return
	var hx: float = e.x + eo.x
	var hy: float = e.y + eo.y - (34 if not Game.FLY.has(e.k) else 30)
	# primeiro encontro com cada tipo de inimigo: dica curta dizendo que ele é perigoso
	if e.get("seen") and not g.en_seen.has(e.k) and EN_NAME.has(e.k):
		g.en_seen[e.k] = true
		g.flash("%s: inimigo (olhos e contorno vermelhos). Pule na cabeça ou use a picareta." % EN_NAME[e.k], 170)
	var s: int = e.get("st", 0)
	if s != e.get("pst", 0) and ATK.get(e.k, []).has(s):
		e.warnT = 34
	e.pst = s
	if e.get("charge") and not e.get("pch"):
		e.warnT = 34
	e.pch = e.get("charge", false)
	if e.k == "frog":
		var jt: int = int(e.get("jt", 0)) % 130
		var pp: Dictionary = g.player
		if jt >= 74 and jt < 100 and abs(pp.x - e.x) < 320:
			e.warnT = max(e.get("warnT", 0), 2)
	var wt: int = e.get("warnT", 0)
	if wt > 0:
		e.warnT = wt - 1
		var k: float = min(1.0, wt / 8.0)
		var sc: float = 1.0 + .25 * sin(wt * .5)
		Spr.text("!", hx, hy - 24, int(28 * sc), Color(1, .2, .12, k), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 5, Color(.25, 0, 0, k * .9))
	elif hop_u >= 0 and hop_u < 1.6:
		var a: float = clamp(1.6 - hop_u, 0, 1)
		Spr.text("!", hx, hy - 22 - sin(min(hop_u, 1.0) * PI) * 12, 26, Color(1, .25, .15, a), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 5, Color(.25, 0, 0, a * .9))
	if e.get("stun", 0) > 0:
		dizzy(hx, hy - 8, T)

## estrelinhas de tontura girando em volta da cabeça (inimigos e chefes)
static func dizzy(x: float, y: float, t: int) -> void:
	for i in 3:
		var a: float = t * .12 + TAU * i / 3.0
		var sx: float = x + cos(a) * 20
		var sy: float = y + sin(a) * 6
		var s: float = 4.5 + sin(a) * 1.2
		var pts := PackedVector2Array()
		for k in 10:
			var r: float = s if k % 2 == 0 else s * .45
			var aa: float = -PI / 2 + TAU * k / 10.0 + t * .05
			pts.push_back(Vector2(sx + cos(aa) * r, sy + sin(aa) * r))
		Spr.poly(pts, Color(1, .9, .3, .95))
## corpo vivo dos bichos (como nos filmes 3D): inclina na direção em que acelera, respira parado,
## achata antes do bote do javali e se inclina nas curvas de quem voa
func _enemy_body(e: Dictionary, dist: float) -> void:
	var vx: float = e.x - float(e.get("_pbx", e.x))
	e._pbx = e.x
	var fly: bool = Game.FLY.has(e.k) or e.k in ["crow", "bat", "owl", "piranha"]
	var tl: float = clamp(vx * (.05 if fly else .035), -.12, .12)
	e._ln = lerp(float(e.get("_ln", 0.0)), tl, .12)
	var w: int = int(e.get("wind", 0))
	if w > 0:
		# antecipação do bote: abaixa e joga o peso para trás
		var u: float = sin((16 - w) / 16.0 * PI)
		Spr.rotate(-e.dir * .1 * u)
		Spr.scale(1.0 + .07 * u, 1.0 - .1 * u)
		return
	Spr.rotate(e._ln)
	var lt: int = int(e.get("landT", 0)) if e.k != "frog" else 0
	if lt > 0:
		Spr.scale(1.0 + .16 * lt / 10.0, 1.0 - .2 * lt / 10.0)
	elif e.get("leap") and e.k != "frog":
		Spr.scale(.94, 1.07)
	if abs(vx) < .2 and not fly:
		Spr.scale(1.0 - sin(T * .08 + e.x) * .008, 1.0 + sin(T * .08 + e.x) * .016)

func _enemy(e: Dictionary) -> void:
	Spr.save()
	if e.dead:
		Spr.alpha = clamp(1 - (e.dead - 24) / 14.0, 0, 1) if e.dk == "flat" else clamp(1 - (e.dead - 34) / 16.0, 0, 1)
	var dist: float = e.get("_dd", 0.0)
	var fs: float = e.get("_fs", 1.0 if e.dir > 0 else -1.0)
	Spr.translate(e.x, e.y)
	if not e.dead:
		_enemy_body(e, dist)
	Spr.scale(Spr.turnw(fs) if not e.dead else (1.0 if e.dir > 0 else -1.0), 1)
	if e.dead:
		if e.dk == "flat":
			var q: float = min(1, e.dead / 4.0)
			Spr.scale(1 + .3 * q, 1 - .62 * q)
		else:
			Spr.translate(0, e.ddy)
			var m := 0.0 if Game.FLY.has(e.k) else -15.0
			Spr.translate(0, m)
			Spr.rotate(min(PI, e.dead * .25))
			Spr.translate(0, -m)
	elif not Game.FLY.has(e.k) and not e.k in ["spider", "mole", "frog", "plant", "leech"]:
		# sobe-e-desce do passo, só quando anda (parado fica no chão, respirando);
		# no quadro de apoio o corpo achata um tiquinho e estica no impulso
		var ph: float = sin(dist * .14)
		Spr.translate(0, -abs(ph) * 1.6)
		Spr.scale(1.0 - abs(ph) * .015, 1.0 + (abs(ph) - .5) * .03)
	match e.k:
		"frog":
			if e.dead:
				Spr.A("en_frog_dead", 0, 3, .9)
			elif Spr.tex.has("en_frog2"):
				# respira (papo inflando), pisca de vez em quando, agacha antes do pulo e estica no ar
				var jt: int = int(e.get("jt", 0)) % 130
				var ff: int = (T / 22) % 2
				if (T + int(e.x)) % 150 < 7:
					ff = 2
				if jt >= 86 and jt < 100:
					ff = 3
				if e.leap:
					ff = 4
				# estica no salto (subindo), achata ao cair no chão, papo respira parado
				var fsq := 1.0
				var lt: int = jt - 100
				if e.leap:
					fsq = 1.0 + .12 * cos(clamp(lt / 30.0, 0, 1) * PI)
				elif jt < 8:
					fsq = 1.0 - .18 * (1.0 - jt / 8.0)
				elif jt >= 86:
					fsq = 1.0 - .1 * sin(clamp((jt - 86) / 14.0, 0, 1) * PI * .5)
				else:
					fsq = 1.0 + sin(T * .09 + e.x) * .015
				Spr.scale(1.0 / sqrt(fsq), fsq)
				if ff <= 1:
					Spr.frame_seq(Spr.tex.en_frog2, [0, 1], T / 22.0, 130, 70, 65, 68, 0, 3, .82)
				else:
					Spr.frame(Spr.tex.en_frog2, ff, 130, 70, 65, 68, 0, 3, .82)
			else:
				Spr.A("en_frog_jump" if e.leap else "en_frog", 0, 3, .9 if e.leap else .82 + sin(T * .12) * .02)
		"fly":
			Spr.P_cycle("fly", ["fly0", "fly1"], T / 2.0, 0, 0, 40, false, Color.WHITE, true)
		"owl":
			if e.dead:
				Spr.A("en_owl_dead", 0, 22, .9)
			elif e.get("st", 0) == 0:
				Spr.A("en_owl", 0, 24, .9)
			elif e.st == 1:
				Spr.A("en_owl_dive" if e.t < 34 else "en_owl_atk", 0, 0, .95)
			else:
				Spr.A_cycle("en_owl", ["en_owl1", "en_owl2"], T / 7.0 + 1.0, 0, 0, .95)
		"bat":
			WorldExtras.bat(e, T)
		"spider":
			WorldExtras.spider(e, T)
		"mole":
			WorldExtras.mole(e, T)
		"plant":
			WorldTraps.plant(e, T)
		"squirrel":
			WorldNature.squirrel(e, T)
		"crow":
			WorldNature.crow(e, T)
		"piranha":
			WorldNature.piranha(e, T)
		"leech":
			Spr.A("en_puddle", 0, 6, .9)
			if e.dead:
				WorldExtras._pc("leech0", 0, 2, 36)
			else:
				var t: int = int(e.get("lt", 0)) % 200
				if t >= 90:
					# sai da poça encolhida e se estica para pegar
					var up: bool = t >= 110 and t < 180
					WorldExtras._pc("leech1" if not up else "leech0", 0, -6 if up else 0, 34 if not up else 42)
		_:
			# javali
			var fr: int
			if e.dead or e.stun:
				fr = 6
			elif e.get("charge"):
				fr = 5
			else:
				fr = [0, 1, 2, 3][(T / 8) % 4]
			if fr < 4 and Spr.tex.has("en_boar"):
				# andando: 6 quadros novos, pernas alternando, com transição entre um quadro e outro
				Spr.frame_mix(Spr.tex.en_boar, dist / 6.6, 6, 0, 210, 140, 105, 136, 0, 3, .46)
			else:
				Spr.frame(Spr.tex.javali, fr, 210, 140, 105, 136, 0, 3, .46)
	Spr.restore()

# ---------- cavalo e trilha da cavalgada ----------
const RS := .58   # escala das folhas da cavalgada (quadros 260x250, chão em 244)

func _ride_world(g: Game) -> void:
	var RD: Ride = g.RD
	if RD == null or RD.H.is_empty():
		return
	var x0: float = g.cam - 160
	var x1: float = g.cam + g.W + 160
	for o in RD.OBS:
		if o.x > x1 or o.x + 160 < x0:
			continue
		# marca de cascos na neve: o melhor ponto para saltar
		var cx: float = Ride.obs_center(o)
		if cx > 0 and not o.hit and (RD.riding or RD.H.st == "trapped"):
			var tx: float = RD.takeoff_x(o)
			var pa: float = .45 + .25 * sin(T * .12 + o.x)
			Spr.glow(tx, 497, 22, Color(.75, .9, 1, .25 * pa))
			for k in 2:
				var hxk: float = tx - 7 + k * 14
				Spr.ellipse(hxk, 498, 5, 2.5, Color(.35, .45, .6, .55 + pa * .3))
				Spr.ring(hxk, 497.5, 4, Color(.3, .38, .5, .6), 1.2, PI, TAU)
		match o.k:
			"log":
				WorldVehicles._hlog(o.x + 2, o.x + 62, 474, 26)
				Spr.P("logend0", o.x + 62, 501, 26)
				Spr.ellipse(o.x + 32, 474, 30, 5, Color(.97, .98, 1))
			"rock":
				Spr.P("rock0", o.x + 30, 504, 58)
				Spr.ellipse(o.x + 28, 466, 18, 5, Color(.97, .98, 1))
			"fence":
				# cerquinha de madeira: dois mourões e duas travessas, neve em cima
				for px2 in [o.x + 14.0, o.x + 46.0]:
					Spr.PR("stake", px2 - 6, 456, 12, 46, Color(.85, .8, .75))
				WorldVehicles._hlog(o.x + 4, o.x + 58, 466, 8)
				WorldVehicles._hlog(o.x + 4, o.x + 58, 482, 8)
				Spr.ellipse(o.x + 14, 457, 7, 3, Color(.97, .98, 1))
				Spr.ellipse(o.x + 46, 457, 7, 3, Color(.97, .98, 1))
			"gap":
				# riacho gelado: água escura correndo, placas de gelo e margens de neve com pedras
				var gw: float = o.w
				if Spr.has("p_riacho"):
					# riacho pintado: a água (36% do meio da pintura) cobre o vão
					var rk: float = (gw + 24.0) / 421.0
					var aw: float = 680.0 * rk
					var ah: float = 290.0 * rk
					var rcx: float = o.x + gw / 2.0
					Spr.PR("riacho", rcx - aw * .511, 499.0 - 40.0 * rk, aw, ah)
					# brilhos da correnteza
					for k in 3:
						var wx: float = o.x + 8 + fposmod(T * 1.2 + k * 37.0, gw - 16)
						Spr.seg(wx, 516 + k * 6, wx + 8, 516 + k * 6, Color(.8, .92, 1, .5), 1.5)
					continue
				Spr.vgrad(o.x, 470, gw, 30, Color("#5f9cc4"), Color("#24506e"))
				Spr.vgrad(o.x, 500, gw, 160, Color("#163a52"), Color("#04090f"))
				Spr.rect(o.x, 470, gw, 3, Color(.85, .95, 1, .8))
				for k in 4:
					var wx: float = o.x + fposmod(T * 1.4 + k * 31.0, gw - 20) + 4
					Spr.line(PackedVector2Array([Vector2(wx, 482 + k * 5), Vector2(wx + 7, 480 + k * 5), Vector2(wx + 14, 482 + k * 5)]), Color(.6, .8, .95, .5), 1.5)
				for k in 2:
					var fx: float = o.x + 18 + k * (gw - 56)
					var bob: float = sin(T * .08 + k * 2.0) * 1.5
					Spr.poly(PackedVector2Array([Vector2(fx, 476 + bob), Vector2(fx + 22, 473 + bob), Vector2(fx + 28, 479 + bob), Vector2(fx + 4, 482 + bob)]), Color(.85, .94, 1, .95))
				for sd in [0, 1]:
					var ex: float = o.x if sd == 0 else o.x + gw
					var dr: float = 1.0 if sd == 0 else -1.0
					Spr.poly(PackedVector2Array([Vector2(ex - dr * 14, 466), Vector2(ex + dr * 10, 468), Vector2(ex + dr * 6, 482), Vector2(ex - dr * 14, 488)]), Color(.8, .92, 1))
					Spr.P("peb%d" % sd, ex + dr * 4, 492, 18, sd == 1, 0.0, Color(.8, .85, .95))
					Spr.ellipse(ex, 465, 18, 6, Color(.97, .98, 1))
			"branch":
				# árvore com neve do lado de lá e um galho baixo cheio de neve por cima da trilha
				WorldNature.prop("arvore_neve", o.x + 130, 504, 300)
				WorldNature.prop("galho_neve", o.x + 73, 504, 130, true)
			"rope":
				for px3 in [o.x - 4.0, o.x + 88.0]:
					Spr.PR("stake", px3 - 6, 360, 12, 142, Color(.85, .8, .75))
				Spr.seg(o.x - 4, 380, o.x + 88, 384, Color("#7a5a32"), 4)
				Spr.seg(o.x - 4, 380, o.x + 88, 384, Color("#d4ae74"), 2)
				for k in 4:
					Spr.poly(PackedVector2Array([Vector2(o.x + 8 + k * 20, 383), Vector2(o.x + 14 + k * 20, 395), Vector2(o.x + 20 + k * 20, 383)]), [Color("#e0463a"), Color("#f0c040"), Color("#3a8ad0"), Color("#5ab04a")][k])
	var H: Dictionary = RD.H
	if RD.riding:
		return
	var ft := Spr.opt("horse_free")
	match H.st:
		"trapped", "free":
			var fr := 1
			if H.st == "trapped":
				# preso: fica de cabeça baixa e de vez em quando empina puxando o arame
				fr = 0 if (T % 220) < 50 else 1
				Spr.text("!", H.x - 20, H.y - 150 + sin(T * .2) * 3, 26, Color("#ffecaa"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 4)
			else:
				fr = 0 if (H.t > 90 and H.t < 130) else 2
			Spr.ellipse(H.x, H.y + 2, 60, 7, Color(0, 0, 0, .22))
			if ft:
				Spr.frame(ft, fr, 260, 250, 130, 244, H.x, H.y + 3, RS, true)
		"gone":
			Spr.ellipse(H.hx, 502, 60, 7, Color(0, 0, 0, .22))
			if ft:
				Spr.frame(ft, 3, 260, 250, 130, 244, H.hx, 503, RS, true)

var _hpitch := 0.0
func _rider(g: Game) -> void:
	var RD: Ride = g.RD
	var p: Dictionary = g.player
	if p.iframe > 0 and (T / 4) % 2 == 0:
		Spr.alpha = .55
	var gt := Spr.opt("ride_gallop")
	var jt := Spr.opt("ride_jump")
	var dt := Spr.opt("ride_dis")
	if RD.endT >= 0:
		# desmontando (cena curta): o cavalo parado e o Tomé descendo
		Spr.ellipse(RD.hx, 502, 62, 7, Color(0, 0, 0, .22))
		var df: int = 0 if RD.endT < 50 else (1 if RD.endT < 95 else 2)
		if dt:
			Spr.frame(dt, df, 340, 250, 130, 244, RD.hx, RD.hy + 3, RS)
		else:
			var ft := Spr.opt("horse_free")
			if ft:
				Spr.frame(ft, 2, 260, 250, 130, 244, RD.hx, RD.hy + 3, RS)
			var u: float = clamp(RD.endT / 110.0, 0, 1)
			Spr.save()
			Spr.translate(lerpf(RD.hx - 6, RD.hx - 30, u), lerpf(RD.hy - 64, RD.hy + 2, u * u))
			Spr.frame(Spr.tex.pai, 0, 170, 160, 85, 156, 0, 0, .46, false)
			Spr.restore()
		Spr.alpha = 1.0
		return
	Spr.ellipse(RD.hx, 502, 62 * (1.0 - clamp((500.0 - RD.hy) / 160.0, 0, .6)), 7, Color(0, 0, 0, .22))
	Spr.save()
	Spr.translate(RD.hx, RD.hy + 3)
	if RD.stumble > 0:
		Spr.rotate(sin(T * .6) * .06)
	# no salto o cavalo empina subindo e abaixa o focinho descendo (gira em volta das patas)
	var pt: float = clamp(RD.vy * .014, -.12, .1) if RD.hy < 497.0 else 0.0
	_hpitch = lerp(_hpitch, pt, .2)
	Spr.rotate(_hpitch)
	if RD.hy < 497.0 and jt:
		var jf: int = 0 if RD.vy < -3.0 else (1 if RD.vy < 3.0 else 2)
		Spr.frame(jt, jf, 260, 250, 130, 244, 0, 0, RS)
	elif RD.duck and jt:
		# abaixado: o cavalo baixa o corpo e o Tomé deita sobre o pescoço
		Spr.scale(1.04, .86)
		Spr.frame(jt, 3, 260, 250, 130, 244, 0, 0, RS)
	elif gt:
		var gf: int = int(RD.gallop) % 8
		if RD.duck:
			Spr.translate(0, 10)
			Spr.scale(1, .9)
		if RD.hy < 497.0:
			Spr.frame(gt, 3, 260, 250, 130, 244, 0, 0, RS)
		else:
			# galope com transição entre os quadros (passada contínua)
			Spr.frame_mix(gt, RD.gallop, 8, 0, 260, 250, 130, 244, 0, 0, RS)
	Spr.restore()
	Spr.alpha = 1.0

# ---------- alavancas, contrapesos e portão de ferro da mina ----------
func _levers(g: Game) -> void:
	if not g.EV or g.EV.LV.is_empty():
		return
	var LV: Dictionary = g.EV.LV
	var G: Dictionary = g.EV.GATE
	if G.x < g.cam - 300 or G.x > g.cam + g.W + 300:
		return
	var y: float = float(LV.y)
	# portão de ferro forjado subindo entre batentes de pedra, com duas luzinhas (uma por alavanca)
	var gx: float = G.x
	var gy: float = G.y
	var ndown := 0
	for o in LV.list:
		if o.down:
			ndown += 1
	Spr.PR("wb3", gx - 16, 360, G.w + 32, 24, Color(.75, .72, .7))
	Spr.PR("gate_iron", gx - 6, gy - 10, G.w + 12, G.h + 10)
	for k in 2:
		var lit: bool = k < ndown
		var lx2: float = gx + G.w / 2 + (k - .5) * 16
		if lit:
			Spr.glow(lx2, 372, 14, Color(1, .85, .4, .6))
		Spr.circle(lx2, 372, 4, Color(1, .85, .4) if lit else Color(.25, .22, .2))
	# roldana no teto
	Spr.circle(gx + G.w / 2, 392, 9, Color("#4a4642"))
	Spr.ring(gx + G.w / 2, 392, 9, Color("#2a2622"), 2)
	var near_any: bool = false
	for lv in LV.list:
		var lx: float = float(lv.x)
		var a: float = lv.a
		var wy: float = lerpf(390, 452, a)
		# corrente da alavanca até o contrapeso e do contrapeso até a roldana do portão
		_chain(Vector2(lx, wy - 12), Vector2(lx, 384))
		_chain(Vector2(lx, 384), Vector2(gx + G.w / 2 - 8, 388))
		# contrapeso de pedra com argola
		Spr.PR("wb2", lx - 15, wy - 14, 30, 26, Color(.7, .7, .74))
		Spr.ring(lx, wy - 14, 4, Color("#5f5a55"), 2)
		# alavanca pintada na base de pedra (gira de cima para baixo ao puxar)
		Spr.save()
		Spr.translate(lx, y)
		Spr.rotate(lerpf(-.35, .9, a))
		Spr.P("lever", 0, 2, 40)
		Spr.restore()
		var near: bool = not lv.down and abs(g.player.x + g.player.w / 2 - lx) < 60
		if near:
			near_any = true
			Spr.glow(lx, y - 26, 30, Color(1, .85, .45, .25 + .15 * sin(T * .15)))
			Spr.ci.draw_texture_rect(Spr.tex.btn_use if Spr.tex.has("btn_use") else Spr.tex.pad_S, Rect2(lx - 15, y - 82 + sin(T * .12) * 3, 30, 30), false, Color(1, 1, 1, .95))
			Spr.text("PUXAR", lx, y - 40 + sin(T * .12) * 3, 13, Color("#ffecaa"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 3)

## corrente de elos de ferro entre dois pontos
func _chain(a: Vector2, b: Vector2) -> void:
	var L2: float = a.distance_to(b)
	var n: int = max(1, int(L2 / 7.0))
	for i in n:
		var p: Vector2 = a.lerp(b, (i + .5) / n)
		if i % 2 == 0:
			Spr.ellipse(p.x, p.y, 3.2, 2.2, Color("#5f5a55"), atan2(b.y - a.y, b.x - a.x))
		else:
			Spr.ellipse(p.x, p.y, 2.4, 1.2, Color("#3a3632"), atan2(b.y - a.y, b.x - a.x))

# ---------- reflexo do Tomé na água ----------
func _reflection(g: Game) -> void:
	var p: Dictionary = g.player
	if p.swim or p.dyingT > 0 or not g.WV or p.get("wpose", "") != "" or (g.VH and g.VH.active()) or (g.RD and g.RD.riding):
		return
	var px: float = p.x + p.w / 2
	var by: float = p.y + p.h
	for k in g.WV.B:
		var b: Dictionary = g.WV.B[k]
		var d: float = b.y - by
		if px < b.x0 + 10 or px > b.x1 - 10 or d < -2 or d > 150:
			continue
		var off := g.ip_off()
		var wy: float = b.y + off.y
		Spr.save()
		var a0: float = Spr.alpha
		Spr.alpha = a0 * .32 * (1.0 - d / 150.0)
		# espelha em volta da linha da água, com um tremidinho de onda
		Spr.translate(off.x + sin(T * .09) * 1.5, wy * 2.0)
		Spr.scale(1, -1)
		_player_draw(g)
		Spr.alpha = a0
		Spr.restore()
		return

# ---------- vapor da respiração no frio ----------
var puffs: Array = []
func _breath(g: Game) -> void:
	var p: Dictionary = g.player
	var cold: bool = g.AMB.get("snow", 0.0) > .2
	if cold and g.running and not p.swim and p.dyingT == 0 and not (g.VH and g.VH.active()) and not (g.RD and g.RD.riding):
		var per: int = 46 if (abs(p.vx) > 2.5 or p.get("pant", 0) > 0) else 110
		if T % per == 0 or T % per == 8:
			var off := g.ip_off()
			puffs.append({"x": p.x + p.w / 2 + p.face * 12 + off.x, "y": p.y + p.h - 44 + off.y, "vx": p.face * .5 + p.vx * .3, "t": 0})
	var keep: Array = []
	for f in puffs:
		f.t += 1
		f.x += f.vx
		f.vx *= .96
		f.y -= .25
		var u: float = f.t / 50.0
		if u < 1:
			Spr.circle(f.x, f.y, 3 + u * 9, Color(.95, .97, 1, .45 * (1 - u)))
			keep.append(f)
	puffs = keep

# ---------- o Tomé ----------
func _player(g: Game) -> void:
	if g.RD and g.RD.riding:
		_rider(g)
		return
	if g.VH and g.VH.active():
		WorldVehicles.rider(g, T)
		return
	if g.M and g.M.ctrl:
		# o jogador está com o Pipoca: o Tomé fica parado onde estava
		var real: Dictionary = g.player
		g.player = g.M.tome
		_player_draw(g)
		g.player = real
		return
	var off := g.ip_off()
	var p: Dictionary = g.player
	# fim de tarde: sombra comprida do Tomé deitada no chão
	var tw: float = g.section_weights().get("tarde", 0.0)
	if tw > 0 and p.onGround:
		var u: float = clamp((p.x - 3430.0) / 11710.0, 0, 1) * tw
		if u > .2:
			Spr.ellipse(p.x + p.w / 2 + off.x + 22 * u, p.y + p.h + 1 + off.y, 18 + 26 * u, 3.2, Color(.2, .08, .02, .22 * u))
	Spr.save()
	var gd = p.get("_g")
	var pdip: float = gd.get("dip", 0.0) if gd is Dictionary else 0.0
	Spr.translate(off.x, off.y + p.get("wdy", 0.0) + p.get("sink", 0.0) + pdip)
	var a0: float = Spr.alpha
	Spr.alpha = a0 * p.get("wal", 1.0)
	if p.get("wpose", "") != "":
		_warp_pose(p)
	else:
		_player_draw(g)
		# com o capacete de mergulho: dentro d'água o Tomé fica com ele na cabeça
		if g.NT and g.NT.helmet and p.swim and not p.get("dog") and p.dyingT == 0 and not (p.iframe > 0 and (T / 4) % 2 == 0):
			var hx: float = p.x + p.w / 2 + p.face * 3
			var hb: float = p.y + p.h - 34
			if p.crouch:
				# deitado (rastejando no fundo): a cabeça fica na frente, perto do chão
				hx = p.x + p.w / 2 + p.face * 20
				hb = p.y + p.h - 2
			WorldNature.prop("capacete", hx, hb, 46, p.face < 0)
		WorldExtras.tool_fx(g, T)
	Spr.alpha = a0
	Spr.restore()

## a Isis (fase da fuga) — arte do Gemini, isis2.png: 0-3 correndo, 4 parada, 5 pulando, 6 caindo,
## 7 ajoelhada (shh), 8 subindo escada, 9 agachada escondida, 10 pendurada, 11-12 engatinhando
const ISIS_H := 76.0
func _isis_draw(p: Dictionary) -> void:
	var cx: float = p.x + p.w / 2
	var by: float = p.y + p.h + 2
	var fr := 4
	var flip: bool = p.face < 0
	if p.get("bar"):
		fr = 10
		by = game.NT.bar_y(p.bar, cx) + ISIS_H * .66
	elif p.ladder:
		fr = 8
		flip = false
		if p.ladder.kind == "ladder":
			cx = p.ladder.x + p.ladder.w / 2
	elif not p.onGround:
		# braços para cima subindo e no começo da descida; a pose de tombo só numa queda longa
		fr = 6 if p.vy > 7.5 else 5
	elif p.crouch:
		if abs(p.vx) > .4:
			fr = 11 + int(p.anim * .5) % 2
		else:
			fr = 9 if game.VL and game.VL.hidden(p) else 7
	elif abs(p.vx) > .5:
		fr = int(p.anim * .78) % 4
	_ppos = Vector2(p.x, p.y)
	var air: float = clamp(1 - abs(p.vy) / 16.0, .35, 1) if not p.onGround else 1.0
	if fr != 10 and fr != 8:
		Spr.ellipse(cx, p.y + p.h + 1, 13 * air, 3 * air, Color(0, 0, 0, .3 * air))
	var t: Texture2D = Spr.tex.get("isis2")
	if t == null:
		return
	var s: float = ISIS_H / 150.0
	var rot := 0.0
	var st := Vector2.ONE
	if fr <= 6:
		st = _body_flex(p, "isis", fr, 4)
		rot = p.lean
		if fr < 4:
			# passada: o corpo sobe um tiquinho no quadro de apoio (1 e 3)
			st.y *= 1 + (.012 if fr % 2 == 1 else -.008) * clamp(abs(p.vx) / 4.3, 0, 1)
	elif fr == 10:
		rot = float(p.get("bsw", 0.0))
	var sq: float = p.squash
	var sx: float = (-s if flip else s) * st.x * (1 + sq * .2)
	var sy: float = s * st.y * (1 - sq * .25)
	var src := Rect2(fr * 150, 0, 150, 150)
	var dst := Rect2(-75, -150, 150, 150)
	# folha de corrida completa (assets/sprites/isis_run.png, quadros 150x150 na mesma escala), se existir
	var rt: Texture2D = Spr.opt("isis_run")
	var rn: int = int(rt.get_width() / 150) if rt else 0
	var fp2: float = p.anim * .78
	if fr < 4 and rt and rn > 0:
		t = rt
		src = Rect2((int(fp2) % rn) * 150, 0, 150, 150)
	# quadros intermediários (x4): corrida e engatinhar agachada
	var im4: Dictionary = {}
	var ifp := 0.0
	if fr < 4 and p.onGround and not p.crouch:
		im4 = Spr.x4("isis_run:0-1-2-3-4-5-6-7") if (rt and rn == 8) else Spr.x4("isis2:0-1-2-3")
		ifp = fp2 if (rt and rn == 8) else p.anim * .78
	elif fr >= 11 and fr <= 12:
		im4 = Spr.x4("isis2:11-12")
		ifp = p.anim * .5
	var ik4 := 0.0
	var isrc4 := Rect2()
	if not im4.is_empty():
		var iq: Array = Spr.x4_pos(im4, ifp)
		t = im4.tex
		src = Spr.x4_src(im4, iq[0])
		isrc4 = Spr.x4_src(im4, iq[1])
		ik4 = smoothstep(.5, 1.0, iq[2]) * .5 if iq[1] != iq[0] else 0.0
	_pose("isis%d" % (fr if fr >= 4 else 0), t, src, dst, cx, by, rot, sx, sy)
	Spr.save()
	Spr.translate(cx, by)
	Spr.rotate(rot)
	Spr.scale(sx, sy)
	Spr.ci.draw_texture_rect_region(t, dst, src, Color(1, 1, 1, Spr.alpha))
	if not im4.is_empty():
		if ik4 > .02:
			Spr.ci.draw_texture_rect_region(t, dst, isrc4, Color(1, 1, 1, Spr.alpha * ik4))
	elif fr < 4 and rt and rn > 0 and p.onGround and not p.crouch:
		var kr: float = smoothstep(.6, 1.0, fp2 - floor(fp2)) * .5
		if kr > .02:
			Spr.ci.draw_texture_rect_region(t, dst, Rect2(((int(fp2) + 1) % rn) * 150, 0, 150, 150), Color(1, 1, 1, Spr.alpha * kr))
	elif fr < 4 and p.onGround and not p.crouch:
		# só 4 quadros de corrida: perto da troca o próximo aparece por cima (movimento contínuo)
		var fp: float = p.anim * .78
		var kk: float = smoothstep(.55, 1.0, fp - floor(fp)) * .7
		if kk > .02:
			Spr.ci.draw_texture_rect_region(t, dst, Rect2(((fr + 1) % 4) * 150, 0, 150, 150), Color(1, 1, 1, Spr.alpha * kk))
	Spr.restore()

## poses da animação de entrar/sair dos esconderijos
func _warp_pose(p: Dictionary) -> void:
	var cx: float = p.x + p.w / 2
	var by: float = p.y + p.h
	match p.wpose:
		"crouch":
			Spr.A("pai_crouch", cx, by, .56, p.face < 0)
		"crawl":
			Spr.A_cycle("pai_crawl", ["pai_crawl1", "pai_crawl2", "pai_crawl3", "pai_crawl2"], T / 7.0, cx, by, .56, p.face < 0)
		"climb":
			var t3: Texture2D = Spr.tex.pai_climb
			var mv := int(p.climbA / 22) % 2
			Spr.save()
			Spr.translate(cx, by + 6)
			Spr.scale(-.56 if mv else .56, .56)
			Spr.ci.draw_texture(t3, Vector2(-t3.get_width() / 2.0, -t3.get_height()), Color(1, 1, 1, Spr.alpha))
			Spr.restore()

func _player_draw(g: Game) -> void:
	var p: Dictionary = g.player
	if p.iframe > 0 and (T / 4) % 2 == 0 and p.dyingT == 0:
		return
	if p.get("isis"):
		_isis_draw(p)
		return
	var cx: float = p.x + p.w / 2
	var by: float = p.y + p.h
	_ppos = Vector2(p.x, p.y)
	if p.lastFace != p.face:
		p.turnT = 6
		p.lastFace = p.face
	if p.turnT > 0:
		p.turnT -= 1
	var pai: Texture2D = Spr.tex.pai
	var pai2: Texture2D = Spr.tex.pai2
	# subindo na beirada: braço erguido segurando, corpo inclinado sobre a quina
	if p.get("mantleT", 0) > 0:
		var u: float = 1.0 - p.mantleT / 16.0
		Spr.save()
		Spr.translate(cx, by)
		Spr.rotate(p.face * (.25 if u > .5 else .1))
		Spr.scale(p.face * .48, .48 * (1.0 + .06 * sin(u * PI)))
		Spr.ci.draw_texture_rect_region(pai, Rect2(-85, -156, 170, 160), Rect2(4 * 170, 0, 170, 160), Color(1, 1, 1, Spr.alpha))
		Spr.restore()
		return
	if p.dyingT > 0:
		Spr.save()
		Spr.translate(cx, by - 30)
		Spr.rotate((46 - p.dyingT) * .12)
		Spr.translate(0, 30)
		Spr.frame(pai2, 8, 170, 160, 85, 156, 0, 0, .48, p.face < 0)
		Spr.restore()
		return
	# pendurado na corda esticada: mão sobre mão
	if p.get("bar"):
		# mão sobre mão: troca de mão a cada palmo; o corpo balança como um pêndulo preso às mãos
		var bt: Texture2D = Spr.tex.pai_vine_a if int(p.get("bfr", 0)) == 0 else Spr.tex.pai_vine_b
		var bax := 63.0 if bt == Spr.tex.pai_vine_a else 60.0
		var bty: float = g.NT.bar_y(p.bar, cx) + 1
		var brot: float = float(p.get("bsw", 0.0)) + sin(T * .05) * .02
		_pose("bar%d" % int(p.get("bfr", 0)), bt, Rect2(Vector2.ZERO, bt.get_size()), Rect2(Vector2(-bax, -2), bt.get_size()), cx, bty, brot, -.56 if p.face < 0 else .56, .56)
		Spr.save()
		Spr.translate(cx, bty)
		Spr.rotate(brot)
		Spr.scale(-.56 if p.face < 0 else .56, .56)
		Spr.ci.draw_texture(bt, Vector2(-bax, -2))
		Spr.restore()
		return
	# subindo: escada/rede (de costas), corda (de lado) e cipó (pendurado pela mão)
	if not (p.iframe > 40) and (p.ladder or p.vine):
		var mv := int(p.climbA / 22) % 2
		if p.vine:
			var v: Dictionary = p.vine
			var hx: float = v.x + sin(v.th) * p.vr
			var hy: float = v.y + cos(v.th) * p.vr
			# pose firme enquanto balança; a outra só quando quase parado (sem ficar trocando)
			var still: bool = p.get("vstill", false)
			if still and abs(v.om) > .012:
				still = false
			elif not still and abs(v.om) < .004:
				still = true
			p.vstill = still
			var t: Texture2D = Spr.tex.pai_vine_b if still else Spr.tex.pai_vine_a
			var ax := 63.0 if t == Spr.tex.pai_vine_a else 60.0
			_pose("vine" + str(still), t, Rect2(Vector2.ZERO, t.get_size()), Rect2(Vector2(-ax, -2), t.get_size()), hx, hy, -p.get("vang", v.th), -.56 if p.face < 0 else .56, .56)
			Spr.save()
			Spr.translate(hx, hy)
			Spr.rotate(-p.get("vang", v.th))
			Spr.scale(-.56 if p.face < 0 else .56, .56)
			Spr.ci.draw_texture(t, Vector2(-ax, -2))
			Spr.restore()
		elif p.ladder.kind == "rope":
			var t2: Texture2D = Spr.tex.pai_rope_a if mv else Spr.tex.pai_rope_b
			var rx := 46.0 if mv else 52.0
			var lx: float = p.ladder.x + p.ladder.w / 2
			_pose("rope%d" % mv, t2, Rect2(Vector2.ZERO, t2.get_size()), Rect2(Vector2(-rx, -t2.get_height()), t2.get_size()), lx, by + 4, 0.0, .56, .56)
			Spr.save()
			Spr.translate(lx, by + 4)
			Spr.scale(.56, .56)
			Spr.ci.draw_texture(t2, Vector2(-rx, -t2.get_height()))
			Spr.restore()
		else:
			var t3: Texture2D = Spr.tex.pai_climb
			var lx2: float = p.ladder.x + p.ladder.w / 2 if p.ladder.kind == "ladder" else cx
			var bob := -2.0 if mv else 0.0
			_pose("ladder%d" % mv, t3, Rect2(Vector2.ZERO, t3.get_size()), Rect2(Vector2(-t3.get_width() / 2.0, -t3.get_height()), t3.get_size()), lx2, by + 6 + bob, 0.0, -.56 if mv else .56, .56)
			Spr.save()
			Spr.translate(lx2, by + 6 + bob)
			Spr.scale(-.56 if mv else .56, .56)
			Spr.ci.draw_texture(t3, Vector2(-t3.get_width() / 2.0, -t3.get_height()))
			Spr.restore()
		_armor(p, cx, by)
		return
	# Tomé em peças com "ossos" (se as artes de assets/rig/tome existirem)
	if not (p.iframe > 40) and Rig.ready("tome"):
		var air2: float = clamp(1 - abs(p.vy) / 16.0, .3, 1) if not p.onGround else 1.0
		Spr.ellipse(cx, by + 1, 17 * air2, 4 * air2, Color(0, 0, 0, .25 * air2))
		var sqv := Vector2(1 + p.squash * .25, 1 - p.squash * .3)
		Rig.draw_pose("tome", cx, by, p.face, Rig.pose_for(p, T), sqv)
		_armor(p, cx, by)
		return
	# poses novas (atlas 2)
	if not (p.iframe > 40):
		var n := ""
		var cyk := ""
		var cyn: Array = []
		var cyf := 0.0
		if p.crouch:
			if p.slideT:
				n = "pai_slide"
			elif abs(p.vx) > .3:
				cyk = "pai_crawl"
				cyn = ["pai_crawl1", "pai_crawl2", "pai_crawl3", "pai_crawl2"]
				cyf = T / 8.0
				n = cyn[(T / 8) % 4]
			else:
				n = "pai_crouch"
		elif p.actT > 0 and p.act in ["throw1", "throw2", "gear"]:
			n = "pai_" + p.act
		elif p.actT > 0 and p.act == "swing":
			n = "pai_throw1" if p.actT > 14 else "pai_throw2"
		elif p.pushT > 0 and p.onGround:
			cyk = "pai_push"
			cyn = ["pai_push1", "pai_push2", "pai_push3"]
			cyf = T / 10.0
			n = cyn[(T / 10) % 3]
		elif p.run and p.onGround and abs(p.vx) > 3 and not Spr.anim.has("run"):
			n = "pai_run1" if int(p.anim * 1.6) % 2 else "pai_run2"
		if n != "":
			if p.onGround:
				Spr.ellipse(cx, by + 1, 18, 4, Color(0, 0, 0, .22))
			var cm: Dictionary = Spr.x4("A:" + cyk) if cyk != "" else {}
			var ar = Spr.AR.get(n)
			if not cm.is_empty():
				_pose(cyk, cm.tex, Spr.x4_src(cm, Spr.x4_pos(cm, cyf)[0]), Rect2(-float(cm.ax), -float(cm.ay), float(cm.cw), float(cm.ch)), cx, by, 0.0, -.56 if p.face < 0 else .56, .56)
			elif ar != null:
				_pose(n, Spr.atlas_tex(ar), Rect2(ar[0], ar[1], ar[2], ar[3]), Rect2(-ar[4], -ar[5], ar[2], ar[3]), cx, by, 0.0, -.56 if p.face < 0 else .56, .56)
			p.lean = lerp(float(p.get("lean", 0.0)), 0.0, .3)
			if not cm.is_empty():
				Spr.A_cycle(cyk, cyn, cyf, cx, by, .56, p.face < 0)
			else:
				Spr.A(n, cx, by, .56, p.face < 0)
			_armor(p, cx, by)
			return
	# nadando: o corpo deita na direção do nado (braçada), sobe e desce devagar; parado, fica de pé
	# batendo as pernas (sem ficar trocando entre as poses de pulo e queda)
	if p.swim and not p.crouch and not (p.iframe > 40) and Spr.anim.has("fall"):
		var sa: Dictionary = Spr.anim["fall"]
		var ssz: float = sa.s
		var sk := 78.0 / ssz
		var spd: float = Vector2(p.vx, p.vy).length()
		var mvk: float = clamp(spd / 3.0, 0, 1)
		var tgt: float = 0.0
		if abs(p.vx) > .3:
			tgt = sign(p.vx) * mvk * .95 + p.vy * .05 * sign(p.vx)
		p.swr = lerp(float(p.get("swr", 0.0)), tgt, .1)
		var stroke: float = sin(T * (.12 + mvk * .1))
		var sbob: float = sin(T * .06) * 2.0 * (1.0 - mvk)
		_ppos = Vector2(p.x, p.y)
		Spr.save()
		Spr.translate(cx, by - 30 + sbob)
		Spr.rotate(p.swr)
		Spr.scale(p.face * sk * (1 + stroke * .03 * mvk), sk * (1 - stroke * .04))
		Spr.ci.draw_texture_rect_region(sa.tex, Rect2(-ssz / 2, -ssz + 30 / sk, ssz, ssz), Rect2(0, 0, ssz, ssz), Color(1, 1, 1, Spr.alpha))
		Spr.restore()
		_armor(p, cx, by)
		return
	# animações novas (se existirem em assets/sprites/tome/)
	if not Spr.anim.is_empty() and not (p.iframe > 40) and not p.puff and not p.slam:
		var key := ""
		var f := 0
		var fnext := -1      # quadro seguinte (mistura suave entre quadros = animação mais fluida)
		var fmix := 0.0
		if not p.onGround:
			key = "jump" if p.vy < 0 else "fall"
		elif p.landT > 0:
			key = "land"
		elif abs(p.vx) > .4:
			key = "run" if p.run and Spr.anim.has("run") else "walk"
		else:
			key = _reaction(g, p)
		if Spr.anim.has(key):
			var a: Dictionary = Spr.anim[key]
			var n: int = a.n
			match key:
				"shiver":
					f = (T / 3) % n
				"lantern":
					f = (T / 40) % n
				"walk", "run":
					var ff: float = p.get("gait", p.anim * 1.2) * n / 4.0
					f = int(ff) % n
					fnext = (f + 1) % n
					fmix = ff - floor(ff)
				"idle":
					f = (T / 12) % n
					fnext = (f + 1) % n
					fmix = (T % 12) / 12.0
				"jump":
					f = int(clamp((p.vy + 12) / 12.0, 0, .999) * n)
				"fall":
					f = int(clamp(p.vy / 10.0, 0, .999) * n)
				"land":
					f = min(n - 1, int((1 - p.landT / 8.0) * n))
			var sz: float = a.s
			var k2 := 78.0 / sz
			var air3: float = clamp(1 - abs(p.vy) / 16.0, .35, 1) if not p.onGround else 1.0
			Spr.ellipse(cx, by + 1, 16 * air3, 4 * air3, Color(0, 0, 0, .25 * air3))
			var sq3: float = p.squash
			var st: Vector2 = _body_flex(p, key, f, n)
			var turn3: float = .7 + .3 * (1 - p.turnT / 6.0) if p.turnT > 0 else 1.0
			var sx3: float = p.face * k2 * (1 + sq3 * .2) * st.x * turn3
			var sy3: float = k2 * (1 - sq3 * .25) * st.y
			var src3 := Rect2(f * sz, 0, sz, sz)
			var dst3 := Rect2(-sz / 2, -sz, sz, sz)
			# quadros intermediários (x4): posição contínua dentro da animação
			var tx3: Texture2D = a.tex
			var src4 := Rect2()
			var k4 := 0.0
			var m4: Dictionary = {}
			var fp := -1.0
			match key:
				"walk", "run":
					fp = p.get("gait", p.anim * 1.2) * n / 4.0
				"shiver":
					fp = T / 3.0
				"lantern":
					fp = T / 40.0
				"jump":
					fp = clamp((p.vy + 12) / 12.0, 0, 1) * (n - 1)
				"fall":
					fp = clamp(p.vy / 10.0, 0, 1) * (n - 1)
				"land":
					fp = clamp(1 - p.landT / 8.0, 0, 1) * (n - 1)
			if fp >= 0.0:
				m4 = Spr.x4("tome/" + key + ":" + Spr.seqkey(range(n)))
			if not m4.is_empty():
				var q4: Array = Spr.x4_pos(m4, fp)
				tx3 = m4.tex
				src3 = Spr.x4_src(m4, q4[0])
				src4 = Spr.x4_src(m4, q4[1])
				k4 = smoothstep(.5, 1.0, q4[2]) * .5 if q4[1] != q4[0] else 0.0
			_pose(key, tx3, src3, dst3, cx, by, p.lean, sx3, sy3)
			Spr.save()
			Spr.translate(cx, by)
			Spr.rotate(p.lean)
			Spr.scale(sx3, sy3)
			Spr.ci.draw_texture_rect_region(tx3, dst3, src3, Color(1, 1, 1, Spr.alpha))
			if not m4.is_empty():
				if k4 > .02:
					Spr.ci.draw_texture_rect_region(tx3, dst3, src4, Color(1, 1, 1, Spr.alpha * k4))
			elif fnext >= 0 and fmix > .2:
				# mistura com o próximo quadro: o passo fica contínuo (sem "pulos" entre quadros)
				Spr.ci.draw_texture_rect_region(a.tex, dst3, Rect2(fnext * sz, 0, sz, sz), Color(1, 1, 1, Spr.alpha * smoothstep(.2, 1.0, fmix) * .55))
			Spr.restore()
			_armor(p, cx, by)
			return
	# folhas de sprites antigas (parado, andar, pulo, planar, mergulho)
	var tex := pai
	var fr := 0
	if p.iframe > 40:
		tex = pai2
		fr = 8
	elif p.puff:
		tex = pai2
		fr = [0, 1][(T / 14) % 2]
	elif p.slam:
		tex = pai2
		fr = [4, 7][(T / 6) % 2]
	elif not p.onGround:
		fr = 4 if p.vy < -3 else (6 if p.vy < 2 else 7)
	elif abs(p.vx) > .4:
		fr = [1, 2, 3, 2][int(p.anim * (1.6 if p.run else 1.2)) % 4]
	else:
		fr = 0
	# quadros intermediários (x4) dos ciclos da folha antiga
	var otex: Texture2D = tex
	var osrc := Rect2(fr * 170, 0, 170, 160)
	var om: Dictionary = {}
	var ofp := 0.0
	if p.iframe <= 40:
		if p.puff:
			om = Spr.x4("pai2:0-1")
			ofp = T / 14.0
		elif p.slam:
			om = Spr.x4("pai2:4-7")
			ofp = T / 6.0
		elif p.onGround and abs(p.vx) > .4:
			om = Spr.x4("pai:1-2-3-2")
			ofp = p.anim * (1.6 if p.run else 1.2)
	if not om.is_empty():
		otex = om.tex
		osrc = Spr.x4_src(om, Spr.x4_pos(om, ofp)[0])
	var air: float = clamp(1 - abs(p.vy) / 16.0, .3, 1)
	Spr.ellipse(cx, by + 1, 16 * air, 4 * air, Color(0, 0, 0, .25 * air))
	if p.puff:
		Spr.glow(cx, by - 30, 50, Color(1, .96, .82, .55))
	if p.run and p.onGround:
		for k in 3:
			var yy: float = by - 44 + k * 12
			Spr.seg(cx - p.face * (20 + k * 4), yy, cx - p.face * (40 + k * 6), yy, Color(.94, .9, .78, .5), 2)
	var sc := .48
	var sq: float = p.squash
	var idle := sin(T * .08) * .025 if (fr == 0 and tex == pai and p.onGround) else 0.0
	# cansado depois de correr muito: respira rápido e fundo, curvado para a frente
	var pant: float = p.get("pant", 0) / 150.0
	if pant > 0 and fr == 0 and tex == pai:
		idle = sin(T * .32) * .05 * pant - .02 * pant
	var turn: float = .65 + .35 * (1 - p.turnT / 6.0) if p.turnT > 0 else 1.0
	var rim2 := _rim(g, p)
	_body_flex(p, "old", fr, 4)
	var rot0: float = p.lean + (p.face * .06 * pant if (pant > 0 and fr == 0 and tex == pai) else 0.0)
	var sx0: float = p.face * sc * (1 + sq * .25) * turn
	var sy0: float = sc * (1 - sq * .3 + idle)
	_pose("old%d_%d" % [tex.get_instance_id(), fr], otex, osrc, Rect2(-85, -156, 170, 160), cx, by, rot0, sx0, sy0)
	for pass_i in (2 if rim2.a > 0 else 1):
		var rimp: bool = pass_i == 0 and rim2.a > 0
		Spr.save()
		Spr.translate(cx + (rim_off.x if rimp else 0.0), by + (rim_off.y if rimp else 0.0))
		Spr.rotate(rot0)
		Spr.scale(sx0, sy0)
		if rimp:
			Spr.ci.draw_texture_rect_region(Spr.sil(otex), Rect2(-85, -156, 170, 160), osrc, Color(rim2.r, rim2.g, rim2.b, rim2.a * Spr.alpha))
		else:
			if tex == pai and (abs(p.vx) > 2.2 or not p.onGround):
				_scarf(p)
			Spr.ci.draw_texture_rect_region(otex, Rect2(-85, -156, 170, 160), osrc, Color(1, 1, 1, Spr.alpha))
			if tex == pai and fr == 0:
				_blink(p)
		Spr.restore()
	_armor(p, cx, by)
	if not p.onGround and not p.vine and not p.ladder and p.airJumps > 0:
		Spr.ring(cx, by + 7, 4, Color(.92, .88, .76, .55), 1.5)

## corpo vivo: inclinação suave (acompanha a velocidade, sem tranco), esticar no pulo,
## sobe-e-desce do passo (sem tirar o pé do chão: estica/encolhe a partir da sola)
func _body_flex(p: Dictionary, key: String, f: int, n: int) -> Vector2:
	var lt: float = 0.0
	if p.onGround:
		lt = p.vx / 6.6 * (.075 if p.run else .05)
		if p.skidT > 0:
			lt = p.vx / 6.6 * .2
	else:
		lt = p.vx / 6.6 * .07 + clamp(p.vy / 13.0, -1, 1) * .025 * sign(p.vx)
	p.lean = lerp(float(p.get("lean", 0.0)), lt, .16)
	var sy: float = 1.0
	if not p.onGround and not p.vine and not p.ladder:
		if p.vy < 0:
			sy = 1 + clamp(-p.vy / 12.0, 0, 1) * .07
		else:
			sy = 1 + clamp((p.vy - 5) / 8.0, 0, 1) * .05
	elif (key == "walk" or key == "run") and n == 8:
		# quadros 1-2 e 5-6: perna de apoio esticada (corpo mais alto); 0, 3, 4, 7: pés abertos (mais baixo)
		var amp: float = clamp(abs(p.vx) / 4.3, 0, 1) * (.022 if key == "run" else .016)
		sy = 1 + amp * [-1.0, .8, 1.0, -.4, -1.0, .8, 1.0, -.4][f % 8]
	var st: float = lerp(float(p.get("flex", 1.0)), sy, .35)
	p.flex = st
	return Vector2(1 - (st - 1) * .8, st)

## troca de pose sem salto: a pose anterior some aos poucos por baixo da nova (alguns quadros)
var _pose_last := {}
var _ghost := {}
var _ghostT := 0
var _ghost_tick := -1
var _ppos := Vector2.ZERO
const GHOST_N := 5
func _pose(key: String, tex: Texture2D, src: Rect2, dst: Rect2, x: float, y: float, rot: float, sx: float, sy: float) -> void:
	if _ghost_tick != T:
		_ghost_tick = T
		if _ghostT > 0:
			_ghostT -= 1
		if _pose_last.has("key") and _pose_last.key != key and T - int(_pose_last.t) <= 2:
			_ghost = _pose_last
			_ghostT = GHOST_N
	if _ghostT > 0 and not _ghost.is_empty():
		var a: float = float(_ghostT) / (GHOST_N + 1) * .6
		Spr.save()
		Spr.translate(_ppos.x + _ghost.off.x, _ppos.y + _ghost.off.y)
		Spr.rotate(_ghost.rot)
		Spr.scale(_ghost.sx, _ghost.sy)
		Spr.ci.draw_texture_rect_region(_ghost.tex, _ghost.dst, _ghost.src, Color(1, 1, 1, a * Spr.alpha))
		Spr.restore()
	_pose_last = {"key": key, "tex": tex, "src": src, "dst": dst, "rot": rot, "sx": sx, "sy": sy, "t": T, "off": Vector2(x, y) - _ppos}

## ponta do cachecol esvoaçando para trás quando corre ou pula (atrás do corpo)
func _scarf(p: Dictionary) -> void:
	var sp: float = clamp(abs(p.vx) / 6.0, .4, 1.0)
	var pts_top := PackedVector2Array()
	var pts_bot := PackedVector2Array()
	var n := 7
	for i in n + 1:
		var u := float(i) / n
		var x: float = -18 - u * 46 * sp
		var y: float = -88 + u * (14 - sp * 10) + sin(T * .45 - u * 4.0) * 7 * u
		var wd: float = 8.0 - u * 2.0
		pts_top.push_back(Vector2(x, y - wd * .5))
		pts_bot.push_back(Vector2(x, y + wd * .5))
	# listras verdes e creme, como o cachecol do Tomé
	for i in n:
		var c := Color(.33, .55, .2) if i % 2 == 0 else Color(.93, .86, .55)
		var q := PackedVector2Array([pts_top[i], pts_top[i + 1], pts_bot[i + 1], pts_bot[i]])
		Spr.ci.draw_colored_polygon(q, Color(c.r, c.g, c.b, Spr.alpha))
	var outl := PackedVector2Array(pts_top)
	for i in range(n, -1, -1):
		outl.push_back(pts_bot[i])
	outl.push_back(pts_top[0])
	Spr.ci.draw_polyline(outl, Color(.12, .1, .05, Spr.alpha), 2.0, true)
	# franjinha na ponta
	var tip: Vector2 = (pts_top[n] + pts_bot[n]) / 2
	for k in 3:
		Spr.ci.draw_line(tip + Vector2(0, (k - 1) * 3), tip + Vector2(-6, (k - 1) * 3.5 + 1), Color(.93, .86, .55, Spr.alpha), 1.5)

## o Tomé parado reage ao mundo: cansado, olhando para cima, protegendo-se da chuva, tremendo de frio
## ou erguendo a lanterna no escuro
func _reaction(g: Game, p: Dictionary) -> String:
	if p.crouch or p.swim or p.get("act", "") != "" and p.actT > 0:
		return "idle"
	if p.get("pant", 0) > 0:
		return "tired"
	if p.lookT > 0:
		return "look"
	var it: int = p.get("idleT", 0)
	if g.get("bird_near") and it > 10:
		return "look"
	if (g.indoors() or g.AMB.dark > .5) and it > 50:
		return "lantern"
	if g.AMB.rain > .45 and not g.indoors() and it > 30:
		return "rain"
	if g.AMB.get("snow", 0.0) > .3 and it > 90:
		return "shiver"
	return "idle"

## contorno de luz: de dia vem do sol (de cima, atrás), à noite da lanterna (da frente)
var rim_off := Vector2.ZERO
func _rim(g: Game, p: Dictionary) -> Color:
	# o contorno por fora (silhueta clara atrás) deixava o Tomé com cara de papel recortado;
	# agora a luz e a sombra são feitas por dentro do desenho (scripts/depth.gdshader)
	if true:
		return Color(0, 0, 0, 0)
	if p.swim or p.dyingT > 0 or p.iframe > 40:
		return Color(0, 0, 0, 0)
	var dark: float = g.AMB.dark
	if g.L.has("under") and p.y > g.L.under:
		dark = 1.0
	if dark > .3:
		rim_off = Vector2(p.face * 1.6, -1.0)
		return Color(1, .78, .45, .55)
	rim_off = Vector2(-1.8, -1.6)
	var tw: float = g.section_weights().get("tarde", 0.0)
	return Color(1, .95, .78).lerp(Color(1, .72, .4), tw) * Color(1, 1, 1, .7)

## piscadinha: de vez em quando as pálpebras descem sobre os olhos (só na pose parada)
func _blink(p: Dictionary) -> void:
	var t: int = (T + int(p.x)) % 220
	var c: float = 0.0
	if t < 8:
		c = 1.0 - abs(t - 4) / 4.0
	elif t > 30 and t < 36 and (T / 220) % 3 == 0:
		c = 1.0 - abs(t - 33) / 3.0
	if c <= 0:
		return
	var skin := Color(.96, .69, .53)
	for e in [Vector2(5, -101), Vector2(21, -102)]:
		Spr.ci.draw_rect(Rect2(e.x - 4.5, e.y - 5, 9, 9 * c + .5), skin)
		Spr.ci.draw_line(Vector2(e.x - 4, e.y - 5 + 9 * c), Vector2(e.x + 4, e.y - 5 + 9 * c), Color(.35, .2, .15), 1.6)

func _armor(p: Dictionary, cx: float, by: float) -> void:
	if p.armor > 0:
		# escudo: um brilho quente e macio que respira, com faíscas douradas girando em volta
		var pu: float = .5 + .5 * sin(T * .07)
		Spr.glow(cx, by - 30, 44 + pu * 6, Color(1, .85, .5, .16 + pu * .08))
		for i in 6:
			var a: float = T * .045 + TAU * i / 6.0
			var r2: float = 24 + sin(T * .09 + i) * 3
			var sx: float = cx + cos(a) * r2
			var sy: float = by - 30 + sin(a) * r2 * 1.25
			var tw: float = .5 + .5 * sin(T * .2 + i * 1.7)
			Spr.glow(sx, sy, 6, Color(1, .9, .55, .35 * tw))
			Spr.circle(sx, sy, 1.3 + tw * .6, Color(1, .95, .7, .85 * tw))


## porta redonda de ferro do cofre do Vargas (fim do Episódio 2), com o V gravado
func _vault(cx: float, gy: float) -> void:
	var cy: float = gy - 118
	Spr.rect(cx - 150, gy - 250, 300, 250, Color("#3a3530"))
	for k in 6:
		Spr.rect(cx - 150 + k * 50, gy - 250, 48, 248, Color(.27 + .03 * (k % 2), .25, .23))
	Spr.circle(cx, cy, 116, Color("#1c1a18"))
	Spr.circle(cx, cy, 108, Color("#6a6e74"))
	Spr.circle(cx, cy, 96, Color("#55595f"))
	for k in 16:
		var a: float = k * TAU / 16
		Spr.circle(cx + cos(a) * 102, cy + sin(a) * 102, 4, Color("#8a8e96"))
	# o V gravado
	Spr.ci.draw_polyline(PackedVector2Array([Vector2(cx - 46, cy - 50), Vector2(cx, cy + 46), Vector2(cx + 46, cy - 50)]), Color("#2a2c30"), 16)
	Spr.ci.draw_polyline(PackedVector2Array([Vector2(cx - 46, cy - 52), Vector2(cx, cy + 42), Vector2(cx + 46, cy - 52)]), Color("#b0a070"), 6)
	# o volante
	var wx: float = cx + 70
	Spr.ring(wx, cy + 10, 20, Color("#2a2c30"), 6)
	for k in 4:
		var a2: float = k * PI / 4 + .3
		Spr.seg(wx - cos(a2) * 20, cy + 10 - sin(a2) * 20, wx + cos(a2) * 20, cy + 10 + sin(a2) * 20, Color("#2a2c30"), 4)
	Spr.circle(wx, cy + 10, 5, Color("#8a8e96"))
