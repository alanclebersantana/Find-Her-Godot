extends Node
## All the Above — O Planeta dos Colossos (protótipo 1).
## Monta o vale, o colosso, o Tomé, os alienígenas, a câmera e a tela; cuida da tela de abertura.

var inp: InputState
var sfx: Sfx
var world: World
var colossus: Colossus
var player: Player
var aliens: Aliens
var cam: CameraRig
var hud: Hud
var state := "title"     # title, play
var asleep := 0

func _ready() -> void:
	inp = InputState.new()
	add_child(inp)
	sfx = Sfx.new()
	add_child(sfx)
	world = World.new()
	add_child(world)
	# a ordem importa: o colosso se move antes do Tomé (que fica grudado nele)
	colossus = Colossus.new()
	colossus.main = self
	add_child(colossus)
	player = Player.new()
	player.main = self
	add_child(player)
	player.global_position = world.spawn
	player.face_yaw = PI * 1.15
	aliens = Aliens.new()
	aliens.main = self
	add_child(aliens)
	cam = CameraRig.new()
	cam.main = self
	add_child(cam)
	hud = Hud.new()
	hud.main = self
	add_child(hud)
	colossus.piece_taken.connect(_on_piece)
	colossus.fell_asleep.connect(_on_sleep)
	if "--play" in OS.get_cmdline_user_args():
		start()

func _physics_process(_dt: float) -> void:
	inp.poll()
	if state == "title" and inp.take_tap():
		start()

func start() -> void:
	if state == "play":
		return
	state = "play"
	inp.take_tap()
	cam.snap()
	hud.msg("Sua nave caiu. As peças estão cravadas nos colossos.", 5.0)
	get_tree().create_timer(5.5).timeout.connect(func():
		if state == "play" and asleep == 0:
			hud.msg("Mire num galho (o brilho) e segure GANCHO para balançar.", 5.0))

func _on_piece(left: int) -> void:
	if left > 0:
		hud.msg("Peça da nave arrancada! Faltam %d neste colosso." % left, 3.5)

func _on_sleep() -> void:
	asleep += 1
	hud.msg("O Chifrudo de Musgo voltou a dormir… e virou montanha.", 6.0)
