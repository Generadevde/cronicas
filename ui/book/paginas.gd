class_name Paginas
extends RefCounted
## Monta o texto (BBCode) das páginas da wiki, dos capítulos e dos fatos.
## Links usam o formato "ent:<id>", "cap:<id>", "fato:<id>", "nota:<id>".

const GOTICA := "res://assets/fonts/UnifrakturMaguntia.ttf"
const VERSALETE := "res://assets/fonts/IMFellEnglishSC.ttf"


static func _e(t: String) -> String:
	return TextUtil.escapar_bbcode(t)


static func cabecalho(titulo: String, subtitulo: String = "") -> String:
	var s := "[center][font=%s][font_size=40]%s[/font_size][/font][/center]\n" % [GOTICA, _e(titulo)]
	if subtitulo != "":
		s += "[center][i]%s[/i][/center]\n" % subtitulo
	s += "[center][color=#5A3A1A]—— ◆ ——[/color][/center]\n"
	return s


static func secao(texto: String) -> String:
	return "\n[font=%s][font_size=17][color=#5A3A1A]%s[/color][/font_size][/font]\n" % [VERSALETE, _e(texto)]


static func link(meta: String, texto: String) -> String:
	return "[url=%s][color=#233B66]%s[/color][/url]" % [meta, _e(texto)]


## Página da wiki de uma entidade.
static func entidade(u: Universo, eid: String) -> String:
	var e := u.entidade(eid)
	if e.is_empty():
		return "[i]Esta página não existe.[/i]"
	var lig := Ligador.new(u)
	var sub := _e(e["tipo"]) if e["tipo"] != "" else "sem tipo"
	if not e["apelidos"].is_empty():
		sub += " · também chamado de " + _e(", ".join(e["apelidos"]))
	if e["removida"]:
		sub += " · [color=#7A2418]retirado do universo[/color]"
	var s := cabecalho(e["nome"], sub)

	if e["campos"].is_empty():
		s += "\n[i]Ficha ainda vazia. Abra em Criadores para preencher.[/i]\n"
	else:
		s += secao("Ficha")
		for c in e["campos"]:
			var valor: String = c["valor"] if c["valor"] != "" else "—"
			s += "[b]%s:[/b] %s\n" % [_e(c["chave"]), lig.para_bbcode(valor)]

	var caps: Array = u.indice().get(eid, [])
	s += secao("Aparece em")
	if caps.is_empty():
		s += "[i]Ainda não aparece em nenhum capítulo.[/i]\n"
	else:
		for cid in caps:
			var cap: Dictionary = u.capitulos[cid]
			s += "• %s [color=#5A3A1A]· %s[/color]\n" % [
				link("cap:" + cid, cap["titulo"]), _e(u.livro(cap["livro"]).get("titulo", ""))]

	var citado: Array = []
	for outra in u.entidades_ativas():
		if outra["id"] == eid:
			continue
		for c in outra["campos"]:
			if lig.encontrar(c["valor"]).any(func(m): return m["entidade"] == eid):
				citado.append(outra)
				break
	if not citado.is_empty():
		s += secao("Citado nas fichas de")
		s += ", ".join(citado.map(func(o): return link("ent:" + o["id"], o["nome"]))) + "\n"

	s += secao("Linha do tempo")
	for f in u.fatos.sobre(eid):
		s += "[color=#5A3A1A]%s[/color] — %s %s\n" % [
			DataMundo.texto(f["data"]), _e(f["descricao"]), link("fato:" + f["id"], "(fato)")]
	return s


## Capítulo para leitura, com nomes virando links.
static func capitulo(u: Universo, cid: String) -> String:
	var cap := u.capitulo(cid)
	if cap.is_empty():
		return "[i]Capítulo não encontrado.[/i]"
	var lig := Ligador.new(u)
	var sub := "%s · %s%s" % [_e(u.livro(cap["livro"]).get("titulo", "")), DataMundo.texto(cap["data"]),
		"" if cap["canon"] else " · rascunho"]
	var s := cabecalho(cap["titulo"], sub)
	var texto: String = cap["texto"]
	if texto.strip_edges() == "":
		s += "\n[i]Página em branco.[/i]"
	else:
		s += "\n" + lig.para_bbcode(texto)
	return s


## Detalhes de um fato: o quê, quem, quando, de onde veio, causas e consequências.
static func fato(u: Universo, fid: String) -> String:
	var f := u.fatos.obter(fid)
	if f.is_empty():
		return "[i]Fato não encontrado.[/i]"
	var s := cabecalho("Fato #%d" % f["seq"], _e(f["tipo"]))
	s += "[b]O quê:[/b] %s\n" % _e(f["descricao"])
	s += "[b]Quando:[/b] %s\n" % DataMundo.texto(f["data"])
	var origem: Dictionary = f["origem"]
	s += "[b]Origem:[/b] %s\n" % _e(str(origem.get("tipo", "?")))
	s += "[b]Canon:[/b] %s\n" % ("sim" if f["canon"] else "não")
	if not f["sujeitos"].is_empty():
		var nomes: Array = []
		for e in f["sujeitos"]:
			var ent := u.entidade(e)
			nomes.append(link("ent:" + e, ent.get("nome", e)) if not ent.is_empty() else "[color=#7A2418]%s (não existe)[/color]" % _e(e))
		s += "[b]Envolve:[/b] %s\n" % ", ".join(nomes)
	if f["lugar"] != "":
		s += "[b]Onde:[/b] %s\n" % link("ent:" + f["lugar"], u.entidade(f["lugar"]).get("nome", f["lugar"]))
	if not f["dados"].is_empty():
		s += "[b]Dados:[/b] [color=#5A3A1A]%s[/color]\n" % _e(JSON.stringify(f["dados"]))

	s += secao("Causas diretas")
	if f["causas"].is_empty():
		s += "[i]Nenhuma (fato raiz: veio do autor ou de um capítulo).[/i]\n"
	for c in f["causas"]:
		var cf := u.fatos.obter(c)
		s += "• %s\n" % (link("fato:" + c, "#%d %s" % [cf["seq"], cf["descricao"]]) if not cf.is_empty() else "[color=#7A2418]%s (não existe)[/color]" % _e(c))

	var cadeia := u.fatos.cadeia_de_causas(fid)
	if cadeia.size() > f["causas"].size():
		s += secao("Cadeia completa de causas")
		for cf in cadeia:
			s += "• %s\n" % link("fato:" + cf["id"], "#%d %s" % [cf["seq"], cf["descricao"]])

	s += secao("Consequências")
	var cons := u.fatos.consequencias(fid)
	if cons.is_empty():
		s += "[i]Nenhuma ainda.[/i]\n"
	for cf in cons:
		s += "• %s\n" % link("fato:" + cf["id"], "#%d %s" % [cf["seq"], cf["descricao"]])
	return s


static func nota(u: Universo, nid: String) -> String:
	var n := u.nota(nid)
	if n.is_empty():
		return "[i]Nota não encontrada.[/i]"
	return cabecalho(n["titulo"], "nota privada do autor") + "\n" + _e(n["texto"])
