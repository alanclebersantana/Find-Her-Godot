extends RefCounted
class_name Rig2
## Tomé montado em peças e animado por ossos, no jeito dos personagens do Rayman Legends:
## corpo inteiro (gorro, rosto, barba, casaco) que inclina, respira e amassa; pernas gordas de calça
## que giram no quadril e encolhem como joelho dobrando; botas que ficam rentes ao chão; braço de perto
## que balança; braço da lanterna estendido à frente com a lanterna pendurada (pêndulo de verdade).
## Todas as poses se misturam aos poucos (nunca troca de pose de uma vez).
## Peças em assets/rig/tome2/ (tools/make_rig_tome2.py). Unidades: pixels do desenho aprovado,
## origem no chão embaixo do Tomé, olhando para a direita.

static var D := {}
const H_TARGET := 84.0     # altura do Tomé na tela (da sola ao topo do gorro)
const NAMES := ["corpo", "braco", "braco_lamp", "lanterna", "perna", "bota"]

static func ready() -> bool:
	if D.is_empty():
		D = {"ok": false}
		var base := "res://assets/rig/tome2/"
		if not FileAccess.file_exists(base + "rig.json"):
			return false
		var j = JSON.parse_string(FileAccess.get_file_as_string(base + "rig.json"))
		if not (j is Dictionary) or not j.has("parts"):
			return false
		D.m = j
		D.tex = {}
		for n in NAMES:
			if not ResourceLoader.exists(base + n + ".png"):
				return false
			D.tex[n] = load(base + n + ".png")
		D.leg = float(j.leg)
		D.foot = float(j.foot)
		D.LL = D.leg + D.foot
		D.k = H_TARGET / float(j.height)
		var J: Dictionary = j.joints
		for k in J:
			D[k] = Vector2(J[k][0], J[k][1])
		var pa: Dictionary = j.parts
		D.P0 = Vector2(pa.corpo.at[0], pa.corpo.at[1])
		# da mão (pivô da lanterna) até o ombro do braço da lanterna, na pose do desenho
		D.hand = Vector2(pa.lanterna.at[0] - pa.braco_lamp.at[0], pa.lanterna.at[1] - pa.braco_lamp.at[1])
		D.ok = true
	return D.ok

# ---------------------------------------------------------------- utilidades
## desenha a peça com o pivô em `at`, girada `ang`, com escala (sx, sy) em volta do pivô
static func _part(n: String, at: Vector2, ang: float, tint: Color, sx: float = 1.0, sy: float = 1.0) -> void:
	var m: Dictionary = D.m.parts[n]
	var t: Texture2D = D.tex[n]
	var w: float = m.w
	var h: float = m.h
	Spr.save()
	Spr.translate(at.x, at.y)
	Spr.rotate(ang)
	if sx != 1.0 or sy != 1.0:
		Spr.scale(sx, sy)
	Spr.ci.draw_texture_rect(t, Rect2(-w * m.px, -h * m.py, w, h), false, Color(tint.r, tint.g, tint.b, tint.a * Spr.alpha))
	Spr.restore()

static func _lerp(rg: Dictionary, k: String, v: float, r: float) -> float:
	var c: float = rg.get(k, v)
	c = lerp(c, v, r)
	rg[k] = c
	return c

static func _lerpv(rg: Dictionary, k: String, v: Vector2, r: float) -> Vector2:
	var c: Vector2 = rg.get(k, v)
	c = c.lerp(v, r)
	rg[k] = c
	return c

## mola com velocidade (lanterna, corpo): volta ao alvo passando um pouco do ponto
static func _spring(rg: Dictionary, k: String, target: float, stiff: float, damp: float, kick: float = 0.0) -> float:
	var x: float = rg.get(k, target)
	var v: float = rg.get(k + "_v", 0.0)
	v += (target - x) * stiff + kick
	v *= damp
	x += v
	rg[k] = x
	rg[k + "_v"] = v
	return x

# ---------------------------------------------------------------- pose a partir do estado do Tomé
static func draw(p: Dictionary, cx: float, by: float, T: int, live: bool = true) -> void:
	if not ready():
		return
	var rg: Dictionary = p.get("rg", {})
	if rg.is_empty():
		p.rg = rg
	var LL: float = D.LL
	var spd: float = abs(p.vx)
	var sn: float = clamp(spd / 6.6, 0, 1)
	var t := float(T)
	var r := .26 if live else 0.0         # rapidez da mistura entre poses
	# --- alvos (pose do desenho = tudo zero)
	var body := Vector2.ZERO               # deslocamento do quadril
	var lean: float = 0.0                  # inclinação do corpo (positivo = para a frente)
	var breath: float = 0.0                # corpo esticando (+) ou amassando (-)
	var fF := Vector2(D.hip_f.x + D.P0.x + 4, 0)   # solas (no chão = 0)
	var fB := Vector2(D.hip_b.x + D.P0.x - 4, 0)
	var tF: float = 0.0                    # inclinação das botas
	var tB: float = 0.0
	var aN: float = .06                    # braço de perto: 0 = pendurado, negativo = para a frente
	var aL: float = 0.0                    # braço da lanterna: 0 = estendido como no desenho, negativo = para cima
	var gait: float = rg.get("ph", 0.0)
	var in_air: bool = not p.onGround and not p.swim
	var body_rot: float = 0.0
	if p.swim:
		var st: float = sin(t * .14)
		body_rot = clamp(abs(p.vx) / 3.0, 0, 1) * 1.1 + .15
		fF = Vector2(-60 + st * 40, -40)
		fB = Vector2(-80 - st * 40, -20)
		tF = .6
		tB = .6
		aN = st * 1.3 - .2
		aL = -.5 - st * .3
		body.y = -20
	elif p.vine or p.get("bar") or p.ladder:
		# pendurado / escalando: braços para cima, pernas soltas balançando
		var sw: float = sin(t * .09)
		var cl: float = sin(p.climbA * .14) if p.ladder else 0.0
		aN = PI - .15 + cl * .3
		aL = -1.45 - cl * .3
		fF = Vector2(30 + sw * 14, -cl * 50 - 6)
		fB = Vector2(-30 - sw * 14, cl * 50 - 6)
		if p.ladder and p.ladder.kind == "ladder":
			fF.y = -abs(cl) * 60 - 6
			fB.y = -abs(cl) * 40
		tF = .15
		tB = .15
	elif in_air:
		var up: float = clamp(-p.vy / 11.0, -1, 1)
		if up > 0:
			# subindo: joelhos encolhidos, braço para cima
			fF = Vector2(40, -LL * .4 * up)
			fB = Vector2(-30, -LL * .3 * up)
			tF = -.25 * up
			tB = .2 * up
			aN = 1.1 + up * 1.5
			aL = -.35 * up
			lean = -.05 + sn * .1
			breath = .06 * up
		else:
			# caindo: pernas esticando para o chão, braço abrindo para equilibrar
			var dn: float = -up
			var wob: float = sin(t * .35) * .18 * dn
			fF = Vector2(36, -LL * .1 * (1 - dn))
			fB = Vector2(-34, -LL * .16 * (1 - dn))
			tF = -.15 * dn
			tB = .15 * dn
			aN = .3 + 1.5 * dn + wob
			aL = -.25 * dn - wob * .5
			lean = .03
			breath = .04 * dn
	else:
		var crouch: bool = p.crouch
		if crouch:
			body.y = LL * .22
			lean = .25
			breath = -.08
		var landk: float = p.get("landT", 0) / 8.0
		body.y += LL * .16 * landk * (1.0 + p.get("landV", 0.0) / 12.0)
		breath -= .12 * landk
		if spd > .35 and p.get("pushT", 0) == 0:
			# passada: sola plantada no chão enquanto o corpo passa; a perna que volta sobe em arco
			var stride: float = LL * (.72 + .6 * sn) * (.6 if crouch else 1.0)
			if live:
				gait += spd / (stride * D.k) * PI
				rg.ph = gait
			var lift: float = LL * (.13 + .09 * sn) * (.5 if crouch else 1.0)
			var feet := []
			var tilt := []
			for i in 2:
				var s: float = fposmod(gait + i * PI, TAU)
				if s < PI:
					feet.append(Vector2(stride * .5 - stride * (s / PI), 0))
					tilt.append(0.0)
				else:
					var u: float = (s - PI) / PI
					var e: float = u * u * (3 - 2 * u)
					feet.append(Vector2(-stride * .5 + stride * e, -lift * sin(u * PI)))
					# bota: calcanhar sobe ao sair, ponta sobe ao chegar
					tilt.append(.35 * sin(u * PI) * (1.0 - 2.0 * u))
			fF = feet[0] + Vector2(12, 0)
			fB = feet[1] + Vector2(-8, 0)
			tF = tilt[0]
			tB = tilt[1]
			body.y += LL * (.02 + .04 * sn) * cos(2 * gait)
			breath += .025 * cos(2 * gait)
			if not crouch:
				lean = .04 + sn * .12 + (-.16 if p.get("skidT", 0) > 0 else 0.0)
			# braço de perto balança ao contrário da perna de perto; a lanterna vai firme à frente
			aN = sin(gait) * (.4 + .45 * sn) - sn * .2
			aL = -sn * .15 + sin(gait * 2) * .03
		elif p.get("pushT", 0) > 0:
			lean = .45
			if live:
				gait += spd * .25 + .04
				rg.ph = gait
			var pp: float = sin(gait)
			fF = Vector2(60 + pp * 16, 0)
			fB = Vector2(-50 - pp * 16, -max(pp, 0.0) * 18)
			aN = -1.5
			aL = .1
			body.y = LL * .05
		else:
			# parado: respira, troca o peso de perna, a lanterna balança de leve
			var br: float = sin(t * .055)
			breath += br * .018
			body.x = sin(t * .021) * 6.0
			lean += br * .012
			aN = .06 + br * .04
			aL = br * .03
			if crouch:
				fF.x += 14
				fB.x -= 14
		if p.get("act", "") in ["swing", "throw1", "throw2"] and p.actT > 0:
			var u2: float = clamp(1.0 - p.actT / 22.0, 0, 1)
			aN = lerp(2.6, -1.6, u2 * u2)
			lean = lerp(-.1, .22, u2)
	if p.get("wslide", false):
		aN = PI - .4
		aL = -1.2
		lean = .12
	if p.get("mantleT", 0) > 0:
		aN = PI - .2
		aL = -1.4
		lean = .3
	# --- mistura suave até os alvos (o corpo tem peso: demora um pouco mais)
	body = _lerpv(rg, "bd", body, r * .9)
	lean = _lerp(rg, "lean", lean + clamp(p.get("ax", 0.0), -1, 1) * .08, r * .7)
	breath = _lerp(rg, "br", breath, r)
	body_rot = _lerp(rg, "brot", body_rot, r * .5)
	var ff: Vector2 = _lerpv(rg, "fF", fF, r * 2.2 if p.onGround else r)
	var fb: Vector2 = _lerpv(rg, "fB", fB, r * 2.2 if p.onGround else r)
	tF = _lerp(rg, "tF", tF, r * 1.6)
	tB = _lerp(rg, "tB", tB, r * 1.6)
	aN = _lerp(rg, "aN", aN, r)
	aL = _lerp(rg, "aL", aL, r)
	# física: o corpo atrasa ao arrancar e passa do ponto ao frear; a lanterna é um pêndulo
	var accel: float = (p.vx - rg.get("pvx", p.vx)) * p.face
	if live:
		rg.pvx = p.vx
	var wob: float = _spring(rg, "wb", 0.0, .16, .8, -accel * .02) if live else rg.get("wb", 0.0)
	lean += wob
	# a lanterna fica sempre pendurada para baixo (desconta o giro do braço e do corpo) e balança
	var kick: float = -accel * .03 + (sin(gait * 2) * .006 if spd > .3 and p.onGround else 0.0)
	var swing: float = _spring(rg, "lp", 0.0, .07, .93, kick) if live else rg.get("lp", 0.0)
	# --- monta (unidades do desenho, olhando para a direita, sola em 0)
	var k: float = D.k
	var sq: float = p.get("squash", 0.0)
	Spr.save()
	Spr.translate(cx, by)
	Spr.scale(p.face * k * (1 + sq * .18), k * (1 - sq * .22))
	var P: Vector2 = D.P0 + body
	if body_rot != 0.0:
		Spr.translate(P.x, P.y)
		Spr.rotate(body_rot)
		Spr.translate(-P.x, -P.y)
	var bsx: float = 1.0 - breath * .6
	var bsy: float = 1.0 + breath
	var rot := func(v: Vector2) -> Vector2: return P + Vector2(v.x * bsx, v.y * bsy).rotated(lean)
	var hb: Vector2 = rot.call(D.hip_b)
	var hf: Vector2 = rot.call(D.hip_f)
	var shN: Vector2 = rot.call(D.sh_n)
	var shL: Vector2 = rot.call(D.sh_l)
	var white := Color(1, 1, 1)
	var far := Color(.66, .64, .7)
	# braço da lanterna (atrás da barba) e a lanterna pendurada na mão
	var la: float = lean + aL
	var hand: Vector2 = shL + D.hand.rotated(la)
	_part("lanterna", hand, swing - body_rot, white)
	_part("braco_lamp", shL, la, white)
	if live:
		rg.lampw = Spr.M * (hand + Vector2(0, 105))
	# pernas: a de trás mais escura; a calça estica/encolhe entre o quadril e o tornozelo
	_leg(hb, fb, tB, far)
	_leg(hf, ff, tF, white)
	_part("corpo", P, lean, white, bsx, bsy)
	# braço de perto, por cima do casaco
	_part("braco", shN, lean + aN, white)
	# onde ficou a cabeça (no mundo): para o capacete de mergulho e outros acessórios
	if live:
		rg.headw = Spr.M * rot.call(D.head)
		rg.heada = (lean + body_rot) * p.face
		rg.lampT = T
	Spr.restore()

static func _leg(hip: Vector2, sole: Vector2, tilt: float, tint: Color) -> void:
	var ank: Vector2 = sole + Vector2(0, -D.foot)
	var v: Vector2 = ank - hip
	var len: float = v.length()
	var s: float = clamp(len / D.leg, .6, 1.12)
	var ang: float = v.angle() - PI * .5
	_part("bota", ank, tilt + ang * .25, tint)
	# perna encolhida fica mais gorda (calça larga dobrando no joelho)
	_part("perna", hip, ang, tint, 1.0 + (1.0 - s) * .45, s)
