extends SceneTree
## Fluxo entre episódios: fim do Ep. 1 libera e abre o Ep. 2; salvar/continuar no Ep. 2; fim do Ep. 2 e a escolha de episódio.
var m
var fails := []

func _end_cuts() -> void:
	for c in m.ui_layer.get_children():
		if c.has_method("_end") and c is Control and not c.is_queued_for_deletion():
			c._end()

func _press(txt: String) -> bool:
	if m.panel == null:
		return false
	var bs: Array = m._joy_buttons()
	for b in bs:
		if b is Button and b.text.begins_with(txt):
			b.pressed.emit()
			return true
	return false

func _initialize() -> void:
	m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	for i in 3:
		await process_frame
	var Sv = root.get_node("Save")
	Sv.setv("prog", "eps", 1)
	Sv.setv("opt", "tut_asked", true)
	m.start_level(false, 0)
	await process_frame
	_end_cuts()
	await process_frame
	m.panel.get_meta("ok").call()
	# fim do Episódio 1: resultados -> CONTINUAR -> cena -> Episódio 2
	m.game.running = false
	m._on_results()
	await process_frame
	if int(Sv.getv("prog", "eps", 1)) < 2:
		fails.append("Ep. 2 não foi liberado")
	if not _press("CONTINUAR"):
		fails.append("sem botão CONTINUAR nos resultados")
	for i in 5:
		await process_frame
		_end_cuts()
	await process_frame
	_end_cuts()
	await process_frame
	if m.game.level_idx != 1:
		fails.append("não abriu o Ep. 2 (level_idx=%d)" % m.game.level_idx)
	if m.panel and m.panel.has_meta("ok"):
		m.panel.get_meta("ok").call()
	await process_frame
	# salvar numa fogueira do Ep. 2 e continuar
	m.game.player.x = 9440
	m.game.save_checkpoint(8)
	m.start_level(true)
	await process_frame
	if m.game.level_idx != 1:
		fails.append("continuar não voltou ao Ep. 2")
	if abs(m.game.player.x - 9440) > 200:
		fails.append("continuar não voltou à fogueira (x=%d)" % int(m.game.player.x))
	if m.panel and m.panel.has_meta("ok"):
		m.panel.get_meta("ok").call()
	await process_frame
	# fim do Ep. 2
	m.game.running = false
	m._on_results()
	await process_frame
	if not _press("CONTINUAR"):
		fails.append("sem CONTINUAR no fim do Ep. 2")
	for i in 6:
		await process_frame
		_end_cuts()
	await process_frame
	if m.state != m.S.TITLE:
		fails.append("depois da Isis não voltou ao início (estado %d)" % m.state)
	if not _press("ESCOLHER EPISÓDIO"):
		fails.append("sem ESCOLHER EPISÓDIO no início")
	await process_frame
	if not _press("EPISÓDIO 2"):
		fails.append("sem botão do Episódio 2")
	await process_frame
	if m.game.level_idx != 1:
		fails.append("escolha do Ep. 2 não abriu a fase")
	print("EP FALHAS: ", fails.size(), " ", fails)
	quit(1 if fails.size() > 0 else 0)
