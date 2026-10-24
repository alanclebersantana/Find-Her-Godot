extends SceneTree
## mede chamadas de desenho por quadro em pontos da fase, ligando/desligando camadas
func _initialize() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 3:
		await process_frame
	main.start_level(false, int(OS.get_environment("LVL")) if OS.get_environment("LVL") != "" else 0)
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
	var g = main.game
	g.lives = 99
	for a in OS.get_cmdline_user_args():
		var x := float(a)
		g.player.x = x
		g.player.y = 300
		g.player.spawnX = x
		g.player.spawnY = 300
		g.snap_camera()
		for i in 60:
			await process_frame
		var dc = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		var wd = null
		for n in main.find_children("*", "Node2D", true, false):
			if n.get_script() and str(n.get_script().resource_path).ends_with("world_dyn.gd"):
				wd = n
		var res := "x=%d total=%d" % [int(x), dc]
		if wd:
			wd.en_node.visible = false
			for i in 4:
				await process_frame
			res += " sem_inimigos=%d" % Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
			wd.en_node.visible = true
			wd.visible = false
			for i in 4:
				await process_frame
			res += " sem_world_dyn=%d" % Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
			wd.visible = true
		print("DC ", res)
	quit()
