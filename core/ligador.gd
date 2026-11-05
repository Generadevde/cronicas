class_name Ligador
extends RefCounted
## Encontra nomes e apelidos de entidades dentro de um texto e transforma em links.
## Ignora maiúsculas e acentos ("Joao" encontra "João") e só casa palavras inteiras
## ("Kai" não é encontrado dentro de "Kaique").

var _termos: Array = []  ## [{termo normalizado, entidade}], do mais longo ao mais curto


func _init(universo: Universo) -> void:
	for e in universo.entidades_ativas():
		var nomes: Array = [e["nome"]]
		nomes.append_array(e["apelidos"])
		for n in nomes:
			var t := TextUtil.chave(str(n))
			if t.length() >= 2:
				_termos.append({"termo": t, "entidade": e["id"]})
	_termos.sort_custom(func(a, b): return a["termo"].length() > b["termo"].length())


## Devolve as menções encontradas, sem sobreposição, em ordem de posição:
## [{inicio, fim, entidade, texto}]  (fim é exclusivo).
func encontrar(texto: String) -> Array:
	if _termos.is_empty() or texto.is_empty():
		return []
	var norm := TextUtil.normalizar(texto)
	var ocupado := PackedByteArray()
	ocupado.resize(texto.length())
	var achados: Array = []
	for item in _termos:
		var termo: String = item["termo"]
		var desde := 0
		while true:
			var pos := norm.find(termo, desde)
			if pos < 0:
				break
			desde = pos + 1
			var fim := pos + termo.length()
			var antes_ok := pos == 0 or not TextUtil.eh_letra(norm[pos - 1])
			var depois_ok := fim >= norm.length() or not TextUtil.eh_letra(norm[fim])
			if not (antes_ok and depois_ok):
				continue
			var livre := true
			for k in range(pos, fim):
				if ocupado[k] == 1:
					livre = false
					break
			if not livre:
				continue
			for k in range(pos, fim):
				ocupado[k] = 1
			achados.append({
				"inicio": pos, "fim": fim, "entidade": item["entidade"],
				"texto": texto.substr(pos, termo.length()),
			})
	achados.sort_custom(func(a, b): return a["inicio"] < b["inicio"])
	return achados


## Converte o texto em BBCode, com cada menção virando link "ent:<id>".
func para_bbcode(texto: String, cor_link: String = "#233B66") -> String:
	var saida := ""
	var cursor := 0
	for m in encontrar(texto):
		saida += TextUtil.escapar_bbcode(texto.substr(cursor, m["inicio"] - cursor))
		saida += "[url=ent:%s][color=%s]%s[/color][/url]" % [
			m["entidade"], cor_link, TextUtil.escapar_bbcode(m["texto"])]
		cursor = m["fim"]
	saida += TextUtil.escapar_bbcode(texto.substr(cursor))
	return saida
