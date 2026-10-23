extends RefCounted
## Sons de secours synthétisés (uniquement si aucun fichier n'existe pour l'id) : le jeu n'est
## jamais muet pour la pièce d'or. Remplacés automatiquement dès que le vrai son est livré.

const RATE := 22050


static func make_ting(freq := 880.0, dur := 0.32) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / RATE
		var env := exp(-t * 11.0) * minf(1.0, t * 800.0)
		var v := sin(TAU * freq * t) * 0.6 + sin(TAU * freq * 2.01 * t) * 0.25 * exp(-t * 18.0)
		data.encode_s16(i * 2, int(clampf(v * env, -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w
