class_name SomMaquina
extends Node
## Som de máquina de escrever, gerado em código (sem arquivos): teclas, espaço e a campainha do fim de linha.

const TAXA := 22050
var _teclas: Array = []
var _sino: AudioStreamWAV
var _vozes: Array = []
var _vez := 0


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 5:
		_teclas.append(_tecla(rng, 150.0 + i * 22.0, 0.045 + i * 0.004))
	_sino = _campainha()
	for i in 4:
		var p := AudioStreamPlayer.new()
		p.volume_db = -9.0
		add_child(p)
		_vozes.append(p)


func _wav(amostras: PackedFloat32Array) -> AudioStreamWAV:
	var b := PackedByteArray()
	b.resize(amostras.size() * 2)
	for i in amostras.size():
		b.encode_s16(i * 2, int(clampf(amostras[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = TAXA
	w.stereo = false
	w.data = b
	return w


func _tecla(rng: RandomNumberGenerator, grave: float, dur: float) -> AudioStreamWAV:
	var n := int(TAXA * dur)
	var a := PackedFloat32Array()
	a.resize(n)
	for i in n:
		var t := float(i) / TAXA
		var estalo := (rng.randf() * 2.0 - 1.0) * exp(-t * 160.0) * 0.9
		var batida := sin(TAU * grave * t) * exp(-t * 55.0) * 0.6
		var metal := sin(TAU * 2600.0 * t) * exp(-t * 220.0) * 0.18
		a[i] = estalo + batida + metal
	return _wav(a)


func _campainha() -> AudioStreamWAV:
	var n := int(TAXA * 0.5)
	var a := PackedFloat32Array()
	a.resize(n)
	for i in n:
		var t := float(i) / TAXA
		a[i] = (sin(TAU * 2093.0 * t) * 0.5 + sin(TAU * 3136.0 * t) * 0.25 + sin(TAU * 4186.0 * t) * 0.12) * exp(-t * 9.0)
	return _wav(a)


func tecla() -> void:
	_tocar(_teclas[randi() % _teclas.size()], randf_range(0.94, 1.06))


func fim_de_linha() -> void:
	_tocar(_sino, 1.0)


func _tocar(s: AudioStream, tom: float) -> void:
	var p: AudioStreamPlayer = _vozes[_vez]
	_vez = (_vez + 1) % _vozes.size()
	p.stream = s
	p.pitch_scale = tom
	p.play()
