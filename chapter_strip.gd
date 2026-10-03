class_name ChapterStrip
extends Control

# Ana menüde PLAY'in üstünde: oyuncunun bulunduğu 10 seviyelik bölüm.
#   geçilenler yeşil tikli, şu anki altın ve nabız gibi, sıradakiler beyaz;
#   zor seviyeler kırmızı + alev, bölüm sonunda bambu sandığı (kazanınca +CHAPTER_CHEST).
# Yaklaşan açılımlar düğümün üstünde: ilk bölümde tanıtılacak yiyecek, günbatımı teması.
# Hedef hep görünür ve yakın: "3 seviye sonra sandık" oyuncuyu bir el daha oynatır.

const W := 640.0
const H := 158.0
const ROW_Y := 112.0       # düğümlerin merkezi
const TEASE_Y := 66.0      # yiyecek / güneş ipuçları
const GREEN := Color(0.42, 0.8, 0.34)
const RED := Color(0.93, 0.33, 0.28)
const INK := Color(0.17, 0.14, 0.16)

var level := 1
var _t := 0.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(W, H)

func set_level(n: int) -> void:
	level = maxi(1, n)
	queue_redraw()

func _process(delta: float) -> void:
	if is_visible_in_tree():
		_t += delta
		queue_redraw()

func first_level() -> int:
	return (level - 1) / GameData.CHAPTER_SIZE * GameData.CHAPTER_SIZE + 1

func _x(i: int) -> float:
	return lerpf(44.0, W - 50.0, float(i) / (GameData.CHAPTER_SIZE - 1))

func _draw() -> void:
	var first := first_level()
	var n: int = GameData.CHAPTER_SIZE
	# başlık
	var title := "Level %d" % level
	draw_string_outline(UiKit.BOLD, Vector2(0, 34), title, HORIZONTAL_ALIGNMENT_CENTER, W, 38, 10, UiKit.OUTLINE)
	draw_string(UiKit.BOLD, Vector2(0, 34), title, HORIZONTAL_ALIGNMENT_CENTER, W, 38, Color.WHITE)
	# düğümlerin arkasında yarı saydam hap: kütüğün üstünde de okunsun
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.16, 0.08, 0.42)
	sb.set_corner_radius_all(30)
	draw_style_box(sb, Rect2(6, ROW_Y - 30, W - 12, 60))
	# bağlantı çizgisi: geçilen kısım yeşil
	for i in n - 1:
		var lv := first + i
		var col := GREEN if lv < level else Color(1, 1, 1, 0.45)
		draw_line(Vector2(_x(i), ROW_Y), Vector2(_x(i + 1), ROW_Y), col, 6.0)
	for i in n:
		var lv := first + i
		var p := Vector2(_x(i), ROW_Y)
		if i == n - 1:
			_chest(p, lv)
		else:
			_node(p, lv)
		_tease(Vector2(p.x, TEASE_Y), lv)

func _node(p: Vector2, lv: int) -> void:
	var hard := Levels.is_peak(lv)
	if lv < level:
		draw_circle(p, 15.0, Color.WHITE)
		draw_circle(p, 12.0, GREEN)
		draw_polyline(PackedVector2Array([p + Vector2(-6, 0), p + Vector2(-1.5, 5), p + Vector2(7, -5)]), Color.WHITE, 3.5, true)
		return
	var cur := lv == level
	var r := 22.0 if cur else 15.0
	if cur:
		var k := 0.5 + 0.5 * sin(_t * 4.0)
		draw_circle(p, r + 5.0 + 4.0 * k, Color(1, 0.9, 0.5, 0.35 * (1.0 - k) + 0.15))
	var fill := RED if hard else (UiKit.GOLD if cur else Color(1, 1, 1, 0.92))
	draw_circle(p, r + 3.0, INK if cur else Color(0.2, 0.25, 0.2, 0.6))
	draw_circle(p, r, fill)
	var txt := str(lv)
	var fs := 24 if cur else (17 if lv < 100 else 14)
	var col := Color.WHITE if hard else INK
	draw_string(UiKit.BOLD, Vector2(p.x - 30, p.y + fs * 0.36), txt, HORIZONTAL_ALIGNMENT_CENTER, 60, fs, col)
	if hard:
		_flame(p + Vector2(r * 1.0, -r * 1.1), 8.0)

# Bölüm sonu: bambu sandığı; altında ödül.
func _chest(p: Vector2, lv: int) -> void:
	var cur := lv == level
	var s := 1.0 + (0.08 * sin(_t * 5.0) if cur else 0.0)
	draw_set_transform(p, 0.0, Vector2(s, s))
	if cur:
		draw_circle(Vector2.ZERO, 30.0, Color(1, 0.9, 0.5, 0.3))
	var wood := Color(0.62, 0.38, 0.2)
	var dark := Color(0.4, 0.23, 0.12)
	draw_rect(Rect2(-22, -6, 44, 26), INK)
	draw_rect(Rect2(-19, -3, 38, 20), wood)
	draw_colored_polygon(PackedVector2Array([Vector2(-23, -5), Vector2(-20, -20), Vector2(20, -20), Vector2(23, -5)]), INK)
	draw_colored_polygon(PackedVector2Array([Vector2(-19, -7), Vector2(-17, -17), Vector2(17, -17), Vector2(19, -7)]), wood.lightened(0.1))
	draw_rect(Rect2(-19, -8, 38, 4), dark)
	draw_rect(Rect2(-4, -12, 8, 14), UiKit.GOLD)   # kilit kayışı
	draw_rect(Rect2(-2, -4, 4, 4), dark)
	draw_set_transform(Vector2.ZERO)
	var t := "+%d" % GameData.CHAPTER_CHEST
	draw_string_outline(UiKit.BOLD, Vector2(p.x - 40, p.y + 44), t, HORIZONTAL_ALIGNMENT_CENTER, 80, 22, 6, UiKit.OUTLINE)
	draw_string(UiKit.BOLD, Vector2(p.x - 40, p.y + 44), t, HORIZONTAL_ALIGNMENT_CENTER, 80, 22, UiKit.GOLD)

# Yaklaşan açılımlar: bu seviyede tanıtılacak yiyecek, günbatımı (bu seviye geçilince).
func _tease(p: Vector2, lv: int) -> void:
	if lv < level:
		return
	var k := Levels.new_kind(lv)
	if k >= 0 and lv > 1:
		draw_set_transform(p + Vector2(0, 4), 0.0, Vector2(0.42, 0.42))
		Food.paint(self, k)
		draw_set_transform(Vector2.ZERO)
	if lv == GameData.SUNSET_LEVEL and not GameData.sunset_unlocked():
		draw_circle(p, 13.0, Color(1.0, 0.62, 0.3))
		draw_circle(p, 9.0, Color(1.0, 0.85, 0.4))
		for i in 8:
			var d := Vector2.from_angle(TAU * i / 8.0)
			draw_line(p + d * 16.0, p + d * 21.0, Color(1.0, 0.75, 0.35), 3.0, true)

# küçük alev (zor seviye): sivri uçlu damla
func _flame(c: Vector2, r: float) -> void:
	var pts := PackedVector2Array([c + Vector2(0, -r * 1.8)])
	for i in 13:
		var a := lerpf(-0.35, PI + 0.35, i / 12.0)
		pts.append(c + Vector2(cos(a) * r * 0.85, sin(a) * r))
	draw_colored_polygon(pts, Color(1.0, 0.55, 0.15))
	draw_circle(c + Vector2(0, r * 0.25), r * 0.45, Color(1.0, 0.9, 0.4))
