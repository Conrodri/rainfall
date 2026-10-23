class_name CoinSound
extends Node
## Ting des pieces d'or, synthetise par code. La hauteur monte en gamme pentatonique a chaque
## piece en chaine ; la chaine est reinitialisee apres CHAIN_RESET_S sans piece.

const CHAIN_RESET_S := 1.5
const MAX_STEP := 12 ## degres pentatoniques (un peu plus de 2 octaves)
const PENTATONIC := [0, 2, 4, 7, 9] ## demi-tons
const VOICES := 6
const SAMPLE_RATE := 22050
const BASE_FREQ := 880.0

var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _step := 0
var _last_ms := -100000


func _ready() -> void:
	var stream := make_stream()
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.stream = stream
		p.volume_db = -12.0
		add_child(p)
		_players.append(p)


## Joue un ting ; appele a chaque piece ramassee.
func play_coin() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_ms > int(CHAIN_RESET_S * 1000.0):
		_step = 0
	_last_ms = now
	var semis: int = int(PENTATONIC[_step % 5]) + 12 * (_step / 5)
	_step = mini(_step + 1, MAX_STEP)
	if _players.is_empty():
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.pitch_scale = pow(2.0, semis / 12.0)
	p.play()


func current_step() -> int:
	return _step


static func make_stream() -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * 0.28)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / SAMPLE_RATE
		var env := exp(-t * 14.0) * minf(1.0, t * 800.0)
		var s := sin(TAU * BASE_FREQ * t) * 0.6 + sin(TAU * BASE_FREQ * 2.0 * t) * 0.25 \
				+ sin(TAU * BASE_FREQ * 3.01 * t) * 0.1
		data.encode_s16(i * 2, int(clampf(s * env, -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = SAMPLE_RATE
	w.stereo = false
	w.data = data
	return w
