extends PandaArt

# Kirişteki panda — Beam'in child'ı, kendi başına fizik nesnesi değil, sadece
# kirişle birlikte döner. Çizim PandaArt'ta; burada davranış: gözler bekleyen
# yiyeceği izler, kiriş tehlikeli eğime gelince endişelenir, çarpılınca kısa süre
# sersemler (yıldızlar döner), seviye bitince sevinir, arada göz kırpar.
# main.gd her kare set_watch() çağırır.

const HIT_SECONDS := 1.3
const LOOK_RANGE := 180.0       # bu kadar yana (px) bakınca gözler tam yana döner

var _hit_left := 0.0
var _look_target := 0.0
var _worried := false
var _blink_in := 2.5
var _blink_left := 0.0

func celebrate() -> void:
	mood = Mood.HAPPY
	queue_redraw()
	var t := create_tween()
	for i in 3:
		t.tween_property(self, "position:y", position.y - 12.0, 0.14).set_ease(Tween.EASE_OUT)
		t.tween_property(self, "position:y", position.y, 0.16).set_ease(Tween.EASE_IN)

func reset() -> void:
	mood = Mood.IDLE
	hits = 0
	look = 0.0
	_hit_left = 0.0
	queue_redraw()

func set_hits(n: int) -> void:
	hits = n
	queue_redraw()
	if n > 0:
		mood = Mood.HIT
		_hit_left = HIT_SECONDS
		var t := create_tween()
		t.tween_property(self, "rotation", 0.12, 0.05)
		t.tween_property(self, "rotation", -0.12, 0.08)
		t.tween_property(self, "rotation", 0.0, 0.06)

# look_x: izlenecek yiyeceğin pandaya göre yatay uzaklığı (px; yoksa 0),
# worried: kiriş tehlikeli eğimde mi.
func set_watch(look_x: float, worried: bool) -> void:
	_look_target = clampf(look_x / LOOK_RANGE, -1.0, 1.0)
	_worried = worried

func _process(delta: float) -> void:
	var changed := false
	var l := move_toward(look, _look_target, delta * 4.0)
	if l != look:
		look = l
		changed = true
	if mood == Mood.HIT:
		spin += delta * 5.0
		_hit_left -= delta
		if _hit_left <= 0.0:
			mood = Mood.IDLE
		changed = true
	elif mood != Mood.HAPPY:
		var m := Mood.WORRIED if _worried else Mood.IDLE
		if m != mood:
			mood = m
			changed = true
	# göz kırpma
	if _blink_left > 0.0:
		_blink_left -= delta
		if _blink_left <= 0.0:
			blink = false
			changed = true
	else:
		_blink_in -= delta
		if _blink_in <= 0.0:
			_blink_in = randf_range(2.5, 5.0)
			_blink_left = 0.12
			blink = true
			changed = true
	if changed:
		queue_redraw()
