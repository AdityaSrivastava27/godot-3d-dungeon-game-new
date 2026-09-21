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

## Damage one bullet does to a guard, as a percentage of its health.
const BULLET_DAMAGE := 50

const SHOT_RANGE := 100.0
const FLASH_TIME := 0.05    # how long the muzzle light stays lit

# The first magazine is loaded at start, so the reserve starts one short.
var bullets: int = MAGAZINE_SIZE
var magazines: int = STARTING_MAGAZINES - 1

@onready var flash: OmniLight3D = $Muzzle/Flash
@onready var _muzzle: Marker3D = $Muzzle
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


# Bullets leave the muzzle, but they are aimed at whatever the crosshair is
# over, not straight down the barrel. The gun sits off to one side of the
# player, so firing along the barrel would land beside the crosshair at close
# range; aiming at the point the crosshair marks keeps the two together.
func _shoot() -> void:
	if _camera == null:
		return

	var muzzle: Vector3 = _muzzle.global_position if _muzzle != null else global_position
	var bullet := Bullet.make()
	bullet.damage = BULLET_DAMAGE
	bullet.shooter = _player
	bullet.direction = (_aim_point() - muzzle).normalized()

	# Parent it to the level so it keeps flying while the player moves on.
	_player.get_parent().add_child(bullet)
	bullet.global_position = muzzle


# Where the crosshair is pointing: the first thing the camera's forward ray
# meets, or a point far down that ray when it meets nothing.
func _aim_point() -> Vector3:
	var from: Vector3 = _camera.global_position
	var to: Vector3 = from - _camera.global_transform.basis.z * SHOT_RANGE

	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 3   # the level on layer 1, the guards on layer 2
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = [_player.get_rid()]

	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.position if not hit.is_empty() else to


func _show_flash() -> void:
	if flash == null:
		return

	flash.visible = true
	get_tree().create_timer(FLASH_TIME).timeout.connect(_hide_flash)


func _hide_flash() -> void:
	if flash != null:
		flash.visible = false
