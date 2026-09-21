class_name Gun
extends Node3D

## Hitscan pistol carried by the player.
##
## Ammo model: the player carries the magazine loaded in the gun plus a number
## of spares. The first magazine is chambered when the game starts, so it comes
## out of the starting count and the reserve begins one lower. Reloading (R)
## swaps in a fresh magazine and spends one spare; rounds left in the old
## magazine are lost, as with a real magazine swap. Firing on an empty magazine
## does nothing -- the player has to reload first.

## Emitted whenever either count changes, so the HUD never has to poll.
signal ammo_changed(bullets: int, magazines: int)

const MAGAZINE_SIZE := 6
const STARTING_MAGAZINES := 5

const SHOT_RANGE := 100.0
const FLASH_TIME := 0.05    # how long the muzzle light stays lit
const IMPACT_TIME := 0.15   # how long the spark at the hit point lives

# The first magazine is loaded at start, so the reserve starts one short.
var bullets: int = MAGAZINE_SIZE
var magazines: int = STARTING_MAGAZINES - 1

@onready var flash: OmniLight3D = $Muzzle/Flash
@onready var _player: CharacterBody3D = get_parent()
@onready var _camera: Camera3D = _player.get_node_or_null("CameraPivot/Camera3D")


func _ready() -> void:
	if flash != null:
		flash.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("fire"):
		fire()
	elif event.is_action_pressed("reload"):
		reload()


## Spends one bullet and shoots. Returns false on an empty magazine, where the
## trigger pull is simply ignored.
func fire() -> bool:
	if bullets <= 0:
		return false

	bullets -= 1
	ammo_changed.emit(bullets, magazines)
	_shoot()
	_show_flash()
	return true


## Swaps in a fresh magazine at the cost of one spare. Refused with no spares
## left, and when the loaded magazine is already full -- that would throw a
## whole magazine away for nothing.
func reload() -> bool:
	if magazines <= 0 or bullets >= MAGAZINE_SIZE:
		return false

	magazines -= 1
	bullets = MAGAZINE_SIZE
	ammo_changed.emit(bullets, magazines)
	return true


# The shot is traced from the player's camera rather than the muzzle so it
# lands where the crosshair is pointing, which is what the player aims with.
func _shoot() -> void:
	if _camera == null:
		return

	var from: Vector3 = _camera.global_position
	var to: Vector3 = from - _camera.global_transform.basis.z * SHOT_RANGE

	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = [_player.get_rid()]

	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		_spawn_impact(hit.position)


# A brief spark where the shot landed, so a hit is visible without any
# enemies in the level yet.
func _spawn_impact(at: Vector3) -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 0.05
	sphere.height = 0.1

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.4)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.75, 0.25)
	mat.emission_energy_multiplier = 4.0

	var spark := MeshInstance3D.new()
	spark.mesh = sphere
	spark.material_override = mat

	# Parent it to the level rather than the gun so it stays where it hit.
	_player.get_parent().add_child(spark)
	spark.global_position = at
	get_tree().create_timer(IMPACT_TIME).timeout.connect(spark.queue_free)


func _show_flash() -> void:
	if flash == null:
		return

	flash.visible = true
	get_tree().create_timer(FLASH_TIME).timeout.connect(_hide_flash)


func _hide_flash() -> void:
	if flash != null:
		flash.visible = false
