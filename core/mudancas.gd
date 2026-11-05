class_name Mudancas
extends RefCounted
## Aplica as operações de mudança guardadas dentro de um fato.
## Todo sistema (escrita, mentes, natureza, regras) descreve o que muda no mundo
## como uma lista dessas operações. Como elas ficam no fato, o estado do mundo
## pode ser reconstruído a qualquer momento relendo o banco de fatos.


static func aplicar(u: Universo, ops: Array, fato: Dictionary) -> void:
	for op in ops:
		aplicar_uma(u, op, fato)


static func aplicar_uma(u: Universo, op: Dictionary, fato: Dictionary) -> void:
	var quem: String = str(op.get("quem", ""))
	match str(op.get("op", "")):
		"ferir":
			Estado.ferir(u, quem, str(op.get("descricao", "")), float(op.get("gravidade", 0.1)), fato)
		"curar":
			if u.entidades.has(quem):
				var s := u.estado(quem)
				s["saude"] = clampf(float(s["saude"]) + float(op.get("quanto", 0.1)), 0.0, 1.0)
				if float(s["saude"]) >= 0.95:
					s["ferimentos"] = []
		"relacao":
			Estado.relacao(u, str(op.get("de", "")), str(op.get("para", "")), op.get("deltas", {}))
		"mudar":
			Estado.mudar(u, quem, str(op.get("chave", "")), float(op.get("delta", 0.0)))
		"definir":
			if u.entidades.has(quem):
				u.estado(quem)[str(op.get("chave", ""))] = op.get("valor")
		"morrer":
			Estado.morrer(u, quem, fato)
		"mover":
			if op.get("se_vivo", false) and not Estado.vivo(u, quem):
				return
			Estado.mover(u, quem, str(op.get("lugar", "")), fato)
		"vinculo":
			Estado.adicionar_vinculo(u, quem, str(op.get("tipo", "")), str(op.get("outro", "")))
		"familia":
			Estado.ligar_familia(u, str(op.get("pai", "")), str(op.get("filho", "")))
		"conhecer":
			Estado.conhecer(u, quem, str(op.get("fato", fato.get("id", ""))))
		"conhecer_capitulo":
			Estado.conhecer_capitulo(u, quem, fato)
		"nascer":
			if u.entidades.has(quem):
				var s := u.estado(quem)
				s["vivo"] = true
				s["nascimento"] = DataMundo.copiar(fato.get("data", u.relogio))
				if str(op.get("lugar", "")) != "":
					Estado.mover(u, quem, str(op["lugar"]), fato)
		"emocao":
			Estado.emocionar(u, quem, str(op.get("emocao", "")), float(op.get("forca", 0.5)), str(op.get("alvo", "")), fato.get("id", ""))
		"esfriar_emocao":
			Estado.esfriar(u, quem, str(op.get("emocao", "")), str(op.get("alvo", "")), float(op.get("quanto", 0.1)))
		"objetivo":
			Estado.adicionar_objetivo(u, quem, str(op.get("tipo", "")), str(op.get("alvo", "")), float(op.get("forca", 0.5)), fato.get("id", ""))
		"objetivo_estado":
			Estado.mudar_objetivo(u, quem, str(op.get("tipo", "")), str(op.get("alvo", "")), op)
		"lembrar":
			Estado.lembrar(u, quem, fato.get("id", ""), float(op.get("peso", 0.5)))
		"traco":
			Estado.ajustar_traco(u, quem, str(op.get("traco", "")), float(op.get("delta", 0.0)))
		"diario":
			Estado.anotar(u, quem, str(op.get("texto", "")), fato)
		_:
			# Operações dos sistemas das próximas partes se registram aqui.
			for sistema in u.sistemas_de_mudanca():
				if sistema.aplicar_op(u, op, fato):
					return
