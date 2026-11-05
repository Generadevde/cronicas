class_name Integridade
extends RefCounted
## Os sistemas que mantêm o Crônica coerente depois de 10 mil acontecimentos.
##   Auditor de causalidade — consequências sem origem válida (Auditor)
##   Auditor de continuidade — contradições históricas (vivo depois de morto, em dois lugares)
##   Controle de conhecimento — ninguém sabe o que não poderia saber
##   Controle de simulação — fatos repetidos, atualizações desnecessárias
##   Recuperação histórica — restaurar acontecimentos desfeitos e versões
##   Gerenciador de memória — arquivar o miúdo antigo sem perder o importante


## Todos os auditores juntos. {causalidade, continuidade, conhecimento, simulacao}
static func auditar_tudo(u: Universo) -> Dictionary:
	return {"causalidade": Auditor.auditar(u), "continuidade": continuidade(u), "conhecimento": conhecimento(u), "simulacao": repetidos(u)}


static func total(r: Dictionary) -> int:
	var n := 0
	for k in r:
		n += Array(r[k]).size()
	return n


## Continuidade: alguém age (é sujeito de um fato que ele faz) depois de morto sem ter
## voltado à vida; alguém nasce duas vezes; capítulos que contradizem o mundo.
static func continuidade(u: Universo) -> Array:
	var p: Array = []
	var morte := {}
	var fatos := u.fatos.todos().filter(func(f): return f["canon"])
	fatos.sort_custom(func(a, b): return DataMundo.ordem(a["data"]) < DataMundo.ordem(b["data"]) or (DataMundo.ordem(a["data"]) == DataMundo.ordem(b["data"]) and a["seq"] < b["seq"]))
	var acoes_de_vivo := ["vitoria", "derrota", "casamento", "usar_poder", "ensino", "luta", "chegada", "traicao", "morte_por", "ferimento"]
	for f in fatos:
		var ops: Array = f["dados"].get("mudancas", [])
		for op in ops:
			if str(op.get("op", "")) in ["reviver", "nascer"]:
				morte.erase(str(op.get("quem", "")))
		var acao := str(f["dados"].get("acao", ""))
		if acao in acoes_de_vivo and not f["sujeitos"].is_empty():
			var agente: String = f["sujeitos"][0]
			if morte.has(agente) and f["origem"]["tipo"] != BancoDeFatos.ORIGEM_AUTOR:
				p.append({"tipo": "agiu_depois_de_morto", "fato": f["id"], "mensagem": "%s age depois de ter morrido (%s)." % [u.entidade(agente).get("nome", agente), DataMundo.texto(f["data"])]})
		for op in ops:
			if str(op.get("op", "")) == "morrer":
				morte[str(op.get("quem", ""))] = f["id"]
	for cid in u.capitulos:
		for a in Continuidade.verificar_capitulo(u, cid):
			p.append({"tipo": "capitulo", "fato": "", "mensagem": "Capítulo \"%s\": %s" % [u.capitulos[cid]["titulo"], a["mensagem"]]})
	return p


## Conhecimento: ninguém sabe de um fato secreto sem ter estado lá, sem ter sido
## contado (conversa, espião) — e ninguém sabe de algo que aconteceu depois de morrer.
static func conhecimento(u: Universo) -> Array:
	var p: Array = []
	var fontes := {}  # fato secreto -> quem pode saber
	for f in u.fatos.todos():
		if not f["canon"]:
			continue
		for op in f["dados"].get("mudancas", []):
			if str(op.get("op", "")) == "conhecer":
				var alvo := str(op.get("fato", f["id"]))
				if not fontes.has(alvo):
					fontes[alvo] = {}
				fontes[alvo][str(op.get("quem", ""))] = true
	for e in u.entidades_ativas():
		var eid: String = e["id"]
		var morte := u.fatos.obter(str(u.estado(eid).get("morte", {}).get("fato", "")))
		for fid in u.estado(eid).get("conhece", {}).keys():
			var f := u.fatos.obter(fid)
			if f.is_empty():
				continue
			if not morte.is_empty() and Estado.vivo(u, eid) == false and DataMundo.ordem(f["data"]) > DataMundo.ordem(morte["data"]) and int(f["seq"]) > int(morte["seq"]):
				p.append({"tipo": "sabe_depois_de_morto", "fato": fid, "mensagem": "%s sabe de algo que aconteceu depois de morrer: %s" % [e["nome"], f["descricao"]]})
			if f["dados"].get("secreto", false) and not f["sujeitos"].has(eid) and not Dictionary(fontes.get(fid, {})).has(eid):
				p.append({"tipo": "sabe_segredo", "fato": fid, "mensagem": "%s sabe de um segredo sem ter como saber: %s" % [e["nome"], f["descricao"]]})
	return p


## Controle de simulação: o mesmo acontecimento registrado duas vezes no mesmo dia.
static func repetidos(u: Universo) -> Array:
	var vistos := {}
	var p: Array = []
	for f in u.fatos.todos():
		if not f["canon"] or f["tipo"] in ["notícia", "rumor"]:
			continue
		var chave := "%d|%s|%s|%s" % [DataMundo.ordem(f["data"]), f["tipo"], f["descricao"], ",".join(f["sujeitos"])]
		if vistos.has(chave):
			p.append({"tipo": "repetido", "fato": f["id"], "mensagem": "Repetido: %s" % f["descricao"]})
		vistos[chave] = true
	return p


# ---------------------------------------------------------------- recuperação histórica

## Fatos desfeitos (fora do canon), do mais recente: dá para restaurar.
static func desfeitos(u: Universo) -> Array:
	var r: Array = u.fatos.todos().filter(func(f): return not f["canon"] and not f["dados"].get("fora_do_galho", false))
	r.sort_custom(func(a, b): return a["seq"] > b["seq"])
	return r


## Restaura um fato desfeito (e o que ele tinha causado e também foi desfeito junto).
static func restaurar(u: Universo, fid: String) -> int:
	var fila: Array = [fid]
	var n := 0
	while not fila.is_empty():
		var atual: String = fila.pop_front()
		var f := u.fatos.obter(atual)
		if f.is_empty() or f["canon"]:
			continue
		# Só volta se as causas estiverem valendo.
		if f["causas"].any(func(c): return not u.fatos.obter(c).get("canon", false)) and atual != fid:
			continue
		f["canon"] = true
		n += 1
		for c in u.fatos.consequencias(atual):
			if not c["canon"]:
				fila.append(c["id"])
	if n > 0:
		AutoAtualizador.reconstruir(u)
		u.marcar_mudanca()
	return n


# ---------------------------------------------------------------- memória

## Quanto o universo ocupa: fatos por tipo, notícias, tamanho aproximado.
static func memoria(u: Universo) -> Dictionary:
	var por_tipo := {}
	for f in u.fatos.todos():
		por_tipo[f["tipo"]] = int(por_tipo.get(f["tipo"], 0)) + 1
	var tamanho := JSON.stringify(u.para_dicionario()).length()
	return {"fatos": u.fatos.quantidade(), "entidades": u.entidades.size(), "por_tipo": por_tipo, "bytes": tamanho,
		"arquivados": int(u.extras.get("arquivo", {}).get("total", 0))}


## Arquiva notícias velhas e miúdas (as que só dizem que uma notícia chegou a um lugar):
## o fato vai para o arquivo do universo (nada se perde) e quem soube continua sabendo
## do fato original. Devolve quantos foram arquivados.
static func arquivar(u: Universo, anos: int = 20, pasta: String = "") -> int:
	var limite := DataMundo.ordem(u.relogio) - anos * DataMundo.DIAS_POR_ANO
	var sai: Array = []
	for f in u.fatos.todos():
		if f["tipo"] in ["notícia", "rumor"] and DataMundo.ordem(f["data"]) < limite and float(f["dados"].get("importancia", 0.12)) < 0.2:
			# Notícias que são causa de algo importante ficam.
			if u.fatos.consequencias(f["id"]).any(func(c): return c["tipo"] != "notícia"):
				continue
			sai.append(f)
	if sai.is_empty():
		return 0
	var arq: Dictionary = u.extras.get("arquivo", {"total": 0, "lotes": []})
	var lote := {"quando": DataMundo.texto(u.relogio), "n": sai.size(), "arquivo": ""}
	if pasta != "":
		DirAccess.make_dir_recursive_absolute(pasta)
		var nome := "%s/arquivo_%d.json" % [pasta, arq["lotes"].size() + 1]
		var fa := FileAccess.open(nome, FileAccess.WRITE)
		if fa != null:
			fa.store_string(JSON.stringify(sai))
			fa.close()
			lote["arquivo"] = nome
	else:
		lote["fatos"] = sai.duplicate(true)
	arq["lotes"].append(lote)
	arq["total"] = int(arq["total"]) + sai.size()
	u.extras["arquivo"] = arq
	u.fatos.remover_varios(sai.map(func(f): return f["id"]))
	u.marcar_mudanca()
	return sai.size()
