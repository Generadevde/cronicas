class_name Cronista
extends RefCounted
## O cronista do universo: escreve anais, biografias e relatos de guerra, sempre a
## partir do que realmente aconteceu (o banco de fatos). Três tons:
##   historiador — neutro, com datas;
##   povo        — com o viés de um povo (os seus são heróis, os inimigos são vilões);
##   bardo       — exagerado, como as lendas contam.

const TONS := ["historiador", "povo", "bardo"]


static func _linhas(u: Universo, fatos: Array, tom: String, povo: String) -> Array:
	var r: Array = []
	for f in fatos:
		var t: String = f["descricao"]
		match tom:
			"bardo":
				var v := Lendas.versao(u, f)
				if v["lenda"] != "":
					t = v["lenda"]
				else:
					t = "E então, como cantam os velhos, " + t.substr(0, 1).to_lower() + t.substr(1)
			"povo":
				if povo != "":
					var nome: String = u.entidade(povo)["nome"]
					var inimigos: Array = u.estado(povo).get("rancores", {}).keys().filter(func(k): return float(u.estado(povo)["rancores"][k]) >= 0.3)
					for i in inimigos:
						if u.entidades.has(i):
							t = t.replace(u.entidade(i)["nome"], "os pérfidos de %s" % u.entidade(i)["nome"])
					t = t.replace(nome, "o nosso glorioso %s" % nome)
		r.append("[color=#5A3A1A]%s[/color] — %s" % [DataMundo.texto(f["data"]), Paginas.link("fato:" + f["id"], t)])
	return r


static func _cabeca(titulo: String, tom: String, povo_nome: String) -> String:
	var sub: Variant = {"historiador": "como registrou o historiador", "povo": "como contam em %s" % povo_nome, "bardo": "como cantam os bardos"}.get(tom, "")
	return Paginas.cabecalho(titulo, sub)


## Anais: o que de importante aconteceu num ano.
static func anais(u: Universo, ano: int, tom: String = "historiador", povo: String = "") -> String:
	var fs: Array = u.fatos.todos().filter(func(f): return f["canon"] and int(f["data"]["ano"]) == ano and float(f["dados"].get("importancia", 0.2)) >= 0.6 and not f["tipo"] in ["notícia", "rumor"])
	var s := _cabeca("Anais do Ano %d" % ano, tom, u.entidade(povo).get("nome", "") if povo != "" else "")
	if fs.is_empty():
		return s + "[i]Um ano calmo. Os cronistas não acharam nada digno de nota.[/i]"
	return s + "\n".join(_linhas(u, fs.slice(0, 40), tom, povo))


## Biografia de alguém: nascimento, feitos, perdas, morte, e o que ficou.
static func biografia(u: Universo, eid: String, tom: String = "historiador", povo: String = "") -> String:
	var e := u.entidade(eid)
	var fs: Array = u.fatos.sobre(eid).filter(func(f): return f["canon"] and float(f["dados"].get("importancia", 0.2)) >= 0.4 and not f["tipo"] in ["notícia", "rumor", "criação"])
	var s := _cabeca("Vida de %s" % Lendas.nome_com_titulo(u, eid), tom, u.entidade(povo).get("nome", "") if povo != "" else "")
	var abertura := "%s %s." % [e["nome"], ("viveu e morreu" if not Estado.vivo(u, eid) else "ainda vive") if tom != "bardo" else "foi alguém de quem ainda se fala"]
	s += "[i]%s[/i]\n\n" % abertura
	s += "\n".join(_linhas(u, fs.slice(0, 40), tom, povo))
	var ls := Lendas.de(u, eid)
	if not ls.is_empty() and tom != "historiador":
		s += "\n\n[i]Dizem ainda: %s[/i]" % Lendas.versao(u, ls[0])["lenda"]
	return s


## Relato de uma guerra.
static func guerra(u: Universo, g: String, tom: String = "historiador", povo: String = "") -> String:
	var fs: Array = u.fatos.sobre(g).filter(func(f): return f["canon"] and f["tipo"] != "criação")
	var s := _cabeca(Guerras.dados(u, g).get("nome_lendario", u.estado(g).get("nome_lendario", u.entidade(g)["nome"])), tom, u.entidade(povo).get("nome", "") if povo != "" else "")
	return s + "\n".join(_linhas(u, fs, tom, povo))
