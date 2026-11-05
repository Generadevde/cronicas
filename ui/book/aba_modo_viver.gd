extends AbaLivro
## Aba "Modo Viver": você é um personagem. Só sabe o que ele sabe, só pode o que ele
## pode, e o resto do mundo segue simulando. À esquerda, o caderno dele (ficha,
## relações, objetivos e pertences, notícias que chegaram, diário); à direita, a cena,
## o mapa local (com névoa no que ele não conhece) e o que você escreve que ele faz.

static var _modo := "ficha"
static var _ultimo := ""   ## o que aconteceu na última ação
static var _novo := {"nome": "", "lugar": "", "idade": "20", "jeito": "", "oficio": "", "origem": "", "familia": ""}
static var _voz := "primeira"

var _dir: VBoxContainer
var _esq: VBoxContainer


func montar(esq: VBoxContainer, dir: VBoxContainer, dado: String) -> void:
	_dir = dir
	_esq = esq
	if dado != "" and u.entidades.has(dado) and Estado.tem_mente(u, dado) and Estado.vivo(u, dado):
		Vivencia.comecar(u, dado, _voz)
		_ultimo = ""
	var eid := Vivencia.encarnado(u)
	if eid == "":
		_escolher()
		return
	var s := Vivencia.sessao(u)
	esq.add_child(Tema.secao("O caderno de %s" % u.entidade(eid)["nome"]))
	var modos := HBoxContainer.new()
	for m in [["ficha", "Ficha"], ["relacoes", "Relações"], ["objetivos", "Planos"], ["noticias", "Notícias"], ["diario", "Diário"]]:
		var b := Tema.botao(m[1])
		b.toggle_mode = true
		b.button_pressed = m[0] == _modo
		b.pressed.connect(func():
			_modo = m[0]
			livro.ir_para_aba("modo_viver"))
		modos.add_child(b)
	esq.add_child(modos)
	var t := Tema.texto_rico()
	t.meta_clicked.connect(_meta)
	match _modo:
		"ficha":
			t.text = _ficha(eid)
		"relacoes":
			t.text = _relacoes(eid)
		"objetivos":
			t.text = _objetivos(eid)
		"noticias":
			t.text = _noticias(eid)
		_:
			t.text = _diario(s)
	esq.add_child(t)
	if _modo == "diario":
		t.scroll_to_line(t.get_line_count())
	var fim := Tema.botao("Virar capítulo", "A sessão vira um capítulo no livro \"Vidas\" (os fatos já existem)")
	fim.pressed.connect(func():
		var cap := Vivencia.virar_capitulo(u, "", str(s["voz"]))
		livro.avisar("A vida de %s virou capítulo." % u.entidade(eid)["nome"])
		livro.ir_para_aba("escrever", cap))
	var voz := Tema.botao("Primeira pessoa" if str(s["voz"]) == "primeira" else "Terceira pessoa", "Trocar a voz da narração")
	voz.pressed.connect(func():
		s["voz"] = "terceira" if str(s["voz"]) == "primeira" else "primeira"
		_voz = s["voz"]
		livro.ir_para_aba("modo_viver"))
	var sair := Tema.botao("Parar de viver", "O personagem volta a decidir sozinho. A sessão fica guardada para voltar depois.")
	sair.pressed.connect(func():
		Vivencia.parar(u)
		livro.ir_para_aba("modo_viver"))
	esq.add_child(linha([fim, voz, sair]))
	_cena(eid, s)


func _meta(meta) -> void:
	var m := str(meta)
	if m.begins_with("viver:"):
		livro.ir_para_aba("modo_viver", m.trim_prefix("viver:"))
	elif m.begins_with("retomar:"):
		livro.ir_para_aba("modo_viver", m.trim_prefix("retomar:"))
	else:
		livro.navegar(meta)


# ---------------------------------------------------------------- a cena (direita)

func _cena(eid: String, s: Dictionary) -> void:
	var t := Tema.texto_rico()
	t.meta_clicked.connect(_meta)
	t.fit_content = true
	t.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var lig := Ligador.new(u)
	var texto := Paginas.cabecalho("A cena", "você é %s" % u.entidade(eid)["nome"])
	for l in Vivencia.cena(u, eid).split("\n"):
		texto += lig.para_bbcode(l) + "\n"
	if _ultimo != "":
		texto += "\n[color=#7A2418][i]%s[/i][/color]\n" % lig.para_bbcode(_ultimo)
	t.text = texto
	_dir.add_child(t)
	# Agir: palavras livres.
	var campo_a := campo("O que %s faz? (ex.: vou até a forja e peço trabalho a Lucas)" % u.entidade(eid)["nome"].split(" ")[0])
	var agir := Tema.botao_principal("Agir")
	var faz := func():
		if campo_a.text.strip_edges() == "":
			return
		var r := Vivencia.agir(u, campo_a.text)
		_ultimo = r["texto"]
		livro.atualizar_cabecalho()
		livro.ir_para_aba("modo_viver")
	agir.pressed.connect(faz)
	campo_a.text_submitted.connect(func(_t): faz.call())
	_dir.add_child(linha([campo_a, agir]))
	var atalhos: Array = []
	for par in [["Comer", "como"], ["Dormir", "durmo"], ["Explorar", "exploro os arredores"], ["Esperar um dia", "espero um dia"], ["Uma semana", "espero uma semana"]]:
		var b := Tema.botao(par[0])
		b.pressed.connect(func():
			_ultimo = Vivencia.agir(u, par[1])["texto"]
			livro.atualizar_cabecalho()
			livro.ir_para_aba("modo_viver"))
		atalhos.append(b)
	_dir.add_child(linha(atalhos))
	# O mapa local: só o que ele conhece; o resto em névoa.
	var aqui := str(u.estado(eid).get("local", ""))
	if aqui == "" and Viagens.viajando(u, eid):
		aqui = str(u.estado(eid)["viagem"]["de"])
	var mapa := Mapa.pai(u, aqui) if aqui != "" else ""
	if mapa != "":
		var mt := MapaTexto.new()
		mt.custom_minimum_size = Vector2(300, 120)
		mt.size_flags_vertical = Control.SIZE_EXPAND_FILL
		mt.mostrar_eventos = false
		mt.nevoa = Vivencia.visao(u, eid, mapa)
		var p := Mapa.posicao(u, aqui)
		if not p.is_empty():
			mt.voce = Vector2i(int(p["x"]), int(p["y"]))
		mt.mostrar(u, mapa)
		mt.celula_clicada.connect(func(_x: int, _y: int, lugar: String):
			if lugar != "" and Vivencia.conhecidos(u, eid).has(lugar):
				livro.navegar("ent:" + lugar))
		_dir.add_child(mt)
	campo_a.call_deferred("grab_focus")


# ---------------------------------------------------------------- o caderno (esquerda)

func _barra(nome: String, v: float, ruim_alto: bool) -> String:
	var cheios := clampi(roundi(v * 10.0), 0, 10)
	var cor := "#3F6A3A"
	if (ruim_alto and v > 0.7) or (not ruim_alto and v < 0.35):
		cor = "#7A2418"
	elif (ruim_alto and v > 0.4) or (not ruim_alto and v < 0.65):
		cor = "#8A6A1A"
	return "[b]%s[/b]  [color=%s]%s[/color][color=#C9B48A]%s[/color]\n" % [nome, cor, "■".repeat(cheios), "■".repeat(10 - cheios)]


func _ficha(eid: String) -> String:
	var f := Vivencia.ficha(u, eid)
	var s := ""
	var e := u.entidade(eid)
	s += "[font_size=%d]%s[/font_size]\n" % [Tema.px(22), Paginas.link("ent:" + eid, e["nome"])]
	s += "[i]%s%s%s[/i]\n\n" % [("%d anos" % int(f["idade"])) if int(f["idade"]) > 0 else "", (", " + f["oficio"]) if f["oficio"] != "" else "", (", trabalha para " + Paginas.link("ent:" + f["patrao"], u.entidade(f["patrao"])["nome"])) if f["patrao"] != "" else ""]
	s += _barra("Saúde  ", float(f["saude"]), false)
	s += _barra("Cansaço", float(f["cansaco"]), true)
	s += _barra("Fome   ", float(f["fome"]), true)
	s += "[b]Dinheiro[/b]  %d moedas\n" % int(f["dinheiro"])
	s += "[b]Humor[/b]  %s\n" % f["humor"]
	if not f["ferimentos"].is_empty():
		s += "[b]Ferimentos[/b]  [color=#7A2418]%s[/color]\n" % ", ".join(f["ferimentos"])
	if not f["poderes"].is_empty():
		s += "[b]Poderes[/b]  %s\n" % ", ".join(f["poderes"])
	s += Paginas.secao("O que sabe fazer")
	s += (", ".join(f["habilidades"]) if not f["habilidades"].is_empty() else "[i]Nada em especial, ainda.[/i]") + "\n"
	s += Paginas.secao("Pertences")
	var itens: Dictionary = f["itens"]
	var lista: Array = []
	for k in itens:
		lista.append(("%s ×%d" % [k, int(itens[k])]) if int(itens[k]) > 1 else str(k))
	var casas: Array = []
	for x in u.entidades_ativas():
		if u.valor_campo(x["id"], "dono") == e["nome"]:
			casas.append(Paginas.link("ent:" + x["id"], x["nome"]))
	s += (", ".join(lista) if not lista.is_empty() else "[i]Só a roupa do corpo.[/i]") + "\n"
	if not casas.is_empty():
		s += "Possui: %s\n" % ", ".join(casas)
	return s


func _relacoes(eid: String) -> String:
	var s := Paginas.secao("Quem conhece e o que sente")
	var rs := Vivencia.relacoes(u, eid)
	if rs.is_empty():
		return s + "[i]Ainda não conhece ninguém de verdade.[/i]"
	for r in rs.slice(0, 30):
		s += "• %s%s — %s%s\n" % [Paginas.link("ent:" + r["id"], r["nome"]), (" (" + r["laco"] + ")") if r["laco"] != "" else "", r["sente"] if r["sente"] != "" else "nada forte", "" if r["vivo"] else " [i](morto)[/i]"]
	return s


func _objetivos(eid: String) -> String:
	var s := Paginas.secao("Desejos e planos")
	var obj := Estado.objetivos_ativos(u, eid)
	s += ("\n".join(obj.map(func(o): return "• " + Conversa._texto_objetivo(u, o)))) + "\n" if not obj.is_empty() else "[i]Nada em especial. Escreva \"quero…\" para dar um plano a ele.[/i]\n"
	var dest := Destinos.todos(u).filter(func(d): return d["quem"] == eid and d["estado"] == "aberto")
	if not dest.is_empty():
		s += Paginas.secao("O que o autor marcou") + "\n".join(dest.map(func(d): return "• " + Paginas._e(d["texto"]))) + "\n"
	s += Paginas.secao("Lugares que conhece")
	var con := Vivencia.conhecidos(u, eid)
	var nomes: Array = []
	for l in con:
		if Mapa.especie(u, l) in ["planeta", "cosmico"]:
			continue
		nomes.append("%s [color=#8A6A3A](%s)[/color]" % [Paginas.link("ent:" + l, u.entidade(l)["nome"]), con[l]])
	s += ", ".join(nomes) + "\n"
	return s


func _noticias(eid: String) -> String:
	var s := Paginas.secao("O que chegou até aqui")
	var ns := Vivencia.noticias(u, eid, 20)
	if ns.is_empty():
		return s + "[i]Nenhuma notícia chegou.[/i]"
	for n in ns:
		s += "• [color=#5A3A1A]%s[/color] — %s%s\n" % [DataMundo.texto(n["data"]), Paginas._e(n["texto"]), " [i](boato)[/i]" if n["boato"] else ""]
	return s


func _diario(s: Dictionary) -> String:
	var t := ""
	var dia := ""
	var chave := "eu" if str(s["voz"]) == "primeira" else "ele"
	for x in s["diario"].slice(maxi(0, s["diario"].size() - 80)):
		var d := DataMundo.texto(x["data"])
		if d != dia:
			t += "\n[color=#5A3A1A][b]%s[/b][/color]\n" % d
			dia = d
		var cor: Variant = {"noticia": "#2F4F8A", "mundo": "#7A2418", "fala": "#2E5E5A", "pensamento": "#6B3A5A"}.get(x["tipo"], "")
		var txt := Paginas._e(str(x[chave]))
		t += ("[color=%s]%s[/color]" % [cor, txt] if cor != "" else txt) + "\n"
	return t if t != "" else "[i]O diário está em branco.[/i]"


# ---------------------------------------------------------------- começar

func _escolher() -> void:
	_esq.add_child(Tema.secao("Modo Viver"))
	var t := Tema.texto_rico()
	t.meta_clicked.connect(_meta)
	var s := "[i]No Livro você é autor e deus. Aqui você é um personagem: só sabe o que ele sabe, só pode o que ele pode, e o mundo segue em volta.[/i]\n"
	var sess := Vivencia.sessoes(u)
	if not sess.is_empty():
		s += Paginas.secao("Retomar")
		for k in sess:
			if u.entidades.has(k):
				s += "• %s — %d entradas no diário%s\n" % [Paginas.link("retomar:" + k, u.entidade(k)["nome"]), sess[k]["diario"].size(), "" if Estado.vivo(u, k) else " [i](morto)[/i]"]
	s += Paginas.secao("Viver alguém que já existe")
	var ms := Simulador._mentes(u)
	ms.sort_custom(func(a, b): return u.entidade(a)["nome"] < u.entidade(b)["nome"])
	var itens: Array = []
	for x in ms.slice(0, 60):
		var l := str(u.estado(x).get("local", ""))
		itens.append("%s%s" % [Paginas.link("viver:" + x, u.entidade(x)["nome"]), (" [color=#8A6A3A](%s)[/color]" % u.entidade(l)["nome"]) if l != "" else ""])
	s += ", ".join(itens) if not itens.is_empty() else "[i]Ninguém com mente própria ainda.[/i]"
	t.text = s
	_esq.add_child(t)
	# Criar alguém novo: nascido num lugar do mundo, com origem, família e ofício.
	_dir.add_child(Tema.secao("Ou nascer alguém novo"))
	var campos := {}
	for par in [["nome", "Nome"], ["idade", "Idade"], ["jeito", "Jeito (ex.: curioso, teimoso e gentil)"], ["oficio", "Ofício (pode ficar vazio)"],
			["origem", "Origem (ex.: filho de pescadores)"], ["familia", "Família (ex.: filho de Marta)"]]:
		var c := campo(par[1], str(_novo.get(par[0], "")))
		campos[par[0]] = c
		_dir.add_child(c)
	var lugar := OptionButton.new()
	var povoados: Array = u.entidades_ativas().filter(func(e): return Mapa.especie(u, e["id"]) == "povoado").map(func(e): return e["id"])
	povoados.sort_custom(func(a, b): return u.entidade(a)["nome"] < u.entidade(b)["nome"])
	for i in povoados.size():
		lugar.add_item("Nasce em " + u.entidade(povoados[i])["nome"])
		lugar.set_item_metadata(i, povoados[i])
	_dir.add_child(lugar)
	var voz := OptionButton.new()
	voz.add_item("Narrar em primeira pessoa")
	voz.add_item("Narrar em terceira pessoa")
	voz.select(0 if _voz == "primeira" else 1)
	voz.item_selected.connect(func(i: int): _voz = "primeira" if i == 0 else "terceira")
	_dir.add_child(voz)
	var nascer := Tema.botao_principal("Nascer e viver")
	nascer.disabled = povoados.is_empty()
	nascer.pressed.connect(func():
		var d := {}
		for k in campos:
			d[k] = campos[k].text
			_novo[k] = campos[k].text
		if str(d["nome"]).strip_edges() == "":
			livro.avisar("Dê um nome a ele.")
			return
		d["idade"] = int(d["idade"]) if str(d["idade"]).is_valid_int() else 20
		d["lugar"] = str(lugar.get_item_metadata(maxi(lugar.selected, 0)))
		var eid := Vivencia.criar(u, d, _voz)
		_novo = {"nome": "", "lugar": "", "idade": "20", "jeito": "", "oficio": "", "origem": "", "familia": ""}
		_ultimo = ""
		livro.ir_para_aba("modo_viver", eid))
	_dir.add_child(linha([nascer]))
