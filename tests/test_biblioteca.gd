extends TesteBase
## Testes de salvar, carregar e apagar universos no disco.

const PASTA := "user://teste_universos"
const LIXEIRA := "user://teste_lixeira"


func test_salvar_carregar_listar() -> void:
	var b := Biblioteca.new(PASTA, LIXEIRA)
	var u := b.criar("Aldra", "fantasia")
	u.criar_entidade("Daren", "pessoa")
	verdadeiro(b.salvar(u), "salvou")
	var lista := b.listar()
	igual(lista.size(), 1, "um universo na estante")
	igual(lista[0]["nome"], "Aldra", "nome na estante")
	var v := b.carregar(u.id)
	verdadeiro(v != null, "carregou")
	igual(v.entidades_ativas().size(), 1, "entidade preservada")


func test_copia_de_seguranca_salva_dados_corrompidos() -> void:
	var b := Biblioteca.new(PASTA, LIXEIRA)
	var u := b.criar("Aldra")
	u.criar_entidade("Kai", "pessoa")
	b.salvar(u)  # agora existe .bak com a versão anterior
	var f := FileAccess.open("%s/%s/universo.json" % [PASTA, u.id], FileAccess.WRITE)
	f.store_string("{ isto não é json")
	f.close()
	var v := b.carregar(u.id)
	verdadeiro(v != null, "carregou pela cópia de segurança")


func test_apagar_vai_para_lixeira() -> void:
	var b := Biblioteca.new(PASTA, LIXEIRA)
	var u := b.criar("Para apagar")
	verdadeiro(b.apagar(u.id), "apagou")
	falso(b.existe(u.id), "não está mais na estante")
	verdadeiro(DirAccess.get_directories_at(LIXEIRA).size() >= 1, "foi para a lixeira")


func limpar() -> void:
	_apagar_pasta(PASTA)
	_apagar_pasta(LIXEIRA)


func _apagar_pasta(caminho: String) -> void:
	if not DirAccess.dir_exists_absolute(caminho):
		return
	for sub in DirAccess.get_directories_at(caminho):
		_apagar_pasta(caminho + "/" + sub)
	for arq in DirAccess.get_files_at(caminho):
		DirAccess.remove_absolute(caminho + "/" + arq)
	DirAccess.remove_absolute(caminho)
