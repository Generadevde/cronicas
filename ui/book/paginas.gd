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


## Um valor de 0 a 1 dito em palavras (o Livro não mostra porcentagens).
static func grau(v: float, palavras: Array = ["quase nenhuma", "pouca", "alguma", "muita", "enorme"]) -> String:
	return str(palavras[clampi(int(v * palavras.size()), 0, palavras.size() - 1)])


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
	var ng := str(u.estado(eid).get("nome_de_guerra", ""))
	if ng != "":
		sub += " · hoje chamado de [b]%s[/b]" % _e(ng)
	var nl := str(u.estado(eid).get("nome_lendario", ""))
	if nl != "":
		sub += " · lembrada como [b]%s[/b]" % _e(nl)
	var s := cabecalho(Lendas.nome_com_titulo(u, eid), sub)

	if e["campos"].is_empty():
		s += "\n[i]Ficha ainda vazia. Abra em Criadores para preencher.[/i]\n"
	else:
		s += secao("Ficha")
		for c in e["campos"]:
			var valor: String = c["valor"] if c["valor"] != "" else "—"
			s += "[b]%s:[/b] %s\n" % [_e(c["chave"]), lig.para_bbcode(valor)]

	s += estado(u, eid)
	if Sociedades.eh_sociedade(u, eid):
		s += sociedade(u, eid)
	if Guerras.eh_guerra(u, eid) and not Guerras.dados(u, eid).is_empty():
		s += guerra(u, eid)
	if Forcas.eh_forca(u, eid):
		s += forca(u, eid)
	if not Ameacas.dados(u, eid).is_empty():
		s += secao("Ameaça") + _e(Ameacas.resumo(u, eid)) + "\n"
	if not Recursos.de(u, eid).is_empty():
		s += secao("Sobrevivência") + _e(Recursos.resumo(u, eid)) + "\n"
	var vivas := RegrasVivas.resumo_do_lugar(u, eid)
	if vivas != "":
		s += secao("Vivendo com as leis do mundo") + _e(vivas) + "\n"
	if Ameacas.defesa(u, eid) > 0.0:
		s += "Defesas do lugar: %s\n" % grau(Ameacas.defesa(u, eid), ["quase nenhuma", "fracas", "razoáveis", "fortes", "muito fortes"])
	s += pactos(u, eid)
	s += criacoes(u, eid)
	if u.estado(eid).get("apagado", false):
		s += "\n[color=#7A2418][b]Apagado da existência.[/b] Quase ninguém lembra que existiu.[/color]\n"
	if u.estado(eid).has("adormecido"):
		s += "\n[color=#233B66][b]Sob sono eterno.[/b] O lugar saiu da simulação até a maldição ser quebrada.[/color]\n"
	var ls := Lendas.de(u, eid)
	if not ls.is_empty():
		var linhas_l: Array = []
		for f in ls:
			var v := Lendas.versao(u, f)
			if v["lenda"] != "":
				linhas_l.append("[i]%s[/i] [color=#5A3A1A](o que aconteceu: %s)[/color]" % [_e(v["lenda"]), link("fato:" + f["id"], v["verdade"])])
		if not linhas_l.is_empty():
			s += secao("Lendas") + "\n".join(linhas_l) + "\n"
	if Mapa.e_lugar(u, eid):
		var l := lugar(u, eid)
		if l != "":
			s += secao("O lugar agora") + l

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
	var viagem: Dictionary = st.get("viagem", {})
	if not viagem.is_empty() and u.entidades.has(viagem["para"]):
		linhas.append("[b]Onde está:[/b] a caminho de %s (chega por volta de %s)" % [link("ent:" + viagem["para"], u.entidade(viagem["para"])["nome"]), DataMundo.texto(_data_de_ordem(int(viagem["chega"])))])
	if mente and st["vivo"] and float(st["saude"]) < 0.99:
		var ferimentos: Array = st["ferimentos"].map(func(f): return _e(f["descricao"]))
		linhas.append("[b]Saúde:[/b] %s%s" % [grau(float(st["saude"]), ["à beira da morte", "muito mal", "debilitado", "abatido", "quase inteiro"]), (" · " + ", ".join(ferimentos)) if not ferimentos.is_empty() else ""])
	var fam: Dictionary = st["familia"]
	var rotulos := {"pais": "Pais", "filhos": "Filhos", "conjuges": "Cônjuge", "mestres": "Mestres", "discipulos": "Discípulos"}
	for k in rotulos:
		if not fam[k].is_empty():
			linhas.append("[b]%s:[/b] %s" % [rotulos[k], ", ".join(fam[k].map(func(x): return link("ent:" + x, u.entidade(x).get("nome", "?"))))])
	if mente:
		linhas.append("[b]Jeito de ser:[/b] %s" % Personalidade.resumo(Personalidade.tracos(u, eid)))
		var idade := Estado.idade(u, eid)
		if idade >= 0 and st["vivo"]:
			linhas.append("[b]Idade:[/b] %d anos" % idade)
		var p := Estado.poder(u, eid)
		if p != 1.0:
			linhas.append("[b]Força:[/b] %s" % _numero(p))
		var pods := Poderes.de(u, eid)
		if not pods.is_empty():
			linhas.append("[b]Poderes:[/b] %s" % ", ".join(pods.map(func(x): return link("ent:" + x, u.entidade(x)["nome"]))))
		var marcas := Pecas.marcas(u, eid)
		if not marcas.is_empty():
			linhas.append("[b]Marcas:[/b] %s" % ", ".join(marcas.map(func(x): return _e(x))))
		var reps := Reputacao.por_grupo(u, eid)
		if not reps.is_empty():
			linhas.append("[b]Fama:[/b] %s" % " · ".join(reps.slice(0, 4).map(func(r): return "%s para %s" % [r["palavra"], link("ent:" + r["grupo"], u.entidade(r["grupo"])["nome"])])))
		var cic := Corpo.cicatrizes(u, eid)
		if not cic.is_empty():
			linhas.append("[b]Cicatrizes:[/b] %s" % ", ".join(cic.map(func(x): return _e(x))))
		if idade >= 0 and st["vivo"]:
			linhas.append("[color=#5A3A1A]Costuma-se viver uns %d anos[/color]" % int(Corpo.expectativa(u, eid)))
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


## Resumo de um lugar: onde fica, gente, comida, natureza, acontecimentos, quem está ali.
static func lugar(u: Universo, eid: String) -> String:
	var linhas: Array = []
	var cadeia := Mapa.ancestrais(u, eid)
	if not cadeia.is_empty():
		var partes: Array = []
		for i in range(cadeia.size() - 1, -1, -1):
			partes.append(link("ent:" + cadeia[i], u.entidade(cadeia[i]).get("nome", "?")))
		linhas.append("[b]Fica em:[/b] %s" % " › ".join(partes))
	elif not Mapa.no_mapa(u, eid):
		linhas.append("[color=#5A3A1A][i]Ainda fora do mapa.[/i][/color]")
	var t := Mapa.terreno_do_lugar(u, eid)
	if t != "":
		linhas.append("[b]Terreno:[/b] %s" % Mapa.TERRENOS[t]["nome"])
	if Natureza.tem_natureza(u, eid):
		var reg := Natureza.de(u, eid)
		if float(reg["pop"]) > 0:
			linhas.append("[b]Habitantes:[/b] cerca de %s · %s" % [_numero(float(reg["pop"])), Natureza.palavra_comida(float(reg["comida"]))])
		linhas.append("[b]Estação:[/b] %s · clima %s" % [Natureza.estacao(u.relogio), _e(str(reg.get("clima", "")))])
		var esp: Array = []
		var nomes: Array = reg["especies"].keys()
		nomes.sort()
		for n in nomes:
			var e: Dictionary = reg["especies"][n]
			var nome_e := link("ent:" + e["entidade"], n) if e.get("entidade", "") != "" else _e(n)
			esp.append("%s (%s)" % [nome_e, Natureza.palavra_nivel(float(e["n"]))])
		if not esp.is_empty():
			linhas.append("[b]Natureza:[/b] %s" % ", ".join(esp))
	for ev in Natureza.eventos_ativos(u, eid):
		var info: Dictionary = Natureza.EVENTOS.get(ev["tipo"], {})
		var onde := "" if ev["lugar"] == eid else " (em toda %s)" % u.entidade(ev["lugar"]).get("nome", "?")
		linhas.append("[color=#7A2418]%s [b]%s[/b]%s até %s[/color] %s" % [info.get("simbolo", "•"), info.get("nome", ev["tipo"]), onde,
			DataMundo.texto(_data_de_ordem(int(ev["ate"]))), link("fato:" + ev["fato"], "(por quê?)")])
	if Mapa.especie(u, eid) == "povoado" and Natureza.tem_natureza(u, eid) and float(Natureza.de(u, eid)["pop"]) > 0:
		var h := Humor.de(u, eid)
		linhas.append("[b]Humor do povo:[/b] %s [color=#5A3A1A](raiva %s · medo %s · alegria %s · fé %s)[/color]" % [Humor.palavra(h),
			grau(float(h["raiva"])), grau(float(h["medo"])), grau(float(h["alegria"])), grau(float(h["fe"]))])
		linhas.append("[b]Pão:[/b] %s" % Economia.palavra_preco(Economia.preco(u, eid)))
	var soc := Sociedades.de_lugar(u, eid)
	if soc != "" and soc != eid:
		linhas.append("[b]Quem manda:[/b] %s%s" % [link("ent:" + soc, u.entidade(soc)["nome"]), " [color=#7A2418](ocupação)[/color]" if u.estado(eid).has("ocupado_por") else ""])
	var em_guerra := Guerras.lugares_em_guerra(u)
	if em_guerra.has(eid):
		linhas.append("[b][color=#7A2418]Guerra:[/color][/b] %s (%s)" % [link("ent:" + em_guerra[eid], u.entidade(em_guerra[eid])["nome"]),
			"ocupada" if u.estado(eid).has("ocupado_por") else "frente de batalha"])
	var gente := Natureza._mentes_em(u, eid)
	if not gente.is_empty():
		linhas.append("[b]Quem está aqui:[/b] %s" % ", ".join(gente.map(func(g): return link("ent:" + g, u.entidade(g)["nome"]))))
	var dentro := Mapa.filhos(u, eid)
	if not dentro.is_empty():
		linhas.append("[b]Lugares dentro:[/b] %s" % ", ".join(dentro.map(func(g): return link("ent:" + g, u.entidade(g)["nome"]))))
	if linhas.is_empty():
		return ""
	return "\n".join(linhas) + "\n"


## A página de uma sociedade: governo, governante e dinastia, conselho, território,
## riqueza, humor de cada povoado, leis, religião e cultura, e como vê as pessoas.
static func sociedade(u: Universo, sid: String) -> String:
	var linhas: Array = []
	var t := Sociedades.tipo(u, sid)
	linhas.append("[b]Governo:[/b] %s · sucessão por %s" % [Sociedades.NOMES_TIPO.get(t, t),
		{"heranca": "herança", "eleicao": "eleição", "fe": "escolha dos sacerdotes", "forca": "força", "colmeia": "a mente central",
		 "calculo": "cálculo", "riqueza": "riqueza", "nenhuma": "ninguém"}.get(Sociedades.SUCESSAO.get(t, "forca"), "?")])
	var l := Sociedades.lider(u, sid)
	if l != "" and u.entidades.has(l):
		var vivo := Estado.vivo(u, l)
		linhas.append("[b]Governante:[/b] %s%s%s" % [link("ent:" + l, u.entidade(l)["nome"]), (" · casa " + _e(Sociedades.casa(u, l))) if Sociedades.casa(u, l) != "" else "", "" if vivo else " [color=#7A2418](morto)[/color]"])
	else:
		linhas.append("[b]Governante:[/b] [i]ninguém[/i]")
	var hist := Sociedades.historia_do_governo(u, sid)
	if hist.size() > 1:
		var nomes: Array = []
		for h in hist:
			nomes.append("%s%s" % [link("ent:" + h["quem"], u.entidade(h["quem"]).get("nome", "?")), (" (desde " + DataMundo.texto(h["desde"]) + ")") if not h["desde"].is_empty() else ""])
		linhas.append("[b]Governantes:[/b] %s" % " → ".join(nomes))
	var cons := Sociedades.conselho(u, sid)
	if not cons.is_empty():
		linhas.append("[b]Conselho:[/b] %s" % ", ".join(cons.map(func(c):
			var v := Sociedades.lealdade(u, c, l)
			return "%s (%s)" % [link("ent:" + c, u.entidade(c)["nome"]), "leal" if v >= 0.6 else ("dividido" if v >= 0.3 else "desleal")])))
	var terr := Sociedades.territorio_base(u, sid)
	if not terr.is_empty():
		linhas.append("[b]Território:[/b] %s" % ", ".join(terr.map(func(x): return link("ent:" + x, u.entidade(x)["nome"]))))
	linhas.append("[b]Riqueza:[/b] %s · impostos %s" % [_numero(Economia.riqueza(u, sid)), {0.0: "nenhum", 0.03: "baixos", 0.07: "comuns", 0.15: "altos"}.get(Sociedades.imposto(u, sid), "comuns")])
	var povo: Array = []
	for p in Sociedades.territorio(u, sid):
		if Mapa.especie(u, p) == "povoado" and Natureza.tem_natureza(u, p) and float(Natureza.de(u, p)["pop"]) > 0:
			povo.append("%s: %s" % [link("ent:" + p, u.entidade(p)["nome"]), Humor.palavra(Humor.de(u, p))])
	if not povo.is_empty():
		linhas.append("[b]O povo:[/b] %s" % " · ".join(povo))
	var leis: Dictionary = u.estado(sid).get("leis_feitas", {})
	if not leis.is_empty():
		linhas.append("[b]Leis:[/b] %s" % " · ".join(leis.keys().map(func(x): return _e(x))))
	var fe := Sociedades._campo(u, sid, ["religi", "fe", "crenc", "deus"])
	if fe != "":
		linhas.append("[b]Fé:[/b] %s" % _e(fe))
	var adm := Sociedades._campo(u, sid, ["admir", "honram"])
	var desp := Sociedades._campo(u, sid, ["desprez", "tabu", "odeiam", "condenam"])
	if adm != "" or desp != "":
		linhas.append("[b]Cultura:[/b] %s%s" % [("admira " + _e(adm)) if adm != "" else "", ("; despreza " + _e(desp)) if desp != "" else ""])
	var vistos: Array = []
	for e in u.entidades_ativas():
		if Sugestoes.categoria(e["tipo"]) != "pessoa":
			continue
		var r := Reputacao.detalhe(u, sid, e["id"])
		if int(r["conhecidos"]) > 0 and absf(float(r["valor"])) >= 0.2:
			vistos.append([e["id"], r])
	vistos.sort_custom(func(a, b): return absf(a[1]["valor"]) > absf(b[1]["valor"]))
	if not vistos.is_empty():
		linhas.append("[b]Como vê as pessoas:[/b] %s" % ", ".join(vistos.slice(0, 6).map(func(v): return "%s (%s)" % [link("ent:" + v[0], u.entidade(v[0])["nome"]), Reputacao.palavra(v[1])])))
	var guerras: Array = []
	for g in Guerras.ativas(u):
		var lado := Guerras.lado_de(u, g, sid)
		if lado != "":
			var inimigos: Array = Guerras.dados(u, g)["b" if lado == "a" else "a"]
			guerras.append("%s contra %s" % [link("ent:" + g, u.entidade(g)["nome"]), ", ".join(inimigos.map(func(x): return link("ent:" + x, u.entidade(x)["nome"])))])
	if not guerras.is_empty():
		linhas.append("[b][color=#7A2418]Em guerra:[/color][/b] %s" % " · ".join(guerras))
	var exercitos := Forcas.da_sociedade(u, sid)
	if not exercitos.is_empty():
		linhas.append("[b]Forças:[/b] %s" % ", ".join(exercitos.map(func(f): return "%s (%s, %s)" % [link("ent:" + f, u.entidade(f)["nome"]), Forcas.numero(Forcas.tamanho(u, f)), Forcas.nome_tipo(u, f)])))
	var rancores: Dictionary = u.estado(sid).get("rancores", {})
	var rl: Array = []
	for outro in rancores:
		if float(rancores[outro]) >= 0.3 and u.entidades.has(outro):
			rl.append("%s (%s)" % [link("ent:" + outro, u.entidade(outro)["nome"]), "ódio antigo" if float(rancores[outro]) >= 0.6 else "rancor"])
	if not rl.is_empty():
		linhas.append("[b]Rancores:[/b] %s" % ", ".join(rl))
	linhas.append("[color=#5A3A1A]%d membros com mente própria[/color]" % Sociedades.membros(u, sid).size())
	return secao("Sociedade") + "\n".join(linhas) + "\n"


## A página de uma guerra: lados, forças, frente, previsão e por quê, batalhas, mortos.
static func guerra(u: Universo, g: String) -> String:
	var d := Guerras.dados(u, g)
	var linhas: Array = []
	var lados: Array = []
	for lado in ["a", "b"]:
		lados.append(", ".join(Array(d[lado]).map(func(x): return link("ent:" + x, u.entidade(x)["nome"]))))
	linhas.append("[b]Lados:[/b] %s  [i]contra[/i]  %s" % lados)
	if str(d.get("motivo", "")) != "":
		linhas.append("[b]Motivo:[/b] %s" % _e(d["motivo"]))
	linhas.append("[b]Começou:[/b] %s%s" % [DataMundo.texto(_data_de_ordem(int(d["inicio"]))),
		(" · [b]acabou:[/b] " + DataMundo.texto(_data_de_ordem(int(d["fim"])))) if int(d.get("fim", -1)) > 0 else ""])
	if d["ativa"]:
		linhas.append("[b][color=#7A2418]Em andamento[/color][/b]")
		var fr := Guerras.frente(u, g)
		if fr != "":
			linhas.append("[b]Frente de batalha:[/b] %s" % link("ent:" + fr, u.entidade(fr)["nome"]))
		var p := Guerras.previsao(u, g)
		linhas.append("[b]Previsão:[/b] %s" % _e(p["texto"]))
		if not p["razoes"].is_empty():
			linhas.append("[b]Por quê:[/b]\n" + "\n".join(p["razoes"].slice(0, 7).map(func(r): return "  • " + _e(r))))
	else:
		var v := str(d.get("vencedor", ""))
		linhas.append("[b]Resultado:[/b] %s" % ("vitória de " + u.entidade(d[v][0])["nome"] if v != "" else "paz sem vencedor"))
		if str(d.get("tratado", "")) != "":
			linhas.append("[b]Tratado:[/b] %s" % link("fato:" + d["tratado"], str(u.fatos.obter(d["tratado"])["dados"].get("tratado", "o tratado"))))
	if not d["ocupados"].is_empty():
		linhas.append("[b]Ocupados:[/b] %s" % ", ".join(Array(d["ocupados"]).map(func(x): return link("ent:" + x, u.entidade(x)["nome"]))))
	var forcas: Array = []
	for lado in ["a", "b"]:
		for f in Guerras.forcas_do_lado(u, g, lado):
			var c := Forcas.comandante(u, f)
			forcas.append("  • %s — %s %s · moral %s · suprimentos %s%s" % [link("ent:" + f, u.entidade(f)["nome"]), Forcas.numero(Forcas.tamanho(u, f)),
				Forcas.nome_tipo(u, f), _palavra_moral(Forcas.moral(u, f)), grau(Forcas.suprimentos(u, f), ["esgotados", "curtos", "pela metade", "bons", "fartos"]),
				(" · comandante " + link("ent:" + c, Lendas.nome_com_titulo(u, c))) if c != "" else ""])
	if not forcas.is_empty():
		linhas.append("[b]Forças:[/b]\n" + "\n".join(forcas))
	var mortos: Dictionary = d.get("mortos", {})
	if not mortos.is_empty():
		var ml: Array = []
		for sid in mortos:
			ml.append("%s: %s" % [u.entidade(sid).get("nome", "?"), Forcas.numero(float(mortos[sid]))])
		linhas.append("[b]Mortos:[/b] %s" % " · ".join(ml))
	if not d["batalhas"].is_empty():
		var bl: Array = []
		for b in d["batalhas"]:
			var f := u.fatos.obter(b)
			if f.get("canon", false):
				bl.append("  • [color=#5A3A1A]%s[/color] — %s" % [DataMundo.texto(f["data"]), link("fato:" + b, f["descricao"])])
		linhas.append("[b]Batalhas:[/b]\n" + "\n".join(bl))
	return secao("Guerra") + "\n".join(linhas) + "\n"


## Pactos de uma entidade (o que ofereceu) ou de uma pessoa (o que pediu). Você vê
## tudo, como deus — inclusive os pactos secretos e quando o preço vai chegar.
static func pactos(u: Universo, eid: String) -> String:
	var linhas: Array = []
	for p in Pactos.todos(u):
		if p["ser"] != eid and p["com"] != eid:
			continue
		var f := u.fatos.obter(p["fato"])
		if f.is_empty() or not f["canon"]:
			continue
		var info: Dictionary = f["dados"].get("pacto", {})
		var outro: String = p["com"] if p["ser"] == eid else p["ser"]
		var estado := "[color=#7A2418]preço pago[/color]" if p["cobrado"] else ("preço chega em %s" % DataMundo.texto(_data_de_ordem(int(p["quando"]))))
		linhas.append("• %s %s — desejo: %s · preço: %s · %s%s" % ["com" if p["ser"] == eid else "com", link("ent:" + outro, u.entidade(outro).get("nome", "?")),
			_e(str(info.get("desejo", {}).get("texto", "?"))), _e(str(info.get("preco", {}).get("resumo", "?"))), estado,
			" [color=#5A3A1A](secreto: só você sabe)[/color]" if p["secreto"] and not p["cobrado"] else ""])
	if linhas.is_empty():
		if Pactos.ofertantes(u).has(eid):
			return secao("Pactos") + "[i]Oferece: %s · cobra: %s. Ainda não fez nenhum pacto.[/i]\n" % [_e(Pactos.oferta(u, eid)), _e(Pactos.preco_escrito(u, eid) if Pactos.preco_escrito(u, eid) != "" else "não disse")]
		return ""
	return secao("Pactos") + "\n".join(linhas) + "\n"


## Técnica, escola, religião, cidade (porte, muralhas, ruínas) e o que a pessoa sabe fazer.
static func criacoes(u: Universo, eid: String) -> String:
	var s := ""
	var st := u.estado(eid)
	var nomes := func(lista: Array) -> String:
		return ", ".join(lista.map(func(x): return link("ent:" + x, u.entidade(x)["nome"]))) if not lista.is_empty() else "[i]ninguém[/i]"
	if Tecnicas.eh_tecnica(u, eid):
		var l: Array = []
		var cria := str(st["tecnica"].get("criador", ""))
		if cria != "":
			l.append("[b]Criada por:[/b] %s" % link("ent:" + cria, u.entidade(cria)["nome"]))
		if Tecnicas.perdida(u, eid):
			l.append("[color=#7A2418][b]Perdida[/b][/color] desde %s%s" % [DataMundo.texto(_data_de_ordem(int(st.get("perdida_em", 0)))),
				(" · ficaram vestígios em " + link("ent:" + str(st["vestigio"]), u.entidade(str(st["vestigio"]))["nome"])) if str(st.get("vestigio", "")) != "" else ""])
		else:
			l.append("[b]Quem sabe:[/b] %s" % nomes.call(Tecnicas.conhecem(u, eid)))
		if float(st.get("nivel", 0.0)) > 0:
			l.append("[b]Aperfeiçoada:[/b] %d vez%s" % [int(st["nivel"]), "" if int(st["nivel"]) == 1 else "es"])
		var linhagem: Array = []
		for f in u.fatos.sobre(eid):
			if f["canon"] and f["tipo"] in ["invenção", "ensino de técnica", "aluno", "técnica roubada", "técnica perdida", "redescoberta"]:
				linhagem.append("  • [color=#5A3A1A]%s[/color] — %s" % [DataMundo.texto(f["data"]), link("fato:" + f["id"], f["descricao"])])
		if not linhagem.is_empty():
			l.append("[b]Linhagem:[/b]\n" + "\n".join(linhagem.slice(-12)))
		s += secao("Técnica") + "\n".join(l) + "\n"
	if st.has("escola"):
		var e: Dictionary = st["escola"]
		var t := str(e.get("tecnica", ""))
		s += secao("Escola") + "[b]Ensina:[/b] %s · [b]sede:[/b] %s%s\n[b]Mestres e alunos:[/b] %s\n" % [link("ent:" + t, u.entidade(t)["nome"]),
			link("ent:" + str(e["sede"]), u.entidade(str(e["sede"]))["nome"]),
			" · [color=#7A2418]proibida[/color]" if e.get("proibida", false) else (" · [color=#7A2418]fechada[/color]" if e.get("fechada", false) else ""),
			nomes.call(Tecnicas.conhecem(u, t).filter(func(q): return str(u.estado(q)["local"]) == str(e["sede"])))]
	if st.has("religiao"):
		var fs := Religioes.fieis(u, eid)
		s += secao("Religião") + ("[color=#7A2418][b]Extinta.[/b][/color] Não restou quem acreditasse.\n" if st.get("extinta", false) else
			"[b]Fiéis:[/b] %d (%s)%s\n" % [fs.size(), nomes.call(fs.slice(0, 8)), (" · dividida pela heresia " + link("ent:" + str(st["heresia"]), u.entidade(str(st["heresia"]))["nome"])) if st.has("heresia") else ""])
	if Mapa.e_lugar(u, eid):
		var extras: Array = []
		if Cidades.porte(u, eid) != "":
			extras.append("[b]Porte:[/b] %s" % Cidades.porte(u, eid))
		if Cidades.muralha(u, eid):
			extras.append("[b]Muralhas[/b] (ajudam quem defende)")
		if Cidades.em_ruinas(u, eid):
			extras.append("[color=#7A2418][b]Em ruínas[/b][/color] — lugar de aventura e de vestígios")
		var g := Intriga.guilda_em(u, eid)
		if g != "":
			extras.append("[b]Submundo:[/b] %s" % link("ent:" + g, u.entidade(g)["nome"]))
		if not extras.is_empty():
			s += secao("Construções") + "\n".join(extras) + "\n"
	var ts := Tecnicas.de(u, eid)
	if not ts.is_empty():
		s += secao("Sabe fazer") + nomes.call(ts) + "\n"
	return s


## Página "O que muda": técnicas, escolas, religiões, cidades, submundo, ideias.
static func transformacoes(u: Universo) -> String:
	var s := cabecalho("O que muda no mundo", "criações, crenças, cidades e ideias")
	var vivas: Array = []
	var perdidas: Array = []
	for t in Tecnicas.todas(u):
		if Tecnicas.perdida(u, t):
			perdidas.append("%s (perdida desde %s)" % [link("ent:" + t, u.entidade(t)["nome"]), DataMundo.texto(_data_de_ordem(int(u.estado(t).get("perdida_em", 0))))])
		else:
			var nq := Tecnicas.conhecem(u, t).size()
			vivas.append("%s (%d %s)" % [link("ent:" + t, u.entidade(t)["nome"]), nq, "sabe" if nq == 1 else "sabem"])
	s += secao("Técnicas e invenções") + ("[b]Vivas:[/b] " + ", ".join(vivas) + "\n" if not vivas.is_empty() else "[i]Ninguém inventou nada ainda.[/i]\n")
	if not perdidas.is_empty():
		s += "[b]Perdidas:[/b] " + ", ".join(perdidas) + "\n"
	var esc: Array = Escolas.todas(u).map(func(e): return link("ent:" + e, u.entidade(e)["nome"]) + (" [color=#7A2418](proibida)[/color]" if u.estado(e)["escola"].get("proibida", false) else ""))
	if not esc.is_empty():
		s += secao("Escolas") + ", ".join(esc) + "\n"
	var rel: Array = Religioes.todas(u).map(func(r): return "%s (%s)" % [link("ent:" + r, u.entidade(r)["nome"]), "extinta" if u.estado(r).get("extinta", false) else "%d fiéis" % Religioes.fieis(u, r).size()])
	if not rel.is_empty():
		s += secao("Religiões") + ", ".join(rel) + "\n"
	var cid: Array = []
	var sub: Array = []
	for e in u.entidades_ativas():
		if Cidades.porte(u, e["id"]) != "":
			cid.append("%s: %s%s" % [link("ent:" + e["id"], e["nome"]), Cidades.porte(u, e["id"]), " (muralhas)" if Cidades.muralha(u, e["id"]) else ""])
		if str(e.get("sim", {}).get("submundo", "")) != "":
			sub.append(link("ent:" + e["id"], e["nome"]))
	if not cid.is_empty():
		s += secao("Cidades") + " · ".join(cid) + "\n"
	if not sub.is_empty():
		s += secao("Submundo") + ", ".join(sub) + "\n"
	var ideias := {}
	for e in u.entidades_ativas():
		var i := Povos.ideia_de(u, e["id"])
		if i != "" and Estado.vivo(u, e["id"]):
			ideias[i] = int(ideias.get(i, 0)) + 1
	if not ideias.is_empty():
		s += secao("Ideias que circulam") + "\n".join(ideias.keys().map(func(k): return "• “%s” — %d pessoa%s" % [_e(k), ideias[k], "" if ideias[k] == 1 else "s"])) + "\n"
	return s


static func _palavra_moral(m: float) -> String:
	if m >= 0.85:
		return "inabalável"
	if m >= 0.65:
		return "alta"
	if m >= 0.45:
		return "média"
	if m >= 0.25:
		return "baixa"
	return "quebrada"


## A página de uma força militar.
static func forca(u: Universo, f: String) -> String:
	var linhas: Array = []
	var sid := Forcas.lado(u, f)
	linhas.append("[b]De:[/b] %s" % (link("ent:" + sid, u.entidade(sid)["nome"]) if sid != "" else "[i]ninguém (escreva \"pertence a\")[/i]"))
	linhas.append("[b]Tamanho agora:[/b] %s de %s · [b]tipo:[/b] %s" % [Forcas.numero(Forcas.tamanho(u, f)), Forcas.numero(Forcas.tamanho_inicial(u, f) + float(u.estado(f).get("reforcos", 0.0))), Forcas.nome_tipo(u, f)])
	linhas.append("[b]Moral:[/b] %s · [b]suprimentos:[/b] %s" % [_palavra_moral(Forcas.moral(u, f)), grau(Forcas.suprimentos(u, f), ["esgotados", "curtos", "pela metade", "bons", "fartos"])])
	var c := Forcas.comandante(u, f)
	if c != "":
		linhas.append("[b]Comandante:[/b] %s%s" % [link("ent:" + c, Lendas.nome_com_titulo(u, c)), "" if Estado.vivo(u, c) else " [color=#7A2418](morto)[/color]"])
	var t: Dictionary = Forcas.TIPOS[Forcas.tipo(u, f)]
	var bom: Array = []
	for alvo in Forcas.VANTAGEM.get(Forcas.tipo(u, f), {}):
		if float(Forcas.VANTAGEM[Forcas.tipo(u, f)][alvo]) > 1.05:
			bom.append(Forcas.TIPOS[alvo]["nome"])
	linhas.append("[color=#5A3A1A]%s: luta com %s%s%s[/color]" % [t["nome"].capitalize(), ", ".join(t["armas"].slice(2, 5) if t["armas"].size() > 3 else t["armas"]),
		("; leva vantagem sobre " + ", ".join(bom)) if not bom.is_empty() else "", "; precisa de magia" if t["depende"] == "magia" else ("; precisa de técnica" if t["depende"] == "tecnologia" else "")])
	return secao("Força militar") + "\n".join(linhas) + "\n"


static func _data_de_ordem(ordem: int) -> Dictionary:
	var ano := int(floor(float(ordem - 1) / DataMundo.DIAS_POR_ANO))
	return DataMundo.criar(ano, ordem - ano * DataMundo.DIAS_POR_ANO)


static func _numero(v: float) -> String:
	if v >= 1000000.0:
		return "%.1f milhões" % (v / 1000000.0)
	if v >= 10000.0:
		return "%d mil" % roundi(v / 1000.0)
	if v >= 1000.0:
		var r := roundi(v / 100.0) * 100
		return "%d.%03d" % [r / 1000, r % 1000]
	if v >= 10.0:
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
	if f["dados"].get("secreto", false):
		s += "[b]Secreto:[/b] só quem estava lá sabe (e você)\n"
	if f["dados"].get("previsao", null) is Array:
		s += secao("O que a visão mostrou")
		var prev: Array = f["dados"]["previsao"]
		if prev.is_empty():
			s += "[i]Nada de grande: um tempo calmo.[/i]\n"
		for p in prev:
			s += "• [color=#5A3A1A]%s[/color] — %s\n" % [DataMundo.texto(p["data"]), _e(p["descricao"])]
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
