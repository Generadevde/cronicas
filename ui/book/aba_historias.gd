extends AbaLivro
## Aba "Histórias": o que dá forma às histórias do mundo.
##   Fios — as histórias em andamento (puxar, deixar correr, cortar) e os arcos;
##   Sementes — o mundo sugere histórias curtas a partir do que está acontecendo;
##   Obras — livros, canções, pinturas e peças escritas dentro do universo;
##   Cultura — feriados, canções, provérbios, tradições e superstições;
##   Cronista — anais, biografias e relatos de guerra, em três tons;
##   Segredos — quem sabe, quem suspeita, e quando vem à tona;
##   Diretor — ritmo e tom do universo.

static var _modo := "fios"
static var _semente: Dictionary = {}
static var _cron := {"tipo": "anais", "tom": "historiador", "alvo": "", "povo": ""}

var _dir: VBoxContainer


func montar(esq: VBoxContainer, dir: VBoxContainer, dado: String) -> void:
	_dir = dir
	esq.add_child(Tema.secao("Histórias e cultura"))
	var modos := [["fios", "Fios de história"], ["sementes", "Sementes"], ["obras", "Obras"], ["cultura", "Cultura"],
		["cronista", "Cronista"], ["segredos", "Segredos e ganchos"], ["diretor", "Diretor de drama"]]
	for mm in modos:
		var b := Tema.botao(mm[1])
		b.toggle_mode = true
		b.button_pressed = mm[0] == _modo
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(func():
			_modo = mm[0]
			livro.ir_para_aba("historias"))
		esq.add_child(b)
	var dica := Tema.rotulo({"fios": "Cada objetivo forte é um fio. Puxe para dar peso, corte para encerrar; os abandonados podem voltar.",
		"sementes": "Histórias curtas com personagens, lugar e conflito reais. Escreva, descarte ou deixe o mundo resolver.",
		"obras": "O universo escreve a própria literatura: com autor, tema real e viés.",
		"cultura": "O que os acontecimentos deixaram em cada povo e lugar.",
		"cronista": "Sempre a partir do que aconteceu de verdade.",
		"segredos": "Fatos escondidos de certos personagens, e o que o mundo tende a trazer de volta.",
		"diretor": "O ritmo e o tom: o diretor só deixa os sistemas mais ou menos propensos."}[_modo], 14, Tema.italico(), Tema.TINTA_SUAVE)
	dica.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	esq.add_child(dica)
	var t := Tema.texto_rico()
	t.meta_clicked.connect(_meta)
	match _modo:
		"fios":
			t.text = _fios()
		"sementes":
			_controles_semente()
			t.text = _texto_semente()
		"obras":
			t.text = _obras()
		"cultura":
			t.text = _cultura()
		"cronista":
			_controles_cronista()
			t.text = _cronica()
		"segredos":
			t.text = _segredos()
		"diretor":
			_controles_diretor()
			t.text = _diretor()
	_dir.add_child(t)


func _meta(meta) -> void:
	var m := str(meta)
	if m.begins_with("puxar:"):
		Fios.puxar(u, m.trim_prefix("puxar:"))
		livro.avisar("Fio puxado: ganhou mais força.")
		livro.ir_para_aba("historias")
	elif m.begins_with("cortar:"):
		Fios.cortar(u, m.trim_prefix("cortar:"))
		livro.ir_para_aba("historias")
	elif m.begins_with("revelar:"):
		var fid := m.trim_prefix("revelar:")
		livro.pedir_texto("Quando vem à tona?", "Ano (ex.: 420)", str(int(u.relogio["ano"]) + 1), func(t: String):
			if t.strip_edges().is_valid_int():
				Enredo.revelar_em(u, fid, DataMundo.criar(int(t), 1))
				livro.ir_para_aba("historias"))
	elif m.begins_with("ler:"):
		var o := m.trim_prefix("ler:")
		livro.confirmar(Obras.texto(u, o), func(): pass)
	else:
		livro.navegar(meta)


func _l(meta: String, texto: String) -> String:
	return Paginas.link(meta, texto)


func _fios() -> String:
	var s := Paginas.cabecalho("Fios de história", "o que pode acontecer, não o que vai")
	var fs := Fios.todos(u)
	if fs.is_empty():
		return s + "[i]Nenhum fio ainda: quando alguém quiser muito alguma coisa (vingança, amor, poder), ele aparece aqui.[/i]"
	for estado in ["perto do clímax", "em tensão", "crescendo", "nascendo", "abandonado", "resolvido"]:
		var deste: Array = fs.filter(func(f): return f["estado"] == estado)
		if deste.is_empty():
			continue
		s += Paginas.secao(estado.capitalize())
		for f in deste:
			s += "[b]%s[/b]%s  %s · %s\n" % [_l("ent:" + f["quem"], f["nome"]), (" → " + _l("ent:" + f["alvo"], u.entidade(f["alvo"])["nome"])) if f["alvo"] != "" and u.entidades.has(f["alvo"]) else "",
				_l("puxar:" + f["id"], "puxar"), _l("cortar:" + f["id"], "cortar")]
			if not estado in ["resolvido", "abandonado"]:
				s += "[color=#5A3A1A]%s[/color]\n" % "\n".join(Fios.caminhos(u, f).map(func(c): return "  • " + c))
	var arcos := Fios.arcos(u)
	if not arcos.is_empty():
		s += Paginas.secao("Arcos de personagem (sementes para você fechar)")
		for a in arcos:
			s += "• %s: de \"%s\" para %s\n" % [_l("ent:" + a["quem"], u.entidade(a["quem"]).get("nome", "?")), a["de"], a["para"]]
	return s


func _controles_semente() -> void:
	var b := Tema.botao_principal("Surpreenda-me")
	b.pressed.connect(func():
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		_semente = Enredo.semente(u, rng)
		livro.ir_para_aba("historias"))
	var escrever := Tema.botao("Escrever esta história", "Abre um capítulo com a semente")
	escrever.disabled = _semente.is_empty()
	escrever.pressed.connect(func():
		var livro_id := ""
		for l in u.livros:
			if l["titulo"] == "Sementes":
				livro_id = l["id"]
		if livro_id == "":
			livro_id = u.criar_livro("Sementes")
		var cap := u.criar_capitulo(livro_id, _semente["titulo"])
		u.atualizar_capitulo(cap, {"texto": "", "canon": true})
		u.criar_nota(_semente["titulo"], "%s\n\nGancho: %s" % [_semente["resumo"], _semente["gancho"]])
		livro.ir_para_aba("escrever", cap))
	var deixar := Tema.botao("Deixar o mundo resolver", "Puxa os fios dos personagens da semente")
	deixar.disabled = _semente.is_empty()
	deixar.pressed.connect(func():
		for f in Fios.todos(u):
			if _semente.get("personagens", []).has(f["quem"]):
				Fios.puxar(u, f["id"])
		livro.avisar("Os fios dessa história ganharam força. Avance o tempo e leia o jornal.")
		_semente = {}
		livro.ir_para_aba("historias"))
	_dir.add_child(linha([b, escrever, deixar]))


func _texto_semente() -> String:
	var s := Paginas.cabecalho("Sementes de histórias", "do que está acontecendo agora")
	if _semente.is_empty():
		return s + "[i]Aperte \"Surpreenda-me\". (Se nada vier, o mundo ainda está calmo demais: avance o tempo.)[/i]"
	s += "[font_size=%d][b]%s[/b][/font_size]\n\n%s\n\n[i]Gancho:[/i] %s\n\n[b]Personagens:[/b] %s" % [Tema.px(22), Paginas._e(_semente["titulo"]), Paginas._e(_semente["resumo"]),
		Paginas._e(_semente["gancho"]), ", ".join(_semente["personagens"].map(func(p): return _l("ent:" + p, u.entidade(p)["nome"])))]
	return s


func _obras() -> String:
	var s := Paginas.cabecalho("Obras do universo", "livros, canções, pinturas, peças e hinos")
	var os := Obras.todas(u)
	if os.is_empty():
		return s + "[i]Ninguém criou nada ainda. Escritores, bardos, pintores e veteranos de guerra criam sobre o que viveram.[/i]"
	for o in os:
		var d := Obras.dados(u, o)
		var autor := str(d.get("autor", ""))
		s += "[b]%s[/b] (%s), de %s · %s · %s\n" % [_l("ent:" + o, u.entidade(o)["nome"]), u.entidade(o)["tipo"], _l("ent:" + autor, u.entidade(autor).get("nome", "?")) if autor != "" else "?",
			("[color=#7A2418]perdida[/color]" if Obras.perdida(u, o) else "%d cópia%s" % [Obras.copias(u, o), "" if Obras.copias(u, o) == 1 else "s"]), _l("ler:" + o, "ler")]
		for l in d.get("leituras", []):
			s += "   [color=#5A3A1A]%s, ano %d:[/color] %s\n" % ["original" if l.get("original", false) else "leitura de " + u.entidade(str(l["por"])).get("nome", "?"), int(l["ano"]), Paginas._e(str(l["texto"]))]
	return s


func _cultura() -> String:
	var s := Paginas.cabecalho("Cultura dos povos e lugares", "feriados, canções, provérbios, tradições e superstições")
	var algum := false
	for e in u.entidades_ativas():
		var c := Legado.de(u, e["id"])
		if c.is_empty():
			continue
		algum = true
		s += Paginas.secao(e["nome"])
		for x in c:
			var hoje := Legado.como_esta(u, x)
			s += "• [b]%s[/b] — %s: %s %s\n" % [Paginas._e(str(hoje["nome"])), hoje["tipo"], Paginas._e(str(hoje["texto"])), _l("fato:" + str(x["fato"]), "(a verdade)")]
	return s if algum else s + "[i]Ainda nada marcou a cultura. Guerras, heróis, traições e pactos deixam marcas.[/i]"


func _controles_cronista() -> void:
	var tipo := OptionButton.new()
	var tipos := [["anais", "Anais do ano"], ["biografia", "Biografia"], ["guerra", "Relato de guerra"]]
	for i in tipos.size():
		tipo.add_item(tipos[i][1])
		if tipos[i][0] == _cron["tipo"]:
			tipo.select(i)
	tipo.item_selected.connect(func(i: int):
		_cron["tipo"] = tipos[i][0]
		_cron["alvo"] = ""
		livro.ir_para_aba("historias"))
	var tom := OptionButton.new()
	for i in Cronista.TONS.size():
		tom.add_item({"historiador": "historiador neutro", "povo": "com o viés de um povo", "bardo": "bardo exagerado"}[Cronista.TONS[i]])
		if Cronista.TONS[i] == _cron["tom"]:
			tom.select(i)
	tom.item_selected.connect(func(i: int):
		_cron["tom"] = Cronista.TONS[i]
		livro.ir_para_aba("historias"))
	var alvo := OptionButton.new()
	var opcoes: Array = []
	match str(_cron["tipo"]):
		"anais":
			for a in range(int(u.relogio["ano"]), int(u.relogio["ano"]) - 30, -1):
				opcoes.append([str(a), "Ano %d" % a])
		"biografia":
			for e in u.entidades_ativas():
				if Sugestoes.categoria(e["tipo"]) == "pessoa":
					opcoes.append([e["id"], e["nome"]])
		"guerra":
			for g in Guerras.todas(u):
				opcoes.append([g, u.entidade(g)["nome"]])
	for i in opcoes.size():
		alvo.add_item(opcoes[i][1])
		if opcoes[i][0] == _cron["alvo"]:
			alvo.select(i)
	if _cron["alvo"] == "" and not opcoes.is_empty():
		_cron["alvo"] = opcoes[0][0]
	alvo.item_selected.connect(func(i: int):
		_cron["alvo"] = opcoes[i][0]
		livro.ir_para_aba("historias"))
	var povo := OptionButton.new()
	var socs := Sociedades.todas(u)
	povo.add_item("(povo)")
	for i in socs.size():
		povo.add_item(u.entidade(socs[i])["nome"])
		if socs[i] == _cron["povo"]:
			povo.select(i + 1)
	povo.item_selected.connect(func(i: int):
		_cron["povo"] = socs[i - 1] if i > 0 else ""
		livro.ir_para_aba("historias"))
	_dir.add_child(linha([tipo, alvo, tom, povo]))


func _cronica() -> String:
	var a := str(_cron["alvo"])
	match str(_cron["tipo"]):
		"anais":
			return Cronista.anais(u, int(a) if a.is_valid_int() else int(u.relogio["ano"]), _cron["tom"], _cron["povo"])
		"biografia":
			return Cronista.biografia(u, a, _cron["tom"], _cron["povo"]) if u.entidades.has(a) else "[i]Escolha alguém.[/i]"
		"guerra":
			return Cronista.guerra(u, a, _cron["tom"], _cron["povo"]) if u.entidades.has(a) else "[i]Nenhuma guerra ainda.[/i]"
	return ""


func _segredos() -> String:
	var s := Paginas.cabecalho("Segredos e ganchos", "você vê tudo; os personagens, não")
	var ss := Enredo.segredos(u)
	s += Paginas.secao("Segredos")
	if ss.is_empty():
		s += "[i]Nenhum segredo guardado.[/i]\n"
	for x in ss:
		s += "• %s\n   [color=#5A3A1A]sabem:[/color] %s · [color=#5A3A1A]suspeitam:[/color] %s · %s\n" % [_l("fato:" + x["fato"], x["texto"]),
			", ".join(x["sabem"].map(func(e): return u.entidade(e)["nome"])) if not x["sabem"].is_empty() else "ninguém",
			", ".join(x["suspeitam"].map(func(e): return u.entidade(e)["nome"])) if not x["suspeitam"].is_empty() else "ninguém",
			("vem à tona em %s" % DataMundo.texto(Paginas._data_de_ordem(int(x["revelar_em"])))) if int(x["revelar_em"]) > 0 else _l("revelar:" + x["fato"], "marcar quando vem à tona")]
	s += Paginas.secao("Ganchos (o mundo tende a trazê-los de volta)")
	var gs := Enredo.ganchos(u)
	if gs.is_empty():
		s += "[i]Nenhuma promessa, profecia ou objeto marcado ainda.[/i]\n"
	for g in gs:
		s += "• [b]%s[/b]: %s%s\n" % [g["tipo"], Paginas._e(str(g["texto"])), " [color=#5A3A1A](já voltou)[/color]" if g["voltou"] else ""]
	return s


func _controles_diretor() -> void:
	var c := Diretor.config(u)
	var ritmo := OptionButton.new()
	var rs := Diretor.RITMOS.keys()
	for i in rs.size():
		ritmo.add_item(rs[i])
		if rs[i] == c["ritmo"]:
			ritmo.select(i)
	var tom := OptionButton.new()
	for i in Diretor.TONS.size():
		tom.add_item(Diretor.TONS[i])
		if Diretor.TONS[i] == c["tom"]:
			tom.select(i)
	ritmo.item_selected.connect(func(i: int):
		Diretor.definir(u, rs[i], c["tom"])
		livro.ir_para_aba("historias"))
	tom.item_selected.connect(func(i: int):
		Diretor.definir(u, c["ritmo"], Diretor.TONS[i])
		livro.ir_para_aba("historias"))
	_dir.add_child(linha([Tema.rotulo("Ritmo:", 16), ritmo, Tema.rotulo("Tom:", 16), tom]))


func _diretor() -> String:
	var c := Diretor.config(u)
	var s := Paginas.cabecalho("Diretor de drama", "ritmo %s · tom %s" % [c["ritmo"], c["tom"]])
	s += "[b]Agora:[/b] %s (tensão %.1f)\n" % [Diretor.fase(u), Diretor.tensao(u)]
	s += "\n[i]Calmaria longa demais acende uma faísca num conflito que já existia; depois de uma guerra vem a reconstrução. O tom deixa alguns acontecimentos mais prováveis:[/i]\n"
	for tipo in ["guerra", "epidemia", "fartura", "pacto", "torneio", "invencao"]:
		s += "• %s: ×%.1f\n" % [tipo, Diretor.fator(u, tipo)]
	return s
