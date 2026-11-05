class_name Paginas
extends RefCounted
## Monta o texto (BBCode) das páginas da wiki, dos capítulos e dos fatos.
## Links usam o formato "ent:<id>", "cap:<id>", "fato:<id>", "nota:<id>".

const GOTICA := "res://assets/fonts/UnifrakturMaguntia.ttf"
const VERSALETE := "res://assets/fonts/IMFellEnglishSC.ttf"


static func _e(t: String) -> String:
	return TextUtil.escapar_bbcode(t)


static func cabecalho(titulo: String, subtitulo: String = "") -> String:
	var s := "[center][font=%s][font_size=%d]%s[/font_size][/font][/center]\n" % [GOTICA, Tema.px(40), _e(titulo)]
	if subtitulo != "":
		s += "[center][i]%s[/i][/center]\n" % subtitulo
	s += "[center][color=#5A3A1A]—— ◆ ——[/color][/center]\n"
	return s


static func secao(texto: String) -> String:
	return "\n[font=%s][font_size=%d][color=#5A3A1A]%s[/color][/font_size][/font]\n" % [VERSALETE, Tema.px(17), _e(texto)]


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

	s += estado(u, eid)

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


const NOMES_EMOCAO := {"odio": "ódio", "raiva": "raiva", "humilhacao": "humilhação", "luto": "luto",
	"rancor": "rancor", "medo": "medo", "amor": "amor", "rivalidade": "rivalidade", "alegria": "alegria",
	"esperanca": "esperança", "culpa": "culpa", "inveja": "inveja", "orgulho": "orgulho", "desespero": "desespero",
	"solidao": "solidão", "gratidao": "gratidão", "ambicao": "ambição", "tristeza": "tristeza", "paz": "paz",
	"alivio": "alívio", "vazio": "vazio", "ciume": "ciúme"}


## O que o mundo sabe sobre a entidade agora (vivo/morto, onde, família, relações, mente).
static func estado(u: Universo, eid: String) -> String:
	var st := u.estado(eid)
	var linhas: Array = []
	var mente := Estado.tem_mente(u, eid)
	if not st["vivo"]:
		var m: Dictionary = st["morte"]
		linhas.append("[color=#7A2418][b]Morto[/b][/color]%s" % ((" em " + DataMundo.texto(m["data"])) if m.has("data") else ""))
	elif not st["nascimento"].is_empty():
		linhas.append("[b]Nasceu:[/b] %s" % DataMundo.texto(st["nascimento"]))
	if st["local"] != "" and u.entidades.has(st["local"]):
		linhas.append("[b]Onde está:[/b] %s" % link("ent:" + st["local"], u.entidade(st["local"])["nome"]))
	if mente and st["vivo"] and float(st["saude"]) < 0.99:
		var ferimentos: Array = st["ferimentos"].map(func(f): return _e(f["descricao"]))
		linhas.append("[b]Saúde:[/b] %d%%%s" % [roundi(float(st["saude"]) * 100), (" · " + ", ".join(ferimentos)) if not ferimentos.is_empty() else ""])
	var fam: Dictionary = st["familia"]
	var rotulos := {"pais": "Pais", "filhos": "Filhos", "conjuges": "Cônjuge", "mestres": "Mestres", "discipulos": "Discípulos"}
	for k in rotulos:
		if not fam[k].is_empty():
			linhas.append("[b]%s:[/b] %s" % [rotulos[k], ", ".join(fam[k].map(func(x): return link("ent:" + x, u.entidade(x).get("nome", "?"))))])
	if float(st["reputacao"]) != 0.0:
		linhas.append("[b]Fama:[/b] %s" % ("conhecido" if float(st["reputacao"]) > 0 else "mal falado"))
	if mente:
		linhas.append("[b]Jeito de ser:[/b] %s" % Personalidade.resumo(Personalidade.tracos(u, eid)))
		var idade := Estado.idade(u, eid)
		if idade >= 0 and st["vivo"]:
			linhas.append("[b]Idade:[/b] %d anos" % idade)
		var p := Estado.poder(u, eid)
		if p != 1.0:
			linhas.append("[b]Força:[/b] %s" % _numero(p))
		var emocoes: Array = Estado.emocoes_atuais(u, eid)
		var txt: Array = []
		for e in emocoes.slice(0, 5):
			var alvo := ""
			if e["alvo"] != "" and u.entidades.has(e["alvo"]):
				alvo = " por " + link("ent:" + e["alvo"], u.entidade(e["alvo"])["nome"])
			txt.append("%s%s" % [NOMES_EMOCAO.get(e["emocao"], e["emocao"]), alvo])
		if not txt.is_empty():
			linhas.append("[b]Sente:[/b] %s" % ", ".join(txt))
		var objs: Array = []
		for o in Estado.objetivos_ativos(u, eid):
			var alvo := ""
			if o["alvo"] != "" and u.entidades.has(o["alvo"]):
				alvo = " (" + link("ent:" + o["alvo"], u.entidade(o["alvo"])["nome"]) + ")"
			objs.append(_e(o["tipo"]) + alvo)
		if not objs.is_empty():
			linhas.append("[b]Quer:[/b] %s" % ", ".join(objs))
		var rels: Array = []
		for outro in st["relacoes"]:
			if not u.entidades.has(outro):
				continue
			var r: Dictionary = st["relacoes"][outro]
			var palavra := _palavra_relacao(r)
			if palavra != "":
				rels.append("%s: %s" % [link("ent:" + outro, u.entidade(outro)["nome"]), palavra])
		if not rels.is_empty():
			linhas.append("[b]Relações:[/b] %s" % " · ".join(rels))
		linhas.append("[color=#5A3A1A]Sabe de %d fatos · lembra de %d[/color]" % [st["conhece"].size(), st["memorias"].size()])
	if linhas.is_empty():
		return ""
	return secao("No mundo agora") + "\n".join(linhas) + "\n"


static func _numero(v: float) -> String:
	if v >= 1000000.0:
		return "%.1f milhões" % (v / 1000000.0)
	if v >= 10000.0:
		return "%d mil" % roundi(v / 1000.0)
	if v >= 100.0:
		return str(roundi(v))
	return "%.1f" % v


static func _palavra_relacao(r: Dictionary) -> String:
	var partes: Array = []
	if float(r.get("raiva", 0)) >= 0.6:
		partes.append("ódio")
	elif float(r.get("raiva", 0)) >= 0.3:
		partes.append("raiva")
	if float(r.get("afeto", 0)) >= 0.5:
		partes.append("amor")
	elif float(r.get("afeto", 0)) >= 0.25:
		partes.append("afeto")
	if float(r.get("medo", 0)) >= 0.4:
		partes.append("medo")
	if float(r.get("respeito", 0)) >= 0.4:
		partes.append("respeito")
	if float(r.get("confianca", 0)) <= -0.4:
		partes.append("desconfiança")
	elif float(r.get("confianca", 0)) >= 0.4:
		partes.append("confiança")
	return ", ".join(partes)


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
		s += "\n[font=%s][font_size=%d]%s[/font_size][/font]" % [Tema.caminho_escrita(), Tema.px_escrita(21), lig.para_bbcode(texto)]
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
