class_name Levels

# Seviye tanımları. İlk 10 seviye elle dizilmiş: her yeni yiyecek kendi
# seviyesinde tek başına tanıtılır, zorluk yavaş yavaş artar. Sıra her denemede
# aynıdır — kaybeden oyuncu "şanssızdım" değil "bu sefer nereye koyacağımı
# biliyorum" diye düşünsün. 10'dan sonrası parametrelerle üretilir.

const S := Food.Kind.SANDWICH
const C := Food.Kind.CHEESE
const T := Food.Kind.TOAST
const P := Food.Kind.PIZZA
const W := Food.Kind.WATERMELON
const A := Food.Kind.APPLE

const HAND_MADE := [
	{"foods": [S, S, S, S], "hint": "Drag and release to drop"},
	{"foods": [S, C, S, C], "hint": "Don't drop it on the panda!"},
	{"foods": [S, C, T, S, C], "hint": "New: Toast"},
	{"foods": [S, C, P, S, C], "hint": "New: Pizza — sharp top!"},
	{"foods": [S, P, C, T, P, S], "hint": "New: Swap a hard food!"},
	{"foods": [S, C, W, T, S, C], "hint": "New: Watermelon — very heavy!"},
	{"foods": [S, W, C, P, T, W, S], "hint": ""},
	{"foods": [S, C, A, T, S, C, S], "hint": "New: Apple — it rolls!"},
	{"foods": [S, P, W, C, A, T, S, C], "hint": ""},
	{"foods": [S, W, P, A, C, T, W, P, S], "hint": ""},
]

# Seviye için: sıralı yiyecek listesi, ipucu metni ve (yiyecek kirişten düşerse
# yerine gelecek) yedek havuzu. level 1'den başlar.
static func get_level(level: int) -> Dictionary:
	if level <= HAND_MADE.size():
		var d: Dictionary = HAND_MADE[level - 1]
		var pool: Array = []
		for k in d["foods"]:
			if k not in pool:
				pool.append(k)
		return {"foods": d["foods"], "hint": d["hint"], "pool": pool}
	return _generated(level)

# 11'den sonraki seviyeler planlı bir eğriyle üretilir (eskiden oran rastgeleydi:
# 14'te 4 karpuz, 23'te 14'ün 11'i zor gibi duvarlar çıkıyordu).
# 4'lük döngü — nefes, orta, zor, ZİRVE — ve 20 seviyede yükselip 31'de duran eğilim.
# Zirveden sonra hep bir nefes seviyesi gelir: oyuncu takıldığı yeri geçince ödüllenir.
const CYCLE := [-0.1, 0.05, 0.15, 0.3]
const MIN_FOODS := 8
const MAX_FOODS := 12          # kiriş boyu sabit: daha fazlası planlamayı yer darlığına çevirir

# 0 (kolay) .. 1 (en zor)
static func difficulty(level: int) -> float:
	var extra := level - HAND_MADE.size() - 1          # 11. seviye = 0
	var trend := minf(extra / 20.0, 1.0)
	return clampf(0.1 + trend * 0.7 + CYCLE[extra % CYCLE.size()], 0.0, 1.0)

static func is_peak(level: int) -> bool:
	return level > HAND_MADE.size() and (level - HAND_MADE.size() - 1) % CYCLE.size() == CYCLE.size() - 1

static func _generated(level: int) -> Dictionary:
	# Aynı seviye her seferinde aynı diziyi üretsin diye tohum = seviye no.
	var rng := RandomNumberGenerator.new()
	rng.seed = level * 7919
	var d := difficulty(level)
	var count: int = MIN_FOODS + roundi(d * (MAX_FOODS - MIN_FOODS))
	var n_tough: int = roundi(count * (0.25 + d * 0.35))   # %25 -> %60
	# karpuz sayısı şansa değil zorluğa bağlı: zor yiyeceklerin ~üçte biri, en fazla 1 -> 3
	var n_w: int = mini(1 + int(d * 2.5), roundi(n_tough / 3.0))
	var easy := [S, C, T]

	# zor yiyeceklerin yerleri: ilk ikisi hep kolay (sağlam taban), art arda en fazla 2 zor
	var tough_at := _place(range(2, count), n_tough, 3, rng)
	# karpuzlar zor yerlerin içinden: ilk 3 parçada ve en sonda değil (hemen ardından
	# 3 sn'lik denge sayacı başlar), iki karpuz yan yana değil
	var w_slots: Array = []
	for i in tough_at:
		if i >= 3 and i < count - 1:
			w_slots.append(i)
	var w_at := _place(w_slots, n_w, 2, rng)

	var foods: Array = []
	for i in count:
		if i == 0:
			foods.append(S)
		elif w_at.has(i):
			foods.append(W)
		elif tough_at.has(i):
			foods.append([P, A][rng.randi() % 2])
		else:
			foods.append(easy[rng.randi() % easy.size()])
	var hint := "Hard level!" if is_peak(level) else ""
	return {"foods": foods, "hint": hint, "pool": easy + [P, W, A]}

# slots içinden n yer seçer; hiçbir yerde `run` tane seçili art arda gelmez.
# Karışık sırayla açgözlü dener, en çok yer doldurabilen denemeyi tutar.
static func _place(slots: Array, n: int, run: int, rng: RandomNumberGenerator) -> Dictionary:
	var best := {}
	for attempt in 40:
		var order := slots.duplicate()
		for i in range(order.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var t = order[i]
			order[i] = order[j]
			order[j] = t
		var picked := {}
		for s in order:
			if picked.size() >= n:
				break
			picked[s] = true
			if _longest_run(picked, s) >= run:
				picked.erase(s)
		if picked.size() > best.size():
			best = picked
		if best.size() >= n:
			break
	return best

# s'yi içeren art arda seçili yer sayısı
static func _longest_run(picked: Dictionary, s: int) -> int:
	var a := s
	while picked.has(a - 1):
		a -= 1
	var b := s
	while picked.has(b + 1):
		b += 1
	return b - a + 1

# Bu seviyede ilk kez gelen yiyecek (giriş kartında gösterilir); yoksa -1.
static func new_kind(level: int) -> int:
	if level < 1 or level > HAND_MADE.size():
		return -1
	var seen := {}
	for i in level - 1:
		for k in HAND_MADE[i]["foods"]:
			seen[k] = true
	for k in HAND_MADE[level - 1]["foods"]:
		if not seen.has(k):
			return k
	return -1
