extends TesteBase
## Parte 2: o texto vira fatos (propostas, ecos, dicionário, continuidade, versões).

var u: Universo
var kai: String
var lucas: String
var daren: String
var varn: String
var livro: String


func _init() -> void:
	u = Universo.novo("Aldra")
	kai = u.criar_entidade("Kai", "pessoa")
	lucas = u.criar_entidade("Lucas", "pessoa, ferreiro")
	daren = u.criar_entidade("Daren", "pessoa")
	varn = u.criar_entidade("Varn", "cidade")
	livro = u.criar_livro("Livro I")


func _cap(texto: String, ano: int = 411) -> String:
	var c := u.criar_capitulo(livro, "Cap")
	u.atualizar_capitulo(c, {"texto": texto, "data": DataMundo.criar(ano, 100)})
	return c


func _por_acao(props: Array, acao: String) -> Dictionary:
	for p in props:
		if p["acao"] == acao:
			return p
	return {}


func test_frase_da_praca_vira_propostas_certas() -> void:
	var c := _cap("Kai enfrentou Lucas na praça de Varn, e Lucas perdeu. Daren, o filho de Lucas, viu tudo.")
	var props := Extrator.analisar(u, c)
	var vit := _por_acao(props, "vitoria")
	verdadeiro(not vit.is_empty(), "propôs uma vitória")
	igual(vit.get("sujeitos", []), [kai, lucas], "Kai venceu Lucas")
	igual(vit.get("lugar", ""), varn, "em Varn")
	igual(_por_acao(props, "filiacao").get("sujeitos", []), [daren, lucas], "Daren é filho de Lucas")
	igual(_por_acao(props, "testemunho").get("sujeitos", []), [daren], "quem viu foi Daren")
	igual(Extrator.analisar(u, c).size(), 0, "analisar de novo não repete propostas")


func test_luta_e_resultado_em_frases_diferentes() -> void:
	var c := _cap("Kai enfrentou Lucas na praça de Varn, sob o olhar da cidade inteira. O velho ferreiro lutou bem, mas a espada de Kai foi mais rápida, e Lucas perdeu.")
	var props := Extrator.analisar(u, c)
	igual(_por_acao(props, "vitoria").get("sujeitos", []), [kai, lucas], "junta luta e resultado mesmo em frases separadas")
	igual(_por_acao(props, "luta"), {}, "não sobra a luta \"em aberto\"")
	igual(_por_acao(props, "derrota_um"), {}, "nem o \"Lucas perdeu\" solto")


func test_aceitar_gera_fato_e_ecos_com_causa() -> void:
	var c := _cap("Kai enfrentou Lucas na praça de Varn, e Lucas perdeu. Daren, o filho de Lucas, viu tudo.")
	var props := Extrator.analisar(u, c)
	u.aceitar_proposta(_por_acao(props, "filiacao")["id"])
	u.aceitar_proposta(_por_acao(props, "testemunho")["id"])
	var fid := u.aceitar_proposta(_por_acao(props, "vitoria")["id"])
	verdadeiro(fid != "", "vitória virou fato")
	igual(u.fatos.obter(fid)["origem"]["tipo"], BancoDeFatos.ORIGEM_CAPITULO, "origem capítulo")
	verdadeiro(u.estado(lucas)["familia"]["filhos"].has(daren), "família ligada")
	igual(u.estado(kai)["local"], varn, "Kai está em Varn")
	var ecos := u.propostas.filter(func(p): return p["status"] == "eco")
	var eco_daren: Array = ecos.filter(func(p): return p["efeito"].get("quem", "") == daren)
	igual(eco_daren.size(), 1, "eco para Daren, que viu a derrota do pai")
	var eco_fid := u.aceitar_proposta(eco_daren[0]["id"])
	igual(u.fatos.obter(eco_fid)["causas"], [fid], "eco aponta para a vitória como causa")
	verdadeiro(Estado.objetivos_ativos(u, daren).any(func(o): return o["tipo"] == "vingança" and o["alvo"] == kai), "Daren quer vingança contra Kai")
	verdadeiro(Estado.valor_relacao(u, daren, kai, "raiva") > 0.5, "Daren tem raiva de Kai")
	igual(Auditor.auditar(u).size(), 0, "tudo íntegro")


func test_negacao_nao_vira_fato() -> void:
	var c := _cap("Kai não matou Lucas.")
	igual(_por_acao(Extrator.analisar(u, c), "morte_por"), {}, "\"não matou\" não é morte")


func test_duvida_e_dicionario_ensinado() -> void:
	var c := _cap("Kai esmurrou Lucas.")
	var props := Extrator.analisar(u, c)
	var duvida: Array = props.filter(func(p): return p["status"] == "duvida")
	igual(duvida.size(), 1, "frase com dois nomes e verbo desconhecido vira dúvida")
	igual(duvida[0]["palavra"], "esmurrou", "sugere a palavra a ensinar")
	u.ensinar("esmurrou", "vitoria", duvida[0]["id"])
	var vit := _por_acao(u.propostas_do_capitulo(c), "vitoria")
	igual(vit.get("sujeitos", []), [kai, lucas], "depois de ensinar, vira vitória de Kai")
	var c2 := _cap("Daren esmurrou Kai.")
	igual(_por_acao(Extrator.analisar(u, c2), "vitoria").get("sujeitos", []), [daren, kai], "a palavra ensinada vale nos outros capítulos")


func test_morte_e_continuidade() -> void:
	var c1 := _cap("Kai matou Lucas.", 411)
	u.aceitar_proposta(_por_acao(Extrator.analisar(u, c1), "morte_por")["id"])
	falso(u.estado(lucas)["vivo"], "Lucas morreu")
	var c2 := _cap("Lucas sorriu na forja.", 415)
	var avisos := Continuidade.verificar_capitulo(u, c2)
	igual(avisos.size(), 1, "avisa que Lucas aparece vivo depois de morrer")
	var c3 := _cap("Daren lembrou de Lucas na forja.", 415)
	igual(Continuidade.verificar_capitulo(u, c3).size(), 0, "lembrança não é erro")


func test_rascunho_nao_gera_fatos() -> void:
	var c := _cap("Kai matou Daren.")
	u.atualizar_capitulo(c, {"canon": false})
	igual(Extrator.analisar(u, c).size(), 0, "rascunho não afeta o mundo")


func test_versoes_do_capitulo() -> void:
	var c := _cap("Primeira versão.")
	u.guardar_versao(c)
	u.atualizar_capitulo(c, {"texto": "Segunda versão."})
	u.guardar_versao(c)
	u.restaurar_versao(c, 0)
	igual(u.capitulo(c)["texto"], "Primeira versão.", "restaurou")
	igual(u.capitulo(c)["versoes"].back()["texto"], "Segunda versão.", "a versão atual foi guardada antes")


func test_pronome_aponta_para_o_sujeito_anterior() -> void:
	var c := _cap("Daren chegou a Varn. Ele matou Kai.")
	var props := Extrator.analisar(u, c)
	igual(_por_acao(props, "chegada").get("sujeitos", []), [daren], "Daren chegou")
	igual(_por_acao(props, "morte_por").get("sujeitos", []), [daren, kai], "\"Ele\" é Daren")


func test_desfazer_reconstroi_o_mundo_sem_o_fato() -> void:
	var c := _cap("Kai matou Lucas.")
	var p := _por_acao(Extrator.analisar(u, c), "morte_por")
	var fid := u.aceitar_proposta(p["id"])
	falso(u.estado(lucas)["vivo"], "Lucas morto")
	u.desfazer_proposta(p["id"])
	verdadeiro(u.estado(lucas)["vivo"], "desfeito: Lucas vivo de novo")
	verdadeiro(u.fatos.existe(fid), "o fato continua guardado")
	falso(u.fatos.obter(fid)["canon"], "mas não é mais canon")


func test_reconstruir_da_o_mesmo_estado() -> void:
	var c := _cap("Kai enfrentou Lucas na praça de Varn, e Lucas perdeu. Daren, o filho de Lucas, viu tudo.")
	var props := Extrator.analisar(u, c)
	for acao in ["filiacao", "testemunho", "vitoria"]:
		u.aceitar_proposta(_por_acao(props, acao)["id"])
	for eco in u.propostas.filter(func(p): return p["status"] == "eco"):
		u.aceitar_proposta(eco["id"])
	var antes: String = JSON.stringify(u.estado(daren)["relacoes"]) + JSON.stringify(u.estado(lucas)["ferimentos"].size()) + u.estado(kai)["local"]
	AutoAtualizador.reconstruir(u)
	var depois: String = JSON.stringify(u.estado(daren)["relacoes"]) + JSON.stringify(u.estado(lucas)["ferimentos"].size()) + u.estado(kai)["local"]
	igual(depois, antes, "estado reconstruído do banco de fatos é igual")
	verdadeiro(Estado.objetivos_ativos(u, daren).size() > 0, "objetivo de vingança volta na reconstrução")


func test_propostas_sobrevivem_ao_salvar() -> void:
	var c := _cap("Kai enfrentou Lucas, e Lucas perdeu.")
	Extrator.analisar(u, c)
	u.ensinar("esmurrou", "vitoria")
	var v := Universo.de_dicionario(JSON.parse_string(JSON.stringify(u.para_dicionario())))
	igual(v.propostas.size(), u.propostas.size(), "propostas salvas")
	igual(v.dicionario.get("esmurrou", ""), "vitoria", "dicionário salvo")
