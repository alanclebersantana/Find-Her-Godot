extends SceneTree
## Capturas das telas: mochila, pista 6 (crachá) e placar.
func _initialize() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 3:
		await process_frame
	main.start_level(false)
	await process_frame
	main.panel.get_meta("ok").call()
	var g = main.game
	g.INV = ["corda", "gancho", "engrenagem", "oleo"]
	g.CLUEGOT[1] = 1
	g.CLUEGOT[3] = 1
	g.CLUEGOT[6] = 1
	g.SPECGOT["verde"] = 1
	g.SPECGOT["azul"] = 1
	main.open_bag()
	for i in 6:
		await process_frame
	root.get_texture().get_image().save_png("/tmp/fh_shots/u_bag.png")
	main.close_panel()
	main._on_clue(6)
	for i in 6:
		await process_frame
	root.get_texture().get_image().save_png("/tmp/fh_shots/u_clue.png")
	main.close_panel()
	for c in ["vermelho", "laranja", "amarelo", "roxo"]:
		g.SPECGOT[c] = 1
	g.STATS.pen = 99
	main._on_results()
	for i in 6:
		await process_frame
	root.get_texture().get_image().save_png("/tmp/fh_shots/u_res.png")
	quit()
