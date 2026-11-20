extends RefCounted
class_name ColossusSkin
## Monta o colosso a partir de um modelo 3D (quadrúpede de frente para +Z, pés para baixo).
## Lê os vértices, acha as 4 patas, o tronco, a cabeça e a cauda pela posição, e:
##  - corta a malha em pedaços presos nos pivôs (anca, joelho, cabeça, cauda) para o andar
##    procedural continuar funcionando;
##  - cria as caixas invisíveis de escalada (CPart) do tamanho de cada pedaço;
##  - põe os pontos de gancho e as três peças da nave (pontos fracos).

const HEIGHT := 21.0            # altura do corpo (antes da escala S do colosso)

static func _xf_to_root(n: Node, root: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var c := n
	while c != null and c != root:
		if c is Node3D:
			t = (c as Node3D).transform * t
		c = c.get_parent()
	return t

static func _pct(vals: Array, q: float) -> float:
	if vals.is_empty():
		return 0.0
	var a := vals.duplicate()
	a.sort()
	return a[clampi(int(q * (a.size() - 1)), 0, a.size() - 1)]

static func build(col, path: String) -> bool:
	if not ResourceLoader.exists(path):
		return false
	var ps: PackedScene = load(path)
	if ps == null:
		return false
	var inst := ps.instantiate()
	# ---------------------------------------------------------------- junta os triângulos
	var pos := PackedVector3Array()
	var nrm := PackedVector3Array()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()
	var mat: Material = null
	for n in inst.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n
		var xf := _xf_to_root(mi, inst)
		for s in mi.mesh.get_surface_count():
			var a := mi.mesh.surface_get_arrays(s)
			var base := pos.size()
			var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var nn: PackedVector3Array = a[Mesh.ARRAY_NORMAL] if a[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
			var tt: PackedVector2Array = a[Mesh.ARRAY_TEX_UV] if a[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
			for i in v.size():
				pos.append(xf * v[i])
				nrm.append((xf.basis * nn[i]).normalized() if i < nn.size() else Vector3.UP)
				uv.append(tt[i] if i < tt.size() else Vector2.ZERO)
			var ii: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			if ii.is_empty():
				for i in v.size():
					idx.append(base + i)
			else:
				for i in ii:
					idx.append(base + i)
			if mat == null:
				mat = mi.get_active_material(s)
	inst.free()
	if pos.size() < 100:
		return false
	# ---------------------------------------------------------------- escala: pés no chão
	var mn := Vector3(1e9, 1e9, 1e9)
	var mx := -mn
	for p in pos:
		mn = mn.min(p)
		mx = mx.max(p)
	var k := HEIGHT / (mx.y - mn.y)
	var c0 := Vector3((mn.x + mx.x) * .5, mn.y, (mn.z + mx.z) * .5)
	for i in pos.size():
		pos[i] = (pos[i] - c0) * k
	var L := (mx.z - mn.z) * k
	var zmin := (mn.z - c0.z) * k
	var leg_top := HEIGHT * .30
	var knee_y := HEIGHT * .155
	var hoof_y := HEIGHT * .045
	var z_head := zmin + L * .76
	var z_tail := zmin + L * .12
	# ---------------------------------------------------------------- patas: 4 grupos
	var lz := []
	for p in pos:
		if p.y < leg_top and p.z < z_head:
			lz.append(p.z)
	var zc := (_pct(lz, .02) + _pct(lz, .98)) * .5
	var leg_pts := [[], [], [], []]       # 0: esq. frente, 1: dir. frente, 2: esq. trás, 3: dir. trás
	for p in pos:
		if p.y < leg_top and p.z < z_head:
			leg_pts[_leg_id(p, zc)].append(p)
	var leg_c := []
	for i in 4:
		var xs := []
		var zs := []
		for p in leg_pts[i]:
			if p.y < knee_y:
				xs.append(p.x)
				zs.append(p.z)
		if xs.is_empty():
			for p in leg_pts[i]:
				xs.append(p.x)
				zs.append(p.z)
		leg_c.append(Vector2(_pct(xs, .5), _pct(zs, .5)))
	# ---------------------------------------------------------------- monta os pivôs e as caixas
	var body: Node3D = col.body if col.body else Node3D.new()
	if col.body == null:
		body.scale = Vector3.ONE * col.S
		col.add_child(body)
		col.body = body
	var offs := [0.0, PI, PI, 0.0]
	var pivots := {}                   # nome -> Node3D (pedaços da malha)
	pivots["body"] = body
	for i in 4:
		var c: Vector2 = leg_c[i]
		var hip := Node3D.new()
		hip.position = Vector3(c.x, leg_top, c.y)
		body.add_child(hip)
		var knee := Node3D.new()
		knee.position = Vector3(0, knee_y - leg_top, 0)
		hip.add_child(knee)
		var up_b := _bounds(leg_pts[i], knee_y, leg_top, hip.position)
		var lo_b := _bounds(leg_pts[i], hoof_y, knee_y, hip.position + knee.position)
		var ho_b := _bounds(leg_pts[i], 0.0, hoof_y * 1.4, hip.position + knee.position)
		# a coxa entra um pouco no tronco (para passar de uma para o outro escalando)
		var up_he := Vector3(up_b.he.x, (leg_top - knee_y) * .5 + HEIGHT * .04, up_b.he.z)
		var up: CPart = col.cpart(hip, up_he, Vector3(up_b.c.x, -(leg_top - knee_y) * .5 + HEIGHT * .04, up_b.c.z))
		var low: CPart = col.cpart(knee, Vector3(lo_b.he.x, (knee_y - hoof_y) * .5, lo_b.he.z), Vector3(lo_b.c.x, -(knee_y - hoof_y) * .5, lo_b.c.z))
		var hoof: CPart = col.cpart(knee, Vector3(ho_b.he.x * 1.05, hoof_y * .5, ho_b.he.z * 1.05), Vector3(ho_b.c.x, -knee_y + hoof_y * .5, ho_b.c.z))
		col.legs.append({"hip": hip, "knee": knee, "hoof": hoof, "off": offs[i], "last": 0.0, "up": up, "low": low})
		pivots["hip%d" % i] = hip
		pivots["knee%d" % i] = knee
	# tronco: 3 fatias ao longo do comprimento (a corcova na frente é mais alta)
	var body_pts := []
	for p in pos:
		if p.y >= leg_top * .9 and p.z <= z_head and p.z >= z_tail:
			body_pts.append(p)
	var zr := _pct(body_pts.map(func(q): return q.z), .01)
	var cuts := [zr, zr + (z_head - zr) * .36, zr + (z_head - zr) * .7, z_head + HEIGHT * .02]
	var order := [1, 0, 2]   # a do meio primeiro (parts[0] = tronco)
	var slabs := {}
	for si in order:
		var z0: float = cuts[si] - HEIGHT * .015
		var z1: float = cuts[si + 1] + HEIGHT * .015
		var ys := []
		var xs2 := []
		for p in body_pts:
			if p.z >= z0 and p.z <= z1:
				ys.append(p.y)
				xs2.append(abs(p.x))
		var top := _pct(ys, .96)
		var bot := maxf(leg_top - HEIGHT * .05, _pct(ys, .03))
		var hx := _pct(xs2, .93)
		var sl: CPart = col.cpart(body, Vector3(hx, (top - bot) * .5, (z1 - z0) * .5), Vector3(0, (top + bot) * .5, (z0 + z1) * .5))
		slabs[si] = sl
	# cabeça (sem os chifres) e um "pescoço" curtinho na junção
	var head_pts := []
	var hxs := []
	for p in pos:
		if p.z > z_head:
			head_pts.append(p)
			hxs.append(abs(p.x))
	var horn_x := _pct(hxs, .999)
	var core := []
	for p in head_pts:
		if abs(p.x) < horn_x * .55:
			core.append(p)
	var hy0 := _pct(core.map(func(q): return q.y), .03)
	var hy1 := _pct(core.map(func(q): return q.y), .9)
	var hz1 := _pct(core.map(func(q): return q.z), .985)
	var hxx := _pct(core.map(func(q): return abs(q.x)), .9)
	var neck := Node3D.new()
	neck.position = Vector3(0, (hy0 + hy1) * .5, z_head)
	body.add_child(neck)
	col.neck = neck
	var head := Node3D.new()
	neck.add_child(head)
	col.head = head
	pivots["head"] = head
	var hd: CPart = col.cpart(head, Vector3(hxx, (hy1 - hy0) * .5, (hz1 - z_head) * .5), Vector3(0, 0, (hz1 - z_head) * .5))
	var front_slab: CPart = slabs[2]
	var neck_top := front_slab.position.y + front_slab.he.y * .85
	var nk: CPart = col.cpart(neck, Vector3(hxx * .9, (neck_top - hy0) * .5, HEIGHT * .05), Vector3(0, (neck_top + hy0) * .5 - neck.position.y, -HEIGHT * .02))
	# cauda
	var t_node := Node3D.new()
	var tail_pts := []
	for p in pos:
		if p.z < z_tail and p.y >= leg_top * .9:
			tail_pts.append(p)
	var ty := _pct(tail_pts.map(func(q): return q.y), .9) if not tail_pts.is_empty() else HEIGHT * .6
	t_node.position = Vector3(0, ty, z_tail)
	body.add_child(t_node)
	col.tail = t_node
	pivots["tail"] = t_node
	# ---------------------------------------------------------------- corta a malha nos pedaços
	var own: Material = col.own_mat(mat) if mat else null
	var groups := {}
	for t in range(0, idx.size(), 3):
		var a: Vector3 = pos[idx[t]]
		var b: Vector3 = pos[idx[t + 1]]
		var c2: Vector3 = pos[idx[t + 2]]
		var ce := (a + b + c2) / 3.0
		var key := _region(ce, leg_top, knee_y, z_head, z_tail, zc)
		if not groups.has(key):
			groups[key] = PackedInt32Array()
		var g: PackedInt32Array = groups[key]
		g.append(idx[t])
		g.append(idx[t + 1])
		g.append(idx[t + 2])
		groups[key] = g
	for key in groups:
		var piv: Node3D = pivots.get(key, body)
		var rest := _rest_in_body(piv, body)
		var inv := rest.affine_inverse()
		var remap := {}
		var vv := PackedVector3Array()
		var vn := PackedVector3Array()
		var vt := PackedVector2Array()
		var ni := PackedInt32Array()
		for i in groups[key]:
			if not remap.has(i):
				remap[i] = vv.size()
				vv.append(inv * pos[i])
				vn.append((inv.basis * nrm[i]).normalized())
				vt.append(uv[i])
			ni.append(remap[i])
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = vv
		arr[Mesh.ARRAY_NORMAL] = vn
		arr[Mesh.ARRAY_TEX_UV] = vt
		arr[Mesh.ARRAY_INDEX] = ni
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		if own:
			am.surface_set_material(0, own)
		var m := MeshInstance3D.new()
		m.name = "skin_" + key
		m.mesh = am
		piv.add_child(m)
	# ---------------------------------------------------------------- ganchos e pontos fracos
	for lg in col.legs:
		var lowp: CPart = lg.low
		var upp: CPart = lg.up
		var sx: float = 1.0 if (lg.hip as Node3D).position.x > 0 else -1.0
		Mk.hook_point(lowp, Vector3(sx * (lowp.he.x + .4), lowp.he.y * .3, 0), "colossus")
		Mk.hook_point(upp, Vector3(sx * (upp.he.x + .4), -upp.he.y * .2, 0), "colossus")
	for si in slabs:
		var sl2: CPart = slabs[si]
		Mk.hook_point(sl2, Vector3(sl2.he.x + .4, -sl2.he.y * .3, 0), "colossus")
		Mk.hook_point(sl2, Vector3(-sl2.he.x - .4, -sl2.he.y * .3, 0), "colossus")
	Mk.hook_point(nk, Vector3(0, nk.he.y + .4, 0), "colossus")
	# pontas dos chifres
	var tip_l := Vector3.ZERO
	var tip_r := Vector3.ZERO
	for p in head_pts:
		if p.x < tip_l.x:
			tip_l = p
		if p.x > tip_r.x:
			tip_r = p
	var hinv := _rest_in_body(head, body).affine_inverse()
	Mk.hook_point(head, hinv * tip_l, "colossus")
	Mk.hook_point(head, hinv * tip_r, "colossus")
	var leg0: CPart = col.legs[0].low
	col.weak_at(leg0, Vector3(0, leg0.he.y * .55, leg0.he.z), Vector3(0, 0, 1), "joelho")
	# a nuca fica em cima da corcova, logo atrás da cabeça
	col.weak_at(front_slab, Vector3(0, front_slab.he.y, front_slab.he.z * .55), Vector3(0, 1, 0), "nuca")
	col.weak_at(hd, Vector3(0, hd.he.y * .35, hd.he.z), Vector3(0, 0, 1), "testa")
	# os olhos ficam vermelhos antes de sacudir: uma luz na testa
	var wl := OmniLight3D.new()
	wl.light_color = Color(1, .25, .1)
	wl.light_energy = 0.0
	wl.omni_range = 10.0
	wl.position = Vector3(0, hd.he.y * .6, hd.position.z + hd.he.z + 1.0)
	head.add_child(wl)
	col.warn_light = wl
	return true

static func _leg_id(p: Vector3, zc: float) -> int:
	var front := p.z > zc
	var left := p.x < 0.0
	if front:
		return 0 if left else 1
	return 2 if left else 3

static func _region(p: Vector3, leg_top: float, knee_y: float, z_head: float, z_tail: float, zc: float) -> String:
	if p.z > z_head:
		return "head"
	if p.y < leg_top:
		var i := _leg_id(p, zc)
		return ("hip%d" if p.y > knee_y else "knee%d") % i
	if p.z < z_tail:
		return "tail"
	return "body"

## caixa (centro relativo a origin e metade do tamanho em x/z) dos pontos entre y0 e y1
static func _bounds(pts: Array, y0: float, y1: float, origin: Vector3) -> Dictionary:
	var xs := []
	var zs := []
	for p in pts:
		if p.y >= y0 and p.y <= y1:
			xs.append(p.x)
			zs.append(p.z)
	if xs.size() < 4:
		for p in pts:
			xs.append(p.x)
			zs.append(p.z)
	var x0 := _pct(xs, .04)
	var x1 := _pct(xs, .96)
	var z0 := _pct(zs, .04)
	var z1 := _pct(zs, .96)
	return {"c": Vector3((x0 + x1) * .5 - origin.x, 0, (z0 + z1) * .5 - origin.z), "he": Vector3(maxf((x1 - x0) * .5, .5), 0, maxf((z1 - z0) * .5, .5))}

static func _rest_in_body(n: Node3D, body: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var c: Node = n
	while c != null and c != body:
		t = (c as Node3D).transform * t
		c = c.get_parent()
	return t
