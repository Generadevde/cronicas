extends SceneTree
## Roda todos os testes automáticos sem abrir janela:
##   godot --headless --path . -s res://tests/run_tests.gd
## Cada arquivo tests/test_*.gd tem funções "test_..." que usam os asserts de TesteBase.

const ARQUIVOS := [
	"res://tests/test_nucleo.gd",
	"res://tests/test_ligacao_pesquisa.gd",
	"res://tests/test_biblioteca.gd",
	"res://tests/test_telas.gd",
	"res://tests/test_parte2.gd",
	"res://tests/test_parte3.gd",
	"res://tests/test_parte4.gd",
	"res://tests/test_parte5.gd",
	"res://tests/test_parte6.gd",
	"res://tests/test_parte7.gd",
	"res://tests/test_parte8.gd",
	"res://tests/test_parte9.gd",
	"res://tests/test_parte10.gd",
]


func _initialize() -> void:
	var total := 0
	var falhas: Array = []
	for caminho in ARQUIVOS:
		var script: GDScript = load(caminho)
		if script == null or not script.can_instantiate():
			falhas.append("%s: não compilou (veja os erros acima)" % caminho)
			continue
		for m in script.get_script_method_list():
			var nome: String = m["name"]
			if not nome.begins_with("test_"):
				continue
			var teste: TesteBase = script.new()
			teste.arvore = self
			total += 1
			await teste.call(nome)
			if not teste.erros.is_empty():
				for e in teste.erros:
					falhas.append("%s · %s: %s" % [caminho.get_file(), nome, e])
			teste.limpar()
	print("")
	print("Testes: %d · falhas: %d" % [total, falhas.size()])
	for f in falhas:
		print("  FALHOU  ", f)
	if falhas.is_empty():
		print("Tudo certo.")
	quit(1 if not falhas.is_empty() else 0)
