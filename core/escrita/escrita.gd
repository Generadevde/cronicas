class_name Escrita
extends RefCounted
## O coração do Crônica: você escreve e o mundo anda junto.
## A cada frase terminada (ponto, exclamação, interrogação ou fim de linha):
##   1. o Leitor transforma a frase em mundo (lugares, gente, criaturas, leis…);
##   2. o Extrator acha as ações de quem já existe ("Mira mata o slime") e elas valem;
##   3. o tempo anda (o que a frase disser, ou um dia se ela contar algo);
##   4. a margem recebe um cartão: o que a frase criou (com Desfazer) e o que o mundo fez;
##   5. o mundo sugere uma continuação (com ressalva: você usa se quiser).
## Apagar ou mudar uma frase desfaz o que ela tinha criado.

const MAX_CARTOES := 80


static func _cap(u: Universo, cid: String) -> Dictionary:
	return u.capitulos.get(cid, {})


static func cartoes(u: Universo, cid: String) -> Array:
	return _cap(u, cid).get("feed", [])


static func chave(frase: String) -> String:
	return TextUtil.normalizar(frase.strip_edges().trim_suffix(".").trim_suffix("!").trim_suffix("?").strip_edges())


## Frases terminadas do texto (a última, ainda sendo escrita, fica de fora).
static func frases_prontas(texto: String) -> Array:
	var r: Array = []
	for f in Extrator.frases(texto):
		var s: String = f
		var fim := s.strip_edges(false, true)
		if fim == "":
			continue
		if s.ends_with("\n") or fim.ends_with(".") or fim.ends_with("!") or fim.ends_with("?") or fim.ends_with(";"):
			if s.strip_edges().length() >= 3:
				r.append(s.strip_edges())
	return r


## Capítulo aberto pela primeira vez neste modo: o que já estava escrito não é relido.
static func preparar(u: Universo, cid: String) -> void:
	var cap := _cap(u, cid)
	if cap.is_empty() or cap.has("lidas"):
		return
	var lidas := {}
	for f in frases_prontas(str(cap["texto"])):
		lidas[chave(f)] = "antigo"
	cap["lidas"] = lidas
	cap["feed"] = []


## Lê o que é novo no capítulo e desfaz o que foi apagado. Devolve os cartões novos.
static func processar(u: Universo, cid: String) -> Array:
	var cap := _cap(u, cid)
	if cap.is_empty() or not cap.get("canon", true):
		return []
	if not cap.has("lidas"):
		cap["lidas"] = {}
		cap["feed"] = []
	var lidas: Dictionary = cap["lidas"]
	var novos: Array = []
	var presentes := {}
	var prontas := frases_prontas(str(cap["texto"]))
	for f in prontas:
		presentes[chave(f)] = true
	# Primeiro, as frases que sumiram do texto: o que elas criaram sai do mundo.
	for k in lidas.keys():
		if presentes.has(k):
			continue
		var raiz := str(lidas[k])
		lidas.erase(k)
		# O que a IA tinha lido desta linha (e o autor aceitou) sai junto.
		for ri in cap.get("ia", {}).get(k, []):
			if u.fatos.existe(str(ri)) and u.fatos.obter(str(ri))["canon"]:
				if u.fatos.obter(str(ri))["dados"].get("leitura", false):
					Leitor.desfazer(u, str(ri))
				else:
					u.desfazer_fato(str(ri))
		cap.get("ia", {}).erase(k)
		if raiz == "" or raiz in ["antigo", "mundo", "ignorada"] or not u.fatos.existe(raiz) or not u.fatos.obter(raiz)["canon"]:
			continue
		var n := Leitor.desfazer(u, raiz)
		var c2 := {"frase": str(u.fatos.obter(raiz)["dados"].get("frase", k)), "desfeita": true, "raiz": raiz, "itens": [], "mundo": [], "dias": 0,
			"data": DataMundo.copiar(u.relogio), "texto": "A frase saiu do texto: %d coisa(s) desfeita(s)." % n}
		_guardar(cap, c2)
		novos.append(c2)
	# Depois, as frases novas.
	for f in prontas:
		var k := chave(f)
		if lidas.has(k):
			continue
		var c := processar_frase(u, cid, f)
		lidas[k] = c.get("raiz", "")
		novos.append(c)
	return novos


static func _guardar(cap: Dictionary, c: Dictionary) -> void:
	var feed: Array = cap.get("feed", [])
	feed.append(c)
	while feed.size() > MAX_CARTOES:
		feed.pop_front()
	cap["feed"] = feed


## Uma frase: lê, aplica as ações, faz o tempo andar e monta o cartão.
static func processar_frase(u: Universo, cid: String, frase: String) -> Dictionary:
	var cap := _cap(u, cid)
	var lido := Leitor.ler(u, frase, {"capitulo": cid, "foco": str(cap.get("foco", ""))})
	if str(lido["foco"]) != "":
		cap["foco"] = lido["foco"]
	var itens: Array = lido["itens"]
	var leitor_entendeu := not itens.is_empty()
	# Ações de quem já existe (o Extrator lê o capítulo; as propostas desta frase valem).
	cap["data"] = DataMundo.copiar(u.relogio)
	Extrator.analisar(u, cid)
	var k := chave(frase)
	var acoes := 0
	for p in u.propostas.duplicate():
		if p["capitulo"] != cid or not p["status"] in ["pendente", "eco"] or chave(str(p.get("frase", ""))) != k:
			continue
		var fid := u.aceitar_proposta(p["id"])
		if fid != "":
			acoes += 1
			itens.append({"tipo": "acao", "texto": u.fatos.obter(fid)["descricao"], "id": fid, "proposta": p["id"]})
	# Se a frase é uma ação entre quem já existe, não precisa ficar também "anotada como acontecimento".
	if acoes > 0:
		for it in itens.duplicate():
			if str(it["tipo"]) == "acontecimento":
				u.desfazer_fato(str(it["id"]))
				itens.erase(it)
	# O que o Leitor já entendeu não vira dúvida ("nas colinas" não é uma ação).
	if leitor_entendeu:
		for p in u.propostas.duplicate():
			if p["capitulo"] == cid and p["status"] == "duvida" and chave(str(p.get("frase", ""))) == k:
				u.riscar_proposta(p["id"])
	var duvidas: Array = u.propostas.filter(func(p): return p["capitulo"] == cid and p["status"] == "duvida" and chave(str(p.get("frase", ""))) == k).map(func(p): return p["id"])
	# O tempo: o que a frase disser; se ela conta algo (não só descreve o mundo), um dia.
	var dias := int(lido["dias"])
	var so_descreve := acoes == 0 and itens.any(func(i): return str(i["tipo"]) in ["lugar", "gente", "criatura", "recurso", "lei", "consulta", "regra", "coisa", "pergunta", "por_vir", "sentimento"])
	if dias == 0 and not so_descreve and not (lido.get("descreve", false) and acoes == 0):
		dias = 1
	if u.extras.get("escrita_sem_tempo", false):
		dias = 0
	var mundo: Array = []
	if dias > 0:
		var antes := Acompanhar._ultimo_seq(u)
		Simulador.avancar(u, dias)
		mundo = _o_que_o_mundo_fez(u, antes, str(cap.get("foco", "")))
		cap["data"] = DataMundo.copiar(u.relogio)
	var c := {"frase": frase, "raiz": lido["raiz"], "itens": itens, "duvidas": duvidas, "mundo": mundo, "dias": dias, "data": DataMundo.copiar(u.relogio),
		"entendeu": not itens.is_empty(), "sugestao": sugestao(u, mundo, dias)}
	_guardar(cap, c)
	u.marcar_mudanca()
	return c


## Os acontecimentos que importam desde 'antes' (primeiro os de onde a história está).
static func _o_que_o_mundo_fez(u: Universo, antes: int, foco: String) -> Array:
	var r: Array = []
	for f in u.fatos.todos():
		if int(f["seq"]) <= antes or not f["canon"] or f["dados"].get("silencioso", false) or f["tipo"] in ["escrita", "reserva", "notícia"]:
			continue
		var imp := float(f["dados"].get("importancia", 0.2))
		var aqui: bool = foco != "" and (f["lugar"] == foco or Mapa.ancestrais(u, str(f["lugar"])).has(foco))
		if imp < (0.25 if aqui else 0.55):
			continue
		# O povo sem nome morrendo de velhice não é notícia: só entra o que toca em algo que o autor escreveu, ou o que é grande.
		if imp < 0.7 and not _toca_no_autor(u, f):
			continue
		r.append({"fato": f["id"], "texto": f["descricao"], "importancia": imp + (0.3 if aqui else 0.0), "data": f["data"], "seq": int(f["seq"])})
	r.sort_custom(func(a, b): return float(a["importancia"]) > float(b["importancia"]))
	r = r.slice(0, 10)
	# Na ordem em que aconteceram.
	r.sort_custom(func(a, b): return DataMundo.ordem(a["data"]) < DataMundo.ordem(b["data"]) or (DataMundo.ordem(a["data"]) == DataMundo.ordem(b["data"]) and int(a["seq"]) < int(b["seq"])))
	return r


static func _toca_no_autor(u: Universo, f: Dictionary) -> bool:
	if not u.extras.get("escrita_por_cima", false):
		return true
	var pessoas := 0
	for s in f["sujeitos"]:
		var e: Dictionary = u.entidade(str(s))
		if e.is_empty() or e["tipo"] != "pessoa":
			continue
		pessoas += 1
		if u.valor_campo(str(s), "descrição") != "":
			return true
	return pessoas == 0


## O mundo escreve (com ressalva): uma continuação montada do que aconteceu.
static func sugestao(u: Universo, mundo: Array, dias: int) -> String:
	if mundo.is_empty():
		return ""
	var ordem := mundo.duplicate()
	ordem.sort_custom(func(a, b): return float(a["importancia"]) > float(b["importancia"]))
	ordem = ordem.slice(0, 4)
	ordem.sort_custom(func(a, b): return DataMundo.ordem(a["data"]) < DataMundo.ordem(b["data"]) or (DataMundo.ordem(a["data"]) == DataMundo.ordem(b["data"]) and int(a["seq"]) < int(b["seq"])))
	var frases: Array = []
	var abertura := "Naquela noite, " if dias <= 1 else ("Nos dias que se seguiram, " if dias <= 30 else "Com o passar do tempo, ")
	for i in ordem.size():
		var t := str(ordem[i]["texto"]).strip_edges()
		if i == 0:
			t = abertura + t.substr(0, 1).to_lower() + t.substr(1) if not _comeca_com_nome(u, t) else abertura + t
		elif i == ordem.size() - 1 and ordem.size() > 2:
			t = "Por fim, " + (t.substr(0, 1).to_lower() + t.substr(1) if not _comeca_com_nome(u, t) else t)
		frases.append(t)
	return " ".join(frases)


static func _comeca_com_nome(u: Universo, t: String) -> bool:
	for m in Ligador.new(u).encontrar(t):
		return int(m["inicio"]) == 0
	return false


## Usa a sugestão: o texto entra no capítulo e não é relido (os fatos já existem).
static func usar_sugestao(u: Universo, cid: String, texto: String) -> void:
	var cap := _cap(u, cid)
	if cap.is_empty() or texto.strip_edges() == "":
		return
	preparar(u, cid)
	var atual := str(cap["texto"]).strip_edges()
	u.atualizar_capitulo(cid, {"texto": (atual + ("\n\n" if atual != "" else "") + texto.strip_edges()) + "\n"})
	for f in frases_prontas(texto + "\n"):
		cap["lidas"][chave(f)] = "mundo"


## Desfaz o que uma frase fez (a frase fica no texto, mas não vale mais).
static func desfazer(u: Universo, cid: String, raiz: String) -> int:
	var cap := _cap(u, cid)
	var n := Leitor.desfazer(u, raiz)
	for c in cap.get("feed", []):
		if str(c.get("raiz", "")) == raiz:
			c["desfeita"] = true
	for k in cap.get("lidas", {}):
		if str(cap["lidas"][k]) == raiz:
			cap["lidas"][k] = "ignorada"
	u.marcar_mudanca()
	return n


## Desfaz só uma ação aceita de uma frase.
static func desfazer_acao(u: Universo, fid: String) -> int:
	return u.desfazer_fato(fid)
