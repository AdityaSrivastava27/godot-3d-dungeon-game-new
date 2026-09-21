extends CanvasLayer

## Ammo, health, and what just hit you. It mirrors what the gun and the player
## report and never changes either itself: both announce through signals.
##
## A hit plays a different effect depending on the weapon, so the player can
## tell being shot from being cut down without reading the numbers: gunfire is
## a short amber flash, the blade is a longer red one with slash marks across
## the screen.

const HURT_COLOUR := Color(0.78, 0.18, 0.15)
const HEALTHY_COLOUR := Color(0.32, 0.68, 0.30)

const BULLET_TINT := Color(1.0, 0.72, 0.25, 0.28)
const BULLET_FADE := 0.25
const MELEE_TINT := Color(0.85, 0.05, 0.05, 0.5)
const MELEE_FADE := 0.6

@onready var ammo_label: Label = $AmmoLabel
@onready var health_fill: ColorRect = $HealthBar/Fill
@onready var health_label: Label = $HealthBar/HealthLabel
@onready var hit_flash: ColorRect = $HitFlash
@onready var slash_marks: Control = $SlashMarks
@onready var hit_label: Label = $HitLabel

var _gun: Gun = null
var _player: Player = null
var _hit_tween: Tween = null


func _ready() -> void:
	hit_flash.modulate.a = 0.0
	slash_marks.modulate.a = 0.0
	hit_label.modulate.a = 0.0

	_gun = get_tree().get_first_node_in_group("gun") as Gun
	if _gun == null:
		ammo_label.text = ""
	else:
		_gun.ammo_changed.connect(_on_ammo_changed)
		# Draw the starting counts; the signal only covers changes from here on.
		_on_ammo_changed(_gun.bullets, _gun.magazines)

	_player = get_tree().get_first_node_in_group("player") as Player
	if _player != null:
		_player.health_changed.connect(_on_health_changed)
		_player.damaged.connect(_on_damaged)
		_on_health_changed(_player.health, Player.MAX_HEALTH)


func _on_ammo_changed(bullets: int, magazines: int) -> void:
	var text := "Bullets  %d / %d\nMagazines  %d" % [bullets, Gun.MAGAZINE_SIZE, magazines]

	if bullets == 0:
		text += "\nOUT OF AMMO" if magazines == 0 else "\nEmpty - press R to reload"

	ammo_label.text = text


func _on_health_changed(current: int, maximum: int) -> void:
	var ratio := 0.0 if maximum <= 0 else float(current) / float(maximum)

	# The fill is anchored to the left edge of the bar, so its right anchor is
	# the fraction of health left.
	health_fill.anchor_right = ratio
	health_fill.offset_right = 0.0
	health_fill.color = HURT_COLOUR if ratio <= 0.25 else HEALTHY_COLOUR
	health_label.text = "Health  %d%%" % roundi(ratio * 100.0)


func _on_damaged(amount: int, source: Player.DamageSource) -> void:
	if source == Player.DamageSource.MELEE:
		_play_hit(MELEE_TINT, MELEE_FADE, "SLASHED  -%d%%" % amount, true)
	else:
		_play_hit(BULLET_TINT, BULLET_FADE, "SHOT  -%d%%" % amount, false)


# Restart rather than stack, so a burst of hits does not leave the screen
# permanently tinted.
func _play_hit(tint: Color, fade: float, text: String, slash: bool) -> void:
	if _hit_tween != null and _hit_tween.is_valid():
		_hit_tween.kill()

	hit_flash.color = tint
	hit_flash.modulate.a = 1.0
	hit_label.text = text
	hit_label.modulate.a = 1.0
	slash_marks.modulate.a = 1.0 if slash else 0.0

	_hit_tween = create_tween().set_parallel(true)
	_hit_tween.tween_property(hit_flash, "modulate:a", 0.0, fade)
	_hit_tween.tween_property(hit_label, "modulate:a", 0.0, fade)
	if slash:
		_hit_tween.tween_property(slash_marks, "modulate:a", 0.0, fade)
