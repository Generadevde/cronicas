class_name Biblioteca
extends RefCounted
## A estante de universos salva no computador.
## Cada universo fica em <pasta>/<id>/universo.json, com uma cópia de segurança
## (universo.json.bak) da versão anterior. Apagar manda para a lixeira, nunca some de vez.

var pasta := "user://universos"
var lixeira := "user://lixeira"


func _init(p_pasta: String = "user://universos", p_lixeira: String = "user://lixeira") -> void:
	pasta = p_pasta
	lixeira = p_lixeira
	DirAccess.make_dir_recursive_absolute(pasta)


## Lista os universos salvos, do mais recente ao mais antigo.
## [{id, nome, descricao, atualizado_em}]
func listar() -> Array:
	var lista: Array = []
	var dir := DirAccess.open(pasta)
	if dir == null:
		return lista
	for sub in dir.get_directories():
		var d := _ler_json("%s/%s/universo.json" % [pasta, sub])
		if d.is_empty():
			continue
		lista.append({
			"id": str(d.get("id", sub)),
			"nome": str(d.get("nome", "Sem nome")),
			"descricao": str(d.get("descricao", "")),
			"atualizado_em": str(d.get("atualizado_em", "")),
		})
	lista.sort_custom(func(a, b): return a["atualizado_em"] > b["atualizado_em"])
	return lista


func criar(nome: String, descricao: String = "") -> Universo:
	var u := Universo.novo(nome, descricao)
	salvar(u)
	return u


func carregar(id: String) -> Universo:
	var caminho := "%s/%s/universo.json" % [pasta, id]
	var d := _ler_json(caminho)
	if d.is_empty():
		# Tenta a cópia de segurança se o arquivo principal estiver danificado.
		d = _ler_json(caminho + ".bak")
	if d.is_empty():
		return null
	return Universo.de_dicionario(d)


## Salva de forma segura: escreve num arquivo temporário e só então troca.
func salvar(u: Universo) -> bool:
	var dir_uni := "%s/%s" % [pasta, u.id]
	DirAccess.make_dir_recursive_absolute(dir_uni)
	var caminho := dir_uni + "/universo.json"
	var tmp := caminho + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("Não consegui salvar o universo em %s" % tmp)
		return false
	f.store_string(JSON.stringify(u.para_dicionario(), "\t"))
	f.close()
	if FileAccess.file_exists(caminho):
		if FileAccess.file_exists(caminho + ".bak"):
			DirAccess.remove_absolute(caminho + ".bak")
		DirAccess.rename_absolute(caminho, caminho + ".bak")
	return DirAccess.rename_absolute(tmp, caminho) == OK


## Move o universo para a lixeira (dá para recuperar copiando a pasta de volta).
func apagar(id: String) -> bool:
	DirAccess.make_dir_recursive_absolute(lixeira)
	var origem := "%s/%s" % [pasta, id]
	if not DirAccess.dir_exists_absolute(origem):
		return false
	var destino := "%s/%s_%d" % [lixeira, id, int(Time.get_unix_time_from_system())]
	return DirAccess.rename_absolute(origem, destino) == OK


func existe(id: String) -> bool:
	return FileAccess.file_exists("%s/%s/universo.json" % [pasta, id])


static func _ler_json(caminho: String) -> Dictionary:
	if not FileAccess.file_exists(caminho):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(caminho)) != OK:
		return {}
	if json.data is Dictionary:
		return json.data
	return {}
