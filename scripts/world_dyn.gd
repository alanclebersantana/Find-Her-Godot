extends Node2D
## Tudo o que se mexe no mundo: escadas, cadeados, vitórias-régias, vilão, caixas, inimigos,
## o Tomé, poeira e faíscas. Redesenhado a cada quadro.

var game: Game
var T := 0

func _process(_d: float) -> void:
	queue_redraw()

func _draw() -> void:
	if game == null or not game.L:
		return
	var g := game
	T = g.T
	Spr.begin(self)
	_deco(g)
	_climb(g)
	_locks(g)
	_entrances(g)
	_lily_mud(g)
	WorldExtras.chalk(g, T)
	WorldExtras.footprints(g)
	WorldExtras.crawl(g, T)
	WorldExtras.solids(g, T)
	WorldExtras.mech(g, T)
	WorldProps.draw(g, T)
	WorldExtras.boss(g, T)
	if g.VIL and g.VIL.go and not g.VIL.gone:
		var v: Dictionary = g.VIL
		var f: int = (T / max(3, int(10 - v.get("spd", 3.3)))) % 2
		Spr.A("lia_scared", v.x + 44, v.y - 58, .5)
		Spr.A("vg_cart1" if f else "vg_cart2", v.x, v.y + 2, 1)
	for v in g.VINES:
		_vine(v)
	for s in g.SPR:
		_glow_mush(s.x, s.y, s.t)
	for c in g.CHK:
		_campfire(c)
	for c in g.CR:
		if not c.dead and c.t != "push":
			_crate(c)
	for e in g.EN:
		if e.dead > 50:
			continue
		if e.x < g.cam - 200 or e.x > g.cam + g.W + 200:
			continue
		var eo := g.e_off(e)
		Spr.save()
		Spr.translate(eo.x, eo.y)
		_enemy(e)
		Spr.restore()
	WorldExtras.tocas(g, T)
	if g.M and g.M.ctrl:
		var doff := g.ip_off()
		Spr.save()
		Spr.translate(doff.x, doff.y)
		WorldExtras.dog(g, T)
		Spr.restore()
	else:
		WorldExtras.dog(g, T)
	_player(g)
	WorldExtras.grass(g, T)
	for f in g.FXS:
		Spr.A(f.n, f.x, f.y, f.sc, false, 1.0 - float(f.t) / f.life)
	for p in g.PARTS:
		var c: Color = p.col
		Spr.rect(p.x, p.y, 3, 3, Color(c.r, c.g, c.b, c.a * clamp(p.life / 24.0, 0, 1)))

# ---------- cenário com estado ----------
func _deco(g: Game) -> void:
	var cam := g.cam
	var k := 0
	for x in [4992, 5022, 5452, 5688, 6128, 6172, 6545, 6985]:
		if x > cam - 80 and x < cam + g.W + 80:
			Spr.A("sw_cattail", x, 512, .62 + (k % 3) * .1, k % 2 == 1)
		k += 1
	# mina: trilhos (com pontes sobre os buracos), carrinho parado e porta
	var rx0: float = g.L.villain.x0 - 160 if g.L.has("villain") else 9380.0
	if cam + g.W > rx0:
		var xa: float = max(rx0, floor((cam - 10) / 18) * 18)
		var xb: float = min(g.L.spanX, cam + g.W + 10)
		var x := xa
		while x < xb:
			var over_pit := false
			for pit in g.L.get("pits", []):
				if x > pit[0] and x < pit[1]:
					over_pit = true
			if over_pit:
				if int(x) % 72 < 18:
					Spr.rect(x, 495, 6, 140, Color("#2e2014"))
			else:
				Spr.rect(x, 494, 11, 7, Color("#4a3220"))
			x += 18
		Spr.rect(max(rx0, cam - 10), 491, xb - max(rx0, cam - 10), 4, Color("#8a8f98"))
		var gx: float = g.DOOR.x - 60
		if gx > cam - 300 and gx < cam + g.W + 300:
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
		if z.kind == "ladder":
			Spr.strip_v("o_ladder", z.x + z.w / 2 - 18, z.y - 4, 36, z.h + 4)
		elif z.kind == "net":
			Spr.strip_v("o_net", z.x - 3, z.y, z.w + 6, z.h)
		else:
			var pts := PackedVector2Array()
			var y: float = z.y
			while y < z.y + z.h:
				pts.push_back(Vector2(z.x + z.w / 2 + sin(y * .05 + T * .04) * 1.5, y))
				y += 12
			pts.push_back(Vector2(z.x + z.w / 2, z.y + z.h))
			Spr.line(pts, Color("#c9a26a"), 4)
			y = z.y + 8
			while y < z.y + z.h:
				Spr.seg(z.x + z.w / 2 - 3, y, z.x + z.w / 2 + 3, y + 4, Color("#8a6a42"), 2)
				y += 10

func _locks(g: Game) -> void:
	for l in g.LOCKS:
		if l.kind == "hook":
			Spr.A("o_ringrock", l.ring[0] + 2, l.ring[1] + 34, .85)
			if l.done:
				Spr.A("it_gancho", l.ring[0], l.ring[1] + 4, .32)
		elif l.kind == "dam":
			Spr.A("sw_gate_open" if l.done else "sw_gate", l.x + l.w + 25, 503, 1)
		if not l.done and g.player.nearL == l:
			var b := sin(T * .15) * 3
			Spr.text("✦ USAR" if g.has_item(l.need) else "?", l.x + l.w / 2, l.y - 14 + b, 20, Color("#ffecaa"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 4)

func _entrances(g: Game) -> void:
	var p: Dictionary = g.player
	for e in g.ENTR:
		if e.get("exit"):
			var cx: float = e.x + e.w / 2
			var top: float = e.y + e.h - 200
			var pts := PackedVector2Array([Vector2(cx - 18, top), Vector2(cx + 18, top), Vector2(cx + 46, e.y + e.h), Vector2(cx - 46, e.y + e.h)])
			Spr.ci.draw_polygon(pts, PackedColorArray([Color(1, .88, .59, .55), Color(1, .88, .59, .55), Color(1, .88, .59, .08), Color(1, .88, .59, .08)]))
			Spr.strip_v("o_ladder", cx - 17, top, 34, 200)
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
	Spr.line(pts, Color("#2f4a1c"), 6)
	Spr.line(pts, Color("#4f7a2c"), 3.5)
	for i in range(2, pts.size() - 1, 2):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i - 1]
		var t := (a - b).normalized()
		var side := 1.0 if (i / 2) % 2 == 0 else -1.0
		var lp: Vector2 = a + Vector2(t.y, -t.x) * side * 6
		Spr.ellipse(lp.x, lp.y, 7, 3.2, Color("#5c8d38"), atan2(t.y, t.x) + side * .7)
	Spr.circle(v.x, v.y, 7, Color("#3a5a24"))
	Spr.circle(v.x, v.y, 3, Color("#5c8d38"))

func _glow_mush(x: float, y: float, t: int) -> void:
	Spr.glow(x, y - 34, 70, Color(.47, .78, 1, .35))
	Spr.A("mu_1" if t > 5 else ("mu_2" if t > 0 else "mu_0"), x, y + 2, 1)

func _campfire(c: Dictionary) -> void:
	if c.on:
		Spr.glow(c.x, c.y - 20, 60, Color(1, .75, .35, .35))
		if T % 5 == 0:
			game.PARTS.append({"x": c.x + (randf() - .5) * 14, "y": c.y - 26, "vx": (randf() - .5) * .6, "vy": -1.4, "life": 22, "col": Color("#ffcf6a")})
	Spr.A("o_fire_on" if c.on else "o_fire_off", c.x, c.y + 4, .8)

func _crate(c: Dictionary) -> void:
	var o := (randf() - .5) * 4 if c.shake else 0.0
	var n: String = {"coin": "crate_coin", "armor": "crate_armor", "heart": "crate_heart"}.get(c.get("item", "coin"), "crate_coin")
	var r = Spr.AR[n]
	var w: float = c.w + 6
	var hh: float = w * r[3] / r[2]
	Spr.AB(n, c.x - 3 + o, c.y + c.h - hh, w, hh)
	if c.get("item") == "heart" and game.player.hp >= Game.MAXHP:
		Spr.rect(c.x, c.y, c.w, c.h, Color(0, 0, 0, .25))

# ---------- inimigos ----------
func _enemy(e: Dictionary) -> void:
	Spr.save()
	if e.dead:
		Spr.alpha = clamp(1 - (e.dead - 24) / 14.0, 0, 1) if e.dk == "flat" else clamp(1 - (e.dead - 34) / 16.0, 0, 1)
	Spr.translate(e.x, e.y)
	Spr.scale(1 if e.dir > 0 else -1, 1)
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
	elif not Game.FLY.has(e.k) and not e.k in ["spider", "mole"]:
		Spr.translate(0, -abs(sin(T * .3 + e.x * .01)) * 1.5)
	match e.k:
		"frog":
			if e.dead:
				Spr.A("en_frog_dead", 0, 3, .9)
			else:
				Spr.A("en_frog_jump" if e.leap else "en_frog", 0, 3, .9 if e.leap else .82 + sin(T * .12) * .02)
		"fly":
			Spr.A("en_fly_dead" if e.dead else "en_fly%d" % ((T / 3) % 5), 0, 0, .8)
		"owl":
			if e.dead:
				Spr.A("en_owl_dead", 0, 22, .9)
			elif e.get("st", 0) == 0:
				Spr.A("en_owl", 0, 24, .9)
			elif e.st == 1:
				Spr.A("en_owl_dive" if e.t < 34 else "en_owl_atk", 0, 0, .95)
			else:
				Spr.A("en_owl1" if (T / 7) % 2 else "en_owl2", 0, 0, .95)
		"bat":
			WorldExtras.bat(e, T)
		"spider":
			WorldExtras.spider(e, T)
		"mole":
			WorldExtras.mole(e, T)
		"leech":
			Spr.A("en_puddle", 0, 6, .9)
			if e.dead:
				Spr.A("en_leech_dead", 0, 2, .8)
			else:
				var t: int = int(e.get("lt", 0)) % 200
				if t >= 90:
					var n := "en_leech3" if (t < 100 or t >= 190) else ("en_leech2" if (t < 110 or t >= 180) else "en_leech1")
					Spr.A(n, 0, 2 + (sin(T * .2) * 2 if n == "en_leech1" else 0.0), .85)
		_:
			# javali
			var fr: int
			if e.dead or e.stun:
				fr = 6
			elif e.get("charge"):
				fr = 5
			else:
				fr = [0, 1, 2, 3][(T / 8) % 4]
			Spr.frame(Spr.tex.javali, fr, 210, 140, 105, 136, 0, 3, .46)
	Spr.restore()

# ---------- o Tomé ----------
func _player(g: Game) -> void:
	if g.M and g.M.ctrl:
		# o jogador está com o Pipoca: o Tomé fica parado onde estava
		var real: Dictionary = g.player
		g.player = g.M.tome
		_player_draw(g)
		g.player = real
		return
	var off := g.ip_off()
	var p: Dictionary = g.player
	Spr.save()
	Spr.translate(off.x, off.y + p.get("wdy", 0.0))
	var a0: float = Spr.alpha
	Spr.alpha = a0 * p.get("wal", 1.0)
	if p.get("wpose", "") != "":
		_warp_pose(p)
	else:
		_player_draw(g)
		WorldExtras.tool_fx(g, T)
	Spr.alpha = a0
	Spr.restore()

## poses da animação de entrar/sair dos esconderijos
func _warp_pose(p: Dictionary) -> void:
	var cx: float = p.x + p.w / 2
	var by: float = p.y + p.h
	match p.wpose:
		"crouch":
			Spr.A("pai_crouch", cx, by, .56, p.face < 0)
		"crawl":
			Spr.A(["pai_crawl1", "pai_crawl2", "pai_crawl3", "pai_crawl2"][(T / 7) % 4], cx, by, .56, p.face < 0)
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
	var cx: float = p.x + p.w / 2
	var by: float = p.y + p.h
	if p.lastFace != p.face:
		p.turnT = 6
		p.lastFace = p.face
	if p.turnT > 0:
		p.turnT -= 1
	var pai: Texture2D = Spr.tex.pai
	var pai2: Texture2D = Spr.tex.pai2
	if p.dyingT > 0:
		Spr.save()
		Spr.translate(cx, by - 30)
		Spr.rotate((46 - p.dyingT) * .12)
		Spr.translate(0, 30)
		Spr.frame(pai2, 8, 130, 160, 65, 156, 0, 0, .48, p.face < 0)
		Spr.restore()
		return
	# subindo: escada/rede (de costas), corda (de lado) e cipó (pendurado pela mão)
	if not (p.iframe > 40) and (p.ladder or p.vine):
		var mv := int(p.climbA / 22) % 2
		if p.vine:
			var v: Dictionary = p.vine
			var hx: float = v.x + sin(v.th) * p.vr
			var hy: float = v.y + cos(v.th) * p.vr
			var t: Texture2D = Spr.tex.pai_vine_a if abs(v.om) > .02 else Spr.tex.pai_vine_b
			var ax := 63.0 if t == Spr.tex.pai_vine_a else 60.0
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
			Spr.save()
			Spr.translate(lx, by + 4)
			Spr.scale(.56, .56)
			Spr.ci.draw_texture(t2, Vector2(-rx, -t2.get_height()))
			Spr.restore()
		else:
			var t3: Texture2D = Spr.tex.pai_climb
			var lx2: float = p.ladder.x + p.ladder.w / 2 if p.ladder.kind == "ladder" else cx
			var bob := -2.0 if mv else 0.0
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
		if p.crouch:
			if p.slideT:
				n = "pai_slide"
			elif abs(p.vx) > .3:
				n = ["pai_crawl1", "pai_crawl2", "pai_crawl3", "pai_crawl2"][(T / 8) % 4]
			else:
				n = "pai_crouch"
		elif p.actT > 0 and p.act in ["throw1", "throw2", "gear"]:
			n = "pai_" + p.act
		elif p.actT > 0 and p.act == "swing":
			n = "pai_throw1" if p.actT > 14 else "pai_throw2"
		elif p.onGround and abs(p.vx) < .3 and p.lookT > 10:
			n = "pai_lookup"
		elif p.pushT > 0 and p.onGround:
			n = ["pai_push1", "pai_push2", "pai_push3"][(T / 10) % 3]
		elif p.run and p.onGround and abs(p.vx) > 3:
			n = "pai_run1" if int(p.anim * 1.6) % 2 else "pai_run2"
		if n != "":
			if p.onGround:
				Spr.ellipse(cx, by + 1, 18, 4, Color(0, 0, 0, .22))
			Spr.A(n, cx, by, .56, p.face < 0)
			_armor(p, cx, by)
			return
	# animações novas (se existirem em assets/sprites/tome/)
	if not Spr.anim.is_empty() and not (p.iframe > 40) and not p.puff and not p.slam:
		var key := ""
		var f := 0
		if not p.onGround:
			key = "jump" if p.vy < 0 else "fall"
		elif p.landT > 0:
			key = "land"
		elif abs(p.vx) > .4:
			key = "run" if p.run and Spr.anim.has("run") else "walk"
		else:
			key = "idle"
		if Spr.anim.has(key):
			var a: Dictionary = Spr.anim[key]
			var n: int = a.n
			match key:
				"walk", "run":
					f = int(p.anim * (1.6 if p.run else 1.2) * n / 4.0) % n
				"idle":
					f = (T / 7) % n
				"jump":
					f = int(clamp((p.vy + 12) / 12.0, 0, .999) * n)
				"fall":
					f = int(clamp(p.vy / 10.0, 0, .999) * n)
				"land":
					f = int((1 - p.landT / 8.0) * (n - 1))
			var sz: float = a.s
			var k2 := 78.0 / sz
			Spr.ellipse(cx, by + 1, 16, 4, Color(0, 0, 0, .25 if p.onGround else .12))
			Spr.save()
			Spr.translate(cx, by)
			Spr.scale(p.face * k2, k2)
			Spr.ci.draw_texture_rect_region(a.tex, Rect2(-sz / 2, -sz, sz, sz), Rect2(f * sz, 0, sz, sz), Color(1, 1, 1, Spr.alpha))
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
	var turn: float = .65 + .35 * (1 - p.turnT / 6.0) if p.turnT > 0 else 1.0
	Spr.save()
	Spr.translate(cx, by)
	if p.skidT > 0 and p.onGround:
		Spr.rotate(-p.face * .18)
	elif p.run and p.onGround:
		Spr.rotate(p.face * .07)
	Spr.scale(p.face * sc * (1 + sq * .25) * turn, sc * (1 - sq * .3 + idle))
	Spr.ci.draw_texture_rect_region(tex, Rect2(-65, -156, 130, 160), Rect2(fr * 130, 0, 130, 160), Color(1, 1, 1, Spr.alpha))
	Spr.restore()
	_armor(p, cx, by)
	if not p.onGround and not p.vine and not p.ladder and p.airJumps > 0:
		Spr.ring(cx, by + 7, 4, Color(.92, .88, .76, .55), 1.5)

func _armor(p: Dictionary, cx: float, by: float) -> void:
	if p.armor > 0:
		var pts := PackedVector2Array()
		for i in 25:
			var a := TAU * i / 24.0
			pts.push_back(Vector2(cx + cos(a) * 26, by - 30 + sin(a) * 36))
		Spr.line(pts, Color(.78, .84, .92, .5 + sin(T * .15) * .2), 2)
