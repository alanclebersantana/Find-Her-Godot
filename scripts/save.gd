extends Node
## Salva progresso e opções em user://save.cfg (fica guardado no celular).

const PATH := "user://save.cfg"
var cfg := ConfigFile.new()

func _ready() -> void:
	cfg.load(PATH)

func getv(sec: String, key: String, def = null):
	return cfg.get_value(sec, key, def)

func setv(sec: String, key: String, v) -> void:
	cfg.set_value(sec, key, v)
	cfg.save(PATH)

## Progresso da fase: pistas, lápis especiais, desenhos e o ponto de retorno (fogueira)
func save_run(data: Dictionary) -> void:
	cfg.set_value("run", "data", data)
	cfg.save(PATH)

func load_run() -> Dictionary:
	return cfg.get_value("run", "data", {})

func clear_run() -> void:
	if cfg.has_section("run"):
		cfg.erase_section("run")
	cfg.save(PATH)

func best(level: int) -> Dictionary:
	return cfg.get_value("best", str(level), {})

func set_best(level: int, d: Dictionary) -> void:
	var b := best(level)
	if d.get("stars", 0) >= b.get("stars", 0):
		cfg.set_value("best", str(level), d)
		cfg.save(PATH)
