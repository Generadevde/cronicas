class_name Acompanhar
extends RefCounted
## Acompanhar alguém de perto: seguir um dia, uma semana ou uma jornada, como uma
## câmera. O que ele faz, com quem fala, o que pensa e sente, como reage ao que
## acontece em volta. Velocidade: cena a cena, resumo do dia ou só o importante.
## Dá para parar a qualquer momento (é só não avançar mais) e salvar como rascunho.
## Sem IA local, sai em forma de diário, montado a partir dos fatos.
##
## Ponto de vista: o mundo como ele conhece — o que sabe (e o que só ouviu dizer),
## o que sente, o que quer, e o que ainda não sabe.

const MODOS := {"cena": "cena a cena", "dia": "resumo do dia", "importante": "só o importante"}


## Segue alguém por 'dias' (o mundo inteiro anda junto). Devolve [{data, texto, fato}].
static func seguir(u: Universo, eid: String, dias: int, modo: String = "dia") -> Array:
	var entradas: Array = []
	var restante := dias
	while restante > 0:
		var passo := mini(7 if modo != "cena" else 1, restante)
		restante -= passo
		var antes := _ultimo_seq(u)
		var novos := Simulador.avancar(u, passo)
		var deste: Array = []
		var local := str(u.estado(eid).get("local", ""))
		for f in u.fatos.todos():
			if int(f["seq"]) <= antes or not f["canon"]:
				continue
			var dele: bool = f["sujeitos"].has(eid)
			var em_volta: bool = local != "" and f["lugar"] == local and not f["tipo"] in ["notícia", "rumor"]
			var soube: bool = f["tipo"] in ["notícia", "rumor"] and f["lugar"] == local and Estado.conhece(u, eid, str(f["dados"].get("noticia_de", "")))
			if not (dele or em_volta or soube):
				continue
			if modo == "importante" and float(f["dados"].get("importancia", 0.2)) < 0.5 and not dele:
				continue
			if modo == "importante" and dele and float(f["dados"].get("importancia", 0.2)) < 0.35:
				continue
			var txt: String = f["descricao"]
			if soube:
				txt = "Ouviu dizer: " + str(u.fatos.obter(str(f["dados"]["noticia_de"])).get("descricao", txt))
			elif em_volta and not dele:
				txt = "Em volta: " + txt
			deste.append({"data": f["data"], "texto": txt, "fato": f["id"]})
		if modo == "dia" and deste.size() > 4:
			deste = deste.filter(func(x): return not str(x["texto"]).begins_with("Em volta:")).slice(0, 4)
		entradas.append_array(deste)
		var pensa := pensamento(u, eid)
		if pensa != "" and modo != "importante":
			entradas.append({"data": DataMundo.copiar(u.relogio), "texto": pensa, "fato": ""})
		if not Estado.vivo(u, eid):
			entradas.append({"data": DataMundo.copiar(u.relogio), "texto": "Aqui termina a jornada de %s." % u.entidade(eid)["nome"], "fato": ""})
			break
	return entradas


static func _ultimo_seq(u: Universo) -> int:
	var t := u.fatos.todos()
	return int(t.back()["seq"]) if not t.is_empty() else 0


## O que se passa na cabeça dele agora (a emoção mais forte e o objetivo).
static func pensamento(u: Universo, eid: String) -> String:
	if not Estado.vivo(u, eid):
		return ""
	var n: String = u.entidade(eid)["nome"].split(" ")[0]
	var partes: Array = []
	var em := Estado.emocoes_atuais(u, eid)
	if not em.is_empty():
		var e: Dictionary = em[0]
		var alvo := str(e.get("alvo", ""))
		partes.append("%s sente %s%s" % [n, Paginas.NOMES_EMOCAO.get(e["emocao"], e["emocao"]), (" por " + u.entidade(alvo).get("nome", "?")) if alvo != "" and u.entidades.has(alvo) else ""])
	var obj := Estado.objetivos_ativos(u, eid)
	if not obj.is_empty():
		partes.append("pensa em %s" % Conversa._texto_objetivo(u, obj[0]))
	if partes.is_empty():
		return ""
	return "(%s.)" % " e ".join(partes)


## Salva o acompanhamento como rascunho de capítulo.
static func salvar(u: Universo, eid: String, entradas: Array) -> String:
	var livro := ""
	for l in u.livros:
		if l["titulo"] == "Cenas":
			livro = l["id"]
	if livro == "":
		livro = u.criar_livro("Cenas")
	var cap := u.criar_capitulo(livro, "Dias de %s" % u.entidade(eid)["nome"])
	var linhas: Array = []
	var dia := ""
	for x in entradas:
		var d := DataMundo.texto(x["data"])
		if d != dia:
			linhas.append("\n%s\n" % d)
			dia = d
		linhas.append(str(x["texto"]))
	u.atualizar_capitulo(cap, {"texto": "\n".join(linhas).strip_edges(), "canon": false})
	return cap


# ---------------------------------------------------------------- ponto de vista

## O mundo pelos olhos dele (BBCode).
static func ponto_de_vista(u: Universo, eid: String) -> String:
	var e := u.entidade(eid)
	var s := Paginas.cabecalho("O mundo de %s" % e["nome"], "só o que %s sabe, sente e quer" % e["nome"].split(" ")[0])
	var sabe := Conversa._o_que_sabe(u, eid)
	var viveu: Array = sabe.filter(func(f): return f["sujeitos"].has(eid))
	var ouviu: Array = sabe.filter(func(f): return not f["sujeitos"].has(eid))
	s += Paginas.secao("O que viveu")
	s += "\n".join(viveu.slice(0, 12).map(func(f): return "• [color=#5A3A1A]%s[/color] — %s" % [DataMundo.texto(f["data"]), Paginas.link("fato:" + f["id"], f["descricao"])])) + "\n" if not viveu.is_empty() else "[i]Nada ainda.[/i]\n"
	s += Paginas.secao("O que ouviu dizer")
	s += "\n".join(ouviu.slice(0, 12).map(func(f): return "• [color=#5A3A1A]%s[/color] — %s" % [DataMundo.texto(f["data"]), Paginas.link("fato:" + f["id"], f["descricao"])])) + "\n" if not ouviu.is_empty() else "[i]Nenhuma notícia chegou até aqui.[/i]\n"
	var rels: Array = []
	for outro in u.estado(eid)["relacoes"]:
		if u.entidades.has(outro):
			var p := Paginas._palavra_relacao(u.estado(eid)["relacoes"][outro])
			if p != "":
				rels.append("%s: %s" % [Paginas.link("ent:" + outro, u.entidade(outro)["nome"]), p])
	s += Paginas.secao("O que sente") + (" · ".join(rels) if not rels.is_empty() else "[i]Ninguém lhe importa muito.[/i]") + "\n"
	var obj := Estado.objetivos_ativos(u, eid)
	s += Paginas.secao("O que quer") + (", ".join(obj.map(func(o): return Conversa._texto_objetivo(u, o))) if not obj.is_empty() else "[i]Nada em especial.[/i]") + "\n"
	# O que ele não sabe: fatos importantes do mundo que ainda não chegaram até ele.
	var nao := 0
	var exemplos: Array = []
	for f in u.fatos.todos():
		if f["canon"] and float(f["dados"].get("importancia", 0.0)) >= 0.7 and not Estado.conhece(u, eid, f["id"]) and not f["tipo"] in ["notícia", "rumor"]:
			nao += 1
			if exemplos.size() < 3:
				exemplos.append(f)
	if nao > 0:
		s += Paginas.secao("O que não sabe") + "[i]%d acontecimento%s importante%s que ainda não chegou até ele" % [nao, "" if nao == 1 else "s", "" if nao == 1 else "s"] + (", como: " if not exemplos.is_empty() else "") + "[/i]"
		s += "; ".join(exemplos.map(func(f): return Paginas.link("fato:" + f["id"], f["descricao"]))) + "\n"
	return s
