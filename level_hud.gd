class_name LevelHud
extends Control

# Oyun arayüzü (UI CanvasLayer'ın altında, tam ekran, dokunuşu yutmaz):
#   üstte büyük seviye başlığı + yiyecek simgelerinden ilerleme şeridi
#   (sayı yerine simge — "3 / 6" seviye numarasıyla karışıyordu), ipucu,
#   ortada büyük "Dengede tut" geri sayımı, seviye bitince kutlama (konfeti,
#   büyük yazı), kaybedince kart, yeni seviyede giriş kartı (yeni yiyecek simgesiyle).
# Oyun mantığı main.gd'de; bu sadece gösterir.

const GOLD := Color(1.0, 0.84, 0.35)
const OUTLINE := Color(0.16, 0.24, 0.16, 0.8)
const CONFETTI_COLORS := [Color(0.98, 0.36, 0.36), Color(1.0, 0.8, 0.25), Color(0.35, 0.8, 0.45),
	Color(0.35, 0.6, 0.98), Color(0.9, 0.45, 0.9)]

var _bold: Font = preload("res://fonts/Fredoka-Bold.ttf")
var _med: Font = preload("res://fonts/Fredoka-Medium.ttf")

var _title: Label
var _progress: HBoxContainer
var _hint: Label
var _hold_box: VBoxContainer
var _hold_num: Label
var _banner: Control
var _banner_title: Label
var _banner_sub: Label
var _intro: Control
var _intro_title: Label
var _intro_hint: Label
var _intro_icon: FoodIcon
var _confetti: CPUParticles2D
var _placed := -1
var _hold_shown := -1
var _intro_tween: Tween
var _swap: SwapButton
var _swap_pulse: Tween
var _lives: LivesView
var _fly_heart: FlyingHeart
var _fly_tween: Tween
var _card_box: VBoxContainer
var _perfect: Label
var _rewards: VBoxContainer
var _total: HBoxContainer
var _total_label: Label
var _goal: GoalBar
var _new_theme: Label
var _btn_ad: UiKit.Btn
var _btn_main: UiKit.Btn
var _btn_home: UiKit.Btn
var _pause_btn: UiKit.Btn
var _pause: Control
var _won := false
var top_inset := 0.0   # çentik payı (main.gd oyun kamerasını buna göre yerleştirir)

signal next_pressed
signal retry_pressed
signal home_pressed
signal double_pressed
signal swap_ad_pressed
signal pause_pressed
signal resume_pressed

# Küçük yiyecek simgesi: yiyeceğin kendi çizimi (Food.paint) kutuya sığdırılır.
class FoodIcon extends Control:
	var kind := 0
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var k := minf(size.x / 84.0, size.y / 66.0)
		draw_set_transform(size / 2.0 + Vector2(0, 3.0 * k), 0.0, Vector2(k, k))
		Food.paint(self, kind)

# Pandanın canları (sol alt, Swap'ın simetriği): mini panda yüzü + kalpler.
# Çarpınca pandanın başından kırık kalp buraya uçar, kalp çatlayıp sönük griye
# döner; son kalp kırmızı nabız gibi atar ("dikkat, son hakkın").
class LivesView extends Control:
	var max_lives := 2
	var lives := 2
	var _t := 0.0
	var _shake := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func heart_center(i: int) -> Vector2:
		return Vector2(84.0 + i * 50.0, size.y / 2.0)

	func _process(delta: float) -> void:
		_t += delta
		_shake = maxf(0.0, _shake - delta * 30.0)
		if lives == 1 or _shake > 0.0:
			queue_redraw()

	func shake() -> void:
		_shake = 7.0

	func _draw() -> void:
		var off := Vector2(randf_range(-_shake, _shake), 0.0)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.1, 0.2, 0.1, 0.28)
		sb.set_corner_radius_all(int(size.y / 2.0))
		draw_style_box(sb, Rect2(off, size))
		_face(Vector2(36, size.y / 2.0) + off)
		for i in max_lives:
			var alive := i < lives
			var s := 1.0
			if alive and lives == 1:
				s += 0.16 * (0.5 + 0.5 * sin(_t * 7.0))
			LivesView.heart(self, heart_center(i) + off, 17.0 * s, alive)

	func _face(c: Vector2) -> void:
		var ink := Color(0.17, 0.14, 0.16)
		for x in [-14.0, 14.0]:
			draw_circle(c + Vector2(x, -15), 8.5, ink)
		draw_circle(c, 21.0, ink)
		draw_circle(c, 18.5, Color(0.99, 0.98, 0.96))
		ArtUtil.ellipse(self, c + Vector2(-7.5, 0), 5.0, 7.0, 0.55, Color(0.19, 0.17, 0.2))
		ArtUtil.ellipse(self, c + Vector2(7.5, 0), 5.0, 7.0, -0.55, Color(0.19, 0.17, 0.2))
		for x in [-7.0, 7.0]:
			draw_circle(c + Vector2(x, -1), 2.6, Color.WHITE)
			draw_circle(c + Vector2(x, -0.5), 1.4, ink)
		ArtUtil.ellipse(self, c + Vector2(0, 7), 2.6, 1.9, 0.0, ink)
		if lives < max_lives:   # yara bandı
			var bc := c + Vector2(6, -14)
			ArtUtil.ellipse(self, bc, 7.5, 3.0, -0.5, Color(0.98, 0.82, 0.62))

	# Kalp: iki daire + üçgen, koyu kontur; sönmüşse gri ve ortasından çatlak.
	static func heart(ci: CanvasItem, c: Vector2, r: float, alive: bool) -> void:
		var ink := Color(0.25, 0.12, 0.14, 0.9)
		var col := Color(0.96, 0.28, 0.34) if alive else Color(0.62, 0.62, 0.64, 0.75)
		for layer in 2:
			var k := r + (3.0 if layer == 0 else 0.0)
			var cc: Color = ink if layer == 0 else col
			ci.draw_circle(c + Vector2(-r * 0.5, -r * 0.25), k * 0.56, cc)
			ci.draw_circle(c + Vector2(r * 0.5, -r * 0.25), k * 0.56, cc)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-k * 1.02, -r * 0.08),
				c + Vector2(k * 1.02, -r * 0.08), c + Vector2(0, r * 0.95 + (k - r) * 1.3)]), cc)
		if alive:
			ci.draw_circle(c + Vector2(-r * 0.55, -r * 0.45), r * 0.18, Color(1, 1, 1, 0.65))
		else:
			ci.draw_polyline(PackedVector2Array([c + Vector2(0, -r * 0.55), c + Vector2(-r * 0.2, -r * 0.1),
				c + Vector2(r * 0.18, r * 0.2), c + Vector2(0, r * 0.7)]), ink, 2.2, true)

# Pandanın başından göstergeye uçan kalp.
class FlyingHeart extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		LivesView.heart(self, Vector2.ZERO, 17.0, true)

# Kazanma kartında sıradaki aksesuar hedefi: "Next: Chef Hat" + dolum çubuğu.
class GoalBar extends Control:
	var item_name := ""
	var have := 0
	var need := 1
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var ready := have >= need
		var head := ("Ready to buy: %s!" if ready else "Next: %s") % item_name
		draw_string_outline(UiKit.BOLD, Vector2(0, 30), head, HORIZONTAL_ALIGNMENT_CENTER, size.x, 30, 7, OUTLINE)
		draw_string(UiKit.BOLD, Vector2(0, 30), head, HORIZONTAL_ALIGNMENT_CENTER, size.x, 30, GOLD if ready else Color.WHITE)
		var r := Rect2(30, 46, size.x - 40, 38)
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.1, 0.15, 0.1, 0.6)
		bg.set_corner_radius_all(19)
		bg.border_color = Color(1, 1, 1, 0.8)
		bg.set_border_width_all(3)
		draw_style_box(bg, r)
		var k := clampf(float(have) / float(need), 0.0, 1.0)
		if k > 0.0:
			var fill := StyleBoxFlat.new()
			fill.bg_color = UiKit.GREEN if ready else GOLD
			fill.set_corner_radius_all(15)
			draw_style_box(fill, Rect2(r.position + Vector2(4, 4), Vector2(maxf(30.0, (r.size.x - 8) * k), r.size.y - 8)))
		UiKit.bamboo(self, Vector2(30, r.get_center().y), 50.0)
		var t := "%d / %d" % [mini(have, need), need]
		draw_string_outline(UiKit.BOLD, Vector2(r.position.x, r.position.y + 29), t, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 26, 6, OUTLINE)
		draw_string(UiKit.BOLD, Vector2(r.position.x, r.position.y + 29), t, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 26, Color.WHITE)

# Kartta bambu simgesi (toplam ödülün yanında).
class BambooIcon extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		UiKit.bamboo(self, size / 2.0, size.y)

# Swap yardımcısı: daire içinde sandviç + dönen oklar, sağ üstte kalan hak rozeti,
# altında "Swap" yazısı. Dokunuşu main.gd konumdan yakalar (burası sadece çizer) —
# böylece düğmeye dokunmak yiyeceği de bırakmaz.
class SwapButton extends Control:
	var count := 0
	var active := false
	var font: Font
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var r := size.x / 2.0
		var c := Vector2(r, r)
		draw_circle(c, r, Color(1.0, 0.84, 0.35, 0.95) if active else Color(0.1, 0.2, 0.1, 0.28))
		var ink := Color(0.35, 0.22, 0.1) if active else Color(1, 1, 1, 0.45)
		for a0 in [PI * 1.1, PI * 0.1]:
			var a1: float = a0 + PI * 0.7
			draw_arc(c, r * 0.8, a0, a1, 16, ink, 5.0, true)
			var p := c + Vector2.from_angle(a1) * r * 0.8
			var t := Vector2.from_angle(a1 + PI / 2.0)
			var n := Vector2.from_angle(a1)
			draw_colored_polygon(PackedVector2Array([p + t * 11.0, p - n * 8.0, p + n * 8.0]), ink)
		draw_set_transform(c + Vector2(0, 2), 0.0, Vector2(0.68, 0.68))
		Food.paint(self, Food.Kind.SANDWICH)
		draw_set_transform(Vector2.ZERO)
		var b := c + Vector2(r * 0.78, -r * 0.78)
		draw_circle(b, 19.0, Color(0.9, 0.3, 0.28) if count > 0 else Color(0.45, 0.45, 0.45))
		draw_string(font, b + Vector2(-19, 9), str(count), HORIZONTAL_ALIGNMENT_CENTER, 38, 26, Color.WHITE)
		draw_string_outline(font, Vector2(0, size.y - 4), "Swap", HORIZONTAL_ALIGNMENT_CENTER, size.x, 26, 6, OUTLINE)
		draw_string(font, Vector2(0, size.y - 4), "Swap", HORIZONTAL_ALIGNMENT_CENTER, size.x, 26,
			Color.WHITE if active else Color(1, 1, 1, 0.7))

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_title = _label("", _bold, 46, Color.WHITE)
	_title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_title.offset_top = 34.0
	_title.offset_bottom = 94.0
	_shadow(_title)
	add_child(_title)

	_progress = HBoxContainer.new()
	_progress.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_progress.offset_top = 100.0
	_progress.offset_bottom = 152.0
	_progress.alignment = BoxContainer.ALIGNMENT_CENTER
	_progress.add_theme_constant_override("separation", 6)
	_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_progress)

	_hint = _label("", _med, 26, Color(1, 1, 1, 0.8))
	_hint.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_hint.offset_top = 162.0
	_hint.offset_bottom = 200.0
	add_child(_hint)

	_hold_box = VBoxContainer.new()
	_hold_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_hold_box.offset_top = 300.0
	_hold_box.offset_bottom = 520.0
	_hold_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_hold_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hold_box.visible = false
	_hold_box.add_child(_label("Keep it balanced!", _bold, 40, GOLD))
	_hold_num = _label("3", _bold, 140, Color.WHITE)
	_shadow(_hold_num)
	_hold_box.add_child(_hold_num)
	add_child(_hold_box)

	# kazanma / kaybetme kartı: başlık, ödül satırları, toplam bambu, sıradaki hedef,
	# düğmeler. Perde arkadaki oyuna giden dokunuşları yutar.
	_banner = Control.new()
	_banner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.visible = false
	_banner.add_child(UiKit.Blocker.new())
	_card_box = VBoxContainer.new()
	_card_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_card_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_card_box.grow_vertical = Control.GROW_DIRECTION_BOTH
	_card_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_card_box.add_theme_constant_override("separation", 14)
	_card_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_title = _label("", _bold, 72, GOLD)
	_shadow(_banner_title)
	_card_box.add_child(_banner_title)
	_perfect = _label("PERFECT!", _bold, 52, Color(0.55, 0.95, 0.5))
	_card_box.add_child(_perfect)
	_rewards = VBoxContainer.new()
	_rewards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rewards.add_theme_constant_override("separation", 0)
	_card_box.add_child(_rewards)
	_total = HBoxContainer.new()
	_total.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_total.alignment = BoxContainer.ALIGNMENT_CENTER
	_total.add_theme_constant_override("separation", 10)
	var bi := BambooIcon.new()
	bi.custom_minimum_size = Vector2(76, 76)
	_total.add_child(bi)
	_total_label = _label("", _bold, 72, GOLD)
	_total.add_child(_total_label)
	_card_box.add_child(_total)
	_new_theme = _label("New theme: Sunset!", _bold, 34, Color(1.0, 0.7, 0.45))
	_card_box.add_child(_new_theme)
	_goal = GoalBar.new()
	_goal.custom_minimum_size = Vector2(500, 90)
	_goal.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_card_box.add_child(_goal)
	_banner_sub = _label("", _med, 32, Color.WHITE)
	_card_box.add_child(_banner_sub)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_box.add_child(gap)
	# reklam teklifi (kazanınca x2 bambu, kaybedince +1 Swap)
	_btn_ad = UiKit.btn("", UiKit.ORANGE, 430, 100, 38, _on_ad_btn, UiKit.ad)
	_btn_ad.icon_size = 54.0
	_btn_ad.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_card_box.add_child(_btn_ad)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)
	_btn_home = UiKit.btn("", UiKit.BLUE, 108, 104, 30, func(): home_pressed.emit(), UiKit.home)
	_btn_home.icon_size = 56.0
	row.add_child(_btn_home)
	_btn_main = UiKit.btn("", UiKit.GREEN, 300, 104, 42, _on_main_btn)
	row.add_child(_btn_main)
	_card_box.add_child(row)
	_banner.add_child(_card_box)
	add_child(_banner)

	# oyun sırasında sol üstte duraklat
	_pause_btn = UiKit.btn("", Color(0.36, 0.6, 0.34), 88, 88, 30, func(): pause_pressed.emit(), UiKit.pause)
	_pause_btn.icon_size = 72.0
	_pause_btn.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_pause_btn.offset_left = 22.0
	_pause_btn.offset_right = 110.0
	_pause_btn.offset_top = 30.0
	_pause_btn.offset_bottom = 118.0
	add_child(_pause_btn)
	move_child(_pause_btn, _banner.get_index())   # kazan/kaybet kartının altında

	# duraklatma kartı (ağaç duraklatılmışken de dokunuş alsın)
	_pause = Control.new()
	_pause.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause.process_mode = Node.PROCESS_MODE_ALWAYS
	_pause.visible = false
	var pb := UiKit.Blocker.new()
	pb.color = Color(0, 0, 0, 0.55)
	_pause.add_child(pb)
	var pbox := VBoxContainer.new()
	pbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	pbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	pbox.grow_vertical = Control.GROW_DIRECTION_BOTH
	pbox.alignment = BoxContainer.ALIGNMENT_CENTER
	pbox.add_theme_constant_override("separation", 26)
	pbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pt := _label("PAUSED", _bold, 80, Color.WHITE)
	_shadow(pt)
	pbox.add_child(pt)
	var resume := UiKit.btn("Resume", UiKit.GREEN, 380, 108, 44, func(): resume_pressed.emit(), UiKit.play)
	resume.icon_size = 56.0
	resume.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pbox.add_child(resume)
	var ph := UiKit.btn("Home", UiKit.BLUE, 380, 108, 44, func(): home_pressed.emit(), UiKit.home)
	ph.icon_size = 50.0
	ph.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pbox.add_child(ph)
	_pause.add_child(pbox)
	add_child(_pause)

	# yeni seviye giriş kartı
	_intro = VBoxContainer.new()
	_intro.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_intro.offset_top = 330.0
	_intro.offset_bottom = 640.0
	(_intro as VBoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER
	(_intro as VBoxContainer).add_theme_constant_override("separation", 10)
	_intro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intro.visible = false
	_intro_title = _label("", _bold, 84, Color.WHITE)
	_shadow(_intro_title)
	_intro.add_child(_intro_title)
	_intro_icon = FoodIcon.new()
	_intro_icon.custom_minimum_size = Vector2(150, 110)
	_intro_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_intro.add_child(_intro_icon)
	_intro_hint = _label("", _bold, 34, GOLD)
	_shadow(_intro_hint)
	_intro.add_child(_intro_hint)
	add_child(_intro)

	_confetti = CPUParticles2D.new()
	_confetti.emitting = false
	_confetti.one_shot = true
	_confetti.amount = 90
	_confetti.lifetime = 2.4
	_confetti.explosiveness = 0.85
	_confetti.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_confetti.emission_rect_extents = Vector2(360, 10)
	_confetti.direction = Vector2(0, 1)
	_confetti.spread = 35.0
	_confetti.initial_velocity_min = 120.0
	_confetti.initial_velocity_max = 420.0
	_confetti.gravity = Vector2(0, 520)
	_confetti.angular_velocity_min = -360.0
	_confetti.angular_velocity_max = 360.0
	_confetti.scale_amount_min = 7.0
	_confetti.scale_amount_max = 12.0
	var g := Gradient.new()
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	g.offsets = PackedFloat32Array([0.0, 0.2, 0.4, 0.6, 0.8])
	g.colors = PackedColorArray(CONFETTI_COLORS)
	_confetti.color_initial_ramp = g
	add_child(_confetti)

	_swap = SwapButton.new()
	_swap.font = _bold
	_swap.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_swap.offset_left = -150.0
	_swap.offset_right = -30.0
	_swap.offset_top = -200.0
	_swap.offset_bottom = -50.0
	_swap.visible = false
	add_child(_swap)
	move_child(_swap, _banner.get_index())   # kazan/kaybet kartının altında

	# canlar: Swap düğmesinin simetriği, dairesinin ortasıyla aynı hizada
	_lives = LivesView.new()
	_lives.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_lives.offset_left = 24.0
	_lives.offset_right = 24.0 + 142.0
	_lives.offset_top = -172.0
	_lives.offset_bottom = -108.0
	add_child(_lives)
	move_child(_lives, _banner.get_index())
	_fly_heart = FlyingHeart.new()
	_fly_heart.visible = false
	add_child(_fly_heart)

	_apply_top_inset()

func _label(text: String, font: Font, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	# açık (gündüz) zeminde okunsun: koyu kontur
	l.add_theme_constant_override("outline_size", maxi(6, size / 5))
	l.add_theme_color_override("font_outline_color", OUTLINE)
	return l

func _shadow(l: Label) -> void:
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.4))
	l.add_theme_constant_override("shadow_offset_y", 4)

func _pulse(l: Label) -> void:
	var t := create_tween().set_loops()
	t.tween_property(l, "modulate:a", 0.45, 0.7).set_trans(Tween.TRANS_SINE)
	t.tween_property(l, "modulate:a", 1.0, 0.7).set_trans(Tween.TRANS_SINE)

# Çentikli telefonlarda üst öğeleri durum çubuğunun altına it.
func _apply_top_inset() -> void:
	var safe := DisplayServer.get_display_safe_area()
	var win := DisplayServer.window_get_size()
	if win.y <= 0:
		return
	var inset: float = float(safe.position.y) * get_viewport_rect().size.y / float(win.y)
	if inset <= 0.0:
		return
	top_inset = inset
	for c: Control in [_title, _progress, _hint, _pause_btn]:
		c.offset_top += inset
		c.offset_bottom += inset

# --- main.gd'nin çağırdıkları ---

func setup_level(level: int, foods: Array, hint: String) -> void:
	_title.text = "LEVEL %d" % level
	_hint.text = hint
	for c in _progress.get_children():
		c.queue_free()
	var icon_w := clampf(640.0 / foods.size() - 6.0, 30.0, 52.0)
	for k in foods:
		var ic := FoodIcon.new()
		ic.kind = k
		ic.custom_minimum_size = Vector2(icon_w, 50)
		_progress.add_child(ic)
	_placed = -1
	set_progress(0)
	hide_hold()
	hide_banner()

# Yerleşen kadar simge dolu, kalanlar soluk; yeni dolan simge zıplar.
func set_progress(placed: int) -> void:
	if placed == _placed:
		return
	var icons := _progress.get_children().filter(func(c): return not c.is_queued_for_deletion())
	for i in icons.size():
		var ic: Control = icons[i]
		var full := i < placed
		ic.modulate = Color(1, 1, 1, 1) if full else Color(1, 1, 1, 0.3)
		if full and i >= _placed and _placed >= 0:
			ic.pivot_offset = ic.size / 2.0
			ic.scale = Vector2(1.5, 1.5)
			create_tween().tween_property(ic, "scale", Vector2.ONE, 0.3) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_placed = placed

func set_hint(text: String) -> void:
	_hint.text = text

func show_hold(seconds_left: int) -> void:
	_hold_box.visible = true
	if seconds_left != _hold_shown:
		_hold_shown = seconds_left
		_hold_num.text = str(seconds_left)
		_hold_num.pivot_offset = _hold_num.size / 2.0
		_hold_num.scale = Vector2(1.6, 1.6)
		create_tween().tween_property(_hold_num, "scale", Vector2.ONE, 0.35) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func hide_hold() -> void:
	_hold_box.visible = false
	_hold_shown = -1

# rewards: [[yazı, miktar], ...]; goal: Accessories.next_goal sonucu ({} = hepsi alındı).
func show_win(level: int, rewards: Array, total: int, perfect: bool, goal: Dictionary, bamboo: int,
		new_theme: bool, offer_double: bool) -> void:
	hide_hold()
	_won = true
	_clear_rewards()
	for r in rewards:
		_rewards.add_child(_label("%s  +%d" % [r[0], r[1]], _med, 32, Color.WHITE))
	_rewards.visible = true
	_perfect.visible = perfect
	_total.visible = true
	set_win_total(total, false)
	_new_theme.visible = new_theme
	_goal.visible = not goal.is_empty()
	if not goal.is_empty():
		_goal.item_name = goal["name"]
		_goal.have = bamboo
		_goal.need = goal["price"]
		_goal.queue_redraw()
	_banner_sub.visible = false
	_btn_ad.visible = offer_double
	_btn_ad.text = "x2 Bamboo"
	_btn_main.text = "Next"
	_btn_main.icon = UiKit.play
	_btn_main.icon_size = 50.0
	_show_banner("LEVEL %d\nCOMPLETE!" % level, GOLD)
	if perfect:
		_perfect.pivot_offset = Vector2(_perfect.size.x / 2.0, _perfect.size.y / 2.0)
		_perfect.scale = Vector2(0.3, 0.3)
		var t := create_tween()
		t.tween_interval(0.35)
		t.tween_property(_perfect, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_confetti.position = Vector2(get_viewport_rect().size.x / 2.0, -20.0)
	_confetti.restart()

# x2 alınınca toplam büyüyerek güncellenir, sıradaki hedef çubuğu da.
func set_win_total(total: int, animate: bool, bamboo: int = -1) -> void:
	_total_label.text = "+%d" % total
	if bamboo >= 0:
		_goal.have = bamboo
		_goal.queue_redraw()
	if animate:
		_total.pivot_offset = _total.size / 2.0
		_total.scale = Vector2(1.5, 1.5)
		create_tween().tween_property(_total, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func set_ad_visible(on: bool) -> void:
	_btn_ad.visible = on

func show_lose(reason: String, offer_swap_ad: bool = false, tip: String = "") -> void:
	hide_hold()
	_won = false
	_clear_rewards()
	_rewards.visible = false
	_perfect.visible = false
	_total.visible = false
	_new_theme.visible = false
	_goal.visible = false
	_banner_sub.text = tip
	_banner_sub.add_theme_color_override("font_color", GOLD)
	_banner_sub.visible = tip != ""
	_btn_ad.visible = offer_swap_ad
	_btn_ad.text = "+1 Swap"
	_btn_main.text = "Try again"
	_btn_main.icon = UiKit.retry
	_btn_main.icon_size = 56.0
	_show_banner(reason, Color(1.0, 0.5, 0.45))

func _clear_rewards() -> void:
	for c in _rewards.get_children():
		_rewards.remove_child(c)
		c.queue_free()

func _on_ad_btn() -> void:
	if _won:
		double_pressed.emit()
	else:
		swap_ad_pressed.emit()

func _on_main_btn() -> void:
	if _won:
		next_pressed.emit()
	else:
		retry_pressed.emit()

func show_pause(on: bool) -> void:
	_pause.visible = on

# Menüdeyken oyun göstergeleri gizli.
func set_play_visible(on: bool) -> void:
	for c: Control in [_title, _progress, _hint, _lives, _pause_btn]:
		c.visible = on
	if not on:
		hide_hold()
		hide_banner()
		_intro.visible = false
		_pause.visible = false
		_swap.visible = false

# Swap düğmesi: görünür mü, kalan hak, şu an kullanılabilir mi, ilk tanıtımda zıplasın mı.
func set_swap(shown: bool, count: int, can_use: bool, highlight: bool) -> void:
	_swap.visible = shown
	if _swap.count != count or _swap.active != can_use:
		_swap.count = count
		_swap.active = can_use
		_swap.queue_redraw()
	var want_pulse := shown and can_use and highlight
	if want_pulse and _swap_pulse == null:
		_swap.pivot_offset = Vector2(_swap.size.x / 2.0, _swap.size.x / 2.0)
		_swap_pulse = create_tween().set_loops()
		_swap_pulse.tween_property(_swap, "scale", Vector2(1.12, 1.12), 0.4).set_trans(Tween.TRANS_SINE)
		_swap_pulse.tween_property(_swap, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_SINE)
	elif not want_pulse and _swap_pulse != null:
		_swap_pulse.kill()
		_swap_pulse = null
		_swap.scale = Vector2.ONE

# Seviye başında canlar dolu.
func reset_lives(max_lives: int) -> void:
	if _fly_tween:
		_fly_tween.kill()
	_fly_heart.visible = false
	_lives.max_lives = max_lives
	_lives.lives = max_lives
	_lives.queue_redraw()

# Pandaya çarpınca: kalp `from`dan (pandanın başı, ekran koordinatı) göstergeye
# uçar, varınca oradaki kalp söner ve gösterge sarsılır.
func lose_life(lives_left: int, from: Vector2) -> void:
	if _fly_tween:
		_fly_tween.kill()
		_lives.lives = lives_left + 1   # önceki uçuş yarıda kaldıysa onun kalbini de düşür
	var target := _lives.get_global_rect().position + _lives.heart_center(lives_left)
	_fly_heart.position = from
	_fly_heart.scale = Vector2(0.6, 0.6)
	_fly_heart.visible = true
	_fly_tween = create_tween()
	_fly_tween.tween_property(_fly_heart, "scale", Vector2(1.5, 1.5), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_fly_tween.tween_property(_fly_heart, "position", target, 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_fly_tween.parallel().tween_property(_fly_heart, "scale", Vector2.ONE, 0.65)
	_fly_tween.tween_callback(func():
		_fly_heart.visible = false
		_lives.lives = lives_left
		_lives.shake()
		_lives.queue_redraw())

func swap_rect() -> Rect2:
	return _swap.get_global_rect() if _swap.visible else Rect2()

# Swap edilen yiyeceğin ilerleme şeridindeki simgesi de sandviçe döner.
func set_icon_kind(index: int, kind: int) -> void:
	var icons := _progress.get_children().filter(func(c): return not c.is_queued_for_deletion())
	if index >= 0 and index < icons.size():
		icons[index].kind = kind
		icons[index].queue_redraw()

func _show_banner(title: String, col: Color) -> void:
	_banner_title.text = title
	_banner_title.add_theme_color_override("font_color", col)
	# uzun tek satırlık başlık (ör. "Ouch! Poor panda!") ekran kenarına dayanmasın
	var longest := 0
	for line in title.split("\n"):
		longest = maxi(longest, line.length())
	_banner_title.add_theme_font_size_override("font_size", 72 if longest <= 12 else 56)
	for b in [_btn_ad, _btn_main, _btn_home]:
		b.queue_redraw()
	_banner.visible = true
	_banner.modulate.a = 0.0
	create_tween().tween_property(_banner, "modulate:a", 1.0, 0.2)
	_banner_title.pivot_offset = _banner_title.size / 2.0
	_banner_title.scale = Vector2(0.4, 0.4)
	create_tween().tween_property(_banner_title, "scale", Vector2.ONE, 0.45) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func hide_banner() -> void:
	_banner.visible = false

# Seviye başında ortada kısa giriş kartı; yeni yiyecek varsa simgesiyle tanıtılır.
func show_intro(level: int, hint: String, new_kind: int, duration: float) -> void:
	_intro_title.text = "LEVEL %d" % level
	_intro_icon.visible = new_kind >= 0
	if new_kind >= 0:
		_intro_icon.kind = new_kind
		_intro_icon.queue_redraw()
	_intro_hint.text = hint
	_intro_hint.visible = hint != ""
	if _intro_tween and _intro_tween.is_valid():
		_intro_tween.kill()
	_intro.visible = true
	_intro.modulate.a = 0.0
	_intro_tween = create_tween()
	_intro_tween.tween_property(_intro, "modulate:a", 1.0, 0.2)
	_intro_tween.tween_interval(duration)
	_intro_tween.tween_property(_intro, "modulate:a", 0.0, 0.3)
	_intro_tween.tween_callback(func(): _intro.visible = false)
