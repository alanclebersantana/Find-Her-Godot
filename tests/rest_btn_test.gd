extends SceneTree
## Fogueira grande: passar por ela só salva (não abre a tela); ✦ USAR perto dela abre a tela de
## descanso já com os botões prontos.
func _initialize() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 3:
		await process_frame
	main.start_level(false)
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
	await process_frame
	var g = main.game
	var fails := 0
	var c: Dictionary = {}
	for k in g.CHK:
		if k.has("rest"):
			c = k
			break
	var saved := []
	g.rest_saved.connect(func(n): saved.append(n))
	g.player.x = float(c.x) - g.player.w / 2 - 10
	g.player.y = float(c.y) - g.player.h - 2
	g.player.vx = 0.0
	g.player.vy = 0.0
	for i in 60:
		await process_frame
	print("px=", g.player.x + g.player.w / 2, " cx=", c.x, " feet=", g.player.y + g.player.h, " cy=", c.y)
	print("saved=", saved, " state=", main.state, " running=", g.running, " avail=", g.use_available())
	if saved.is_empty() or main.state == main.S.REST or not g.running:
		fails += 1
		print("FAIL: passar pela fogueira abriu a tela ou não salvou")
	if not g.use_available():
		fails += 1
		print("FAIL: mãozinha não aparece perto da fogueira")
	g.keys.R = false
	g.keys.Ap = true
	for i in 4:
		await process_frame
	print("state=", main.state, " REST=", main.S.REST)
	if main.state != main.S.REST:
		fails += 1
		print("FAIL: USAR não abriu a tela de descanso")
	else:
		var btns := []
		var stack: Array = [main.panel]
		while not stack.is_empty():
			var n = stack.pop_back()
			if n is Button:
				btns.append(n)
			stack.append_array(n.get_children())
		for b in btns:
			if b.disabled or b.get_parent().modulate.a < .99:
				fails += 1
				print("FAIL: botão não está pronto na hora: ", b.text)
		print("botões=", btns.size())
	print("FALHAS: ", fails)
	print("REST BTN OK" if fails == 0 else "REST BTN FAIL")
	quit(1 if fails else 0)
