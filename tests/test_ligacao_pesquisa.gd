extends TesteBase
## Testes do ligador de nomes, do índice automático e da pesquisa.

var u: Universo
var daren: String
var kai: String
var varn: String


func _init() -> void:
	u = Universo.novo("Aldra")
	daren = u.criar_entidade("Daren", "pessoa", ["o Rancoroso"])
	kai = u.criar_entidade("Kai", "pessoa")
	varn = u.criar_entidade("Varn", "cidade", [], [{"chave": "recursos", "valor": "ferro e trigo"}])
	u.criar_entidade("João Pedreira", "pessoa")


func test_encontra_nomes_inteiros_sem_acento() -> void:
	var lig := Ligador.new(u)
	var m := lig.encontrar("Kai enfrentou Lucas na praça de VARN. Kaique não conta. joao pedreira viu.")
	var ids := m.map(func(x): return x["entidade"])
	verdadeiro(ids.has(kai), "acha Kai")
	verdadeiro(ids.has(varn), "acha VARN em maiúsculas")
	igual(ids.count(kai), 1, "Kaique não é Kai")
	igual(m.back()["texto"], "joao pedreira", "acha nome composto sem acento e mantém o texto original")


func test_apelido_vira_link_para_a_mesma_entidade() -> void:
	var lig := Ligador.new(u)
	var m := lig.encontrar("O Rancoroso treinou até a noite.")
	igual(m.size(), 1, "um link")
	igual(m[0]["entidade"], daren, "apelido aponta para Daren")


func test_bbcode_escapa_colchetes() -> void:
	var lig := Ligador.new(u)
	var bb := lig.para_bbcode("[nota] Kai chegou.")
	verdadeiro(bb.begins_with("[lb]nota]"), "colchete do texto é escapado")
	verdadeiro(bb.contains("[url=ent:%s]" % kai), "link para Kai")


func test_indice_automatico() -> void:
	var l := u.criar_livro("Livro I")
	var c1 := u.criar_capitulo(l, "Um")
	var c2 := u.criar_capitulo(l, "Dois")
	u.atualizar_capitulo(c1, {"texto": "Daren viu Kai. Daren chorou."})
	u.atualizar_capitulo(c2, {"texto": "Em Varn, Daren treinava."})
	var idx := u.indice()
	igual(idx[daren], [c1, c2], "Daren aparece nos dois capítulos, uma vez cada")
	igual(idx[kai], [c1], "Kai só no primeiro")
	u.atualizar_capitulo(c2, {"texto": "Silêncio."})
	igual(u.indice()[daren], [c1], "índice se atualiza quando o texto muda")


func test_pesquisa_sem_acento_e_com_erro() -> void:
	var r := Pesquisa.buscar(u, "joao")
	verdadeiro(not r.is_empty() and r[0]["titulo"] == "João Pedreira", "acha João sem acento")
	r = Pesquisa.buscar(u, "Darn")
	verdadeiro(not r.is_empty() and r[0]["id"] == daren, "tolera erro de digitação")
	r = Pesquisa.buscar(u, "trigo")
	verdadeiro(not r.is_empty() and r[0]["id"] == varn, "acha pelo valor de um campo")


func test_pesquisa_em_capitulos_e_notas() -> void:
	var l := u.criar_livro("Livro II")
	var c := u.criar_capitulo(l, "A Fonte")
	u.atualizar_capitulo(c, {"texto": "A água da fonte apagava memórias."})
	u.criar_nota("Segredo", "A fonte foi criada por um deus esquecido.")
	var tipos := Pesquisa.buscar(u, "fonte").map(func(x): return x["tipo"])
	verdadeiro(tipos.has("capitulo"), "acha capítulo")
	verdadeiro(tipos.has("nota"), "acha nota")
