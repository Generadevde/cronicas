class_name Troca
extends RefCounted
## Importação e exportação de universos.
##  Exportar: uma pasta com o universo completo (universo.json), uma página por
##  entidade (wiki/*.md, com ficha e o que o mundo sabe), as leis, a cronologia e os
##  mapas em texto — para ler em qualquer lugar, versionar ou levar para outro programa.
##  Importar: um universo exportado (vira um universo novo na estante) ou uma pasta de
##  textos (como as páginas do WikidPad): cada arquivo vira uma entidade; linhas
##  "chave: valor" e atributos "[chave: valor]" viram campos da ficha; o resto vira descrição.

const SIMBOLOS := {"agua": "~", "deserto": ":", "floresta": "♣", "montanha": "^", "colina": "n", "campo": ".", "planicie": ",", "pantano": "\"", "gelo": "*", "vazio": " "}


static func _limpar_bbcode(t: String) -> String:
	var rx := RegEx.new()
	rx.compile("\\[/?[a-z_]+(=[^\\]]*)?\\]")
	return rx.sub(t, "", true)


static func _nome_arquivo(nome: String) -> String:
	var n := TextUtil.normalizar(nome)
	var r := ""
	for ch in n:
		r += ch if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") else "_"
	return r.substr(0, 60)


## Exporta para uma pasta. Devolve quantos arquivos escreveu.
static func exportar(u: Universo, pasta: String) -> int:
	DirAccess.make_dir_recursive_absolute(pasta + "/wiki")
	var n := 0
	n += int(_escrever(pasta + "/universo.json", JSON.stringify(u.para_dicionario(), "\t")))
	for e in u.entidades_ativas():
		var txt := _limpar_bbcode(Paginas.entidade(u, e["id"]))
		n += int(_escrever("%s/wiki/%s.md" % [pasta, _nome_arquivo(e["nome"])], "# %s\n\n%s" % [e["nome"], txt]))
	var leis: Array = Regras.todas(u).map(func(r): return "- %s%s" % [r["texto"], "" if r["ligada"] else " (desligada)"])
	n += int(_escrever(pasta + "/leis.md", "# Leis do universo\n\n" + "\n".join(leis)))
	var crono: Array = []
	var fs := u.fatos.todos().filter(func(f): return f["canon"] and not f["tipo"] in ["notícia", "rumor"])
	fs.sort_custom(func(a, b): return DataMundo.ordem(a["data"]) < DataMundo.ordem(b["data"]))
	for f in fs:
		crono.append("- %s — %s" % [DataMundo.texto(f["data"]), f["descricao"]])
	n += int(_escrever(pasta + "/cronologia.md", "# Cronologia de %s\n\n%s" % [u.nome, "\n".join(crono)]))
	var mapas: Array = []
	for e in u.entidades_ativas():
		if not Mapa.filhos(u, e["id"]).is_empty():
			mapas.append("== %s ==\n%s" % [e["nome"], mapa_em_texto(u, e["id"])])
	n += int(_escrever(pasta + "/mapas.txt", "\n\n".join(mapas)))
	return n


static func _escrever(caminho: String, texto: String) -> bool:
	var f := FileAccess.open(caminho, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(texto)
	f.close()
	return true


## O mapa de um lugar em caracteres (terreno, e as iniciais dos lugares por cima).
static func mapa_em_texto(u: Universo, de: String) -> String:
	var g := Mapa.terreno(u, de)
	var linhas: Array = []
	for y in g.size():
		var l := ""
		for x in g[y].size():
			l += str(SIMBOLOS.get(str(g[y][x]), "?"))
		linhas.append(l)
	var legenda: Array = []
	for f in Mapa.filhos(u, de):
		var p := Mapa.posicao(u, f)
		var y := int(p["y"])
		var x := int(p["x"])
		if y < linhas.size() and x < str(linhas[y]).length():
			var ch := str(u.entidade(f)["nome"]).substr(0, 1).to_upper()
			linhas[y] = str(linhas[y]).substr(0, x) + ch + str(linhas[y]).substr(x + 1)
			legenda.append("%s = %s" % [ch, u.entidade(f)["nome"]])
	return "\n".join(linhas) + "\n" + ", ".join(legenda)


## Importa um universo exportado (a pasta, ou o universo.json). Vira um universo novo.
static func importar_universo(caminho: String) -> Universo:
	var arq := caminho if caminho.ends_with(".json") else caminho + "/universo.json"
	var d := Biblioteca._ler_json(arq)
	if d.is_empty():
		return null
	d["id"] = Ids.novo("uni")
	d["nome"] = str(d.get("nome", "Importado")) + " (importado)"
	return Universo.de_dicionario(d)


## Importa uma pasta de textos (WikidPad, Markdown, .txt) para dentro de um universo.
## Devolve os ids das entidades criadas.
static func importar_textos(u: Universo, pasta: String) -> Array:
	var criadas: Array = []
	var dir := DirAccess.open(pasta)
	if dir == null:
		return criadas
	var arquivos: Array = []
	for arq in dir.get_files():
		if arq.get_extension().to_lower() in ["wiki", "txt", "md"]:
			arquivos.append(arq)
	arquivos.sort()
	for arq in arquivos:
		var f := FileAccess.open(pasta + "/" + arq, FileAccess.READ)
		if f == null:
			continue
		var texto := f.get_as_text()
		f.close()
		var nome: Variant = arq.get_basename().replace("_", " ")
		# WikidPad usa CamelCase no nome das páginas: "DarenDeVarn" → "Daren De Varn".
		if not nome.contains(" "):
			var sep := ""
			for i in nome.length():
				if i > 0 and nome[i] == nome[i].to_upper() and nome[i] != nome[i].to_lower() and nome[i - 1] == nome[i - 1].to_lower():
					sep += " "
				sep += nome[i]
			nome = sep
		var r := ler_pagina(texto)
		if str(r["titulo"]) != "":
			nome = r["titulo"]
		var existente := ""
		for e in u.entidades_ativas():
			if TextUtil.chave(e["nome"]) == TextUtil.chave(nome):
				existente = e["id"]
		if existente != "":
			continue
		criadas.append(u.criar_entidade(nome, r["tipo"], [], r["campos"]))
	return criadas


## Lê uma página de texto: título (# ou = ou primeira linha), tipo, campos e descrição.
static func ler_pagina(texto: String) -> Dictionary:
	var campos: Array = []
	var desc: Array = []
	var tipo := ""
	var titulo := ""
	var rx_attr := RegEx.new()
	rx_attr.compile("\\[([^\\]:]+):\\s*([^\\]]+)\\]")
	for linha in texto.split("\n"):
		var l := linha.strip_edges()
		if l == "":
			continue
		if titulo == "" and (l.begins_with("#") or l.begins_with("=")):
			titulo = l.lstrip("#= ").rstrip("= ").strip_edges()
			continue
		var achou := false
		for m in rx_attr.search_all(l):
			var k := m.get_string(1).strip_edges()
			var v := m.get_string(2).strip_edges()
			if TextUtil.normalizar(k) in ["tipo", "type", "categoria", "category"]:
				tipo = v
			else:
				campos.append({"chave": k, "valor": v})
			achou = true
		if achou:
			continue
		var i := l.find(":")
		if i > 0 and i < 30 and not l.substr(0, i).contains(" ") or (i > 0 and i < 30 and l.substr(0, i).split(" ").size() <= 3 and not l.begins_with("-")):
			var k2 := l.substr(0, i).strip_edges().trim_prefix("*").trim_suffix("*")
			var v2 := l.substr(i + 1).strip_edges()
			if v2 != "":
				if TextUtil.normalizar(k2) in ["tipo", "type", "categoria"]:
					tipo = v2
				else:
					campos.append({"chave": k2, "valor": v2})
				continue
		desc.append(l.replace("[[", "").replace("]]", ""))
	if not desc.is_empty():
		campos.append({"chave": "descrição", "valor": " ".join(desc)})
	return {"titulo": titulo, "tipo": tipo, "campos": campos}
