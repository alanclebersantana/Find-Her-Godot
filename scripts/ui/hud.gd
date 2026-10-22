extends Control
## HUD: corações, vidas, lápis, lápis especiais, tempo, nome da fase, desenhos, dica e avisos.

var game: Game
var hint_alpha := 0.0
var hint_txt := ""
var last_coins := -1
var coin_pop := 0.0
var last_hp := -1
var lost_heart := -1
var lost_t := 0.0

func _process(_d: float) -> void:
	queue_redraw()

func _box(x: float, y: float, w: float, h: float) -> void:
	Spr.rr(x, y, w, h, 9, Color(.04, .03, .02, .55))

func _draw() -> void:
	var __t := Time.get_ticks_usec()
	__draw_raw()
	Spr.pt("hud", __t)

func __draw_raw() -> void:
	if game == null or not game.L or not visible:
		return
	var W := size.x
	var p: Dictionary = game.player
	Spr.begin(self)
	if not game.CINE.is_empty():
		_cine(W, size.y)
		return
	var o := 40.0   # 5 corações: o resto do painel anda para a direita
	_box(8, 8, 290 + o, 40)
	# corações: batem de leve; com pouca vida o último pulsa forte; o que se perde dá um pulinho e some
	if last_hp >= 0 and p.hp < last_hp:
		lost_heart = p.hp
		lost_t = 1.0
	last_hp = p.hp
	lost_t = max(0.0, lost_t - .04)
	for i in Game.MAXHP:
		var hs := .45
		if i < p.hp:
			var beat: float = pow(max(0.0, sin(game.T * (.16 if p.hp <= 2 else .07) - i * .5)), 8.0)
			hs *= 1.0 + beat * (.22 if (p.hp <= 2 and i == p.hp - 1) else .06)
		if i == lost_heart and lost_t > 0:
			Spr.A("hud_heart_empty", 26 + i * 23, 28, .45)
			Spr.A("hud_heart_full", 26 + i * 23, 28 - (1.0 - lost_t) * 14, .45 * (1.0 + (1.0 - lost_t) * .5), false, lost_t)
			continue
		Spr.A("hud_heart_full" if i < p.hp else "hud_heart_empty", 26 + i * 23, 28, hs)
	if p.armor > 0:
		Spr.A("hud_shield", 108 + o, 28, .48)
	Spr.text("× %d" % max(0, game.lives), 122 + o, 34, 16, Color("#e6d4ac"))
	# o contador de lápis "pula" a cada lápis pego
	if last_coins >= 0 and game.coin_life != last_coins:
		coin_pop = 1.0
	last_coins = game.coin_life
	coin_pop = max(0.0, coin_pop - .07)
	var cp: float = 1.0 + sin(coin_pop * PI) * .35
	Spr.A("pen_vermelho", 179 + o, 30, .62 * 1.1 * cp)
	Spr.save()
	Spr.translate(194 + o, 34)
	Spr.scale(cp, cp)
	Spr.text("%d/100" % game.coin_life, 0, 0, 14, Color("#f0cd72").lerp(Color(1, 1, .85), coin_pop))
	Spr.restore()
	var k := 0
	for c in GameData.PEN_LIST:
		Spr.rr(240 + o + k * 8, 14, 6, 26, 2, GameData.PEN_COL[c] if game.SPECGOT.has(c) else Color(.35, .31, .25, .6))
		k += 1
	if game.X and not game.X.GOLD.is_empty() and game.X.GOLD.got:
		Spr.rr(240 + o + k * 8, 14, 6, 26, 2, Color("#ffd76a"))
	# tempo
	var s: int = max(0, int(ceil(game.time_left / 60.0)))
	var low := s <= 20
	_box(W / 2 - 52, 8, 104, 36)
	var tc := (Color("#ff7a6a") if game.T % 30 < 15 else Color("#ffd0c0")) if low else Color("#f0e0b8")
	Spr.text("%d:%02d" % [s / 60, s % 60], W / 2 + 8, 33, 20, tc, HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b if low else Spr.font)
	Spr.A("hud_clock", W / 2 - 32, 26, .42)
	# nome e desenhos
	_box(W - 250, 8, 242, 40)
	Spr.text(game.period_label(), W - 18, 33, 14, Color("#cdbfa6"), HORIZONTAL_ALIGNMENT_RIGHT, Spr.font_i)
	var nd := 0
	for d in game.DRWS:
		if d.got:
			nd += 1
	_box(W - 130, 52, 122, 28)
	Spr.A("hud_paper", W - 111, 66, .36)
	Spr.text("desenhos %d/%d" % [nd, game.DRWS.size()], W - 96, 71, 13, Color("#ffd76a") if nd == game.DRWS.size() else Color("#cdbfa6"))
	# controlando o Pipoca
	if game.M and game.M.ctrl:
		_box(8, 54, 228, 30)
		Spr.text("Controlando o PIPOCA", 20, 75, 15, Color("#ffe9a0"), HORIZONTAL_ALIGNMENT_LEFT, Spr.font_b)
	# fôlego (na água)
	var X: Extras = game.X
	if X and X.breath < Extras.BREATH:
		var n: int = int(ceil(X.breath / float(Extras.BREATH) * 8))
		_box(W / 2 - 92, 50, 184, 28)
		for i in 8:
			var on := i < n
			var bx: float = W / 2 - 74 + i * 21
			Spr.circle(bx, 64, 7, Color(.6, .85, 1, .85) if on else Color(.3, .35, .4, .4))
			if on:
				Spr.circle(bx - 2, 62, 2, Color(1, 1, 1, .8))
	# Javali-Rei
	if X and X.boss_active() and X.BOSS.st != "wait":
		var b: Dictionary = X.BOSS
		var bw := 300.0
		_box(W / 2 - bw / 2 - 10, 52, bw + 20, 40)
		Spr.text("JAVALI-REI", W / 2, 68, 13, Color("#ffcf9a"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_title)
		Spr.rr(W / 2 - bw / 2, 74, bw, 10, 5, Color(.2, .1, .08, .9))
		Spr.rr(W / 2 - bw / 2, 74, bw * b.hp / float(b.maxhp), 10, 5, Color("#e0463a"))
	# dica do lugar
	var h := game.hint_text() if game.running else ""
	if h != "":
		hint_txt = h
		hint_alpha = min(1, hint_alpha + .08)
	else:
		hint_alpha = max(0, hint_alpha - .06)
	if hint_alpha > 0 and hint_txt != "":
		# centralizada logo abaixo da faixa do topo (sem cobrir botões nem os painéis dos lados)
		var rx0 := 150.0
		var rx1: float = W - 150.0
		var cx: float = (rx0 + rx1) / 2.0
		var mw: float = min(rx1 - rx0 - 30, 560)
		var hl := _lines(hint_txt, mw, 15)
		var hw := 0.0
		for ln in hl:
			hw = max(hw, Spr.font_i.get_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x)
		var hy: float = (100.0 if (X and X.boss_active()) else 58.0) - (1.0 - hint_alpha) * 10.0
		Spr.rr(cx - hw / 2 - 14, hy, hw + 28, hl.size() * 21 + 12, 9, Color(.04, .03, .02, .55 * hint_alpha))
		_wrapped(hint_txt, cx, hy + 18, mw, 15, Color(.93, .87, .74, hint_alpha), Spr.font_i)
	# aviso (flash)
	if game.flash_t > 0 and game.flash_msg != "":
		var a: float = clamp(game.flash_t / 40.0, 0, 1)
		var lines := _lines(game.flash_msg, min(W - 80, 760), 17)
		var bh := 16 + lines.size() * 23
		var bw := 0.0
		for ln in lines:
			bw = max(bw, Spr.font.get_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x)
		bw += 36
		# aviso no alto, abaixo da dica: nunca em cima das setas e dos botões de baixo
		var by: float = (150.0 if hint_alpha > .05 else 104.0) - (1.0 - clamp(game.flash_t / 10.0, 0, 1)) * 10.0
		Spr.rr(W / 2 - bw / 2, by, bw, bh, 10, Color(.04, .03, .02, .78 * a))
		var y := by + 30
		for ln in lines:
			Spr.text(ln, W / 2, y, 17, Color(.96, .9, .78, a), HORIZONTAL_ALIGNMENT_CENTER)
			y += 23

func _lines(t: String, maxw: float, fs: int) -> Array:
	var out: Array = []
	var cur := ""
	for wd in t.split(" "):
		var test := (cur + " " + wd).strip_edges()
		if Spr.font.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > maxw and cur != "":
			out.append(cur)
			cur = wd
		else:
			cur = test
	if cur != "":
		out.append(cur)
	return out

func _wrapped(t: String, cx: float, y: float, maxw: float, fs: int, c: Color, f: Font) -> void:
	var y2 := y
	for ln in _lines(t, maxw, fs):
		Spr.text(ln, cx, y2, fs, c, HORIZONTAL_ALIGNMENT_CENTER, f)
		y2 += 21

# ---------- cena dramática: faixas de cinema, título e falas ----------
func _cine(W: float, H: float) -> void:
	var c: Dictionary = game.CINE
	var t: int = c.t
	var a: float = clamp(min(t, c.dur - t) / 18.0, 0, 1)
	var bar: float = 62 * a
	Spr.rect(0, 0, W, bar, Color(0, 0, 0, 1))
	Spr.rect(0, H - bar, W, bar, Color(0, 0, 0, 1))
	if c.title.size() == 4 and t >= c.title[0] and t < c.title[1]:
		var k: float = clamp(min(t - c.title[0], c.title[1] - t) / 14.0, 0, 1)
		var ct: String = "cena_" + {"boss": "javali", "vargas": "vargas", "cao": "cao"}.get(c.id, "")
		if Spr.tex.has(ct):
			var tx: Texture2D = Spr.tex[ct]
			var zs: float = max(W / tx.get_width(), H / tx.get_height()) * (1.0 + (t - c.title[0]) * .0012)
			var tw: float = tx.get_width() * zs
			var th: float = tx.get_height() * zs
			Spr.ci.draw_texture_rect(tx, Rect2(W / 2 - tw / 2, H / 2 - th / 2, tw, th), false, Color(1, 1, 1, k))
			Spr.rect(0, 0, W, bar, Color(0, 0, 0, 1))
			Spr.rect(0, H - bar, W, bar, Color(0, 0, 0, 1))
		var sc := 1.0 + (1.0 - k) * .25
		var y := H * .34
		Spr.save()
		Spr.translate(W / 2, y)
		Spr.scale(sc, sc)
		Spr.text(c.title[2], 0, 0, 54, Color(1, .85, .55, k), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_title, 8, Color(0, 0, 0, .85 * k))
		Spr.text(c.title[3], 0, 38, 20, Color(.95, .9, .8, k), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_i, 4, Color(0, 0, 0, .8 * k))
		Spr.restore()
	var l = game.cine_line()
	if l != null:
		var wt: bool = c.get("waiting", false)
		# parada esperando o toque: a caixa da fala fica totalmente visível
		var k2: float = 1.0 if wt else clamp(min(t - l[0], l[1] - t) / 8.0, 0, 1)
		var bw: float = min(W - 80, 760)
		var bx: float = W / 2 - bw / 2
		var by: float = H - 62 - 92
		Spr.rr(bx, by, bw, 84, 12, Color(.05, .04, .03, .88 * k2))
		Spr.ci.draw_rect(Rect2(bx, by, bw, 84), Color(.8, .66, .4, .7 * k2), false, 2)
		# retrato
		Spr.rr(bx + 10, by + 8, 68, 68, 8, Color(.2, .15, .1, k2))
		match l[4]:
			"vargas":
				_portrait("vg_face", bx + 44, by + 42, 62, k2)
			"lia":
				_portrait("lia_scared", bx + 44, by + 42, 62, k2)
			_:
				Spr.save()
				Spr.translate(bx + 44, by + 96)
				Spr.ci.draw_texture_rect_region(Spr.tex.pai, Rect2(-50, -95, 100, 123), Rect2(35, 0, 100, 123), Color(1, 1, 1, k2))
				Spr.restore()
				Spr.rect(bx + 10, by + 76, 68, 20, Color(.05, .04, .03, .88 * k2))
		var col: Color = {"VARGAS": Color("#ff9a7a"), "ISIS": Color("#ffb0d0"), "TOMÉ": Color("#ffd27a")}.get(l[2], Color.WHITE)
		Spr.text(l[2], bx + 92, by + 26, 15, Color(col.r, col.g, col.b, k2), HORIZONTAL_ALIGNMENT_LEFT, Spr.font_title)
		var shown: int = 9999 if c.get("waiting", false) else int((t - l[0]) * 1.6)
		var txt: String = l[3].substr(0, shown)
		var yy := by + 50
		for ln in _lines(txt, bw - 110, 17):
			Spr.text(ln, bx + 92, yy, 17, Color(.96, .92, .82, k2), HORIZONTAL_ALIGNMENT_LEFT, Spr.font_i)
			yy += 21
		if wt:
			var pa: float = .78 + .22 * sin(game.T * .12)
			Spr.text("▸ toque para continuar", bx + bw - 14, by + 78, 15, Color(1, .88, .6, pa), HORIZONTAL_ALIGNMENT_RIGHT, Spr.font_b, 3, Color(0, 0, 0, .8))
	Spr.text("PULAR CENA ▸", W - 20, H - 22, 15, Color(1, .9, .7, .7 * a), HORIZONTAL_ALIGNMENT_RIGHT, Spr.font_b)

func _portrait(n: String, cx: float, cy: float, h: float, al: float) -> void:
	var r = Spr.AR.get(n)
	if r == null:
		return
	var w: float = h * r[2] / r[3]
	if w > 64:
		w = 64
		h = w * r[3] / r[2]
	Spr.ci.draw_texture_rect_region(Spr.atlas_tex(r), Rect2(cx - w / 2, cy - h / 2, w, h), Rect2(r[0], r[1], r[2], r[3]), Color(1, 1, 1, al))
