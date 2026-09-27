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
	{"foods": [S, S, S, S], "hint": "Sürükle, bırakınca düşer"},
	{"foods": [S, C, S, C], "hint": "Pandanın kafasına düşürme!"},
	{"foods": [S, C, T, S, C], "hint": "Yeni: Tost"},
	{"foods": [S, C, P, S, C], "hint": "Yeni: Pizza — üstü sivri"},
	{"foods": [S, P, C, T, P, S], "hint": ""},
	{"foods": [S, C, W, T, S, C], "hint": "Yeni: Karpuz — çok ağır!"},
	{"foods": [S, W, C, P, T, W, S], "hint": ""},
	{"foods": [S, C, A, T, S, C, S], "hint": "Yeni: Elma — yuvarlanır!"},
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

static func _generated(level: int) -> Dictionary:
	# Aynı seviye her seferinde aynı diziyi üretsin diye tohum = seviye no.
	var rng := RandomNumberGenerator.new()
	rng.seed = level * 7919
	var extra := level - HAND_MADE.size()
	var count: int = mini(9 + int(extra / 2.0), 14)
	var hard := 0.25 + minf(extra * 0.03, 0.35)   # zor yiyecek oranı: %25 -> %60
	var easy := [S, C, T]
	var tough := [P, W, A]
	var foods: Array = [S]   # ilk parça hep sağlam bir taban
	for i in count - 1:
		var from: Array = tough if rng.randf() < hard else easy
		foods.append(from[rng.randi() % from.size()])
	return {"foods": foods, "hint": "", "pool": easy + tough}
