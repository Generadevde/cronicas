class_name Religioes
extends RefCounted
## Religiões que nascem e morrem. Um profeta (que surge do medo e da fé) junta
## seguidores; com fiéis bastantes, nasce uma religião (vira entidade na wiki). Ela se
## espalha pelos lugares onde a fé é forte, pode se dividir numa heresia e, sem
## fiéis vivos, desaparece — o templo vira ruína e a crença vira lenda.

const FIEIS_PARA_NASCER := 3


static func todas(u: Universo) -> Array:
	return u.entidades_ativas().filter(func(e): return e.get("sim", {}).has("religiao")).map(func(e): return e["id"])


static func marca(u: Universo, r: String) -> String:
	return "fiel de " + u.entidade(r)["nome"]


static func fieis(u: Universo, r: String) -> Array:
	var m := marca(u, r)
	return Simulador._mentes(u).filter(func(x): return Pecas.marcas(u, x).has(m))


static func viva(u: Universo, r: String) -> bool:
	return not u.estado(r).get("extinta", false)


static func passo(u: Universo, dias: int, rng: RandomNumberGenerator) -> Array:
	var ctrl: Dictionary = u.extra("religioes_ctrl", {"t": -999})
	var agora := DataMundo.ordem(u.relogio)
	if agora - int(ctrl["t"]) < 90:
		return []
	ctrl["t"] = agora
	var novos: Array = []
	# Nascer: um profeta com seguidores bastantes.
	for p in Simulador._mentes(u):
		if not Pecas.marcas(u, p).has("profeta") or u.estado(p).has("fundou_religiao"):
			continue
		var m: Variant = "seguidor de " + u.entidade(p)["nome"]
		var seg: Array = Simulador._mentes(u).filter(func(x): return Pecas.marcas(u, x).has(m))
		if seg.size() >= FIEIS_PARA_NASCER:
			novos.append(nascer(u, p, seg, rng))
	for r in todas(u):
		if not viva(u, r):
			continue
		var fs := fieis(u, r)
		if fs.is_empty():
			novos.append(_morrer(u, r))
			continue
		novos.append_array(_espalhar(u, r, fs, rng))
		if fs.size() >= 8 and not u.estado(r).has("heresia") and rng.randf() < 0.06:
			novos.append(_heresia(u, r, fs, rng))
	return novos.filter(func(x): return x != "")


static func nascer(u: Universo, profeta: String, seguidores: Array, rng: RandomNumberGenerator, nome: String = "") -> String:
	var lugar := str(u.estado(profeta).get("local", ""))
	if nome == "":
		var bases := ["Caminho", "Chama", "Voz", "Luz", "Círculo", "Véu"]
		nome = "%s de %s" % [bases[rng.randi() % bases.size()], u.entidade(profeta)["nome"].split(" ")[0]]
	var causa := ""
	for f in u.fatos.sobre(profeta):
		if f["canon"] and f["tipo"] == "profeta":
			causa = f["id"]
	var crenca := "o sofrimento é um sinal"
	if causa != "":
		var tx: String = u.fatos.obter(causa)["descricao"]
		var i := tx.find("que ")
		if i >= 0:
			crenca = tx.substr(i + 4).trim_suffix(".")
	var r := u.criar_entidade(nome, "religião", [], [{"chave": "profeta", "valor": u.entidade(profeta)["nome"]}, {"chave": "crença", "valor": crenca},
		{"chave": "lugar sagrado", "valor": u.entidade(lugar).get("nome", "")}], [causa] if causa != "" else [])
	var ops: Array = [{"op": "definir", "quem": r, "chave": "religiao", "valor": {"profeta": profeta, "berco": lugar}},
		{"op": "definir", "quem": profeta, "chave": "fundou_religiao", "valor": r}]
	for s in seguidores + [profeta]:
		ops.append({"op": "marca", "quem": s, "marca": "fiel de " + nome})
	return Simulador.registrar(u, {"tipo": "religião nova", "lugar": lugar, "sujeitos": [r, profeta], "causas": [causa] if causa != "" else [],
		"descricao": "Nasceu uma religião em %s: %s, de %s, que diz que %s." % [u.entidade(lugar).get("nome", "?"), nome, u.entidade(profeta)["nome"], crenca],
		"dados": {"importancia": 0.7, "mudancas": ops}})


static func _espalhar(u: Universo, r: String, fs: Array, rng: RandomNumberGenerator) -> Array:
	var lugares := {}
	for f in fs:
		lugares[str(u.estado(f)["local"])] = true
	var ops: Array = []
	for l in lugares:
		if l == "" or not Natureza.tem_natureza(u, l):
			continue
		var fe := float(Humor.de(u, l)["fe"])
		for m in Natureza._mentes_em(u, l):
			if Pecas.marcas(u, m).has(marca(u, r)) or Pecas.marcas(u, m).any(func(x): return str(x).begins_with("fiel de ")):
				continue
			if rng.randf() < 0.08 * fe * (1.0 + float(Personalidade.tracos(u, m)["lealdade"])):
				ops.append({"op": "marca", "quem": m, "marca": marca(u, r)})
	if ops.is_empty():
		return []
	return [Simulador.registrar(u, {"tipo": "conversão", "sujeitos": [r] + ops.map(func(o): return o["quem"]), "causas": [str(u.entidade(r).get("fato_criacao", ""))],
		"descricao": "%d pessoa%s passou a seguir %s." % [ops.size(), "" if ops.size() == 1 else "s", u.entidade(r)["nome"]],
		"dados": {"importancia": 0.3, "mudancas": ops}})]


static func _heresia(u: Universo, r: String, fs: Array, rng: RandomNumberGenerator) -> String:
	var lider: String = fs[0]
	for f in fs:
		var t := Personalidade.tracos(u, f)
		if float(t["orgulho"]) + float(t["ambicao"]) > float(Personalidade.tracos(u, lider)["orgulho"]) + float(Personalidade.tracos(u, lider)["ambicao"]):
			lider = f
	var nome := "%s Verdadeira" % u.entidade(r)["nome"]
	var h := u.criar_entidade(nome, "religião", [], [{"chave": "profeta", "valor": u.entidade(lider)["nome"]},
		{"chave": "crença", "valor": "só nós entendemos o que %s quis dizer" % u.entidade(r).get("nome", "")}, {"chave": "nasceu de", "valor": u.entidade(r)["nome"]}])
	var ops: Array = [{"op": "definir", "quem": h, "chave": "religiao", "valor": {"profeta": lider, "berco": str(u.estado(lider)["local"]), "de": r}},
		{"op": "definir", "quem": r, "chave": "heresia", "valor": h}]
	for f in fs:
		if f == lider or rng.randf() < 0.35:
			ops.append({"op": "desmarcar", "quem": f, "marca": marca(u, r)})
			ops.append({"op": "marca", "quem": f, "marca": "fiel de " + nome})
	return Simulador.registrar(u, {"tipo": "heresia", "sujeitos": [h, r, lider], "causas": [str(u.entidade(r).get("fato_criacao", ""))],
		"descricao": "%s rompeu com %s e fundou %s." % [u.entidade(lider)["nome"], u.entidade(r)["nome"], nome],
		"dados": {"importancia": 0.6, "mudancas": ops}})


static func _morrer(u: Universo, r: String) -> String:
	var berco := str(u.estado(r)["religiao"].get("berco", ""))
	var causa := str(u.entidade(r).get("fato_criacao", ""))
	var ids := u.fatos.ids_sobre(r)
	if not ids.is_empty():
		causa = ids.back()
	var ruina := Cidades.templo_em_ruinas(u, r, berco, causa) if berco != "" else ""
	return Simulador.registrar(u, {"tipo": "religião extinta", "lugar": berco, "sujeitos": [r] + ([ruina] if ruina != "" else []), "causas": [causa],
		"descricao": "%s desapareceu: não restou ninguém que acreditasse.%s" % [u.entidade(r)["nome"], (" O templo virou ruína.") if ruina != "" else ""],
		"dados": {"importancia": 0.55, "mudancas": [{"op": "definir", "quem": r, "chave": "extinta", "valor": true}]}})
