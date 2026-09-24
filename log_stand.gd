extends Node2D

# Pivot'un altındaki görsel destek — ağaç kütüğü. Tamamen görsel: çarpışma
# şekli yok, PinJoint2D'ye bağlı değil, Beam'in dengesini ETKİLEMEZ.
# Genişliği sadece görünüşü değiştirir (dengeyi mass/angular_damp belirliyor).

const LOG_WIDTH := 90.0
const LOG_HEIGHT := 130.0
const BARK := Color(0.40, 0.27, 0.16)
const BARK_DARK := Color(0.30, 0.19, 0.11)
const CUT := Color(0.80, 0.63, 0.42)
const RING := Color(0.66, 0.48, 0.30)

func _draw() -> void:
	var hw := LOG_WIDTH * 0.5

	# gövde (hafif konik, organik dursun)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-hw, 14), Vector2(hw, 14),
		Vector2(hw * 0.88, LOG_HEIGHT), Vector2(-hw * 0.88, LOG_HEIGHT)
	]), BARK)

	# kabuk dokusu (birkaç düşey çizgi)
	for fx in [-0.55, -0.2, 0.2, 0.55]:
		var x0: float = hw * fx
		draw_line(Vector2(x0, 22), Vector2(x0 * 0.9, LOG_HEIGHT - 8), BARK_DARK, 4.0)

	# üst kesit (oval) — halka desenli
	draw_set_transform(Vector2(0, 14), 0.0, Vector2(1.0, 0.34))
	draw_circle(Vector2.ZERO, hw, CUT)
	draw_arc(Vector2.ZERO, hw * 0.62, 0.0, TAU, 28, RING, 3.0, true)
	draw_arc(Vector2.ZERO, hw * 0.30, 0.0, TAU, 24, RING, 3.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
