class_name MapaTexto
extends Control
## O mapa só de texto, no estilo dos mapas antigos: o terreno é uma aguada de cor
## bem leve, as costas são riscadas em tinta (com as linhas finas na água), os rios
## descem em fio de tinta, e tudo tem NOME escrito: serras em versalete espaçado,
## mares em itálico azul, florestas em verde, lugares com um ponto e o nome.
## Os rótulos se arrumam para não ficar letra em cima de letra.
## Passar o mouse mostra o que há ali; clicar avisa a aba.

signal celula_clicada(x: int, y: int, eid: String)
signal celula_arrastada(x: int, y: int)
signal soltou

const LAVAGEM := {
	"agua": Color("#9DB4C2", 0.55), "floresta": Color("#8A9E68", 0.32), "montanha": Color("#A08262", 0.36),
	"colina": Color("#B39B70", 0.24), "deserto": Color("#DDB878", 0.4), "pantano": Color("#7E8E66", 0.32),
	"gelo": Color("#F2F4F4", 0.75), "campo": Color("#BDB574", 0.14),
}
const ESTILO := {
	"montanha": {"fonte": "versalete", "cor": "#5A3418", "maiusculas": true, "espaco": true},
	"colina": {"fonte": "versalete", "cor": "#6A4A28", "maiusculas": false, "espaco": true},
	"oceano": {"fonte": "italico", "cor": "#2E4E70", "maiusculas": true, "espaco": true},
	"lago": {"fonte": "italico", "cor": "#2E4E70", "maiusculas": false, "espaco": false},
	"rio": {"fonte": "italico", "cor": "#2E4E70", "maiusculas": false, "espaco": false},
	"floresta": {"fonte": "italico", "cor": "#2F4A20", "maiusculas": false, "espaco": true},
	"deserto": {"fonte": "versalete", "cor": "#7A5420", "maiusculas": false, "espaco": true},
	"pantano": {"fonte": "italico", "cor": "#3E4E2A", "maiusculas": false, "espaco": false},
	"gelo": {"fonte": "versalete", "cor": "#4A6070", "maiusculas": false, "espaco": true},
	"planicie": {"fonte": "italico", "cor": "#6A5A30", "maiusculas": false, "espaco": true},
}

var u: Universo
var lugar := ""          ## de quem é esta grade ("" = o cosmos)
var selecionado := ""
var acidente_sel := ""   ## chave do acidente escolhido
var mostrar_nomes := true      ## lugares
var mostrar_natureza := true   ## nomes de serras, mares, rios…
var mostrar_eventos := true
var _sobre := Vector2i(-1, -1)
var _arrastando := false
var _rotulos: Array = []  ## retângulos já ocupados por letras
var _guerra: Dictionary = {}  ## lugar → guerra (frentes e lugares ocupados)
var _pactos: Dictionary = {}  ## lugares com pactos ainda não cobrados
var nevoa: Dictionary = {}    ## Modo Viver: células que o personagem enxerga (vazio = tudo)
var voce := Vector2i(-1, -1)  ## Modo Viver: onde o personagem está


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(420, 300)
	tooltip_text = " "


func mostrar(p_u: Universo, p_lugar: String) -> void:
	u = p_u
	lugar = p_lugar
	queue_redraw()


func _celula() -> Vector2:
	return Vector2(size.x / Mapa.COLS, size.y / Mapa.LINHAS)


func celula_em(pos: Vector2) -> Vector2i:
	var c := _celula()
	return Vector2i(clampi(int(pos.x / c.x), 0, Mapa.COLS - 1), clampi(int(pos.y / c.y), 0, Mapa.LINHAS - 1))


func _gui_input(ev: InputEvent) -> void:
	if u == null:
		return
	if ev is InputEventMouseMotion:
		var c := celula_em(ev.position)
		if c != _sobre:
			_sobre = c
			queue_redraw()
			if _arrastando:
				celula_arrastada.emit(c.x, c.y)
	elif ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			var c := celula_em(ev.position)
			_arrastando = true
			celula_clicada.emit(c.x, c.y, Mapa.em(u, lugar, c.x, c.y))
		else:
			_arrastando = false
			soltou.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_sobre = Vector2i(-1, -1)
		queue_redraw()
	elif what == NOTIFICATION_RESIZED:
		queue_redraw()


func _get_tooltip(pos: Vector2) -> String:
	if u == null:
		return ""
	var c := celula_em(pos)
	var eid := Mapa.em(u, lugar, c.x, c.y)
	if eid != "" and not Mapa.entidades_de_acidente(u, lugar).has(eid):
		return descricao_curta(u, eid)
	var a := Mapa.acidente_em(u, lugar, c.x, c.y)
	var t := Mapa.terreno_em(u, lugar, c.x, c.y)
	if not a.is_empty():
		var tipo_txt: String = "rio" if a["grupo"] == "rio" else Mapa.TERRENOS.get(a["grupo"], {}).get("nome", a["grupo"])
		return "%s\n%s" % [a["nome"], tipo_txt]
	return Mapa.TERRENOS[t]["nome"] if t != "vazio" else ""


## O que está acontecendo num lugar, em poucas linhas (usado no passar do mouse).
static func descricao_curta(u: Universo, eid: String) -> String:
	var e := u.entidade(eid)
	var linhas: Array = ["%s · %s" % [e["nome"], e["tipo"]]]
	if Natureza.tem_natureza(u, eid):
		var reg := Natureza.de(u, eid)
		if float(reg["pop"]) > 0:
			linhas.append("%s habitantes · %s" % [Paginas._numero(float(reg["pop"])), Natureza.palavra_comida(float(reg["comida"]))])
	for ev in Natureza.eventos_ativos(u, eid):
		linhas.append(Natureza.EVENTOS.get(ev["tipo"], {}).get("nome", ev["tipo"]))
	var em_guerra := Guerras.lugares_em_guerra(u)
	if em_guerra.has(eid):
		linhas.append("⚔ %s%s" % [u.entidade(em_guerra[eid])["nome"], (" · ocupada por " + u.entidade(u.estado(eid)["ocupado_por"])["nome"]) if u.estado(eid).has("ocupado_por") else ""])
	if str(u.estado(eid).get("nome_de_guerra", "")) != "":
		linhas.append("hoje chamado de " + str(u.estado(eid)["nome_de_guerra"]))
	var gente := Natureza._mentes_em(u, eid)
	if not gente.is_empty():
		var nomes: Array = gente.slice(0, 4).map(func(g): return u.entidade(g)["nome"])
		linhas.append("Aqui: " + ", ".join(nomes) + (" e mais %d" % (gente.size() - 4) if gente.size() > 4 else ""))
	var dentro := Mapa.filhos(u, eid).size()
	if dentro > 0:
		linhas.append("%d lugares dentro (clique duas vezes para entrar)" % dentro)
	return "\n".join(linhas)


# ---------------------------------------------------------------- desenho

func _draw() -> void:
	if u == null:
		return
	_rotulos.clear()
	_guerra = Guerras.lugares_em_guerra(u)
	# Lugares onde mora alguém com um pacto ainda não cobrado (você vê, como deus).
	_pactos = {}
	for p in Pactos.todos(u):
		if not p["cobrado"]:
			_pactos[str(u.estado(str(p["com"])).get("local", ""))] = true
	var c := _celula()
	var cosmos := lugar == "" or Mapa.especie(u, lugar) == "cosmico"
	draw_rect(Rect2(Vector2.ZERO, size), Color("#E4CB97") if not cosmos else Color("#231A12"))
	if cosmos:
		_estrelas(c)
	else:
		_terreno(c)
	if not nevoa.is_empty():
		_nevoa(c)
	# Moldura dupla, como nos mapas impressos.
	var tinta := Color(Tema.TINTA_SUAVE, 0.8) if not cosmos else Color(Tema.OURO, 0.5)
	draw_rect(Rect2(Vector2(2, 2), size - Vector2(4, 4)), tinta, false, 1.6)
	draw_rect(Rect2(Vector2(6, 6), size - Vector2(12, 12)), Color(tinta, 0.45), false, 1.0)
	if _sobre.x >= 0:
		draw_rect(Rect2(Vector2(_sobre.x * c.x, _sobre.y * c.y), c), Color(Tema.OURO, 0.22))
	# Reserva o canto da rosa dos ventos e a escala, para nenhum nome cair em cima.
	var r := minf(c.y * 1.2, 26)
	var centro_rosa := Vector2(size.x - 34, size.y - 40)
	_rotulos.append(Rect2(centro_rosa - Vector2(r + 6, r + 14), Vector2(r * 2 + 12, r * 2 + 20)))
	_rotulos.append(Rect2(Vector2(10, size.y - 30), Vector2(c.x * 8 + 170, 26)))
	_lugares(c, cosmos)
	if mostrar_eventos and not cosmos:
		_alertas(c)
	if voce.x >= 0:
		var pv := Vector2((voce.x + 0.5) * c.x, (voce.y + 0.5) * c.y)
		draw_arc(pv, c.y * 0.9, 0, TAU, 28, Color("#7A2418"), 2.2)
		draw_arc(pv, c.y * 1.25, 0, TAU, 28, Color("#7A2418", 0.45), 1.2)
	if mostrar_natureza and not cosmos and nevoa.is_empty():
		_nomes_da_natureza(c)
	if mostrar_eventos and lugar != "":
		var k2 := 0
		var aqui: Array = []
		for l in _guerra:
			if (l == lugar or Mapa.ancestrais(u, l).has(lugar)) and not aqui.has(_guerra[l]):
				aqui.append(_guerra[l])
		for g in aqui:
			# Faixa de pergaminho por baixo, para não brigar com os nomes do mapa.
			var tg := "⚔ %s" % u.entidade(g)["nome"]
			var wg := Tema.F_FELL_IT.get_string_size(tg, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
			var yg := 26 + k2 * 22
			draw_rect(Rect2(size.x / 2.0 - wg / 2.0 - 10, yg - 16, wg + 20, 22), Color("#EBD6A8"))
			draw_rect(Rect2(size.x / 2.0 - wg / 2.0 - 10, yg - 16, wg + 20, 22), Color("#8A2A10"), false, 1.0)
			_centrado(Tema.F_FELL_IT, size.x / 2.0, yg, tg, 17, Color("#8A2A10"))
			k2 += 1
		for ev in Natureza.eventos_ativos(u, lugar):
			var s2: String = "— %s —" % Natureza.EVENTOS.get(ev["tipo"], {}).get("nome", ev["tipo"])
			_centrado(Tema.F_FELL_IT, size.x / 2.0, 26 + k2 * 20, s2, 17, Color("#8A2A10"))
			k2 += 1
	_rosa_dos_ventos(centro_rosa, r, tinta)
	_escala(c, tinta)


## O que está acontecendo em cada lugar, escrito embaixo do nome: criaturas que
## atacam, fome, falta de ar. O mapa acompanha a história sozinho.
func _alertas(c: Vector2) -> void:
	var por_lugar := {}
	for esp in Ameacas.todas(u):
		var a := Ameacas.dados(u, esp)
		if a.get("ativa", false):
			var l := str(a.get("lugar", ""))
			if not por_lugar.has(l):
				por_lugar[l] = []
			por_lugar[l].append("⚔ " + str(a.get("plural", u.entidade(esp)["nome"])))
	for l in Recursos.lugares(u):
		for nome in Recursos.de(u, l):
			var al := str(Recursos.de(u, l)[nome].get("alerta", ""))
			if al != "":
				if not por_lugar.has(l):
					por_lugar[l] = []
				por_lugar[l].append(("sem " if al == "acabou" else "pouca ") + Recursos._palavra(nome).split(" ")[1])
	for l in por_lugar:
		if not u.entidades.has(l) or Mapa.pai(u, l) != lugar:
			continue
		var pos := Mapa.posicao(u, l)
		if not nevoa.is_empty() and not nevoa.has(Vector2i(int(pos["x"]), int(pos["y"]))):
			continue
		var centro := Vector2((int(pos["x"]) + 0.5) * c.x, (int(pos["y"]) + 0.5) * c.y)
		var t := " · ".join(por_lugar[l])
		var fs := 14
		var w := Tema.F_FELL_IT.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var r := Rect2(centro + Vector2(-w / 2.0 - 4, c.y * 0.55), Vector2(w + 8, fs + 6))
		draw_rect(r, Color("#EBD6A8", 0.9))
		draw_rect(r, Color("#8A2A10", 0.7), false, 1.0)
		_texto(Tema.F_FELL_IT, r.grow_individual(-4, -2, 0, 0), t, fs, Color("#8A2A10"))
		_rotulos.append(r)


## O que o personagem não conhece fica coberto, como papel em branco com hachuras.
func _nevoa(c: Vector2) -> void:
	for y in Mapa.LINHAS:
		for x in Mapa.COLS:
			if nevoa.has(Vector2i(x, y)):
				continue
			var r := Rect2(Vector2(x * c.x, y * c.y), c + Vector2(0.6, 0.6))
			draw_rect(r, Color("#E4CB97", 0.93))
			if (x + y) % 2 == 0:
				draw_line(r.position + Vector2(0, c.y), r.position + Vector2(c.x, 0), Color(Tema.TINTA_SUAVE, 0.12), 1.0)


func _estrelas(c: Vector2) -> void:
	var ruido := FastNoiseLite.new()
	ruido.seed = 4242
	ruido.frequency = 0.3
	for y in Mapa.LINHAS:
		for x in Mapa.COLS:
			var n := ruido.get_noise_2d(x * 7.0, y * 13.0)
			if n > 0.42:
				var p := Vector2((x + 0.5) * c.x + n * 9.0, (y + 0.5) * c.y - n * 7.0)
				draw_circle(p, 0.6 + (n - 0.42) * 3.0, Color("#EBD9AC", 0.35 + n * 0.5))


func _terreno(c: Vector2) -> void:
	var grade := Mapa.terreno(u, lugar)
	for y in Mapa.LINHAS:
		for x in Mapa.COLS:
			var t: String = grade[y][x]
			if not LAVAGEM.has(t):
				continue
			var a := Vector2(floor(x * c.x), floor(y * c.y))
			var b := Vector2(floor((x + 1) * c.x), floor((y + 1) * c.y))
			draw_rect(Rect2(a, b - a), LAVAGEM[t])
	# Costas: a linha de tinta e, na água, duas linhas finas que vão sumindo.
	var tinta := Color(Tema.TINTA_SUAVE, 0.85)
	for y in Mapa.LINHAS:
		for x in Mapa.COLS:
			if grade[y][x] == "agua":
				continue
			var o := Vector2(x * c.x, y * c.y)
			var lados := [
				[y > 0 and grade[y - 1][x] == "agua", o, o + Vector2(c.x, 0), Vector2(0, -1)],
				[y < Mapa.LINHAS - 1 and grade[y + 1][x] == "agua", o + Vector2(0, c.y), o + c, Vector2(0, 1)],
				[x > 0 and grade[y][x - 1] == "agua", o, o + Vector2(0, c.y), Vector2(-1, 0)],
				[x < Mapa.COLS - 1 and grade[y][x + 1] == "agua", o + Vector2(c.x, 0), o + c, Vector2(1, 0)],
			]
			for l in lados:
				if not l[0]:
					continue
				draw_line(l[1], l[2], tinta, 1.5)
				# As linhas finas na água só onde há água de verdade (não em lagoinhas).
				var d: Vector2 = l[3]
				var x2 := x + int(d.x) * 3
				var y2 := y + int(d.y) * 3
				if x2 >= 0 and y2 >= 0 and x2 < Mapa.COLS and y2 < Mapa.LINHAS and grade[y2][x2] == "agua" and grade[y + int(d.y) * 2][x + int(d.x) * 2] == "agua":
					draw_line(l[1] + d * 3.5, l[2] + d * 3.5, Color(Tema.TINTA_SUAVE, 0.32), 1.0)
					draw_line(l[1] + d * 7.0, l[2] + d * 7.0, Color(Tema.TINTA_SUAVE, 0.14), 1.0)
	# Rios: fio de tinta azulada, um pouco sinuoso, engrossando rumo à foz.
	var ondula := FastNoiseLite.new()
	ondula.seed = hash(lugar) + 3
	ondula.frequency = 0.5
	for r in Mapa.rios(u, lugar):
		var pts := PackedVector2Array()
		var n: int = r["pontos"].size()
		for i in n:
			var p: Vector2i = r["pontos"][i]
			var j := Vector2(ondula.get_noise_2d(p.x * 3.0, p.y * 3.0), ondula.get_noise_2d(p.y * 3.0, p.x * 3.0)) * c * 0.35
			pts.append(Vector2((p.x + 0.5) * c.x, (p.y + 0.5) * c.y) + (j if i > 0 and i < n - 1 else Vector2.ZERO))
		for i in range(pts.size() - 1):
			draw_line(pts[i], pts[i + 1], Color("#3E5F80", 0.85), 1.0 + 1.6 * float(i) / maxf(1.0, n - 1), true)


## Lugares: um ponto (ou anel) e o nome. Regiões: letras grandes e espaçadas.
func _lugares(c: Vector2, cosmos: bool) -> void:
	var de_acidente := Mapa.entidades_de_acidente(u, lugar)
	var filhos := Mapa.filhos(u, lugar)
	# Os maiores primeiro, para terem o melhor lugar para o nome.
	filhos.sort_custom(func(a, b): return _peso(a) > _peso(b))
	for eid in filhos:
		if de_acidente.has(eid):
			continue
		var pos := Mapa.posicao(u, eid)
		if not nevoa.is_empty() and not nevoa.has(Vector2i(int(pos["x"]), int(pos["y"]))):
			continue
		var centro := Vector2((int(pos["x"]) + 0.5) * c.x, (int(pos["y"]) + 0.5) * c.y)
		var esp := Mapa.especie(u, eid)
		var nome: String = u.entidade(eid)["nome"]
		var cor := Tema.VERMELHO if not cosmos else Tema.OURO_CLARO
		var sel: bool = eid == selecionado
		if esp == "regiao" and not cosmos:
			# Região: só o nome, grande e espaçado, como nos mapas antigos.
			var t := _espacar(nome.to_upper())
			var fs := int(clampf(c.y * 0.95, 14, 30))
			var rr := _colocar_rotulo(Tema.F_VERSALETE, t, fs, centro, [Vector2.ZERO, Vector2(0, -c.y), Vector2(0, c.y), Vector2(-c.x * 3, 0), Vector2(c.x * 3, 0)])
			if rr.size.x > 0:
				_texto(Tema.F_VERSALETE, rr, t, fs, Color(Tema.VERMELHO, 0.85 if not sel else 1.0))
				if sel:
					draw_line(rr.position + Vector2(0, rr.size.y), rr.end, Tema.VERMELHO, 1.5)
			continue
		# Ponto: capital com anel, cidade ponto cheio, vila ponto pequeno, construção quadradinho.
		var tipo := TextUtil.normalizar(u.entidade(eid)["tipo"])
		var raio := c.y * 0.2
		if esp == "construcao":
			draw_rect(Rect2(centro - Vector2(3, 3), Vector2(6, 6)), cor, false, 1.3)
		elif cosmos or esp == "planeta":
			draw_circle(centro, c.y * 0.42, Color(cor, 0.25))
			draw_arc(centro, c.y * 0.42, 0, TAU, 24, cor, 1.4)
		elif tipo.contains("capital"):
			draw_circle(centro, raio * 1.3, cor)
			draw_arc(centro, raio * 2.2, 0, TAU, 20, cor, 1.2)
		elif esp == "povoado" and (tipo.contains("cidade") or tipo.contains("porto")):
			draw_circle(centro, raio * 1.3, cor)
		elif esp == "povoado":
			draw_circle(centro, raio * 0.85, cor)
		else:
			draw_arc(centro, raio, 0, TAU, 12, cor, 1.2)
		if sel:
			draw_arc(centro, c.y * 0.75, 0, TAU, 28, cor, 1.8)
		_rotulos.append(Rect2(centro - Vector2(5, 5), Vector2(10, 10)))
		if not mostrar_nomes:
			continue
		var grande := tipo.contains("capital") or cosmos or esp == "planeta"
		var reto := (esp == "povoado" and not tipo.contains("vila") and not tipo.contains("aldeia")) or grande
		var fonte: Font = Tema.F_FELL if reto else Tema.F_FELL_IT
		var fs2 := int(clampf(c.y * (0.95 if grande else 0.78), 13, 26))
		var texto := nome.to_upper() if tipo.contains("capital") else nome
		var off := c.x * 0.45
		var rr2 := _colocar_rotulo(fonte, texto, fs2, centro, [
			Vector2(off, 0), Vector2(-off, 0), Vector2(0, -c.y * 0.75), Vector2(0, c.y * 0.75)], true)
		if rr2.size.x > 0:
			draw_rect(rr2.grow(1), Color("#E4CB97", 0.55) if not cosmos else Color("#231A12", 0.6))
			_texto(fonte, rr2, texto, fs2, Tema.TINTA if not cosmos else Tema.TEXTO_CLARO)
			if mostrar_eventos:
				var evs: Array = Natureza.eventos_ativos(u, eid).filter(func(x): return x["lugar"] == eid)
				var nomes_ev: Array = evs.map(func(x): return Natureza.EVENTOS.get(x["tipo"], {}).get("nome", x["tipo"]))
				if _guerra.has(eid):
					nomes_ev.push_front("⚔ ocupada" if u.estado(eid).has("ocupado_por") else "⚔ guerra")
				if u.estado(eid).has("adormecido"):
					nomes_ev.push_front("☾ sono eterno")
				if _pactos.has(eid):
					nomes_ev.append("◉ pacto")
				if not nomes_ev.is_empty():
					var t2 := "(%s)" % ", ".join(nomes_ev)
					var rr3 := _colocar_rotulo(Tema.F_FELL_IT, t2, 13, Vector2(rr2.get_center().x, rr2.end.y + 8), [Vector2.ZERO, Vector2(0, -rr2.size.y - 14)])
					if rr3.size.x > 0:
						_texto(Tema.F_FELL_IT, rr3, t2, 13, Color("#8A2A10"))


func _peso(eid: String) -> float:
	var esp := Mapa.especie(u, eid)
	var p: float = {"regiao": 5.0, "planeta": 6.0, "povoado": 3.0, "natural": 2.0, "construcao": 1.0}.get(esp, 1.5)
	if TextUtil.normalizar(u.entidade(eid)["tipo"]).contains("capital"):
		p += 1.5
	return p + Natureza.populacao_inicial(u, eid) / 100000.0


## Nomes das serras, mares, lagos, florestas, rios… (os maiores primeiro).
func _nomes_da_natureza(c: Vector2) -> void:
	var lista := Mapa.acidentes(u, lugar)
	lista.sort_custom(func(a, b): return a["celulas"].size() > b["celulas"].size())
	for a in lista:
		var est: Dictionary = ESTILO.get(a["tipo"], ESTILO["planicie"])
		var fonte: Font = Tema.F_VERSALETE if est["fonte"] == "versalete" else Tema.F_FELL_IT
		var n: int = a["celulas"].size()
		var fs := int(clampf(c.y * (0.62 + sqrt(float(n)) / 22.0), 11, 28))
		if a["tipo"] == "rio":
			fs = int(clampf(c.y * 0.62, 11, 16))
		var texto: String = a["nome"]
		if est["maiusculas"] and n >= 30:
			texto = texto.to_upper()
		if est["espaco"] and n >= 20:
			texto = _espacar(texto)
		var sel: bool = a["chave"] == acidente_sel
		var cor := Color(est["cor"])
		if sel:
			cor = Tema.VERMELHO
			for k in a["celulas"]:
				draw_rect(Rect2(Vector2(k.x * c.x, k.y * c.y), c), Color(Tema.VERMELHO, 0.08))
		# Posições candidatas: as células do acidente mais perto do centro dele.
		var cands: Array = a["celulas"].duplicate()
		var centro: Vector2 = a["centro"]
		cands.sort_custom(func(p, q): return Vector2(p).distance_squared_to(centro) < Vector2(q).distance_squared_to(centro))
		var pontos: Array = []
		for k in cands.slice(0, 24):
			pontos.append(Vector2((k.x + 0.5) * c.x, (k.y + 0.5) * c.y) + (Vector2(0, -c.y * 0.6) if a["tipo"] == "rio" else Vector2.ZERO))
		if pontos.is_empty():
			continue
		var base: Vector2 = pontos[0]
		var rel: Array = pontos.map(func(p): return p - base)
		var rr := _colocar_rotulo(fonte, texto, fs, base, rel)
		if rr.size.x > 0:
			_texto(fonte, rr, texto, fs, cor)


func _espacar(t: String) -> String:
	var partes: Array = []
	for palavra in t.split(" ", false):
		var letras: Array = []
		for ch in palavra:
			letras.append(ch)
		partes.append(" ".join(letras))
	return "   ".join(partes)


## Acha um retângulo livre para o texto perto de 'ancora' (tentando cada deslocamento).
## 'ao_lado' = o texto começa no ponto (para nomes à direita/esquerda de um ponto).
func _colocar_rotulo(fonte: Font, texto: String, fs: int, ancora: Vector2, deslocamentos: Array, ao_lado: bool = false) -> Rect2:
	var tam := fonte.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	tam.y = fs * 1.05
	for d in deslocamentos:
		var p: Vector2 = ancora + d
		var pos := p - tam / 2.0
		if ao_lado and d.x > 0:
			pos = Vector2(p.x + 2, p.y - tam.y / 2.0)
		elif ao_lado and d.x < 0:
			pos = Vector2(p.x - tam.x - 2, p.y - tam.y / 2.0)
		var r := Rect2(pos, tam)
		if r.position.x < 8 or r.position.y < 8 or r.end.x > size.x - 8 or r.end.y > size.y - 8:
			continue
		var livre := true
		for o in _rotulos:
			if r.grow(-1).intersects(o):
				livre = false
				break
		if livre:
			_rotulos.append(r)
			return r
	return Rect2()


func _texto(fonte: Font, r: Rect2, texto: String, fs: int, cor: Color) -> void:
	draw_string(fonte, Vector2(r.position.x, r.position.y + fs * 0.82), texto, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, cor)


## Texto centrado em x.
func _centrado(fonte: Font, x: float, y: float, texto: String, tamanho: int, cor: Color) -> void:
	var w := fonte.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho).x
	draw_string(fonte, Vector2(x - w / 2.0, y), texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho, cor)


func _rosa_dos_ventos(centro: Vector2, r: float, cor: Color) -> void:
	for i in 4:
		var ang := i * PI / 2.0 - PI / 2.0
		var ponta := centro + Vector2(cos(ang), sin(ang)) * r
		var lado1 := centro + Vector2(cos(ang + PI / 2.0), sin(ang + PI / 2.0)) * r * 0.22
		var lado2 := centro + Vector2(cos(ang - PI / 2.0), sin(ang - PI / 2.0)) * r * 0.22
		draw_colored_polygon(PackedVector2Array([ponta, lado1, centro]), cor)
		draw_polyline(PackedVector2Array([ponta, lado2, centro, ponta]), cor, 1.0)
	draw_arc(centro, r * 0.45, 0, TAU, 24, Color(cor, 0.6), 1.0)
	_centrado(Tema.F_VERSALETE, centro.x, centro.y - r - 4, "N", int(r * 0.6), cor)


func _escala(c: Vector2, cor: Color) -> void:
	var km := Mapa.km_por_celula(u, lugar)
	if km <= 0:
		return
	var celulas := 8
	var total := km * celulas
	var texto := ("%s km" % Paginas._numero(total)) if total >= 1.0 else ("%d m" % roundi(total * 1000))
	var dias := ceili(total / Mapa.VELOCIDADE_KM_DIA)
	if total >= 10:
		texto += " · %d dia%s a pé" % [dias, "s" if dias > 1 else ""]
	var y := size.y - 16
	var x0 := 16.0
	draw_line(Vector2(x0, y), Vector2(x0 + c.x * celulas, y), cor, 1.5)
	for i in range(0, celulas + 1, 2):
		draw_line(Vector2(x0 + c.x * i, y - 4), Vector2(x0 + c.x * i, y + 4), cor, 1.0)
	draw_string(Tema.F_FELL_IT, Vector2(x0 + c.x * celulas + 8, y + 5), texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, cor)
