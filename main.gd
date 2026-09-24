extends Node2D

# --- Faz 1: çıplak fizik prototipi ---
# Amaç: kirişin dengesi doğal mı hissediyor, yoksa "floaty"/"seğirmeli" mi?
# Aşağıdaki sabitler asıl ayar düğmeleri — oyna, sayıları değiştir, tekrar dene.
# (angular_damp ve mass, Beam node'unun Inspector'ında / main.tscn'de de var.)

const TILT_LIMIT_DEG := 29.0     # bu açıyı geçince oyun biter
const FALL_SPEED := 260.0        # yiyeceğin düz iniş hızı (px/sn)
const MAX_LANE_OFFSET := 240.0   # pivot'a göre gidebileceği en uzak nokta (kiriş ucundan pay bırakır)
const STEER_SPEED := 240.0       # basılı tutunca yatay kayma hızı (px/sn)
const STEER_LOCK_DISTANCE := 160.0  # altında bu kadar yakın bir şey varsa yön artık kilitli
const SPAWN_DELAY := 0.55        # bir yiyecek yerleşince sıradakinin gecikmesi
const PANDA_HIT_HALF_WIDTH := 34.0  # pandanın yarı genişliği (beam_panda.gd gövdesi ±34)
const MAX_PANDA_HITS := 2        # bu kadar vuruşta oyun biter

enum Kind { APPLE, WATERMELON, PIZZA }
const FOOD_DATA := {
	Kind.APPLE:      {"mass": 0.5, "radius": 15.0},
	Kind.WATERMELON: {"mass": 1.6, "radius": 26.0},
	Kind.PIZZA:      {"mass": 0.9, "radius": 22.0},
}

@onready var pivot: StaticBody2D = $Pivot
@onready var beam: RigidBody2D = $Beam
@onready var panda: Node2D = $Beam/Panda
@onready var panda_zone: Area2D = $Beam/PandaZone
@onready var food_container: Node2D = $FoodContainer
@onready var score_label: Label = $UI/ScoreLabel
@onready var tilt_label: Label = $UI/TiltLabel
@onready var game_over_label: Label = $UI/GameOverLabel

var score := 0
var game_over := false
var panda_hits := 0
var current_food: RigidBody2D = null
var _active_touch_index := -1  # -1 = şu an hiçbir parmak aktif değil
var _holding := false
var _touch_x := 0.0

func _ready() -> void:
	panda_zone.body_entered.connect(_on_panda_zone_body_entered)
	_spawn_food()

func _on_panda_zone_body_entered(body: Node) -> void:
	# Düşmekte olan parça zaten kendi raycast'iyle (_check_landing) yakalanıyor
	# — o sırada çarpışması kapalı olduğu için buraya hiç girmez. Bu sadece
	# yerleşmiş, sonradan eğimle kayıp pandaya ulaşan parçalar için: yukarıdan
	# düşmüş gibi aynı _panda_hit sonucunu üretir (yaralanma görseli / 2. vuruşta bitiş).
	if body is RigidBody2D and body.get_meta("landed", false):
		_panda_hit(body)

func _process(delta: float) -> void:
	var deg := rad_to_deg(beam.rotation)
	tilt_label.text = "eğim: %.1f°" % deg

	if game_over:
		return

	if abs(deg) >= TILT_LIMIT_DEG:
		_end_game()
		return

	_steer(delta)

	if current_food and current_food.freeze:
		current_food.position.y += FALL_SPEED * delta
		_check_landing(current_food)

func _steer(delta: float) -> void:
	# Parmak basılı kaldıkça yiyecek dokunulan tarafa sabit hızla kayar ve
	# kirişin ucuna (MAX_LANE_OFFSET) kadar gidebilir; parmak kalkınca durur.
	if not _holding or current_food == null or not current_food.freeze:
		return
	if not _is_steerable(current_food):
		return
	var screen_w := get_viewport_rect().size.x
	var dir: float = sign(_touch_x - screen_w / 2.0)
	var target_x: float = pivot.position.x + dir * MAX_LANE_OFFSET
	current_food.position.x = move_toward(current_food.position.x, target_x, STEER_SPEED * delta)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			# Zaten aktif bir parmak varsa, yeni parmağı tamamen yok say
			if _active_touch_index != -1:
				return
			if game_over:
				_restart()
				return
			_active_touch_index = event.index
			_holding = true
			_touch_x = event.position.x
		elif event.index == _active_touch_index:
			_active_touch_index = -1
			_holding = false
	elif event is InputEventScreenDrag:
		if event.index == _active_touch_index:
			_touch_x = event.position.x
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if game_over:
				_restart()
				return
			_holding = true
			_touch_x = event.position.x
		else:
			_holding = false
	elif event is InputEventMouseMotion and _holding:
		_touch_x = event.position.x

func _spawn_food() -> void:
	if game_over:
		return
	var kind: int = [Kind.APPLE, Kind.WATERMELON, Kind.PIZZA][randi() % 3]
	var data: Dictionary = FOOD_DATA[kind]

	var f := RigidBody2D.new()
	f.set_script(load("res://food.gd"))
	f.kind = kind
	f.radius = data["radius"]
	f.freeze = true
	f.mass = data["mass"]
	f.gravity_scale = 1.0
	# Donmuşken (düz iniş sırasında) çarpışma tamamen kapalı — donmuş cisim
	# itilemediği için ona değen her şeyin tepki kuvveti tamamen kirişe/sete
	# gidip sert bir sarsıntı yaratıyordu. "Yerleşti mi" kararını zaten kendi
	# raycast sistemimiz veriyor, fiziğin inişe karışmasına gerek yok.
	f.collision_layer = 0
	f.collision_mask = 0
	var mat := PhysicsMaterial.new()
	mat.friction = 0.7
	mat.bounce = 0.05
	f.physics_material_override = mat

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = data["radius"]
	shape.shape = circle
	f.add_child(shape)

	f.position = Vector2(pivot.position.x, 140.0)
	food_container.add_child(f)
	current_food = f

func _is_steerable(food: RigidBody2D) -> bool:
	# Altında (kirişe ya da bir yığına) STEER_LOCK_DISTANCE'tan yakın bir şey
	# varsa artık yön değiştirtme — geç yönlendirme, tween'i doğrudan zaten
	# yerleşmiş bir yiyeceğin içine atlatıp fizik açılınca sert bir itmeye
	# yol açıyordu. Boş kirişte altta hiçbir şey olmadığı sürece serbest.
	var space_state := get_world_2d().direct_space_state
	var from: Vector2 = food.global_position
	var to: Vector2 = from + Vector2(0, STEER_LOCK_DISTANCE)
	var query := PhysicsRayQueryParameters2D.create(from, to)
	query.exclude = [food.get_rid()]
	return space_state.intersect_ray(query).is_empty()

func _check_landing(food: RigidBody2D) -> void:
	# Sabit bir "üst yüzey" çizgisi (eski Area2D tetikleyici) yığın büyüyünce
	# işe yaramıyor — yeni yiyecek eskisinin İÇİNE düşüyordu (üst üste binme).
	# Bunun yerine her karede düz aşağı kısa bir ışın at: kirişe ya da daha
	# önce yerleşmiş herhangi bir yiyeceğe değecek kadar yaklaştıysa dur.
	var space_state := get_world_2d().direct_space_state
	var from: Vector2 = food.global_position
	var to: Vector2 = from + Vector2(0, food.radius + 4.0)
	var query := PhysicsRayQueryParameters2D.create(from, to)
	query.exclude = [food.get_rid()]
	var result := space_state.intersect_ray(query)
	if result:
		var on_panda: bool = result.collider == beam \
			and abs(beam.to_local(food.global_position).x) <= PANDA_HIT_HALF_WIDTH + food.radius * 0.5
		if on_panda:
			_panda_hit(food)
		else:
			_land_food(food)

func _panda_hit(food: RigidBody2D) -> void:
	# Pandanın kafasına düşen/kayan yiyecek skora sayılmaz, kaybolur.
	food.collision_layer = 0
	food.collision_mask = 0
	# Vuran parça o an düşmekte olan (takip edilen) parça mıydı? Yerleşmiş bir
	# parça sonradan kayarak vurduysa, düşmekte olan başka bir parça hâlâ
	# oyunda olabilir — o zaman yeni spawn tetiklemiyoruz, mevcut akış devam eder.
	var was_current: bool = food == current_food
	if was_current:
		current_food = null
	var fade := create_tween()
	fade.tween_property(food, "modulate:a", 0.0, 0.25)
	fade.tween_callback(food.queue_free)

	panda_hits += 1
	panda.set_hits(panda_hits)

	if panda_hits >= MAX_PANDA_HITS:
		_end_game("Kafasına düştü!")
	elif was_current:
		get_tree().create_timer(SPAWN_DELAY).timeout.connect(_spawn_food)

func _land_food(body: RigidBody2D) -> void:
	if body.get_meta("landed", false):
		return
	body.set_meta("landed", true)
	body.freeze = false
	body.collision_layer = 1
	body.collision_mask = 1
	body.linear_velocity = Vector2.ZERO
	body.angular_velocity = 0.0
	body.lock_rotation = true   # daire yuvarlanıp kaçış döngüsü yaratmasın; sürtünmeyle hâlâ kayabilir

	score += 1
	score_label.text = str(score)

	if body == current_food:
		current_food = null
		get_tree().create_timer(SPAWN_DELAY).timeout.connect(_spawn_food)

func _end_game(reason: String = "Devrildi!") -> void:
	game_over = true
	current_food = null
	game_over_label.visible = true
	game_over_label.text = "%s\nSkor: %d\n\nDokun, tekrar dene" % [reason, score]

func _restart() -> void:
	game_over = false
	game_over_label.visible = false
	score = 0
	score_label.text = "0"
	panda_hits = 0
	panda.set_hits(0)

	for c in food_container.get_children():
		c.queue_free()

	# Not: beam.rotation/.position gibi doğrudan atamalar RigidBody2D'de tutmuyor
	# — bir sonraki fizik adımında motor eski durumu geri yazıyor. Gerçek reset
	# için PhysicsServer2D üzerinden durumu doğrudan yazmak gerekiyor.
	var rid := beam.get_rid()
	PhysicsServer2D.body_set_state(rid, PhysicsServer2D.BODY_STATE_TRANSFORM, Transform2D(0.0, pivot.position))
	PhysicsServer2D.body_set_state(rid, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, Vector2.ZERO)
	PhysicsServer2D.body_set_state(rid, PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY, 0.0)

	_spawn_food()
