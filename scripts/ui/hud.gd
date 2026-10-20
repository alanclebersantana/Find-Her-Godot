extends Control
## HUD: corações, vidas, lápis, lápis especiais, tempo, nome da fase, desenhos, dica e avisos.

var game: Game
var hint_alpha := 0.0
var hint_txt := ""

func _process(_d: float) -> void:
	queue_redraw()

func _box(x: float, y: float, w: float, h: float) -> void:
	Spr.rr(x, y, w, h, 9, Color(.04, .03, .02, .55))

func _draw() -> void:
	if game == null or not game.L or not visible:
		return
	var W := size.x
	var p: Dictionary = game.player
	Spr.begin(self)
	_box(8, 8, 262, 40)
	for i in Game.MAXHP:
		Spr.A("hud_heart_full" if i < p.hp else "hud_heart_empty", 28 + i * 26, 28, .5)
	if p.armor > 0:
		Spr.A("hud_shield", 108, 28, .48)
	Spr.text("× %d" % max(0, game.lives), 122, 34, 16, Color("#e6d4ac"))
	Spr.A("pen_vermelho", 179, 30, .62 * 1.1)
	Spr.text("%d/100" % game.coin_life, 194, 34, 14, Color("#f0cd72"))
	var k := 0
	for c in GameData.PEN_LIST:
		Spr.rr(240 + k * 8, 14, 6, 26, 2, GameData.PEN_COL[c] if game.SPECGOT.has(c) else Color(.35, .31, .25, .6))
		k += 1
	# tempo
	var s: int = max(0, int(ceil(game.time_left / 60.0)))
	var low := s <= 20
	_box(W / 2 - 52, 8, 104, 36)
	var tc := (Color("#ff7a6a") if game.T % 30 < 15 else Color("#ffd0c0")) if low else Color("#f0e0b8")
	Spr.text("%d:%02d" % [s / 60, s % 60], W / 2 + 8, 33, 20, tc, HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b if low else Spr.font)
	Spr.A("hud_clock", W / 2 - 32, 26, .42)
	# nome e desenhos
	_box(W - 250, 8, 242, 40)
	Spr.text("1/7 · " + game.L.name, W - 18, 33, 14, Color("#cdbfa6"), HORIZONTAL_ALIGNMENT_RIGHT, Spr.font_i)
	var nd := 0
	for d in game.DRWS:
		if d.got:
			nd += 1
	_box(W - 130, 52, 122, 28)
	Spr.A("hud_paper", W - 111, 66, .36)
	Spr.text("desenhos %d/%d" % [nd, game.DRWS.size()], W - 96, 71, 13, Color("#ffd76a") if nd == game.DRWS.size() else Color("#cdbfa6"))
	# dica do lugar
	var h := game.hint_text() if game.running else ""
	if h != "":
		hint_txt = h
		hint_alpha = min(1, hint_alpha + .08)
	else:
		hint_alpha = max(0, hint_alpha - .06)
	if hint_alpha > 0 and hint_txt != "":
		var mw: float = min(W - 470, 600)
		var hl := _lines(hint_txt, mw, 15)
		var hw := 0.0
		for ln in hl:
			hw = max(hw, Spr.font_i.get_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x)
		Spr.rr(W / 2 - hw / 2 - 14, 92, hw + 28, hl.size() * 21 + 12, 9, Color(.04, .03, .02, .55 * hint_alpha))
		_wrapped(hint_txt, W / 2, 110, mw, 15, Color(.93, .87, .74, hint_alpha), Spr.font_i)
	# aviso (flash)
	if game.flash_t > 0 and game.flash_msg != "":
		var a: float = clamp(game.flash_t / 40.0, 0, 1)
		var lines := _lines(game.flash_msg, min(W - 80, 760), 17)
		var bh := 16 + lines.size() * 23
		var bw := 0.0
		for ln in lines:
			bw = max(bw, Spr.font.get_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x)
		bw += 36
		var by := size.y - 150 - bh
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
