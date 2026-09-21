extends CanvasLayer

## Ammo and health readout. It mirrors what the gun and the player report and
## never changes either itself: both announce their changes through signals.

const HURT_COLOUR := Color(0.78, 0.18, 0.15)
const HEALTHY_COLOUR := Color(0.32, 0.68, 0.30)

@onready var ammo_label: Label = $AmmoLabel
@onready var health_fill: ColorRect = $HealthBar/Fill
@onready var health_label: Label = $HealthBar/HealthLabel

var _gun: Gun = null
var _player: Node = null


func _ready() -> void:
	_gun = get_tree().get_first_node_in_group("gun") as Gun
	if _gun == null:
		ammo_label.text = ""
	else:
		_gun.ammo_changed.connect(_on_ammo_changed)
		# Draw the starting counts; the signal only covers changes from here on.
		_on_ammo_changed(_gun.bullets, _gun.magazines)

	_player = get_tree().get_first_node_in_group("player")
	if _player != null:
		_player.health_changed.connect(_on_health_changed)
		_on_health_changed(_player.health, _player.MAX_HEALTH)


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
