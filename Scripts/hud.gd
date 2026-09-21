extends CanvasLayer

## Ammo readout. It mirrors the gun's counts and never changes them itself:
## the gun announces every change through its ammo_changed signal.

@onready var ammo_label: Label = $AmmoLabel

var _gun: Gun = null


func _ready() -> void:
	_gun = get_tree().get_first_node_in_group("gun") as Gun
	if _gun == null:
		ammo_label.text = ""
		return

	_gun.ammo_changed.connect(_on_ammo_changed)
	# Draw the starting counts; the signal only covers changes from here on.
	_on_ammo_changed(_gun.bullets, _gun.magazines)


func _on_ammo_changed(bullets: int, magazines: int) -> void:
	var text := "Bullets  %d / %d\nMagazines  %d" % [bullets, Gun.MAGAZINE_SIZE, magazines]

	if bullets == 0:
		text += "\nOUT OF AMMO" if magazines == 0 else "\nEmpty - press R to reload"

	ammo_label.text = text
