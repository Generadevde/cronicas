class_name Observatorio
extends RefCounted
## Relatórios sobre um personagem, lugar ou grupo durante um período:
## o que aconteceu, o que mudou e por quê.


## Fatos importantes ainda não lidos (para o jornal e os bilhetes).
static func noticias(u: Universo, desde_seq: int, importancia_minima: float = 0.35, incluir_noticias: bool = false) -> Array:
	var lista: Array = []
	for f in u.fatos.todos():
		if int(f["seq"]) <= desde_seq or not f["canon"]:
			continue
		if not incluir_noticias and f["tipo"] in ["notícia", "rumor", "convívio", "esforço", "treino"]:
			continue
		if float(f["dados"].get("importancia", Simulador.IMPORTANCIA.get(f["dados"].get("acao", ""), 0.2))) < importancia_minima:
			continue
		if f["origem"].get("tipo", "") == BancoDeFatos.ORIGEM_AUTOR:
			continue
		lista.append(f)
	lista.sort_custom(func(a, b):
		var ia := float(a["dados"].get("importancia", 0.2))
		var ib := float(b["dados"].get("importancia", 0.2))
		if absf(ia - ib) > 0.05:
			return ia > ib
		return int(a["seq"]) > int(b["seq"]))
	return lista


## Relatório (BBCode) sobre uma entidade num período de 'dias' até hoje (0 = desde sempre).
static func relatorio(u: Universo, eid: String, dias: int) -> String:
	var e := u.entidade(eid)
	if e.is_empty():
		return "[i]Escolha alguém ou algum lugar para observar.[/i]"
	var hoje := DataMundo.ordem(u.relogio)
	var inicio := hoje - dias if dias > 0 else -2147483647
	var fatos: Array = u.fatos.sobre(eid).filter(func(f): return f["canon"] and DataMundo.ordem(f["data"]) >= inicio)
	var periodo := "desde sempre" if dias <= 0 else ("no último ano" if dias == 360 else "nos últimos %d anos" % int(dias / 360.0))
	var s := Paginas.cabecalho("Observatório", "%s · %s" % [Paginas._e(e["nome"]), periodo])
	if fatos.is_empty():
		s += "\n[i]Nada aconteceu com %s neste período.[/i]\n" % Paginas._e(e["nome"])
	var importantes: Array = fatos.filter(func(f): return float(f["dados"].get("importancia", 0.3)) >= 0.35 and not f["tipo"] in ["notícia", "rumor"])
	s += Paginas.secao("Momentos decisivos (%d)" % importantes.size())
	for f in importantes.slice(-12):
		s += "[color=#5A3A1A]%s[/color] — %s %s\n" % [DataMundo.texto(f["data"]), Paginas._e(f["descricao"]), Paginas.link("fato:" + f["id"], "(por quê?)")]
	var contagem := {}
	for f in fatos:
		contagem[f["tipo"]] = int(contagem.get(f["tipo"], 0)) + 1
	if not contagem.is_empty():
		s += Paginas.secao("Em números")
		var partes: Array = []
		for k in contagem:
			partes.append("%s: %d" % [Paginas._e(k), contagem[k]])
		s += ", ".join(partes) + "\n"
	if Estado.tem_mente(u, eid):
		s += Paginas.secao("Quem influenciou")
		var influencia := {}
		for f in fatos:
			for outro in f["sujeitos"]:
				if outro != eid:
					influencia[outro] = int(influencia.get(outro, 0)) + 1
		var ordem := influencia.keys()
		ordem.sort_custom(func(a, b): return influencia[a] > influencia[b])
		if ordem.is_empty():
			s += "[i]Ninguém em especial.[/i]\n"
		for o in ordem.slice(0, 6):
			s += "• %s (%d vezes)\n" % [Paginas.link("ent:" + o, u.entidade(o).get("nome", "?")), influencia[o]]
		s += Paginas.secao("Como está agora")
		s += Paginas.estado(u, eid)
	return s
