class_name Lendas
extends RefCounted
## Lendas, títulos e nomes. Tudo vem do que realmente aconteceu (os fatos):
##  • batalhas ganham nome ("Os Dez Dias de Aldra", "A Noite dos Fantasmas do Deserto");
##  • pessoas ganham títulos ("Jhon Black, o Inquebrável", "Sirius, o Matador de Gigantes");
##  • lugares ganham nome de guerra ("Vale dos Ossos"), e o nome antigo fica na história;
##  • lendas se distorcem com o tempo (dez dias viram trinta, o vencedor vira um deus),
##    mas a verdade fica guardada no fato;
##  • lendas mexem com o mundo: soldados invocam o herói (moral), cultos surgem em volta dele.

const NUMEROS := ["zero", "Um", "Dois", "Três", "Quatro", "Cinco", "Seis", "Sete", "Oito", "Nove", "Dez", "Onze", "Doze", "Treze",
	"Catorze", "Quinze", "Dezesseis", "Dezessete", "Dezoito", "Dezenove", "Vinte"]


static func extenso(n: int) -> String:
	if n >= 0 and n < NUMEROS.size():
		return NUMEROS[n]
	if n == 30:
		return "Trinta"
	if n == 40:
		return "Quarenta"
	if n == 50:
		return "Cinquenta"
	if n == 100:
		return "Cem"
	return str(n)


# ---------------------------------------------------------------- nomes de batalhas

static func nome_da_batalha(u: Universo, info: Dictionary) -> String:
	var lugar: String = info.get("lugar", "")
	var nome_l := str(u.entidade(lugar).get("nome", "")) if lugar != "" else ""
	var guerra: String = info.get("guerra", "")
	var base := ""
	var criatura := ""
	for f in info.get("forcas", []):
		if Forcas.tipo(u, f) in ["sobrenaturais", "monstros"]:
			criatura = _criaturas_do_nome(str(u.entidade(f)["nome"]))
			if criatura != "":
				break
	var mortos := float(info.get("mortos", 0.0))
	var engajados := maxf(1.0, float(info.get("engajados", 1.0)))
	var dias := int(info.get("dias", 1))
	if info.get("noite", false) and criatura != "":
		base = "A Noite dos %s" % criatura
	elif dias >= 3:
		base = "Os %s Dias de %s" % [extenso(dias), nome_l if nome_l != "" else u.entidade(guerra).get("nome", "")]
	elif mortos / engajados > 0.22 and nome_l != "":
		base = "O Massacre de %s" % nome_l
	elif str(info.get("vencedor_tipo", "")) == "avioes" and nome_l != "":
		base = "O Céu de Fogo sobre %s" % nome_l
	elif nome_l != "":
		base = "A Batalha de %s" % nome_l
	else:
		base = "A Batalha da %s" % u.entidade(guerra).get("nome", "Guerra")
	return _unico(u, base)


## "Exército de fantasmas do deserto" → "Fantasmas do Deserto".
static func _criaturas_do_nome(nome: String) -> String:
	var n := TextUtil.normalizar(nome)
	for w in Guerras.PALAVRAS_DE_TROPA:
		var i := n.find(w + " de ")
		if i >= 0:
			var resto := nome.substr(i + w.length() + 4).strip_edges()
			var partes: Array = []
			for p in resto.split(" ", false):
				partes.append(p if p.to_lower() in ["de", "do", "da", "dos", "das", "e"] else p.substr(0, 1).to_upper() + p.substr(1))
			return " ".join(partes)
	return ""


static func _unico(u: Universo, base: String) -> String:
	var usados := 0
	for f in u.fatos.todos():
		if f["canon"] and str(f["dados"].get("nome", "")).begins_with(base) and f["dados"].get("batalha", false):
			usados += 1
	if usados == 0:
		return base
	var ord := ["", "", "Segunda", "Terceira", "Quarta", "Quinta", "Sexta", "Sétima"]
	if base.begins_with("A Batalha de "):
		return "A %s Batalha de %s" % [ord[mini(usados + 1, 7)], base.substr("A Batalha de ".length())]
	return "%s (%s vez)" % [base, ord[mini(usados + 1, 7)].to_lower()]


# ---------------------------------------------------------------- lugares com nome de guerra

const NOMES_DE_GUERRA := {
	"deserto": "as Areias Vermelhas", "campo": "o Campo das Cinzas", "planicie": "o Campo das Cinzas", "colina": "a Colina dos Mortos",
	"montanha": "o Passo dos Ossos", "floresta": "a Mata dos Lamentos", "agua": "as Águas Rubras", "pantano": "o Brejo dos Mortos",
	"gelo": "o Gelo Vermelho",
}


## Depois de uma batalha muito sangrenta, o lugar pode ganhar um nome de guerra.
static func nome_de_lugar(u: Universo, lugar: String, mortos: float, engajados: float, rng: RandomNumberGenerator) -> String:
	if lugar == "" or u.estado(lugar).has("nome_de_guerra"):
		return ""
	if mortos < 1500.0 and mortos / maxf(1.0, engajados) < 0.25:
		return ""
	if rng.randf() > 0.45:
		return ""
	var t := Mapa.terreno_do_lugar(u, lugar)
	var nome: String = NOMES_DE_GUERRA.get(t, "o Vale dos Ossos")
	return nome.substr(0, 1).to_upper() + nome.substr(1)


# ---------------------------------------------------------------- títulos

static func titulo(u: Universo, eid: String) -> String:
	return str(u.estado(eid).get("titulo", ""))


## "Jhon Black, o Inquebrável".
static func nome_com_titulo(u: Universo, eid: String) -> String:
	var t := titulo(u, eid)
	var n: String = u.entidade(eid).get("nome", "?")
	return n if t == "" else "%s, %s" % [n, t]


static func _dar(u: Universo, eid: String, t: String, causa: String) -> String:
	if eid == "" or t == "" or titulo(u, eid) != "" or not Estado.tem_mente(u, eid):
		return ""
	return Simulador.registrar(u, {"tipo": "título", "descricao": "%s passou a ser chamado de %s, %s." % [u.entidade(eid)["nome"], u.entidade(eid)["nome"].split(" ")[0], t],
		"sujeitos": [eid], "causas": [causa], "dados": {"importancia": 0.55, "titulo": t, "mudancas": [{"op": "definir", "quem": eid, "chave": "titulo", "valor": t}]}})


## Título de quem venceu uma luta (vem do que aconteceu nela).
static func titulo_de_luta(chance_do_vencedor: float, dias: int, morte: bool, venc_forca: float, perd_forca: float) -> String:
	if chance_do_vencedor < 0.42 or perd_forca > venc_forca * 1.25:
		return "o Matador de Gigantes"
	if dias >= 7:
		return "o Inquebrável"
	if morte:
		return "o Implacável"
	return ""


## Herói de uma batalha: depois da terceira vitória, ganha um título.
static func dar_titulo_de_batalha(u: Universo, eid: String, g: String, fid: String, lado: String) -> void:
	if titulo(u, eid) != "":
		return
	var vitorias := 0
	for b in Guerras.dados(u, g).get("batalhas", []):
		var f := u.fatos.obter(b)
		if f.get("canon", false) and f["dados"].get("heroi", "") == eid:
			vitorias += 1
	var f0 := u.fatos.obter(fid)
	if f0["dados"].get("noite", false) and _ha_criaturas(u, f0):
		_dar(u, eid, "Senhor da Noite", fid)
	elif vitorias >= 3:
		var sede := Guerras._sede(u, str(f0["dados"].get("vencedor", "")))
		_dar(u, eid, "o Conquistador" if lado == "a" else ("o Escudo de %s" % u.entidade(sede)["nome"] if sede != "" else "o Escudo"), fid)


static func _ha_criaturas(u: Universo, f: Dictionary) -> bool:
	return str(f["dados"].get("nome", "")).begins_with("A Noite dos")


## No fim da guerra: o maior herói de cada lado ganha título (se ainda não tiver).
static func titulos_da_guerra(u: Universo, g: String, fim: String) -> Array:
	var conta := {}
	for b in Guerras.dados(u, g).get("batalhas", []):
		var f := u.fatos.obter(b)
		var h := str(f.get("dados", {}).get("heroi", ""))
		if f.get("canon", false) and h != "" and Estado.vivo(u, h):
			conta[h] = int(conta.get(h, 0)) + 1
	var novos: Array = []
	var melhor := ""
	for h in conta:
		if melhor == "" or int(conta[h]) > int(conta[melhor]):
			melhor = h
	if melhor != "" and int(conta[melhor]) >= 2:
		var venc := str(u.fatos.obter(fim)["dados"].get("vencedor", ""))
		var lado := Guerras.lado_de(u, g, venc)
		var t := "o Vencedor da %s" % u.entidade(g)["nome"] if lado != "" and Sociedades.membros(u, venc).has(melhor) else "o Último a Cair"
		var fid := _dar(u, melhor, t, fim)
		if fid != "":
			novos.append(fid)
	return novos


# ---------------------------------------------------------------- lendas que se distorcem

## Fatos que viraram lenda sobre alguém (lutas, batalhas, títulos).
static func de(u: Universo, eid: String) -> Array:
	var lista: Array = []
	for f in u.fatos.sobre(eid):
		if not f["canon"]:
			continue
		if f["dados"].get("batalha", false) and f["dados"].get("heroi", "") == eid:
			lista.append(f)
		elif f["dados"].get("luta_resolvida", false) and f["sujeitos"].size() > 0 and f["sujeitos"][0] == eid:
			lista.append(f)
	return lista


## O que se conta hoje sobre um fato. {lenda, verdade, anos}
static func versao(u: Universo, f: Dictionary) -> Dictionary:
	var anos := (DataMundo.ordem(u.relogio) - DataMundo.ordem(f["data"])) / float(DataMundo.DIAS_POR_ANO)
	var exagero := 1.0 + anos / 15.0
	var verdade: String = f["descricao"]
	var lenda := ""
	if anos < 5:
		return {"lenda": "", "verdade": verdade, "anos": anos}
	var dd: Dictionary = f["dados"]
	if dd.get("luta_resolvida", false):
		var dias := int(dd.get("dias", 1))
		var venc: String = u.entidade(f["sujeitos"][0]).get("nome", "?")
		var perd: String = u.entidade(f["sujeitos"][1]).get("nome", "?") if f["sujeitos"].size() > 1 else "?"
		var dias_l := _arredondar(dias * exagero)
		lenda = "Contam que %s e %s lutaram por %d dias" % [venc, perd, dias_l] if dias > 1 else "Contam que %s derrubou %s com um só golpe" % [venc, perd]
		if anos >= 60 and float(u.estado(f["sujeitos"][0]).get("reputacao", 0.0)) >= 1.5:
			lenda += ", e que %s não era um homem, mas um deus" % venc
		lenda += "."
	elif dd.get("batalha", false):
		var heroi := str(dd.get("heroi", ""))
		var mortos := _arredondar(float(dd.get("mortos", 0.0)) * exagero)
		lenda = "Dizem que em %s caíram %s" % [dd.get("nome", "batalha"), Forcas.numero(mortos)]
		if heroi != "":
			lenda += ", e que %s lutou sozinho contra um exército" % u.entidade(heroi).get("nome", "?")
			if anos >= 60:
				lenda += " — hoje há quem reze para ele"
		lenda += "."
	return {"lenda": lenda, "verdade": verdade, "anos": anos}


static func _arredondar(x: float) -> int:
	if x < 12:
		return int(roundf(x))
	if x < 100:
		return int(roundf(x / 5.0) * 5)
	return int(roundf(x / 100.0) * 100)


# ---------------------------------------------------------------- lendas que mexem com o mundo

## Moral extra de um lado pelos heróis lendários dele (soldados invocam o nome; os
## inimigos temem a lenda). 1.0 a 1.2.
static func inspiracao(u: Universo, nossos: Array, deles: Array) -> float:
	var b := 1.0
	for sid in nossos:
		for eid in _herois_de(u, sid):
			b += 0.05
		b += 0.03 * mini(3, Legado.cancoes_de(u, sid))  # os soldados cantam os heróis
	return minf(b, 1.2)


static func _herois_de(u: Universo, sid: String) -> Array:
	return Sociedades._lembrar(u, "herois|%s|%d" % [sid, DataMundo.ordem(u.relogio) / 90], func():
		var lista: Array = []
		for e in u.entidades_ativas():
			var eid: String = e["id"]
			if titulo(u, eid) == "" or not Estado.tem_mente(u, eid):
				continue
			if Sociedades.membros(u, sid).has(eid) or Sociedades.de_lugar(u, u.estado(eid).get("local", "")) == sid:
				lista.append(eid)
		return lista)


## Uma vez por ano: heróis mortos há tempo viram culto onde a fé é forte.
static func passo(u: Universo, dias: int, rng: RandomNumberGenerator) -> Array:
	var ctrl: Dictionary = u.extra("lendas_ctrl", {"ultimo": -999})
	var agora := DataMundo.ordem(u.relogio)
	if agora - int(ctrl["ultimo"]) < DataMundo.DIAS_POR_ANO:
		return []
	ctrl["ultimo"] = agora
	var novos: Array = []
	for e in u.entidades_ativas():
		var eid: String = e["id"]
		if titulo(u, eid) == "" or Estado.vivo(u, eid) or u.estado(eid).get("culto", false):
			continue
		var morte: Dictionary = u.estado(eid).get("morte", {})
		if morte.is_empty() or agora - DataMundo.ordem(morte) < 20 * DataMundo.DIAS_POR_ANO:
			continue
		var lugar: String = u.estado(eid).get("local", "")
		if lugar == "" or float(Humor.de(u, lugar)["fe"]) < 0.4 or rng.randf() > 0.15:
			continue
		var ops: Array = [{"op": "definir", "quem": eid, "chave": "culto", "valor": true}]
		for m in Natureza._mentes_em(u, lugar).slice(0, 3):
			ops.append({"op": "marca", "quem": m, "marca": "devoto de " + e["nome"]})
		var causa := ""
		var ls := de(u, eid)
		if not ls.is_empty():
			causa = ls.back()["id"]
		novos.append(Simulador.registrar(u, {"tipo": "culto", "descricao": "Em %s surgiu um culto a %s." % [u.entidade(lugar)["nome"], nome_com_titulo(u, eid)],
			"sujeitos": [eid, lugar], "lugar": lugar, "causas": [causa] if causa != "" else [], "dados": {"importancia": 0.6, "mudancas": ops}}))
	return novos
