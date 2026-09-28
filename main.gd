extends Node2D

# --- Faz 1: fizik prototipi, seviyeli ---
# Her seviyede sıralı bir yiyecek listesi var (levels.gd). Hepsi kirişin
# üstünde dururken kiriş HOLD_SECONDS boyunca devrilmezse seviye biter.
# Kiriş çok eğilirse ya da panda MAX_PANDA_HITS kez vurulursa seviye tekrar.
# Aşağıdaki sabitler asıl ayar düğmeleri — oyna, sayıları değiştir, tekrar dene.
# (angular_damp ve mass, Beam node'unun Inspector'ında / main.tscn'de de var.)
#
# PC kısayolları: N = sonraki seviye, B = önceki seviye, R = seviyeyi yeniden başlat

# true: yiyecek tepede bekler, parmağın olduğu yere gelir, bırakınca düşer.
# false: eski mod — yiyecek hemen düşmeye başlar, basılı tutarak yönlendirilir.
const HOVER_DROP := true

const TILT_LIMIT_DEG := 33.0     # bu açıyı geçince oyun biter
const HOLD_SECONDS := 3.0        # son yiyecekten sonra dengede tutma süresi
const HOVER_Y := 250.0           # yiyeceğin bekleme yüksekliği (HOVER_DROP)
const DROP_START_SPEED := 300.0  # bırakınca ilk düşüş hızı (px/sn)
const DROP_ACCEL := 2500.0       # düşerken hızlanma (px/sn²)
const DROP_MAX_SPEED := 1300.0
const FALL_SPEED := 260.0        # eski mod: yiyeceğin düz iniş hızı (px/sn)
const MAX_LANE_OFFSET := 240.0   # pivot'a göre gidebileceği en uzak nokta (kiriş ucundan pay bırakır)
const STEER_SPEED := 240.0       # eski mod: basılı tutunca yatay kayma hızı (px/sn)
const STEER_LOCK_DISTANCE := 160.0  # eski mod: altında bu kadar yakın bir şey varsa yön artık kilitli
const SPAWN_DELAY := 0.55        # bir yiyecek yerleşince sıradakinin gecikmesi
const PANDA_HIT_HALF_WIDTH := 34.0  # pandanın yarı genişliği (beam_panda.gd gövdesi ±34)
const MAX_PANDA_HITS := 2        # bu kadar vuruşta oyun biter
const SAVE_PATH := "user://progress.cfg"
const TILT_WARN_DEG := 22.0      # bu açıdan sonra kiriş kızarıp yanıp söner (limit TILT_LIMIT_DEG)
const INTRO_SECONDS := 1.0       # yeni seviye giriş kartı; ilk yiyecek bundan sonra gelir
const DEV_LONG_PRESS_MS := 600   # test sürümü: seviye başlığına uzun basış = önceki seviye

enum Phase { PLAYING, HOLDING, WON, LOST }

@onready var pivot: StaticBody2D = $Pivot
@onready var beam: RigidBody2D = $Beam
@onready var panda: Node2D = $Beam/Panda
@onready var panda_zone: Area2D = $Beam/PandaZone
@onready var food_container: Node2D = $FoodContainer
@onready var beam_visual: Control = $Beam/Visual
var hud: LevelHud

var level := 1
var phase := Phase.PLAYING
var panda_hits := 0
var current_food: Food = null
var _level_data: Dictionary
var _seq_index := 0
var _rng := RandomNumberGenerator.new()
var _spawn_wait := 0.0
var _hold_left := 0.0
var _dropping := false
var _drop_speed := 0.0
var _active_touch_index := -1  # -1 = şu an hiçbir parmak aktif değil
var _holding := false
var _touch_x := 0.0
var _guide: DropGuide
var _t := 0.0
var _dev_touch_index := -1       # test sürümü kısayolu için başlığa basan parmak
var _dev_press_msec := 0

# Bekleyen yiyeceğin nereye ineceğini gösteren kesikli çizgi; pandaya
# denk geliyorsa kırmızı olur.
class DropGuide extends Node2D:
	var active := false
	var from := Vector2.ZERO
	var to := Vector2.ZERO
	var danger := false

	func _draw() -> void:
		if not active:
			return
		var col := Color(1.0, 0.35, 0.3, 0.85) if danger else Color(1, 1, 1, 0.35)
		draw_dashed_line(from, to, col, 3.0, 12.0)
		draw_line(to + Vector2(-16, 0), to + Vector2(16, 0), col, 3.0)

func _ready() -> void:
	_guide = DropGuide.new()
	add_child(_guide)
	move_child(_guide, food_container.get_index())   # yiyeceklerin altında çizilsin
	hud = LevelHud.new()
	$UI.add_child(hud)
	# Node2D altındaki ColorRect'in anchor'ı çözülmüyor, boyutu 0 kalıp gri
	# varsayılan zemin görünüyordu — boyutu elle ver.
	_fit_background()
	get_viewport().size_changed.connect(_fit_background)
	_start_level(_load_level())

# Yerleşmiş bir parça sonradan eğimle kayıp pandaya ulaştıysa: yukarıdan
# düşmüş gibi aynı _panda_hit sonucu (yaralanma görseli / 2. vuruşta bitiş).
# Alan sadece ucuz bir ön eleme; asıl kural inişteki ve kılavuz çizgideki ile
# aynı (_lands_on_panda) — pandanın hemen yanına konan parça sayılmaz,
# yığının üstündeki parça da sayılmaz.
func _check_panda_zone() -> void:
	for body in panda_zone.get_overlapping_bodies():
		if body is Food and body.get_meta("landed", false) and not body.get_meta("gone", false):
			if _lands_on_panda(body, body.global_transform):
				_panda_hit(body)
				if phase == Phase.LOST:
					return

# --- seviye akışı ---

func _fit_background() -> void:
	var bg: ColorRect = $Background
	bg.set_anchors_preset(Control.PRESET_TOP_LEFT)
	bg.position = Vector2.ZERO
	bg.size = get_viewport_rect().size

# retry = aynı seviyeyi tekrar deniyor (kısa giriş kartı, yeni yiyecek tanıtımı yok)
func _start_level(n: int, retry: bool = false) -> void:
	level = maxi(n, 1)
	_save_level(level)
	_level_data = Levels.get_level(level)
	_rng.seed = level * 104729   # kirişten düşen yiyeceğin yedeği de her denemede aynı gelsin
	_seq_index = 0
	phase = Phase.PLAYING
	panda_hits = 0
	panda.reset()
	current_food = null
	_dropping = false
	_set_guide(false)
	beam_visual.modulate = Color.WHITE
	hud.setup_level(level, _level_data["foods"], _level_data["hint"])
	var intro: float = 0.35 if retry else INTRO_SECONDS
	hud.show_intro(level, "" if retry else _level_data["hint"], -1 if retry else Levels.new_kind(level), intro)
	_spawn_wait = intro + 0.25

	# remove_child: queue_free'lenen eski yiyecekler kare sonuna kadar çocuk olarak
	# kalıp yeni seviyenin ilk karesinde "yerleşmiş" sayılabiliyordu.
	for c in food_container.get_children():
		food_container.remove_child(c)
		c.queue_free()

	# Not: beam.rotation/.position gibi doğrudan atamalar RigidBody2D'de tutmuyor
	# — bir sonraki fizik adımında motor eski durumu geri yazıyor. Gerçek reset
	# için PhysicsServer2D üzerinden durumu doğrudan yazmak gerekiyor.
	var rid := beam.get_rid()
	PhysicsServer2D.body_set_state(rid, PhysicsServer2D.BODY_STATE_TRANSFORM, Transform2D(0.0, pivot.position))
	PhysicsServer2D.body_set_state(rid, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, Vector2.ZERO)
	PhysicsServer2D.body_set_state(rid, PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY, 0.0)

func _target() -> int:
	return _level_data["foods"].size()

# Kirişin üstünde duran (yerleşmiş, pandaya çarpıp kaybolmamış, kirişten
# düşmemiş) yiyecek sayısı — seviye hedefi buna bakar.
func _placed_count() -> int:
	var n := 0
	for f in food_container.get_children():
		if f is Food and f.get_meta("landed", false) and not f.get_meta("gone", false) and not f.get_meta("lost", false):
			n += 1
	return n

# Kirişin açısı fizik motorundan okunur: seviye başında PhysicsServer2D ile
# sıfırlanan kiriş, düğümde (beam.rotation) ancak sonraki fizik adımında
# güncelleniyordu — kazandıktan sonra devrilen kirişle yeni seviye ilk karede
# "Out of balance!" ile bitiyordu.
func _beam_angle() -> float:
	var xf: Transform2D = PhysicsServer2D.body_get_state(beam.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM)
	return xf.get_rotation()

func _process(delta: float) -> void:
	var deg := rad_to_deg(_beam_angle())
	_t += delta

	if phase == Phase.WON or phase == Phase.LOST:
		return

	if abs(deg) >= TILT_LIMIT_DEG:
		_lose("Out of balance!")
		return
	_update_tilt_warning(absf(deg))

	_update_food(delta)
	if phase == Phase.LOST:   # iniş pandaya ikinci vuruş olduysa
		return
	_mark_lost_foods()
	_check_panda_zone()
	if phase == Phase.LOST:
		return
	var placed := _placed_count()
	hud.set_progress(mini(placed, _target()))

	if current_food == null:
		if placed >= _target():
			if phase != Phase.HOLDING:
				phase = Phase.HOLDING
				_hold_left = HOLD_SECONDS
			_hold_left -= delta
			hud.show_hold(maxi(1, ceili(_hold_left)))
			if _hold_left <= 0.0:
				_win()
		else:
			if phase == Phase.HOLDING:
				# beklerken bir yiyecek düştü ya da pandaya kaydı -> yerine yenisi gelir
				phase = Phase.PLAYING
				hud.hide_hold()
				_spawn_wait = SPAWN_DELAY
			_spawn_wait -= delta
			if _spawn_wait <= 0.0:
				_spawn_food()

	# ekrandan çıkan yiyecekleri temizle
	var bottom := get_viewport_rect().size.y + 200.0
	for f in food_container.get_children():
		if f.global_position.y > bottom:
			f.queue_free()

func _mark_lost_foods() -> void:
	# Kirişin ucundan düşen yiyecek artık sayılmaz (yerine yenisi gelir).
	for f in food_container.get_children():
		if f is Food and f.get_meta("landed", false) and not f.get_meta("lost", false):
			var local := beam.to_local(f.global_position)
			if local.y > 30.0 or absf(local.x) > 320.0:
				f.set_meta("lost", true)

func _win() -> void:
	phase = Phase.WON
	_set_guide(false)
	_save_level(level + 1)
	beam_visual.modulate = Color.WHITE
	hud.show_win(level)
	panda.celebrate()
	Input.vibrate_handheld(60)

func _lose(reason: String) -> void:
	phase = Phase.LOST
	if current_food and current_food.freeze:
		current_food.queue_free()
	current_food = null
	_set_guide(false)
	hud.show_lose(reason)
	Input.vibrate_handheld(80)

# Kiriş kritik açıya yaklaştıkça kızarır ve giderek hızlanarak yanıp söner —
# oyuncu devrilmeden önce "tehlike" hissini alsın.
func _update_tilt_warning(abs_deg: float) -> void:
	var k: float = clampf((abs_deg - TILT_WARN_DEG) / (TILT_LIMIT_DEG - TILT_WARN_DEG), 0.0, 1.0)
	if k <= 0.0:
		beam_visual.modulate = Color.WHITE
		return
	var pulse: float = 0.5 + 0.5 * sin(_t * lerpf(8.0, 20.0, k))
	var r: float = k * (0.55 + 0.45 * pulse)
	beam_visual.modulate = Color(1.0 + 0.3 * r, 1.0 - 0.7 * r, 1.0 - 0.7 * r)

func _load_level() -> int:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		return int(cfg.get_value("progress", "level", 1))
	return 1

func _save_level(n: int) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "level", n)
	cfg.save(SAVE_PATH)

# --- yiyecek hareketi ---

# Bekleyen yiyecek parmağı izler (kare hızında, akıcı olsun diye _process'te).
func _update_food(_delta: float) -> void:
	var f := current_food
	if f == null or not f.freeze or not HOVER_DROP or _dropping:
		_set_guide(false)
		return
	if _holding:
		f.position.x = _lane_x(_touch_x)
	_update_guide(f)

# Düşüş fizik adımlarında: kiriş ve düşen yiyecek aynı adımlarla ilerlesin.
# _process'teyken yavaş karelerde (takılma, zayıf telefon) bir karede birkaç
# fizik adımı geçip kiriş duran yiyeceğin içine dönüyordu; tarama da başlangıçta
# iç içe olduğu cismi yok saydığı için yiyecek kirişin içinden geçiyordu.
func _physics_process(delta: float) -> void:
	if phase == Phase.WON or phase == Phase.LOST:
		return
	var f := current_food
	if f == null or not f.freeze:
		return
	if HOVER_DROP:
		if not _dropping:
			return
		_drop_speed = minf(_drop_speed + DROP_ACCEL * delta, DROP_MAX_SPEED)
		if _sweep(f, Vector2(0, _drop_speed * delta)):
			_on_touchdown(f)
	else:
		_steer(delta)
		if _sweep(f, Vector2(0, FALL_SPEED * delta)):
			_on_touchdown(f)

func _lane_x(screen_x: float) -> float:
	return clampf(screen_x, pivot.position.x - MAX_LANE_OFFSET, pivot.position.x + MAX_LANE_OFFSET)

func _set_guide(on: bool) -> void:
	if _guide.active != on:
		_guide.active = on
		_guide.queue_redraw()

func _update_guide(f: Food) -> void:
	var space := get_world_2d().direct_space_state
	var motion := Vector2(0, 1400)
	var res := space.cast_motion(_shape_query(f, f.global_transform, motion))
	var safe: float = res[0] if res.size() > 0 else 1.0
	var land := f.global_transform.translated(motion * safe)
	_guide.active = true
	_guide.from = f.global_position + Vector2(0, f.half_h + 6)
	_guide.to = land.origin + Vector2(0, f.half_h)
	_guide.danger = safe < 1.0 and _lands_on_panda(f, land)
	_guide.queue_redraw()

func _steer(delta: float) -> void:
	# Eski mod: parmak basılı kaldıkça yiyecek dokunulan tarafa sabit hızla kayar
	# ve kirişin ucuna (MAX_LANE_OFFSET) kadar gidebilir; parmak kalkınca durur.
	if not _holding or not _is_steerable(current_food):
		return
	var screen_w := get_viewport_rect().size.x
	var dir: float = sign(_touch_x - screen_w / 2.0)
	var target_x: float = pivot.position.x + dir * MAX_LANE_OFFSET
	var dx: float = move_toward(current_food.position.x, target_x, STEER_SPEED * delta) - current_food.position.x
	if dx != 0.0:
		_sweep(current_food, Vector2(dx, 0))   # yandaki bir yığının içine kaymasın

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_N: _start_level(level + 1)
			KEY_B: _start_level(level - 1)
			KEY_R: _start_level(level, true)
		return
	if OS.is_debug_build() and _dev_shortcut(event):
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			# Zaten aktif bir parmak varsa, yeni parmağı tamamen yok say
			if _active_touch_index != -1:
				return
			_active_touch_index = event.index
			_press(event.position.x)
		elif event.index == _active_touch_index:
			_active_touch_index = -1
			_release()
	elif event is InputEventScreenDrag:
		if event.index == _active_touch_index:
			_touch_x = event.position.x
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press(event.position.x)
		else:
			_release()
	elif event is InputEventMouseMotion and _holding:
		_touch_x = event.position.x

# Yalnız test (debug) sürümünde: seviye başlığına dokun = sonraki seviye,
# uzun bas = önceki seviye, oyun sırasında ikinci parmak = seviyeyi yeniden başlat.
# Release sürümde hiç çağrılmaz. true = olay kısayola gitti, oyun görmesin.
func _dev_shortcut(event: InputEvent) -> bool:
	if not event is InputEventScreenTouch:
		return false
	if event.pressed:
		if _active_touch_index != -1 and event.index != _active_touch_index:
			_holding = false
			_active_touch_index = -1
			_start_level(level, true)
			return true
		if event.position.y < 150.0 and _active_touch_index == -1:
			_dev_touch_index = event.index
			_dev_press_msec = Time.get_ticks_msec()
			return true
	elif event.index == _dev_touch_index:
		_dev_touch_index = -1
		if Time.get_ticks_msec() - _dev_press_msec >= DEV_LONG_PRESS_MS:
			_start_level(level - 1)
		else:
			_start_level(level + 1)
		return true
	return false

func _press(x: float) -> void:
	if phase == Phase.WON:
		_start_level(level + 1)
		return
	if phase == Phase.LOST:
		_start_level(level, true)
		return
	_holding = true
	_touch_x = x

func _release() -> void:
	if not _holding:
		return   # bu dokunuş seviyeyi başlatmak için kullanıldı
	_holding = false
	if HOVER_DROP and current_food and current_food.freeze and not _dropping:
		# anlık dokunuşta da parmağın olduğu yere düşsün
		current_food.position.x = _lane_x(_touch_x)
		_dropping = true
		_drop_speed = DROP_START_SPEED

func _spawn_food() -> void:
	var f := Food.new()
	f.setup(_next_kind())
	f.freeze = true
	f.gravity_scale = 1.0
	# Donmuşken (düz iniş sırasında) çarpışma tamamen kapalı — donmuş cisim
	# itilemediği için ona değen her şeyin tepki kuvveti tamamen kirişe
	# gidip sert bir sarsıntı yaratıyordu. İnişi kendi şekil taramamız (_sweep) yönetiyor.
	f.collision_layer = 0
	f.collision_mask = 0
	var x := pivot.position.x
	if HOVER_DROP and _holding:
		x = _lane_x(_touch_x)
	f.position = Vector2(x, HOVER_Y if HOVER_DROP else 140.0)
	food_container.add_child(f)
	current_food = f
	_dropping = false
	_spawn_wait = SPAWN_DELAY

# Seviyenin sıradaki yiyeceği; liste bittiyse (bir yiyecek düştüğü ya da
# pandaya çarptığı için ek parça gerekiyorsa) seviyenin havuzundan.
func _next_kind() -> int:
	var foods: Array = _level_data["foods"]
	if _seq_index < foods.size():
		_seq_index += 1
		return foods[_seq_index - 1]
	var pool: Array = _level_data["pool"]
	return pool[_rng.randi() % pool.size()]

# --- çarpışma sorguları ---

func _shape_query(food: Food, xform: Transform2D, motion: Vector2) -> PhysicsShapeQueryParameters2D:
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = food.shape
	q.transform = xform
	q.motion = motion
	q.exclude = [food.get_rid()]
	q.collision_mask = 1
	return q

# Yiyeceği gerçek şekliyle `motion` kadar kaydırır; yolda bir şeye (kiriş ya da
# yerleşmiş yiyecek) değecekse tam değmeden önceki noktada durur -> iç içe geçme
# olmaz. Tek bir orta ışını geniş şekillerin kenarını kaçırıyordu. true = temas.
func _sweep(food: Food, motion: Vector2) -> bool:
	var space := get_world_2d().direct_space_state
	# cast_motion başlangıçta iç içe olduğu cismi yok sayar: kiriş yiyeceğe
	# değmiş/girmişse taramaya hiç başlama, temas say (hemen yerleşir).
	if not space.intersect_shape(_shape_query(food, food.global_transform, Vector2.ZERO), 1).is_empty():
		return true
	var res := space.cast_motion(_shape_query(food, food.global_transform, motion))
	var safe: float = res[0] if res.size() > 0 else 1.0
	food.global_position += motion * safe
	return safe < 1.0

func _is_steerable(food: Food) -> bool:
	# Altında (kirişe ya da bir yığına) STEER_LOCK_DISTANCE'tan yakın bir şey
	# varsa artık yön değiştirtme — geç yönlendirme yiyeceği yığının içine
	# sokup fizik açılınca sert bir itmeye yol açıyordu.
	var space := get_world_2d().direct_space_state
	var res := space.cast_motion(_shape_query(food, food.global_transform, Vector2(0, STEER_LOCK_DISTANCE)))
	return res.size() == 0 or res[0] >= 1.0

# `xform` konumunda duran yiyecek doğrudan kirişe, pandanın olduğu yere mi
# değiyor? (yığının üstüne inmek sayılmaz) Şekli birkaç piksel aşağıda sorgular.
func _lands_on_panda(food: Food, xform: Transform2D) -> bool:
	var space := get_world_2d().direct_space_state
	var probe := _shape_query(food, xform.translated(Vector2(0, 3)), Vector2.ZERO)
	for hit in space.intersect_shape(probe, 8):
		if hit["collider"] == beam:
			var lx: float = absf(beam.to_local(xform.origin).x)
			return lx <= PANDA_HIT_HALF_WIDTH + food.half_w * 0.5
	return false

func _on_touchdown(food: Food) -> void:
	_dropping = false
	if _lands_on_panda(food, food.global_transform):
		_panda_hit(food)
	else:
		_land_food(food)

func _panda_hit(food: Food) -> void:
	# Pandanın kafasına düşen/kayan yiyecek sayılmaz, kaybolur.
	food.set_meta("gone", true)
	food.collision_layer = 0
	food.collision_mask = 0
	if food == current_food:
		current_food = null
		_spawn_wait = SPAWN_DELAY
	var fade := create_tween()
	fade.tween_property(food, "modulate:a", 0.0, 0.25)
	fade.tween_callback(food.queue_free)

	panda_hits += 1
	panda.set_hits(panda_hits)
	if panda_hits >= MAX_PANDA_HITS:
		_lose("Ouch! Poor panda!")

func _land_food(body: Food) -> void:
	if body.get_meta("landed", false):
		return
	body.set_meta("landed", true)
	body.freeze = false
	body.collision_layer = 1
	body.collision_mask = 1
	body.linear_velocity = Vector2.ZERO
	body.angular_velocity = 0.0
	# dönme serbest: düz yiyecekler kendiliğinden devrilmez, yuvarlaklar gerçekten yuvarlanır

	if body == current_food:
		current_food = null
		_spawn_wait = SPAWN_DELAY
