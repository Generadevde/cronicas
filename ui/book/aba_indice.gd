extends AbaLivro
## Aba "Índice": onde cada nome aparece (montado sozinho) e os capítulos marcados.

var _lista: ItemList
var _pagina: RichTextLabel


func montar(esq: VBoxContainer, dir: VBoxContainer, _dado: String) -> void:
	esq.add_child(Tema.secao("Índice de nomes"))
	_lista = ItemList.new()
	_lista.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lista.item_selected.connect(func(i: int): _mostrar(str(_lista.get_item_metadata(i))))
	esq.add_child(_lista)
	var idx := u.indice()
	for e in u.entidades_ativas():
		var n: int = idx.get(e["id"], []).size()
		var i := _lista.add_item("%s   (%d)" % [e["nome"], n])
		_lista.set_item_metadata(i, e["id"])
		if n == 0:
			_lista.set_item_custom_fg_color(i, Color(Tema.TINTA, 0.45))

	_pagina = Tema.texto_rico()
	_pagina.meta_clicked.connect(livro.navegar)
	dir.add_child(_pagina)
	_mostrar("")


func _mostrar(eid: String) -> void:
	var s := Paginas.cabecalho("Índice")
	var marcados := u.capitulos_marcados()
	s += Paginas.secao("Marcadores")
	if marcados.is_empty():
		s += "[i]Nenhum capítulo marcado. Marque os importantes ao escrever.[/i]\n"
	for cap in marcados:
		s += "❧ %s [color=#5A3A1A]· %s · %s[/color]\n" % [Paginas.link("cap:" + cap["id"], cap["titulo"]),
			TextUtil.escapar_bbcode(u.livro(cap["livro"]).get("titulo", "")), DataMundo.texto(cap["data"])]
	if eid != "":
		var e := u.entidade(eid)
		s += Paginas.secao("%s aparece em" % e["nome"])
		var caps: Array = u.indice().get(eid, [])
		if caps.is_empty():
			s += "[i]Nenhum capítulo ainda.[/i]\n"
		var lig := Ligador.new(u)
		for cid in caps:
			var cap: Dictionary = u.capitulos[cid]
			var trecho := ""
			for m in lig.encontrar(cap["texto"]):
				if m["entidade"] == eid:
					trecho = TextUtil.trecho(cap["texto"], m["inicio"], 50)
					break
			s += "• %s\n   [i][color=#5A3A1A]%s[/color][/i]\n" % [Paginas.link("cap:" + cid, cap["titulo"]), TextUtil.escapar_bbcode(trecho)]
		s += "\n" + Paginas.link("ent:" + eid, "Abrir a página de %s na wiki" % e["nome"]) + "\n"
	_pagina.text = s
