extends Node
## Autoload "Cronica": guarda a biblioteca e o universo aberto,
## salva sozinho pouco depois de cada mudança e troca de tela.

signal universo_aberto(universo: Universo)

const CENAS := {
	"menu": "res://ui/menu/menu.tscn",
	"biblioteca": "res://ui/library/library.tscn",
	"livro": "res://ui/book/book.tscn",
}
const CONFIG := "user://config.cfg"

var biblioteca: Biblioteca
var universo: Universo
var _timer_salvar: Timer


func _init() -> void:
	randomize()
	biblioteca = Biblioteca.new()
	_timer_salvar = Timer.new()
	_timer_salvar.one_shot = true
	_timer_salvar.wait_time = 1.0
	_timer_salvar.timeout.connect(salvar_agora)
	add_child(_timer_salvar)


func abrir(id: String) -> bool:
	var u := biblioteca.carregar(id)
	if u == null:
		return false
	_definir_universo(u)
	return true


func criar_universo(nome: String, descricao: String) -> Universo:
	var u := biblioteca.criar(nome, descricao)
	_definir_universo(u)
	return u


func _definir_universo(u: Universo) -> void:
	if universo != null:
		salvar_agora()
		if universo.mudou.is_connected(_ao_mudar):
			universo.mudou.disconnect(_ao_mudar)
	universo = u
	universo.mudou.connect(_ao_mudar)
	var cfg := ConfigFile.new()
	cfg.load(CONFIG)
	cfg.set_value("geral", "ultimo_universo", u.id)
	cfg.save(CONFIG)
	universo_aberto.emit(u)


func ultimo_universo() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG) != OK:
		return ""
	var id: String = cfg.get_value("geral", "ultimo_universo", "")
	return id if biblioteca.existe(id) else ""


func _ao_mudar() -> void:
	if _timer_salvar.is_inside_tree():
		_timer_salvar.start()
	else:
		salvar_agora()


func salvar_agora() -> void:
	if universo != null:
		biblioteca.salvar(universo)


func ir_para(tela: String) -> void:
	salvar_agora()
	get_tree().change_scene_to_file(CENAS[tela])


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		salvar_agora()
