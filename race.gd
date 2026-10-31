class_name Race

# Panda Yarışı: 3 günlük, çevrimdışı çalışan yarış. Oyuncu ("You") 19 hayvan rakiple
# yarışır; puanı, kazandığı seviyelerde sağ salim koyduğu altın bambulu yiyeceklerden
# gelir ve galibiyet serisiyle katlanır (x1, x2, x4, x8). Süre bitince sıralamaya göre
# ödül alınır (1.ye yalnız yarışla kazanılan Gold Medal), hemen yeni yarış başlar.
# Rakipler gerçek oyuncu değil — bilerek hayvan isimli: kimse onları insan sanmasın.
# Puanları kayıt gerektirmez: yarış no + geçen süreden her seferinde aynı hesaplanır.

const ENABLED := true              # kapatma anahtarı: false = yarış tamamen gizli
const UNLOCK_LEVEL := 5            # 4. seviye kazanılınca açılır (GameData.best_level). 8'deydi: oyuncuların
                                   # çoğu oraya gelmeden bırakıyordu; yarış ilk oturumda başlasın, "yarın
                                   # gel" sebebi olsun
const DURATION := 3 * 24 * 3600
const TOP_SCORE := 150.0           # en iyi rakibin yarış sonu hedefi (dengeleme ayarı)
# indeks = bu galibiyetle ulaşılan yarış serisi; 6+ = x8. Yavaş basamaklar: yarış 4. seviyeden
# sonra açılıyor ve kolay seviyelerde seri kolay — [1,1,2,4,8] ile tek oturumda zirveye çıkılıyordu
const MULT := [1, 1, 2, 2, 4, 4, 8]
const PRIZES := [300, 150, 75]     # 1-3. bambu (1. ayrıca Gold Medal; varsa +PRIZES[0] daha)
const PRIZE_TOP10 := 25
const MEDAL := "medal"

# isim, yüz rengi
const RIVALS := [
	["Koala Kiki", Color(0.62, 0.64, 0.7)], ["Red Panda Rui", Color(0.86, 0.42, 0.22)],
	["Sloth Sam", Color(0.62, 0.5, 0.38)], ["Otter Ollie", Color(0.5, 0.36, 0.26)],
	["Bunny Bea", Color(0.95, 0.78, 0.84)], ["Fox Finn", Color(0.95, 0.55, 0.2)],
	["Hedgehog Hugo", Color(0.55, 0.42, 0.35)], ["Penguin Pip", Color(0.25, 0.3, 0.4)],
	["Lemur Lulu", Color(0.7, 0.7, 0.72)], ["Owl Olive", Color(0.72, 0.56, 0.36)],
	["Tiger Tess", Color(1.0, 0.62, 0.22)], ["Bear Benny", Color(0.55, 0.36, 0.22)],
	["Duck Daisy", Color(1.0, 0.85, 0.3)], ["Frog Fred", Color(0.42, 0.75, 0.35)],
	["Cat Coco", Color(0.85, 0.72, 0.55)], ["Puppy Pablo", Color(0.8, 0.62, 0.42)],
	["Mouse Mimi", Color(0.75, 0.75, 0.8)], ["Monkey Milo", Color(0.6, 0.42, 0.28)],
	["Turtle Tom", Color(0.45, 0.65, 0.4)],
]

static var time_offset := 0        # test: zamanı ileri sarar (kaydedilmez)

static func now() -> int:
	return int(Time.get_unix_time_from_system()) + time_offset

static func unlocked() -> bool:
	return ENABLED and GameData.best_level >= UNLOCK_LEVEL

static func active() -> bool:
	return unlocked() and GameData.race_start > 0 and not is_over()

static func is_over() -> bool:
	return GameData.race_start > 0 and now() >= GameData.race_start + DURATION

static func time_left() -> int:
	return maxi(0, GameData.race_start + DURATION - now())

static func progress() -> float:
	if GameData.race_start <= 0:
		return 0.0
	return clampf(float(now() - GameData.race_start) / DURATION, 0.0, 1.0)

static func multiplier(streak: int) -> int:
	return MULT[clampi(streak, 0, MULT.size() - 1)]

# Yarış açıldıysa ve henüz başlamadıysa ilkini başlatır (4. seviyeyi yeni geçen ya da
# güncellemeyle gelen ileri seviyedeki oyuncu). true = şimdi başladı.
static func ensure_started() -> bool:
	if not unlocked() or GameData.race_start > 0:
		return false
	GameData.start_race(now())
	Analytics.log_event("race_start", {"race_id": GameData.race_id, "level": GameData.level})
	return true

# Seviyedeki altın bambulu yiyecekler (seviye listesindeki sıra no'ları): 1-3 tane,
# ilk yiyecek hariç; her denemede aynı.
static func golden_seqs(level: int, count: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = level * 104723 + 11
	var n := mini(1 + rng.randi() % 3, count - 1)
	var slots := range(1, count)
	var out := []
	for i in n:
		out.append(slots.pop_at(rng.randi() % slots.size()))
	out.sort()
	return out

# --- rakipler ---

# i. rakibin bu yarıştaki puanı (t: 0..1 yarışın geçen kısmı). Her yarışta kimin önde
# olacağı değişir; puan dakikalar içinde artar. Önden yüklü: rakipler ilk saatlerde hızlı
# (yeni oyuncu ilk oturumda zirveye çıkmasın), sonra yavaşlar (her gün gelen oyuncu tırmansın);
# yarış sonu puanları aynı.
static func rival_score(race_id: int, i: int, t: float) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = race_id * 7349 + 17
	var order := range(RIVALS.size())
	for k in range(order.size() - 1, 0, -1):          # bu yarışın güç sırası
		var j := rng.randi_range(0, k)
		var tmp = order[k]
		order[k] = order[j]
		order[j] = tmp
	var strength: int = order.find(i)                 # 0 = en güçlü
	rng.seed = race_id * 7349 + 101 * (i + 1)
	var shape := 1.0 - float(strength) / (RIVALS.size() - 1)
	var target := TOP_SCORE * (0.05 + 0.95 * pow(shape, 1.5)) * rng.randf_range(0.88, 1.1)
	var curve: float = [0.45, 0.6, 0.8][rng.randi() % 3]
	# çoğu yarışa birkaç puanla girer (oyuncudan önce başlamış gibi): zayıflar 1-3,
	# güçlüler ~10; yaklaşık altıda biri 0'dan. İlk puanını alan oyuncu boş değil,
	# kıpırdayan bir yarış görür.
	var head := 0.0
	if rng.randf() < 0.85:
		head = rng.randf_range(1.0, 3.0) + 8.0 * shape * rng.randf_range(0.6, 1.0)
	var ticks := 864.0                                 # 3 günde ~5 dakikada bir adım
	var tq := clampf(floorf(t * ticks + rng.randf()) / ticks, 0.0, 1.0)
	var burst := 0.25 * minf(tq / 0.04, 1.0)           # ilk ~3 saat: hedefin %25'i
	var f := burst + 0.75 * pow(tq, curve)
	return roundi(head + (maxf(target, head) - head) * f)

# Sıralama: [{name, score, color, you}], puana göre azalan; eşitlikte rakip önde
# (yarış başında herkes 0'dayken oyuncu 1. görünmesin, puan alınca yükselsin).
static func standings(t: float = -1.0) -> Array:
	if t < 0.0:
		t = progress()
	var rows := [{"name": "You", "score": GameData.race_points, "color": Color(1, 1, 1), "you": true}]
	for i in RIVALS.size():
		rows.append({"name": RIVALS[i][0], "score": rival_score(GameData.race_id, i, t), "color": RIVALS[i][1], "you": false})
	rows.sort_custom(func(a, b):
		if a["score"] != b["score"]:
			return a["score"] > b["score"]
		if a["you"] != b["you"]:
			return b["you"]
		# eşit puanlı rakipler her hesapta aynı sırada (sort_custom kararlı değil; kart
		# animasyonu önceki/sonraki listeyi isimle eşleştiriyor)
		return a["name"] < b["name"])
	return rows

static func rank(t: float = -1.0) -> int:
	var rows := standings(t)
	for i in rows.size():
		if rows[i]["you"]:
			return i + 1
	return rows.size()

# {"bamboo": n, "medal": bool} — medal yalnız 1.ye ve henüz yoksa.
static func prize(r: int) -> Dictionary:
	var medal := r == 1 and MEDAL not in GameData.owned
	var b := 0
	if r <= PRIZES.size():
		b = PRIZES[r - 1]
		if r == 1 and not medal:
			b += PRIZES[0]
	elif r <= 10:
		b = PRIZE_TOP10
	return {"bamboo": b, "medal": medal}

static func ordinal(r: int) -> String:
	return I18n.ordinal(r)

static func format_left(sec: int) -> String:
	var d := sec / 86400
	var h := (sec % 86400) / 3600
	var m := (sec % 3600) / 60
	if d > 0:
		return I18n.t("%dd %dh") % [d, h]
	if h > 0:
		return I18n.t("%dh %dm") % [h, m]
	return I18n.t("%dm") % maxi(m, 1)

# Altın bambu jetonu: altın daire, içinde bambu (yiyecek rozeti, simgeler, panel).
static func coin(ci: CanvasItem, c: Vector2, r: float) -> void:
	ci.draw_circle(c, r + 2.5, UiKit.INK)
	ci.draw_circle(c, r, Color(1.0, 0.78, 0.2))
	ci.draw_circle(c + Vector2(0, r * 0.12), r * 0.78, Color(0.96, 0.66, 0.12))
	ci.draw_arc(c, r * 0.8, PI * 1.1, PI * 1.6, 8, Color(1, 1, 1, 0.6), maxf(1.5, r * 0.14), true)
	UiKit.bamboo(ci, c, r * 1.25)
