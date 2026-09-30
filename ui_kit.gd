class_name UiKit

# Menü ve kartların ortak parçaları: dokunmatik düğme, arkadaki dokunuşları yutan
# perde, simgeler (bambu, ev, oynat, duraklat, hediye, tema, reklam).
#
# Projede emulate_mouse_from_touch kapalı (oyun dokunuşları kendisi okuyor), bu
# yüzden Godot'nun Button'u telefonda tepki vermez. Btn dokunuşu _input'ta kendisi
# yakalar ve olayı tüketir — altındaki oyun alanı (_unhandled_input) görmez.

const BOLD := preload("res://fonts/Fredoka-Bold.ttf")
const MED := preload("res://fonts/Fredoka-Medium.ttf")
const INK := Color(0.17, 0.14, 0.16)
const OUTLINE := Color(0.16, 0.24, 0.16, 0.8)
const GREEN := Color(0.36, 0.76, 0.33)
const ORANGE := Color(1.0, 0.6, 0.22)
const BLUE := Color(0.32, 0.6, 0.95)
const RED := Color(0.93, 0.3, 0.3)
const GREY := Color(0.62, 0.64, 0.62)
const GOLD := Color(1.0, 0.84, 0.35)
const CREAM := Color(1.0, 0.98, 0.93)
const PANEL := Color(0.99, 0.97, 0.9)

# Dokunuş: basınca yüzü aşağı iner, parmak düğmenin üstünde kalkarsa on_tap çalışır.
class Btn extends Control:
	var text := ""
	var font_size := 34
	var color := GREEN
	var text_color := Color.WHITE
	var icon := Callable()        # func(ci: CanvasItem, center: Vector2, size: float)
	var icon_size := 0.0          # 0 = font_size * 1.1
	var circle := false           # yuvarlak düğme; text dairenin altına yazılır
	var badge := false            # sağ üstte kırmızı nokta
	var enabled := true
	var on_tap := Callable()
	var _down := -2               # -2 yok, -1 fare, >=0 dokunuş parmağı

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func refresh() -> void:
		queue_redraw()

	func _hit(pos: Vector2) -> bool:
		var local: Vector2 = get_global_transform_with_canvas().affine_inverse() * pos
		return Rect2(Vector2.ZERO, size).grow(10.0).has_point(local)

	func _input(event: InputEvent) -> void:
		if not is_visible_in_tree():
			_down = -2
			return
		var idx := 0
		if event is InputEventScreenTouch:
			idx = event.index
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			idx = -1
		else:
			return
		if event.pressed:
			if _down == -2 and _hit(event.position):
				_down = idx
				queue_redraw()
				get_viewport().set_input_as_handled()
		elif _down == idx:
			_down = -2
			queue_redraw()
			get_viewport().set_input_as_handled()
			if _hit(event.position):
				if enabled and on_tap.is_valid():
					on_tap.call()
				elif not enabled:
					_shake()

	func _shake() -> void:
		var x := position.x
		var t := create_tween()
		for d in [8.0, -8.0, 5.0, 0.0]:
			t.tween_property(self, "position:x", x + d, 0.05)

	func _draw() -> void:
		var base: Color = color if enabled else GREY
		var press := 4.0 if _down != -2 else 0.0
		if circle:
			var r := size.x / 2.0
			var c := Vector2(r, r - 3.0)
			draw_circle(c + Vector2(0, 6), r - 3.0, INK)
			draw_circle(c + Vector2(0, 6), r - 6.0, base.darkened(0.3))
			draw_circle(c + Vector2(0, press), r - 3.0, INK)
			draw_circle(c + Vector2(0, press), r - 6.0, base)
			draw_arc(c + Vector2(0, press), r - 13.0, PI * 1.1, PI * 1.6, 12, Color(1, 1, 1, 0.35), 5.0, true)
			if icon.is_valid():
				icon.call(self, c + Vector2(0, press), icon_size if icon_size > 0.0 else r)
			if text != "":
				var y := size.x + font_size * 0.9
				draw_string_outline(BOLD, Vector2(-40, y), text, HORIZONTAL_ALIGNMENT_CENTER, size.x + 80, font_size,
					maxi(6, font_size / 4), OUTLINE)
				draw_string(BOLD, Vector2(-40, y), text, HORIZONTAL_ALIGNMENT_CENTER, size.x + 80, font_size, text_color)
			if badge:
				UiKit.badge(self, Vector2(size.x - 12, 12))
			return
		var h := size.y - 6.0
		var rad := int(minf(h / 2.0, 34.0))
		var shadow := StyleBoxFlat.new()
		shadow.bg_color = base.darkened(0.32)
		shadow.set_corner_radius_all(rad)
		shadow.border_color = INK
		shadow.set_border_width_all(3)
		draw_style_box(shadow, Rect2(0, 6, size.x, h))
		var face := StyleBoxFlat.new()
		face.bg_color = base
		face.set_corner_radius_all(rad)
		face.border_color = INK
		face.set_border_width_all(3)
		draw_style_box(face, Rect2(0, press, size.x, h))
		var hi := StyleBoxFlat.new()
		hi.bg_color = Color(1, 1, 1, 0.22)
		hi.set_corner_radius_all(rad - 4)
		draw_style_box(hi, Rect2(8, press + 6, size.x - 16, h * 0.36))
		# yazı (+ solda simge) ortada
		var tw := BOLD.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x if text != "" else 0.0
		var isz := icon_size if icon_size > 0.0 else font_size * 1.1
		var gap := 12.0 if text != "" else 0.0
		var total := tw + ((isz + gap) if icon.is_valid() else 0.0)
		var x := (size.x - total) / 2.0
		var mid := press + h / 2.0
		if icon.is_valid():
			icon.call(self, Vector2(x + isz / 2.0, mid), isz)
			x += isz + gap
		if text != "":
			var base_y := mid + font_size * 0.36
			draw_string_outline(BOLD, Vector2(x, base_y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
				maxi(6, font_size / 4), base.darkened(0.45))
			draw_string(BOLD, Vector2(x, base_y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)
		if badge:
			UiKit.badge(self, Vector2(size.x - 8, 8))

# Arkasındaki her şeye giden dokunuşları yutan yarı saydam perde (açılır paneller,
# kazan/kaybet kartı). on_tap verilirse boşluğa dokunmak onu çağırır (ör. paneli kapat).
class Blocker extends ColorRect:
	var on_tap := Callable()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		color = Color(0, 0, 0, 0.45)
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _input(event: InputEvent) -> void:
		if not is_visible_in_tree():
			return
		var ok: bool = event is InputEventScreenTouch or event is InputEventScreenDrag \
			or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT)
		if not ok:
			return
		get_viewport().set_input_as_handled()
		if on_tap.is_valid() and event is InputEventScreenTouch and not event.pressed:
			on_tap.call()
		elif on_tap.is_valid() and event is InputEventMouseButton and not event.pressed:
			on_tap.call()

static func btn(text: String, col: Color, w: float, h: float, font_size: int, on_tap: Callable, icon: Callable = Callable()) -> Btn:
	var b := Btn.new()
	b.text = text
	b.color = col
	b.custom_minimum_size = Vector2(w, h)
	b.size = Vector2(w, h)
	b.font_size = font_size
	b.on_tap = on_tap
	b.icon = icon
	return b

static func label(text: String, font: Font, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", maxi(6, size / 5))
	l.add_theme_color_override("font_outline_color", OUTLINE)
	return l

# Koyu yazılı düz etiket (açık renkli panel üstünde).
static func ink_label(text: String, font: Font, size: int, color: Color = INK) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

static func panel_style(col: Color = PANEL, radius: int = 36) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = col
	s.set_corner_radius_all(radius)
	s.border_color = INK
	s.set_border_width_all(4)
	s.shadow_color = Color(0, 0, 0, 0.25)
	s.shadow_size = 12
	s.shadow_offset = Vector2(0, 6)
	return s

static func badge(ci: CanvasItem, c: Vector2) -> void:
	ci.draw_circle(c, 14.0, Color.WHITE)
	ci.draw_circle(c, 11.0, RED)

# --- simgeler: hepsi (ci, merkez, boyut) ---

# Çapraz duran bambu parçası: iki boğum, yaprak, sticker konturu.
static func bamboo(ci: CanvasItem, c: Vector2, s: float) -> void:
	var k := s / 44.0
	var xf := Transform2D(0.6, Vector2(k, k), 0.0, c)
	var body := PackedVector2Array()
	for p in [Vector2(-8, -21), Vector2(8, -21), Vector2(8, 21), Vector2(-8, 21)]:
		body.append(xf * p)
	var outline := PackedVector2Array()
	for p in [Vector2(-10.5, -23.5), Vector2(10.5, -23.5), Vector2(10.5, 23.5), Vector2(-10.5, 23.5)]:
		outline.append(xf * p)
	ci.draw_colored_polygon(outline, INK)
	ci.draw_colored_polygon(body, Color(0.5, 0.78, 0.32))
	var hi := PackedVector2Array()
	for p in [Vector2(-5, -21), Vector2(-1.5, -21), Vector2(-1.5, 21), Vector2(-5, 21)]:
		hi.append(xf * p)
	ci.draw_colored_polygon(hi, Color(0.72, 0.92, 0.5))
	for y in [-7.0, 9.0]:
		var ring := PackedVector2Array()
		for p in [Vector2(-10, y - 2.2), Vector2(10, y - 2.2), Vector2(10, y + 2.2), Vector2(-10, y + 2.2)]:
			ring.append(xf * p)
		ci.draw_colored_polygon(ring, Color(0.3, 0.55, 0.2))
	var lb := xf * Vector2(8, -7)
	var dir := xf.basis_xform(Vector2(1, -0.6)).normalized()
	ArtUtil.leaf(ci, lb - dir * 2.0 * k, dir, 22.0 * k, 8.0 * k, INK)
	ArtUtil.leaf(ci, lb, dir, 18.0 * k, 6.0 * k, Color(0.42, 0.76, 0.3))

static func play(ci: CanvasItem, c: Vector2, s: float) -> void:
	var r := s * 0.42
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.7, -r), c + Vector2(r, 0), c + Vector2(-r * 0.7, r)]), Color.WHITE)

# Reklam: beyaz yuvarlak içinde oynat üçgeni.
static func ad(ci: CanvasItem, c: Vector2, s: float) -> void:
	ci.draw_circle(c, s * 0.46, Color.WHITE)
	var r := s * 0.22
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.6, -r), c + Vector2(r, 0), c + Vector2(-r * 0.6, r)]), ORANGE.darkened(0.1))

static func pause(ci: CanvasItem, c: Vector2, s: float) -> void:
	var w := s * 0.14
	var h := s * 0.46
	for x in [-s * 0.13, s * 0.13]:
		ci.draw_rect(Rect2(c + Vector2(x - w / 2.0, -h / 2.0), Vector2(w, h)), Color.WHITE)

static func home(ci: CanvasItem, c: Vector2, s: float) -> void:
	var k := s / 40.0
	var roof := PackedVector2Array([c + Vector2(-17, -2) * k, c + Vector2(0, -17) * k, c + Vector2(17, -2) * k])
	ci.draw_polyline(roof, Color.WHITE, 5.0 * k, true)
	ci.draw_rect(Rect2(c + Vector2(-11, -4) * k, Vector2(22, 17) * k), Color.WHITE)

static func retry(ci: CanvasItem, c: Vector2, s: float) -> void:
	var r := s * 0.3
	ci.draw_arc(c, r, -PI * 0.35, PI * 1.35, 20, Color.WHITE, s * 0.11, true)
	var p := c + Vector2.from_angle(-PI * 0.35) * r
	ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-s * 0.16, -s * 0.06), p + Vector2(s * 0.1, -s * 0.14),
		p + Vector2(s * 0.08, s * 0.12)]), Color.WHITE)

# Kırmızı hediye kutusu, sarı kurdele.
static func gift(ci: CanvasItem, c: Vector2, s: float) -> void:
	var k := s / 60.0
	var box := Rect2(c + Vector2(-16, -6) * k, Vector2(32, 24) * k)
	var lid := Rect2(c + Vector2(-19, -14) * k, Vector2(38, 10) * k)
	for r in [box, lid]:
		ci.draw_rect(r.grow(2.5 * k), INK)
	ci.draw_rect(box, Color(0.95, 0.35, 0.4))
	ci.draw_rect(lid, Color(1.0, 0.45, 0.5))
	ci.draw_rect(Rect2(c + Vector2(-4, -14) * k, Vector2(8, 32) * k), GOLD)
	for sx in [-1.0, 1.0]:
		ArtUtil.ellipse(ci, c + Vector2(sx * 7, -19) * k, 8.0 * k, 5.0 * k, sx * 0.5, INK)
		ArtUtil.ellipse(ci, c + Vector2(sx * 7, -19) * k, 6.0 * k, 3.4 * k, sx * 0.5, GOLD)

# Tema: güneşli tepe + bambu.
static func landscape(ci: CanvasItem, c: Vector2, s: float) -> void:
	var k := s / 60.0
	ci.draw_circle(c + Vector2(8, -8) * k, 9.0 * k, GOLD)
	ArtUtil.ellipse(ci, c + Vector2(-6, 14) * k, 24.0 * k, 12.0 * k, 0.0, Color(0.46, 0.78, 0.36))
	ci.draw_rect(Rect2(c + Vector2(-15, -18) * k, Vector2(6, 30) * k), Color(0.36, 0.62, 0.3))
	ci.draw_rect(Rect2(c + Vector2(-16, -6) * k, Vector2(8, 2.5) * k), Color(0.26, 0.48, 0.22))

# Gardırop: kırmızı fiyonk.
static func wardrobe(ci: CanvasItem, c: Vector2, s: float) -> void:
	var k := s / 34.0
	var xf := Transform2D(0.3, Vector2(k, k), 0.0, Vector2.ZERO)
	xf.origin = c - xf.basis_xform(Vector2(-14, -99))
	ci.draw_set_transform_matrix(xf)
	Accessories.draw(ci, "bow")
	ci.draw_set_transform(Vector2.ZERO)

static func close(ci: CanvasItem, c: Vector2, s: float) -> void:
	for d in [Vector2(1, 1), Vector2(1, -1)]:
		ci.draw_line(c - d * s * 0.2, c + d * s * 0.2, Color.WHITE, s * 0.12, true)

static func lock(ci: CanvasItem, c: Vector2, s: float) -> void:
	var k := s / 40.0
	ci.draw_arc(c + Vector2(0, -6) * k, 9.0 * k, PI, TAU, 12, INK, 5.0 * k, true)
	ci.draw_rect(Rect2(c + Vector2(-13, -6) * k, Vector2(26, 20) * k), INK)
	ci.draw_rect(Rect2(c + Vector2(-10.5, -3.5) * k, Vector2(21, 15) * k), Color(0.95, 0.75, 0.3))
	ci.draw_circle(c + Vector2(0, 3) * k, 2.6 * k, INK)
