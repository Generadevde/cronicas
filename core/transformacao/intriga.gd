class_name Intriga
extends RefCounted
## Espiões, submundo, propaganda e mal-entendidos entre línguas.
##  • Espiões: rivais e inimigos plantam agentes; o espião rouba segredos (pactos,
##    técnicas, a previsão da guerra) e o lado dele luta melhor; pode ser descoberto
##    (ou virar agente duplo).
##  • Submundo: onde há fome, preço alto e gente fria, nasce uma guilda de ladrões;
##    ela rouba, contrabandeia e é perseguida.
##  • Propaganda: depois de uma derrota, o governo espalha a sua versão; o humor do
##    povo segue a história que vence, não a verdade.
##  • Línguas: tratados entre povos de línguas diferentes podem sair mal traduzidos.


static func passo(u: Universo, dias: int, rng: RandomNumberGenerator) -> Array:
	var ctrl: Dictionary = u.extra("intriga_ctrl", {"t": -999, "visto": 0})
	var agora := DataMundo.ordem(u.relogio)
	var novos: Array = []
	novos.append_array(_propaganda(u, rng, ctrl))
	if agora - int(ctrl["t"]) < 90:
		return novos.filter(func(x): return x != "")
	ctrl["t"] = agora
	novos.append_array(_espioes(u, rng))
	novos.append_array(_submundo(u, rng))
	return novos.filter(func(x): return x != "")


# ---------------------------------------------------------------- espiões

static func espiao_de(u: Universo, eid: String) -> String:
	for m in Pecas.marcas(u, eid):
		if str(m).begins_with("espião de "):
			var nome := str(m).trim_prefix("espião de ")
			for sid in Sociedades.todas(u):
				if u.entidade(sid)["nome"] == nome:
					return sid
	return ""


## Quantos espiões uma sociedade tem dentro de outra (dá vantagem na guerra).
static func espioes_em(u: Universo, de: String, em: String) -> int:
	var n := 0
	for m in Sociedades.membros(u, em):
		if espiao_de(u, m) == de and not Pecas.marcas(u, m).has("espião descoberto"):
			n += 1
	return n


static func _espioes(u: Universo, rng: RandomNumberGenerator) -> Array:
	var novos: Array = []
	var socs: Array = Sociedades.todas(u).filter(func(s): return not Sociedades.tipo(u, s) in ["corporacao", "ordem", "anarquia"])
	for a in socs:
		for b in socs:
			if a == b:
				continue
			var rivais := Guerras.em_guerra(u, a, b) != "" or Guerras.rancor(u, a, b) >= 0.4 or TextUtil.chave(Sociedades._campo(u, a, ["inimig", "rival"])).contains(TextUtil.chave(u.entidade(b)["nome"]))
			if not rivais:
				continue
			# Recrutar: alguém de B, pouco leal e ambicioso, vende-se para A.
			if espioes_em(u, a, b) == 0 and rng.randf() < 0.25:
				var melhor := ""
				var nota := 0.0
				for m in Sociedades.membros(u, b):
					var t := Personalidade.tracos(u, m)
					var x := float(t["ambicao"]) - float(t["lealdade"]) + rng.randf() * 0.2
					if x > nota and espiao_de(u, m) == "" and Sociedades.lider(u, b) != m:
						nota = x
						melhor = m
				if melhor != "" and nota > 0.2:
					novos.append(Simulador.registrar(u, {"tipo": "espionagem", "sujeitos": [melhor, a, b], "lugar": u.estado(melhor)["local"],
						"causas": [Guerras._fato_entre(u, a, b)], "descricao": "%s passou a espionar %s para %s." % [u.entidade(melhor)["nome"], u.entidade(b)["nome"], u.entidade(a)["nome"]],
						"dados": {"importancia": 0.5, "secreto": true, "mudancas": [{"op": "marca", "quem": melhor, "marca": "espião de " + u.entidade(a)["nome"]}, {"op": "conhecer", "quem": melhor}]}}))
			# Os espiões roubam segredos e às vezes são pegos.
			for m in Sociedades.membros(u, b):
				if espiao_de(u, m) != a or Pecas.marcas(u, m).has("espião descoberto"):
					continue
				var lb := Sociedades.lider(u, b)
				var pega := 0.12 * (float(Personalidade.tracos(u, lb)["prudencia"]) if lb != "" else 0.5)
				if rng.randf() < pega:
					var ops: Array = [{"op": "marca", "quem": m, "marca": "espião descoberto"}]
					var texto := "%s descobriu que %s espionava para %s" % [u.entidade(b)["nome"], u.entidade(m)["nome"], u.entidade(a)["nome"]]
					if rng.randf() < 0.3:
						ops.append({"op": "marca", "quem": m, "marca": "agente duplo"})
						texto += ", e o fez virar agente duplo"
					else:
						ops.append({"op": "ferir", "quem": m, "descricao": "preso e torturado", "gravidade": 0.4})
						ops.append({"op": "marca", "quem": m, "marca": "preso"})
					ops.append({"op": "rancor", "de": b, "para": a, "delta": 0.2})
					novos.append(Simulador.registrar(u, {"tipo": "espião descoberto", "sujeitos": [m, a, b], "lugar": u.estado(m)["local"],
						"causas": [_fato_da_marca(u, m, "espionagem")], "descricao": texto + ".", "dados": {"importancia": 0.6, "mudancas": ops}}))
					continue
				var segredo := _segredo(u, b, m)
				if segredo != "" and rng.randf() < 0.4:
					var la := Sociedades.lider(u, a)
					var ops2: Array = [{"op": "conhecer", "quem": m, "fato": segredo}]
					if la != "":
						ops2.append({"op": "conhecer", "quem": la, "fato": segredo})
					novos.append(Simulador.registrar(u, {"tipo": "segredo roubado", "sujeitos": [m, a, b], "lugar": u.estado(m)["local"], "causas": [segredo],
						"descricao": "%s roubou um segredo de %s para %s: %s" % [u.entidade(m)["nome"], u.entidade(b)["nome"], u.entidade(a)["nome"], u.fatos.obter(segredo)["descricao"]],
						"dados": {"importancia": 0.5, "secreto": true, "mudancas": ops2}}))
	return novos


## Um segredo que o espião pode levar: um fato secreto de alguém da sociedade.
static func _segredo(u: Universo, sid: String, espiao: String) -> String:
	for m in Sociedades.membros(u, sid).slice(0, 30):
		for fid in u.fatos.ids_sobre(m):
			var f := u.fatos.obter(fid)
			if f["canon"] and f["dados"].get("secreto", false) and not Estado.conhece(u, espiao, fid) and f["tipo"] != "espionagem":
				return fid
	return ""


static func _fato_da_marca(u: Universo, eid: String, tipo: String) -> String:
	var ids := u.fatos.ids_sobre(eid)
	for i in range(ids.size() - 1, -1, -1):
		if u.fatos.obter(ids[i])["tipo"] == tipo:
			return ids[i]
	return Simulador.causa_de_presenca(u, eid)


# ---------------------------------------------------------------- submundo

static func guilda_em(u: Universo, lugar: String) -> String:
	for e in u.entidades_ativas():
		if str(e.get("sim", {}).get("submundo", "")) == lugar:
			return e["id"]
	return ""


static func _submundo(u: Universo, rng: RandomNumberGenerator) -> Array:
	var novos: Array = []
	for e in u.entidades_ativas():
		var l: String = e["id"]
		if Mapa.especie(u, l) != "povoado" or not Natureza.tem_natureza(u, l) or Motor.adormecido(u, l):
			continue
		var gente := Natureza._mentes_em(u, l)
		var frios: Array = gente.filter(func(m): return float(Personalidade.tracos(u, m)["empatia"]) < 0.35 and float(Personalidade.tracos(u, m)["ambicao"]) > 0.55)
		var g := guilda_em(u, l)
		var miseria := float(Humor.de(u, l)["raiva"]) + maxf(0.0, Economia.preco(u, l) - 1.0)
		if g == "":
			if frios.size() >= 2 and miseria > 0.3 and rng.randf() < 0.3:
				var nome := "%s de %s" % [["Os Mãos Leves", "A Irmandade da Sombra", "Os Ratos do Cais", "A Lâmina Cinza"][rng.randi() % 4], e["nome"]]
				var gid := u.criar_entidade(nome, "guilda criminosa", [], [{"chave": "chefe", "valor": u.entidade(frios[0])["nome"]}, {"chave": "sede", "valor": e["nome"]}],
					[Natureza._ultimo_fato_natural(u, l)])
				var ops: Array = [{"op": "definir", "quem": gid, "chave": "submundo", "valor": l}]
				for f in frios.slice(0, 4):
					ops.append({"op": "marca", "quem": f, "marca": "membro de " + nome})
				novos.append(Simulador.registrar(u, {"tipo": "submundo", "lugar": l, "sujeitos": [gid] + frios.slice(0, 4), "causas": [Natureza._ultimo_fato_natural(u, l)],
					"descricao": "Nasceu em %s uma guilda de ladrões: %s." % [e["nome"], nome], "dados": {"importancia": 0.5, "mudancas": ops}}))
			continue
		# A guilda age: rouba alguém rico ou contrabandeia; a sociedade persegue.
		var x := rng.randf()
		var sid := Sociedades.de_lugar(u, l)
		if x < 0.35:
			var vitima := ""
			for m in gente:
				if Pecas.marcas(u, m).has("rico") or float(u.estado(m).get("reputacao", 0.0)) > 1.0:
					vitima = m
			if vitima != "":
				novos.append(Simulador.registrar(u, {"tipo": "roubo", "lugar": l, "sujeitos": [g, vitima], "causas": [str(u.entidade(g).get("fato_criacao", ""))],
					"descricao": "%s roubou %s." % [u.entidade(g)["nome"], u.entidade(vitima)["nome"]],
					"dados": {"importancia": 0.4, "mudancas": [{"op": "desmarcar", "quem": vitima, "marca": "rico"}, {"op": "emocao", "quem": vitima, "emocao": "raiva", "forca": 0.6, "alvo": g}]}}))
		elif x < 0.6 and sid != "":
			var eco := Economia.dados(u)
			if not eco.has("riqueza"):
				eco["riqueza"] = {}
			eco["riqueza"][sid] = maxf(0.0, Economia.riqueza(u, sid) - 0.3)
			novos.append(Simulador.registrar(u, {"tipo": "contrabando", "lugar": l, "sujeitos": [g, sid], "causas": [str(u.entidade(g).get("fato_criacao", ""))],
				"descricao": "%s contrabandeia mercadorias por %s, e %s perde impostos." % [u.entidade(g)["nome"], e["nome"], u.entidade(sid)["nome"]],
				"dados": {"importancia": 0.3, "mudancas": []}}))
		elif x < 0.7 and sid != "":
			var membros: Array = gente.filter(func(m): return Pecas.marcas(u, m).has("membro de " + u.entidade(g)["nome"]))
			if not membros.is_empty():
				var preso: String = membros[rng.randi() % membros.size()]
				novos.append(Simulador.registrar(u, {"tipo": "prisão", "lugar": l, "sujeitos": [preso, g, sid], "causas": [str(u.entidade(g).get("fato_criacao", ""))],
					"descricao": "%s prendeu %s, de %s." % [u.entidade(sid)["nome"], u.entidade(preso)["nome"], u.entidade(g)["nome"]],
					"dados": {"importancia": 0.4, "mudancas": [{"op": "marca", "quem": preso, "marca": "preso"}]}}))
	return novos


# ---------------------------------------------------------------- propaganda e línguas

## Depois de um fato ruim para um governo, ele espalha a sua versão.
static func _propaganda(u: Universo, rng: RandomNumberGenerator, ctrl: Dictionary) -> Array:
	var novos: Array = []
	var todos := u.fatos.todos()
	var ate := int(ctrl["visto"])
	for i in range(todos.size() - 1, -1, -1):
		var f: Dictionary = todos[i]
		if int(f["seq"]) <= int(ctrl["visto"]):
			break
		ate = maxi(ate, int(f["seq"]))
		if not f["canon"] or not f["tipo"] in ["batalha", "revolta esmagada", "fim da guerra", "queda do governo", "ocupação"]:
			continue
		var perdedor := ""
		match str(f["tipo"]):
			"batalha":
				perdedor = str(f["dados"].get("perdedor", ""))
			"fim da guerra":
				var g := str(f["dados"].get("guerra", ""))
				var v := str(f["dados"].get("vencedor", ""))
				for lado in ["a", "b"]:
					var s0: String = Guerras.dados(u, g).get(lado, [""])[0]
					if s0 != v and v != "":
						perdedor = s0
			"ocupação":
				perdedor = str(f["sujeitos"][2]) if f["sujeitos"].size() > 2 else ""
		if perdedor == "" or not u.entidades.has(perdedor):
			continue
		var lider := Sociedades.lider(u, perdedor)
		if lider == "" or not u.entidades.has(lider):
			continue
		var t := Personalidade.tracos(u, lider)
		if float(t["orgulho"]) + float(t["ambicao"]) < 0.9 or rng.randf() > 0.7:
			continue
		var versao: Variant = {"batalha": "foi uma retirada estratégica, e o inimigo perdeu muito mais", "fim da guerra": "foi uma paz honrosa, arrancada à força",
			"ocupação": "foi um sacrifício necessário, e a cidade será retomada"}.get(f["tipo"], "foi culpa de traidores")
		var credito := clampf(0.5 + float(u.estado(lider).get("reputacao", 0.0)) * 0.1, 0.1, 0.9)
		for l in Sociedades.territorio(u, perdedor):
			if Natureza.tem_natureza(u, l):
				var h := Humor.de(u, l)
				h["raiva"] = clampf(float(h["raiva"]) - 0.1 * credito, 0.0, 1.0)
		novos.append(Simulador.registrar(u, {"tipo": "propaganda", "sujeitos": [perdedor, lider], "causas": [f["id"]],
			"descricao": "Segundo %s, %s %s." % [u.entidade(perdedor)["nome"], _primeira_minuscula(f["descricao"].split(":")[0].trim_suffix(".")), versao],
			"dados": {"importancia": 0.45, "versao_de": f["id"], "credito": credito, "mudancas": []}}))
	ctrl["visto"] = ate
	return novos


static func _primeira_minuscula(t: String) -> String:
	return t.substr(0, 1).to_lower() + t.substr(1) if t != "" else t


## Um tratado entre povos de línguas diferentes pode sair mal traduzido.
static func tratado_mal_traduzido(u: Universo, fim: String, rng: RandomNumberGenerator) -> String:
	var f := u.fatos.obter(fim)
	var g := str(f["dados"].get("guerra", ""))
	var d := Guerras.dados(u, g)
	if d.is_empty():
		return ""
	var a: String = d["a"][0]
	var b: String = d["b"][0]
	var la := Linguas.do_lugar(u, Guerras._sede(u, a))
	var lb := Linguas.do_lugar(u, Guerras._sede(u, b))
	if la == lb or la == "" or lb == "" or rng.randf() > 0.35:
		return ""
	return Simulador.registrar(u, {"tipo": "mal-entendido", "sujeitos": [a, b], "causas": [fim],
		"descricao": "O %s foi mal traduzido: em %s, cada lado entendeu uma coisa sobre as fronteiras." % [str(f["dados"].get("tratado", "tratado")), la + " e " + lb],
		"dados": {"importancia": 0.5, "mudancas": [{"op": "rancor", "de": a, "para": b, "delta": 0.2}, {"op": "rancor", "de": b, "para": a, "delta": 0.2}]}})
