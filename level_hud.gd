class_name LevelHud
extends Control

# Oyun arayüzü (UI CanvasLayer'ın altında, tam ekran, dokunuşu yutmaz):
#   üstte büyük seviye başlığı + yiyecek simgelerinden ilerleme şeridi
#   (sayı yerine simge — "3 / 6" seviye numarasıyla karışıyordu), ipucu,
#   ortada büyük "Dengede tut" geri sayımı, seviye bitince kutlama (konfeti,
#   büyük yazı), kaybedince kart, yeni seviyede giriş kartı (yeni yiyecek simgesiyle).
# Oyun mantığı main.gd'de; bu sadece gösterir.

const GOLD := Color(1.0, 0.84, 0.35)
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

# Küçük yiyecek simgesi: yiyeceğin kendi çizimi (Food.paint) kutuya sığdırılır.
class FoodIcon extends Control:
	var kind := 0
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var k := minf(size.x / 84.0, size.y / 66.0)
		draw_set_transform(size / 2.0 + Vector2(0, 3.0 * k), 0.0, Vector2(k, k))
		Food.paint(self, kind)

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

	# kazanma / kaybetme kartı
	_banner = Control.new()
	_banner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.visible = false
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.45)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.add_child(dim)
	var bbox := VBoxContainer.new()
	bbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	bbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bbox.grow_vertical = Control.GROW_DIRECTION_BOTH
	bbox.alignment = BoxContainer.ALIGNMENT_CENTER
	bbox.add_theme_constant_override("separation", 28)
	bbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_title = _label("", _bold, 72, GOLD)
	_shadow(_banner_title)
	bbox.add_child(_banner_title)
	_banner_sub = _label("", _med, 32, Color.WHITE)
	bbox.add_child(_banner_sub)
	_banner.add_child(bbox)
	add_child(_banner)
	_pulse(_banner_sub)

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

	_apply_top_inset()

func _label(text: String, font: Font, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
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
	for c: Control in [_title, _progress, _hint]:
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

func show_win(level: int) -> void:
	hide_hold()
	_show_banner("LEVEL %d\nCOMPLETE!" % level, GOLD, "Tap for the next level")
	_confetti.position = Vector2(get_viewport_rect().size.x / 2.0, -20.0)
	_confetti.restart()

func show_lose(reason: String) -> void:
	hide_hold()
	_show_banner(reason, Color(1.0, 0.5, 0.45), "Tap to try again")

func _show_banner(title: String, col: Color, sub: String) -> void:
	_banner_title.text = title
	_banner_title.add_theme_color_override("font_color", col)
	# uzun tek satırlık başlık (ör. "Bonk! Poor panda!") ekran kenarına dayanmasın
	var longest := 0
	for line in title.split("\n"):
		longest = maxi(longest, line.length())
	_banner_title.add_theme_font_size_override("font_size", 72 if longest <= 12 else 56)
	_banner_sub.text = sub
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
