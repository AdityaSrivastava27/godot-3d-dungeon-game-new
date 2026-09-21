class_name Enemy
extends CharacterBody3D

## Room guard. Walks a fixed patrol loop inside its own room, and charges the
## player when it catches sight of them.
##
## Sight is a cone plus a clear line: the player has to be within range, inside
## the cone the guard is facing, and not behind a wall. Losing sight does not
## stop the chase instantly -- the guard keeps going for MEMORY_TIME, so
## stepping behind a pillar for a moment does not switch it straight back to
## patrolling.
##
## `speed` is the 1x patrol speed; the chase runs at CHASE_MULTIPLIER times it.
## Both stay under the player's own speed, so the player can still break away.

## Patrol loop in world space, walked in order and then repeated. Only x and z
## are used -- the guard is held on the floor by gravity.
@export var patrol_points: PackedVector3Array = PackedVector3Array()

@export var speed: float = 2.5          # the 1x patrol speed
@export var sight_range: float = 14.0
@export var sight_angle: float = 60.0   # half-angle of the vision cone, degrees

## Damage a hit takes off the player, as a percentage of full health.
@export var ranged_damage: int = 20
@export var melee_damage: int = 50

## The blade only lands when the two bodies are actually touching. Capsules of
## radius 0.4 cannot get closer than 0.8 m centre to centre, so this is contact
## plus a little tolerance rather than a swing through thin air.
@export var contact_reach: float = 0.9

const CHASE_MULTIPLIER := 1.5
const TURN_SPEED := 8.0
const WAYPOINT_RADIUS := 0.6   # close enough to count as having arrived
const EYE_HEIGHT := 0.6        # above the body's centre
const MEMORY_TIME := 1.5       # seconds of pursuit after the player breaks sight
const SHOT_INTERVAL := 1.5     # seconds between shots
const MELEE_INTERVAL := 1.2    # seconds between swings
const FLASH_TIME := 0.05       # how long the muzzle light stays lit

var chasing: bool = false      # read by the tests and anything watching the guard

var _waypoint: int = 0
var _memory: float = 0.0
var _sees_player: bool = false
var _shot_timer: float = 0.0
var _melee_timer: float = 0.0

@onready var _player: CharacterBody3D = get_tree().get_first_node_in_group("player")
@onready var _muzzle: Marker3D = $Gun/Muzzle
@onready var _flash: OmniLight3D = $Gun/Muzzle/Flash


func _ready() -> void:
	if _flash != null:
		_flash.visible = false


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	chasing = _update_awareness(delta)
	_fight(delta)

	var target := _player.global_position if chasing else _current_waypoint()
	var to_target := target - global_position
	to_target.y = 0.0

	# Only patrolling advances the loop; a chase heads straight for the player.
	if not chasing and to_target.length() < WAYPOINT_RADIUS:
		_waypoint += 1
		to_target = _current_waypoint() - global_position
		to_target.y = 0.0

	var pace := speed * (CHASE_MULTIPLIER if chasing else 1.0)

	if to_target.length() > 0.001:
		var dir := to_target.normalized()
		velocity.x = dir.x * pace
		velocity.z = dir.z * pace
		# Face the way it is going, so the vision cone points down its own path.
		rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), TURN_SPEED * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, pace)
		velocity.z = move_toward(velocity.z, 0.0, pace)

	move_and_slide()


## True while the guard is pursuing: either it can see the player right now, or
## it lost them less than MEMORY_TIME ago.
func _update_awareness(delta: float) -> bool:
	if _player == null:
		return false

	_sees_player = can_see_player()
	if _sees_player:
		_memory = MEMORY_TIME
		return true

	_memory = maxf(_memory - delta, 0.0)
	return _memory > 0.0


## In range, inside the vision cone, and nothing solid in between.
func can_see_player() -> bool:
	if _player == null:
		return false

	var eye := global_position + Vector3(0, EYE_HEIGHT, 0)
	var to_player := _player.global_position - eye

	var flat := Vector2(to_player.x, to_player.z)
	if flat.length() > sight_range or flat.length() < 0.001:
		return false

	var forward := global_transform.basis.z
	var facing := Vector2(forward.x, forward.z)
	if facing.length() < 0.001:
		return false

	if absf(rad_to_deg(facing.angle_to(flat))) > sight_angle:
		return false

	# Mask 1 is the world and the player; other guards are on their own layer
	# and so never block the view.
	var query := PhysicsRayQueryParameters3D.create(eye, _player.global_position)
	query.collision_mask = 1
	query.collide_with_areas = false
	query.exclude = [get_rid()]

	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.collider == _player


# Falls back to standing still if the scene forgot to give this guard a route.
func _current_waypoint() -> Vector3:
	if patrol_points.is_empty():
		return global_position

	_waypoint = _waypoint % patrol_points.size()
	var p := patrol_points[_waypoint]
	return Vector3(p.x, global_position.y, p.z)


## Swing when the guard is actually touching the player, otherwise shoot at
## them. Both weapons are on their own cooldown, and neither is used while the
## guard has not found the player.
func _fight(delta: float) -> void:
	_shot_timer = maxf(_shot_timer - delta, 0.0)
	_melee_timer = maxf(_melee_timer - delta, 0.0)

	if _player == null or not chasing:
		return

	if touching_player():
		if _melee_timer <= 0.0:
			_melee_timer = MELEE_INTERVAL
			_player.take_damage(melee_damage, Player.DamageSource.MELEE)
	elif _sees_player and _shot_timer <= 0.0:
		_shot_timer = SHOT_INTERVAL
		_fire_at_player()


# A shot only lands if the muzzle has a clear line of its own; the guard can
# be pursuing from memory with a wall in the way, and those shots should miss.
func _fire_at_player() -> void:
	_show_flash()

	var from: Vector3 = _muzzle.global_position if _muzzle != null else global_position
	var query := PhysicsRayQueryParameters3D.create(from, _player.global_position)
	query.collision_mask = 1
	query.collide_with_areas = false
	query.exclude = [get_rid()]

	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.collider == _player:
		_player.take_damage(ranged_damage, Player.DamageSource.RANGED)


func _show_flash() -> void:
	if _flash == null:
		return

	_flash.visible = true
	get_tree().create_timer(FLASH_TIME).timeout.connect(_hide_flash)


func _hide_flash() -> void:
	if _flash != null:
		_flash.visible = false


## True when the guard and the player are in contact.
##
## A guard that walked into the player reports the touch from its own last
## move, which is a frame old and close enough at these speeds. The player walking into a guard that is
## standing still shows up on the player's own move instead, not here, so fall
## back to the gap between them -- at contact_reach the capsules are already
## pressed together.
func touching_player() -> bool:
	if _player == null:
		return false

	for i in get_slide_collision_count():
		if get_slide_collision(i).get_collider() == _player:
			return true

	var gap := Vector2(_player.global_position.x - global_position.x,
		_player.global_position.z - global_position.z).length()
	return gap <= contact_reach
