class_name PandaTip
extends Node2D

# 2. seviyede bekleyen yiyecek pandanın üstündeyken pandanın yanında çıkan uyarı
# baloncuğu (UI katmanında, ekran koordinatları). Kuyruğu pandanın başını gösterir.
# Konumu ve görünürlüğü main.gd her kare verir; açılınca kısa bir "pop" yapar.

const TEXT := "Not on the panda!"
const FONT_SIZE := 30
const PAD := Vector2(22, 12)
const OFFSET := Vector2(46, -58)   # pandanın başına göre baloncuğun sol-alt köşesi
const RED := Color(0.9, 0.24, 0.22)
const INK := Color(0.17, 0.14, 0.16)

var _on := false
var _t := 0.0

func _ready() -> void:
	visible = false

# head: pandanın başının ekrandaki yeri
func show_at(head: Vector2) -> void:
	position = head
	if not _on:
		_on = true
		_t = 0.0
		visible = true

func hide_tip() -> void:
	_on = false
	visible = false

func _process(delta: float) -> void:
	if not _on:
		return
	_t += delta
	queue_redraw()

func _draw() -> void:
	# açılış: büyüyerek gelir, hafifçe esner; sonra yavaşça "nefes alır"
	var s := 1.0
	if _t < 0.25:
		var k := _t / 0.25
		s = lerpf(0.4, 1.12, k)
	elif _t < 0.4:
		s = lerpf(1.12, 1.0, (_t - 0.25) / 0.15)
	else:
		s = 1.0 + 0.03 * sin((_t - 0.4) * 6.0)
	var font := UiKit.BOLD
	var tw := font.get_string_size(TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	var box := Rect2(OFFSET + Vector2(0, -FONT_SIZE - PAD.y * 2.0), Vector2(tw + PAD.x * 2.0, FONT_SIZE + PAD.y * 2.0))
	# kuyruk köşesinden ölçeklensin: baloncuk pandadan "çıkıyor" gibi görünsün
	var pivot := OFFSET + Vector2(14, 0)
	draw_set_transform(pivot * (1.0 - s), 0.0, Vector2.ONE * s)
	# taban kutunun sol-alt köşesinin içinde, uca giden yöne dik: kuyruk dolgun görünür
	var tail := PackedVector2Array([OFFSET + Vector2(4, -28), OFFSET + Vector2(36, -2), Vector2(18, -14)])
	# kontur
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color.WHITE
	sb.set_corner_radius_all(int(box.size.y / 2.0))
	sb.set_border_width_all(5)
	sb.border_color = INK
	sb.anti_aliasing = true
	sb.shadow_color = Color(0, 0, 0, 0.2)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 4)
	draw_colored_polygon(_grown(tail, 4.0), INK)
	draw_style_box(sb, box)
	draw_colored_polygon(tail, Color.WHITE)
	# yazı: kırmızı
	draw_string(font, box.position + Vector2(PAD.x, PAD.y + FONT_SIZE * 0.82), TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, RED)
	draw_set_transform(Vector2.ZERO)

# üçgeni ağırlık merkezinden dışa doğru büyüt (kontur için)
func _grown(pts: PackedVector2Array, d: float) -> PackedVector2Array:
	var c := (pts[0] + pts[1] + pts[2]) / 3.0
	var out := PackedVector2Array()
	for p in pts:
		out.append(p + (p - c).normalized() * d * 1.6)
	return out
