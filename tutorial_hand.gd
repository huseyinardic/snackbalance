class_name TutorialHand
extends Node2D

# İlk seviyede "sürükle ve bırak"ı gösteren el (UI katmanında, ekran koordinatları).
# Parmak yiyeceğin altından başlar, yana kayar; yiyeceğin soluk bir kopyası onu
# izler, parmak kalkınca kopya aşağı düşüp kaybolur. Oyuncu ekrana dokununca
# main.gd stop() der; ilk yiyecek kirişe konunca bir daha gösterilmez.

const CYCLE := 2.6          # bir gösterimin süresi (sn), sonra tekrar
const FINGER_BELOW := 95.0  # parmak yiyeceğin bu kadar altında (yiyeceği kapatmasın)
const FILL := Color(1.0, 0.98, 0.95)
const SLEEVE := Color(0.32, 0.6, 0.95)
const INK := Color(0.17, 0.14, 0.16)

var _active := false
var _t := 0.0
var _from := Vector2.ZERO    # yiyeceğin ekrandaki yeri
var _to := Vector2.ZERO      # gösterilen bırakma yeri (aynı yükseklik)
var _kind := 0
# Yarı saydam çizimde üst üste binen parçalar koyulaşmasın diye el ve yiyecek
# kopyası CanvasGroup içinde: grup önce tek resim olur, sonra saydamlaşır.
var _ghost_group := CanvasGroup.new()
var _ghost := Node2D.new()
var _hand_group := CanvasGroup.new()
var _hand := Node2D.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # duraklatınca kendini gizleyebilsin
	visible = false
	_ghost.draw.connect(func(): Food.paint(_ghost, _kind))
	_ghost_group.add_child(_ghost)
	add_child(_ghost_group)
	_hand.draw.connect(_draw_hand)
	_hand_group.add_child(_hand)
	add_child(_hand_group)

# Her kare çağrılabilir: konumları günceller, animasyonu baştan başlatmaz.
func play(from: Vector2, to: Vector2, kind: int, food_scale: float) -> void:
	_from = from
	_to = to
	if kind != _kind:
		_kind = kind
		_ghost.queue_redraw()
	_ghost.scale = Vector2.ONE * food_scale
	if not _active:
		_active = true
		_t = 0.0

func stop() -> void:
	_active = false
	visible = false

func _process(delta: float) -> void:
	if not _active or get_tree().paused:
		visible = false
		return
	visible = true
	_t = fmod(_t + delta, CYCLE)
	_animate()
	queue_redraw()

func _animate() -> void:
	var p := _t
	var hand_a := 1.0
	var hand_s := 1.0
	var x := _from.x
	var ghost_a := 0.0
	var ghost_drop := 0.0
	if p < 0.3:                  # belir + bas
		var k := p / 0.3
		hand_a = k
		hand_s = lerpf(1.18, 1.0, k)
	elif p < 1.4:                # sürükle
		x = lerpf(_from.x, _to.x, smoothstep(0.0, 1.0, (p - 0.3) / 1.1))
		ghost_a = 0.6
	elif p < 1.75:               # bırak: parmak kalkar, yiyecek düşer
		var k := (p - 1.4) / 0.35
		x = _to.x
		hand_s = lerpf(1.0, 1.15, k)
		ghost_a = 0.6 * (1.0 - k)
		ghost_drop = 90.0 * k * k
	elif p < 2.1:                # kaybol
		x = _to.x
		hand_s = 1.15
		hand_a = 1.0 - (p - 1.75) / 0.35
	else:
		hand_a = 0.0
	_hand_group.self_modulate.a = hand_a
	_hand.position = Vector2(x, _from.y + FINGER_BELOW)
	_hand.scale = Vector2.ONE * hand_s
	_ghost_group.self_modulate.a = ghost_a
	_ghost.position = Vector2(x, _from.y + ghost_drop)

# sürükleme izi: başlangıçtan parmağa kadar soluk noktalar
func _draw() -> void:
	if _t < 0.3 or _t >= 1.75:
		return
	var x := _hand.position.x
	var y := _from.y + FINGER_BELOW
	var n := int(absf(x - _from.x) / 22.0)
	for i in n:
		draw_circle(Vector2(_from.x + signf(x - _from.x) * (i + 0.5) * 22.0, y), 4.0, Color(1, 1, 1, 0.6))

# Parmak ucu orijinde, işaret parmağı yukarıyı gösterir; el sağ-alta doğru uzanır.
func _draw_hand() -> void:
	_hand.draw_set_transform(Vector2.ZERO, -0.22)
	var shapes := [
		["cap", Vector2(0, 9), Vector2(0, 50), 9.5, FILL],      # işaret parmağı
		["cap", Vector2(6, 72), Vector2(30, 72), 24.0, FILL],   # avuç
		["dot", Vector2(15, 51), Vector2.ZERO, 10.0, FILL],     # bükülü parmaklar
		["dot", Vector2(28, 54), Vector2.ZERO, 10.0, FILL],
		["dot", Vector2(40, 60), Vector2.ZERO, 9.5, FILL],
		["cap", Vector2(-12, 62), Vector2(-19, 82), 9.0, FILL], # başparmak
		["cap", Vector2(5, 101), Vector2(33, 101), 11.0, SLEEVE],
	]
	for sh in shapes:   # gölge
		_shape(sh, 5.0, Color(0, 0, 0, 0.18), Vector2(4, 6))
	for sh in shapes:   # kontur
		_shape(sh, 4.0, INK, Vector2.ZERO)
	for sh in shapes:   # dolgu
		_shape(sh, 0.0, sh[4], Vector2.ZERO)
	# tırnak ve parmak boğumu
	_hand.draw_arc(Vector2(0, 12), 4.5, PI * 1.1, PI * 1.9, 8, Color(INK, 0.35), 2.0, true)
	_hand.draw_line(Vector2(10, 58), Vector2(10, 64), Color(INK, 0.35), 2.0, true)

func _shape(sh: Array, grow: float, col: Color, off: Vector2) -> void:
	var r: float = sh[3] + grow
	if sh[0] == "dot":
		_hand.draw_circle(sh[1] + off, r, col)
	else:
		_hand.draw_line(sh[1] + off, sh[2] + off, col, r * 2.0)
		_hand.draw_circle(sh[1] + off, r, col)
		_hand.draw_circle(sh[2] + off, r, col)
