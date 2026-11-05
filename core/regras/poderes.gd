class_name Poderes
extends RefCounted
## Poderes, magias e dons. Um poder é uma entidade (tipo livre: "magia", "dom",
## "técnica"…). Alguém TEM o poder quando a ficha dele cita o poder (campos como
## "poderes", "magias", "habilidades") ou quando o poder cita a pessoa ("quem pode usar").
##
## Na ficha do poder, o autor escreve em português:
##   força: 3           — quanto ajuda numa luta (padrão: um pouco)
##   custo: envelhece um ano       — o que acontece com quem usa (vira efeito de verdade)
##   limite: uma vez por mês       — quantas vezes pode usar
##   efeitos permitidos: o outro fica ferido; o outro sente medo
##                                 — o motor aplica sozinho
## Poderes NARRATIVOS (mudar a realidade, reescrever o destino…) nunca são aplicados
## sozinhos: o uso vira um PEDIDO para o autor dizer o que acontece.

const CAMPOS_DE_PODER := ["poderes", "poder", "magias", "magia", "habilidades", "dons", "dom", "feiticos", "feitiços", "tecnicas", "técnicas", "artes"]
const PALAVRAS_NARRATIVAS := ["realidade", "destino", "reescrev", "tempo", "absolut", "qualquer coisa", "onipot", "existencia", "apagar", "desfazer", "narrativ"]


static func eh_poder(u: Universo, pid: String) -> bool:
	return Sugestoes.categoria(u.entidade(pid).get("tipo", "")) == "poder"


## Poderes de alguém (ativos no universo).
static func de(u: Universo, eid: String) -> Array:
	var lista: Array = []
	var lig: Ligador = null
	for c in u.entidade(eid).get("campos", []):
		if TextUtil.normalizar(c["chave"]) in CAMPOS_DE_PODER.map(func(x): return TextUtil.normalizar(x)):
			if lig == null:
				lig = Ligador.new(u)
			for m in lig.encontrar(c["valor"]):
				if eh_poder(u, m["entidade"]) and not lista.has(m["entidade"]):
					lista.append(m["entidade"])
	var nome := TextUtil.chave(u.entidade(eid).get("nome", ""))
	for p in u.entidades_ativas():
		if not eh_poder(u, p["id"]) or lista.has(p["id"]):
			continue
		for campo in ["quem pode usar", "usuario", "usuário", "dono", "portador", "mestre"]:
			var v := TextUtil.chave(u.valor_campo(p["id"], campo))
			if v != "" and nome != "" and v.contains(nome):
				lista.append(p["id"])
				break
	return lista


static func categoria(u: Universo, pid: String) -> String:
	var t := TextUtil.normalizar(u.entidade(pid).get("tipo", "") + " " + u.valor_campo(pid, "origem") + " " + u.valor_campo(pid, "tipo de poder"))
	if t.contains("magia") or t.contains("feitic") or t.contains("encant") or t.contains("arcan") or t.contains("ritual") or t.contains("maldic") or t.contains("bencao"):
		return "magia"
	return ""


static func narrativo(u: Universo, pid: String) -> bool:
	var t := TextUtil.normalizar(u.entidade(pid).get("tipo", "") + " " + u.valor_campo(pid, "efeito") + " " + u.valor_campo(pid, "natureza"))
	for p in PALAVRAS_NARRATIVAS:
		if t.contains(p):
			return true
	return false


const PECAS_DO_MOTOR := ["pausar", "adormecer", "despertar", "apagar", "prever", "galho"]


## Quanto o poder multiplica a força numa luta.
static func bonus(u: Universo, pid: String) -> float:
	var v := u.valor_campo(pid, "força")
	if v == "":
		v = u.valor_campo(pid, "forca")
	if v == "":
		v = u.valor_campo(pid, "potência")
	var n := Combate.ler_numero(v) if v != "" else -1.0
	var b := 1.0 + (0.3 if n < 0 else clampf(n / 10.0, 0.05, 3.0))
	if categoria(u, pid) == "magia":
		b = 1.0 + (b - 1.0) * clampf(float(Cosmos.leis(u)["magia"]) * 2.0, 0.0, 2.0)
	return b


## Ainda pode usar (respeita o "limite: N vezes por mês")?
static func pode_usar(u: Universo, eid: String, pid: String) -> bool:
	if categoria(u, pid) == "magia" and float(Cosmos.leis(u)["magia"]) < 0.05:
		return false  # neste universo a magia não funciona
	var lim := TextUtil.normalizar(u.valor_campo(pid, "limite"))
	if lim == "":
		return true
	var vezes := 1
	var rx := RegEx.new()
	rx.compile("(\\d+|uma|duas|tres|quatro|cinco)\\s+vez")
	var m := rx.search(lim)
	if m != null:
		vezes = int(Pecas._num(m.get_string(1)))
	var janela := Pecas._dias(lim, 36000000 if lim.contains("vida") or lim.contains("so uma vez") else 30)
	var desde := DataMundo.ordem(u.relogio) - janela
	var usos := 0
	for f in u.fatos.sobre(eid):
		if f["canon"] and str(f["dados"].get("poder", "")) == pid and f["dados"].get("acao", "") == "usar_poder" and DataMundo.ordem(f["data"]) > desde:
			usos += 1
	return usos < vezes


## Alguém usa um poder (contra alguém, ou não). Cria o fato do uso; aplica o custo;
## aplica os efeitos permitidos; se o poder for narrativo, cria um PEDIDO ao autor.
## Devolve {fatos: [ids], bonus: float, pedido: id}.
static func usar(u: Universo, eid: String, pid: String, alvo: String, causas: Array) -> Dictionary:
	var nome: String = u.entidade(eid)["nome"]
	var pnome: String = u.entidade(pid)["nome"]
	var narr := narrativo(u, pid)
	var contra: String = (" contra " + u.entidade(alvo)["nome"]) if alvo != "" else ""
	var desc := ("%s tentou usar %s%s." if narr else "%s usou %s%s.") % [nome, pnome, contra]
	var fid := Simulador.registrar(u, {
		"tipo": "uso de poder", "descricao": desc, "sujeitos": [eid, pid] + ([alvo] if alvo != "" else []),
		"lugar": u.estado(eid)["local"], "causas": causas.filter(func(c): return u.fatos.existe(c)),
		"dados": {"acao": "usar_poder", "poder": pid, "alvo": alvo, "narrativo": narr, "importancia": 0.5},
	})
	var r := {"fatos": [fid] if fid != "" else [], "bonus": 1.0 if narr else bonus(u, pid), "pedido": ""}
	if fid == "":
		return r
	var c := consequencias_do_uso(u, fid)
	r["fatos"].append_array(c["fatos"])
	r["pedido"] = c["pedido"]
	return r


## O que vem depois de usar um poder: o custo, os efeitos permitidos e, se for
## narrativo, o pedido ao autor. Vale para usos da simulação e dos capítulos.
static func consequencias_do_uso(u: Universo, fid: String) -> Dictionary:
	var f := u.fatos.obter(fid)
	var r := {"fatos": [], "pedido": ""}
	var pid := str(f["dados"].get("poder", ""))
	if pid == "" or not u.entidades.has(pid):
		return r
	var eid: String = f["sujeitos"][0]
	var alvo := str(f["dados"].get("alvo", ""))
	var pnome: String = u.entidade(pid)["nome"]
	var ctx := {"sujeito": eid, "outro": alvo, "lugar": f["lugar"]}
	# Poderes que mudam o motor (parar o tempo, sono eterno, ver o futuro…) valem pelo "efeito".
	var motor := u.valor_campo(pid, "efeitos permitidos") == "" and Pecas.ler(u, u.valor_campo(pid, "efeito")).any(func(e): return str(e.get("peca", "")) in PECAS_DO_MOTOR)
	for par in [["custo", "custo de "], ["efeitos permitidos", ""], ["efeito", ""]]:
		if par[0] == "efeitos permitidos" and narrativo(u, pid) and u.valor_campo(pid, "efeitos permitidos") == "":
			continue
		if par[0] == "efeito" and not motor:
			continue
		var txt := u.valor_campo(pid, par[0])
		if txt == "":
			continue
		var ops: Array = []
		var frases: Array = []
		for e in Pecas.ler(u, txt):
			ops.append_array(Pecas.operacoes(u, e, ctx))
			frases.append(Pecas.descrever(u, e))
		if ops.is_empty():
			continue
		var f2 := Simulador.registrar(u, {
			"tipo": "custo de poder" if par[0] == "custo" else "efeito de poder",
			"descricao": "%s%s: %s." % [par[1].capitalize() if par[1] != "" else "", pnome, "; ".join(frases)],
			"sujeitos": [eid] + ([alvo] if alvo != "" else []), "lugar": f["lugar"], "causas": [fid],
			"dados": {"importancia": 0.45, "mudancas": ops, "poder": pid},
		})
		if f2 != "":
			r["fatos"].append(f2)
	if narrativo(u, pid) and u.valor_campo(pid, "efeitos permitidos") == "" and not motor:
		r["pedido"] = criar_pedido(u, fid, eid, pid, alvo)
	return r


# ---------------------------------------------------------------- pedidos ao autor

static func pedidos(u: Universo, so_abertos: bool = true) -> Array:
	var lista: Array = u.extra("pedidos", [])
	if so_abertos:
		return lista.filter(func(p): return p["estado"] == "aberto" and u.fatos.obter(p["fato"]).get("canon", false))
	return lista


static func criar_pedido(u: Universo, fid: String, eid: String, pid: String, alvo: String) -> String:
	var id := Ids.novo("ped")
	u.extra("pedidos", []).append({"id": id, "fato": fid, "quem": eid, "poder": pid, "alvo": alvo, "estado": "aberto",
		"texto": u.fatos.obter(fid)["descricao"], "data": DataMundo.copiar(u.relogio)})
	u.marcar_mudanca()
	return id


## O autor diz o que o uso do poder fez (texto de efeito) — ou "" para "não funcionou".
static func responder_pedido(u: Universo, id: String, efeito: String) -> String:
	for p in pedidos(u, false):
		if p["id"] != id or p["estado"] != "aberto":
			continue
		var ctx := {"sujeito": p["quem"], "outro": p["alvo"], "lugar": u.estado(p["quem"])["local"]}
		var ops: Array = []
		var frases: Array = []
		if efeito.strip_edges() != "":
			for e in Pecas.ler(u, efeito):
				ops.append_array(Pecas.operacoes(u, e, ctx))
				frases.append(e["texto"])
		var pnome: String = u.entidade(p["poder"]).get("nome", "o poder")
		var fid := Simulador.registrar(u, {
			"tipo": "efeito de poder",
			"descricao": ("%s: %s." % [pnome, "; ".join(frases)]) if not frases.is_empty() else "%s não teve efeito." % pnome,
			"sujeitos": [p["quem"]] + ([p["alvo"]] if p["alvo"] != "" else []), "lugar": ctx["lugar"], "causas": [p["fato"]],
			"origem": {"tipo": BancoDeFatos.ORIGEM_AUTOR, "ref": "pedido"},
			"dados": {"importancia": 0.6, "mudancas": ops, "poder": p["poder"]},
		})
		p["estado"] = "respondido"
		p["resposta"] = fid
		u.marcar_mudanca()
		return fid
	return ""


## Numa luta: cada lado pode usar um poder. Devolve {fatos, bonus: {eid: mult}}.
static func na_luta(u: Universo, a: String, b: String, rng: RandomNumberGenerator, causas: Array) -> Dictionary:
	var r := {"fatos": [], "bonus": {}}
	for par in [[a, b], [b, a]]:
		var quem: String = par[0]
		if not Estado.tem_mente(u, quem):
			continue
		var lista := de(u, quem).filter(func(p): return pode_usar(u, quem, p))
		if lista.is_empty() or rng.randf() > 0.75:
			continue
		var pid: String = lista[rng.randi() % lista.size()]
		var uso := usar(u, quem, pid, par[1], causas)
		r["fatos"].append_array(uso["fatos"])
		r["bonus"][quem] = float(uso["bonus"])
	return r
