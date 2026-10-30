extends RefCounted
class_name WorldEp2
## Desenho das lutas novas do Episódio 2 (Ep2Bosses):
## lamparinas e olhos do Morcego-Rei; colmeias, língua e mira do Sapo-Rei.

const IRON := Color("#4a4d52")
const IRON_HI := Color("#9aa0a6")
const OL := Color("#1a1410")

# ======================================================================
#  MORCEGO-REI: lamparinas nos postes das plataformas
# ======================================================================
static func lamps(g: Game, h: Dictionary, T: int) -> void:
	if h.is_empty() or not h.has("lamps"):
		return
	var near = Ep2Bosses.near_lamp(g, g.K)
	for l in h.lamps:
		var x: float = l.x
		var y: float = l.y
		if x < g.cam - 200 or x > g.cam + g.W + 200:
			continue
		# poste com braço
		Spr.rect(x - 4, y - 92, 8, 92, OL)
		Spr.rect(x - 2, y - 90, 4, 90, Color("#6a4a2e"))
		Spr.rect(x - 4, y - 94, 26, 6, OL)
		Spr.rect(x - 3, y - 93, 24, 4, Color("#6a4a2e"))
		# lamparina pendurada
		var lx: float = x + 18
		var ly: float = y - 74
		var sw: float = sin(T * .04 + x) * 1.5
		Spr.seg(lx, y - 88, lx + sw, ly - 12, OL, 2)
		Spr.rr(lx + sw - 9, ly - 12, 18, 24, 3, OL)
		var k: float = float(l.k)
		var glass := Color(.18, .16, .12).lerp(Color(1, .86, .5), k)
		Spr.rr(lx + sw - 7, ly - 10, 14, 19, 2, glass)
		Spr.rect(lx + sw - 9, ly - 14, 18, 4, IRON)
		Spr.rect(lx + sw - 8, ly + 10, 16, 3, IRON)
		if near == l:
			Spr.text("✦", lx, ly - 34 + sin(T * .2) * 4, 22, Color("#ffe27a"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 4)

## por cima da escuridão: chama das lamparinas e os olhos vermelhos do morcego no aviso
static func glow(g: Game, T: int) -> void:
	if g.K == null:
		return
	var h: Dictionary = g.K.HAWK
	if not h.is_empty() and h.has("lamps"):
		for l in h.lamps:
			var k: float = float(l.k)
			if k <= .01:
				continue
			var lx: float = l.x + 18 + sin(T * .04 + l.x) * 1.5
			var ly: float = l.y - 74
			var fl: float = .9 + .1 * sin(T * .5 + l.x)
			Spr.glow(lx, ly, 70 * k * fl, Color(1, .75, .35, .35 * k))
			Spr.glow(lx, ly, 22 * k, Color(1, .9, .6, .8 * k))
			Spr.poly(PackedVector2Array([Vector2(lx - 3, ly + 5), Vector2(lx, ly - 7 * fl), Vector2(lx + 3, ly + 5)]), Color(1, .95, .7, k))
		if h.get("active", false) and not h.get("done", false) and h.st in ["lurk", "warn", "swoop", "recoil"]:
			var c := Vector2(h.x, h.y - 138.0)
			var a: float = 0.0
			if h.st == "warn":
				a = .6 + .4 * sin(T * .6)
			elif h.st == "swoop":
				a = .9
			elif h.st == "lurk":
				a = .18 + .1 * sin(T * .07)
			if a > 0.0:
				for ex in [-7.0, 7.0]:
					Spr.glow(c.x + ex + h.dir * 3.0, c.y, 14 + 10 * a, Color(1, .15, .1, .55 * a))
					Spr.circle(c.x + ex + h.dir * 3.0, c.y, 2.6, Color(1, .35, .25, a))
			if h.st == "warn" and (T / 5) % 2 == 0:
				Spr.text("!", c.x, c.y - 70, 34, Color("#ff6a4a"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 5)

# ======================================================================
#  SAPO-REI: colmeias, sapo na vitória-régia gigante, língua e mira
# ======================================================================
static func frog(g: Game, K, T: int) -> void:
	var f: Dictionary = K.FISH
	if f.is_empty() or not f.has("hives"):
		return
	# (as colmeias no cipó ficam atrás do Tomé: hives_back; aqui só as que a língua puxou e o enxame)
	for hv in f.hives:
		if hv.st in ["pulled", "home", "swarm"]:
			_hive(hv, f, T)
	if f.done and f.st != "down":
		return
	if f.st == "wait" or f.done:
		_frog_body(f, T)
		return
	# mira: um alvo brilhando no Tomé (trava nos últimos quadros: é a hora de desviar)
	if f.st == "aim":
		var aim_t: int = 40 if f.hp <= 1 else 52
		var locked: bool = f.t >= aim_t - 18
		var tg: Vector2 = f.tg.get("tgt", Vector2.ZERO)
		var pul: float = .5 + .5 * sin(T * (.7 if locked else .3))
		var col := Color(1, .25, .2) if locked else Color(1, .7, .3)
		Spr.glow(tg.x, tg.y, 30 + 8 * pul, Color(col.r, col.g, col.b, .35))
		Spr.ring(tg.x, tg.y, 20 + 4 * pul, col, 3)
		for k in 4:
			var a: float = k * PI / 2 + T * .05
			Spr.seg(tg.x + cos(a) * 12, tg.y + sin(a) * 12, tg.x + cos(a) * 26, tg.y + sin(a) * 26, col, 2.5)
		if (T / 6) % 2 == 0:
			Spr.text("!", f.x, f.y - 150, 32, Color("#ff6a4a"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 5)
	_frog_body(f, T)
	# língua
	var st: String = f.tg.get("st", "")
	if st != "":
		var m: Vector2 = Ep2Bosses.frog_mouth(f)
		var tip: Vector2 = f.tg.get("tip", m)
		Spr.seg(m.x, m.y, tip.x, tip.y, Color("#5a1a22"), 12)
		Spr.seg(m.x, m.y, tip.x, tip.y, Color("#e0607a"), 8)
		Spr.seg(m.x, m.y - 2, tip.x, tip.y - 2, Color(1, .8, .85, .5), 2)
		Spr.circle(tip.x, tip.y, 10, Color("#5a1a22"))
		Spr.circle(tip.x, tip.y, 8, Color("#e86a84"))
		Spr.circle(tip.x - 2, tip.y - 3, 3, Color(1, .85, .9, .7))
	# tonto: o enxame em volta da cabeça
	if f.st in ["dizzy", "hurt"]:
		for k in 3:
			var a2: float = T * .12 + TAU * k / 3.0
			Spr.text("★", f.x + cos(a2) * 46, f.y - 150 + sin(a2) * 10, 16, Color("#ffe27a"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 3)

## colmeias penduradas nos cipós (camada do mundo, atrás do Tomé: ele fica "na frente" de uma)
static func hives_back(g: Game, T: int) -> void:
	if g.K == null:
		return
	var f: Dictionary = g.K.FISH
	if f.is_empty() or not f.has("hives"):
		return
	for hv in f.hives:
		if hv.st in ["hang", "stuck", "gone", "pulled", "swarm", "home"]:
			if hv.st in ["pulled", "swarm", "home"]:
				# só o cipó vazio (a colmeia está com a língua ou com o enxame)
				Spr.seg(hv.x, hv.top, hv.x, hv.top + 40, Color("#3c2a14"), 4)
				Spr.seg(hv.x, hv.top, hv.x, hv.top + 40, Color("#5e8a32"), 2)
			else:
				_hive(hv, f, T)

static func _frog_body(f: Dictionary, T: int) -> void:
	var srt: Texture2D = Spr.opt("sapo_rei")
	if srt == null:
		return
	var fr := 1
	var sx := 1.0
	var sy := 1.0
	var rot := 0.0
	var al := 1.0
	match f.st:
		"idle", "wait":
			var br: float = sin(T * .08)
			sy = 1.0 + br * .025
			sx = 1.0 - br * .012
		"aim":
			var aim_t: int = 40 if f.hp <= 1 else 52
			fr = 3 if f.t >= aim_t - 18 else 1
			sy = 1.0 - .05 * clamp(f.t / float(aim_t), 0, 1)
		"tongue":
			fr = 3
		"dizzy":
			fr = 0
			rot = sin(T * .15) * .05
		"hurt":
			fr = 0
			sx = 1.0 + .12 * clamp(float(f.get("hitT", 0)) / 16.0, 0, 1)
			sy = 1.0 - .16 * clamp(float(f.get("hitT", 0)) / 16.0, 0, 1)
		"down":
			fr = 2 if f.t < 30 else 0
			rot = -f.dir * .3 if f.t < 30 else 0.0
			al = clamp(1.0 - (f.t - 40) / 100.0, 0.0, 1.0)
	var tint := Color(1, .55, .5) if f.red > 0 and (T / 3) % 2 == 0 else Color(1, 1, 1)
	tint = tint * Polish.fury(int(f.hp))
	Spr.ellipse(f.x, f.y + 2, 92, 10, Color(0, 0, 0, .25 * al))
	Spr.save()
	Spr.translate(f.x, f.y + 4)
	Spr.rotate(rot)
	# a arte olha para a direita
	Spr.scale((1.0 if f.dir > 0 else -1.0) * sx, sy)
	Spr.ci.draw_texture_rect_region(srt, Rect2(-150, -158, 300, 169), Rect2(fr * 320, 0, 320, 180), Color(tint.r, tint.g, tint.b, Spr.alpha * al))
	Spr.restore()

static func _hive(hv: Dictionary, f: Dictionary, T: int) -> void:
	var x: float = hv.x
	var y: float = hv.y
	var top: float = hv.top
	match hv.st:
		"hang", "stuck":
			var sh: float = sin(T * .5) * 2.0 if hv.st == "stuck" else sin(T * .03 + x) * 1.0
			Spr.seg(x, top, x + sh * .5, y - 44, Color("#3c2a14"), 4)
			Spr.seg(x, top, x + sh * .5, y - 44, Color("#5e8a32"), 2)
			Spr.P("hive", x + sh, y + 2, 46)
			for k in 3:
				var a: float = T * .07 + k * 2.1 + x
				_bee(x + cos(a) * 30, y - 26 + sin(a * 1.3) * 16, T + k * 7, -sin(a) > 0.0)
		"pulled", "home":
			Spr.P("hive", hv.sx, hv.sy + 2, 46)
			if hv.st == "home":
				for k in 5:
					var a3: float = T * .2 + k * 1.3
					_bee(hv.sx + cos(a3) * 26, hv.sy - 26 + sin(a3) * 14, T + k * 5, -sin(a3) > 0.0)
		"swarm":
			Spr.circle(hv.sx, hv.sy, 34 + sin(T * .3) * 3, Color(.15, .1, 0, .18))
			for k in 16:
				var a2: float = T * .23 + k * .9
				var r: float = 12 + (k % 5) * 7
				_bee(hv.sx + cos(a2) * r, hv.sy + sin(a2 * 1.4) * r * .7, T + k * 5, -sin(a2) > 0.0)
		"gone":
			Spr.seg(x, top, x, top + 40, Color("#3c2a14"), 4)
			Spr.seg(x, top, x, top + 40, Color("#5e8a32"), 2)

static func _bee(x: float, y: float, t: int, right: bool) -> void:
	Spr.P("bee", x, y + 5 + (1.0 if (t / 2) % 2 == 0 else 0.0), 13, right)
