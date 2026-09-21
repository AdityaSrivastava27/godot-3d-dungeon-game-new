extends Control

## Circular minimap, drawn from the level's own geometry rather than from a
## second camera looking down. A camera would need the ceilings hidden and
## could not show a guard's line of sight at all; drawing it means every kind
## of thing on the map can be told apart by shape and colour.
##
## The map turns with the player: the player sits at the centre facing up the
## screen at all times, and the dungeon rotates underneath. Everything is
## therefore drawn in the player's frame -- straight ahead is up.
##
## The level is read once at startup by walking the scene and sorting the CSG
## boxes by name, so rooms added later appear without touching this file.
## Doors are re-read every frame, since they swing.

@export var metres_shown: float = 22.0   # radius, in metres of dungeon
@export var show_enemy_sight: bool = true

const CIRCLE_SEGMENTS := 48
const DOOR_MIN_THICKNESS := 0.45   # a door leaf is 0.18 m thick, too thin to see

const BACKDROP := Color(0.05, 0.06, 0.08, 0.86)
const FLOOR_COLOUR := Color(0.21, 0.23, 0.27)
const PROP_COLOUR := Color(0.36, 0.32, 0.25)
const WALL_COLOUR := Color(0.56, 0.58, 0.64)
const DOOR_COLOUR := Color(1.0, 0.72, 0.2)
const ENEMY_COLOUR := Color(0.92, 0.16, 0.13)
const SIGHT_COLOUR := Color(0.92, 0.2, 0.15, 0.16)
const SIGHT_ALERT := Color(1.0, 0.35, 0.1, 0.32)
const PLAYER_COLOUR := Color(0.42, 0.92, 0.5)
const RIM_COLOUR := Color(0.85, 0.87, 0.92, 0.9)

var _player: Player = null

# World-space footprints, gathered once. Doors are not in here: they move.
var _floors: Array[PackedVector2Array] = []
var _props: Array[PackedVector2Array] = []
var _walls: Array[PackedVector2Array] = []
var _doors: Array[CSGBox3D] = []

var _clip := PackedVector2Array()
var _centre := Vector2.ZERO
var _radius := 0.0
var _scale := 1.0

# The player's position and facing for the frame being drawn.
var _origin := Vector2.ZERO
var _sin := 0.0
var _cos := 1.0


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player") as Player
	var level := get_tree().current_scene
	if _player != null:
		level = _player.get_parent()
	if level != null:
		_collect(level)
	_measure()
	resized.connect(_measure)


func _process(_delta: float) -> void:
	queue_redraw()


func _measure() -> void:
	_centre = size * 0.5
	_radius = maxf(minf(size.x, size.y) * 0.5 - 2.0, 1.0)
	_scale = _radius / maxf(metres_shown, 0.001)

	_clip = PackedVector2Array()
	for i in CIRCLE_SEGMENTS:
		var a := TAU * float(i) / float(CIRCLE_SEGMENTS)
		_clip.append(_centre + Vector2(cos(a), sin(a)) * _radius)


# Sorts the level's boxes into what they are by name. Ceilings are skipped --
# from above they would cover everything else.
func _collect(node: Node) -> void:
	for child in node.get_children():
		if child is CSGBox3D:
			var name := String(child.name)
			if name.begins_with("Ceil"):
				pass
			elif name == "Leaf":
				_doors.append(child)
			elif name.begins_with("Floor") or name.begins_with("Pad"):
				_floors.append(_footprint(child))
			elif name.begins_with("Wall"):
				_walls.append(_footprint(child))
			else:
				_props.append(_footprint(child))
		_collect(child)


## The box's four corners on the floor plane, in world x/z.
func _footprint(box: CSGBox3D, min_thickness: float = 0.0) -> PackedVector2Array:
	var half_x: float = maxf(box.size.x, min_thickness) * 0.5
	var half_z: float = maxf(box.size.z, min_thickness) * 0.5
	var t := box.global_transform

	var out := PackedVector2Array()
	for corner in [Vector3(-half_x, 0, -half_z), Vector3(half_x, 0, -half_z),
			Vector3(half_x, 0, half_z), Vector3(-half_x, 0, half_z)]:
		var p: Vector3 = t * corner
		out.append(Vector2(p.x, p.z))
	return out


## World x/z to a point on the map, in the player's frame: their facing is up.
##
## The player faces +Z, not Godot's usual -Z: their yaw is taken from the
## camera's basis.z as they move (see Player._physics_process), so forward is
## (sin, cos). Facing that way puts their right hand towards -x, which is why
## the sideways axis is (-cos, sin) rather than the (cos, -sin) a -Z facing
## would give -- with the latter the map came out mirrored left to right.
func _to_map(world: Vector2) -> Vector2:
	var rel := world - _origin
	var ahead := rel.x * _sin + rel.y * _cos
	var beside := rel.y * _sin - rel.x * _cos
	return _centre + Vector2(beside, -ahead) * _scale


func _draw() -> void:
	draw_circle(_centre, _radius, BACKDROP)

	if _player == null or not is_instance_valid(_player):
		draw_arc(_centre, _radius, 0.0, TAU, CIRCLE_SEGMENTS, RIM_COLOUR, 2.0)
		return

	_origin = Vector2(_player.global_position.x, _player.global_position.z)
	_sin = sin(_player.rotation.y)
	_cos = cos(_player.rotation.y)

	for poly in _floors:
		_blot(poly, FLOOR_COLOUR)
	for poly in _props:
		_blot(poly, PROP_COLOUR)
	for poly in _walls:
		_blot(poly, WALL_COLOUR)

	# Doors swing, so their footprint is taken fresh each frame. They are also
	# widened: a leaf is under 0.2 m thick and would vanish at this scale.
	for leaf in _doors:
		if is_instance_valid(leaf):
			_blot(_footprint(leaf, DOOR_MIN_THICKNESS), DOOR_COLOUR)

	for guard in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(guard):
			continue
		if show_enemy_sight:
			_blot(_sight_cone(guard), SIGHT_ALERT if guard.chasing else SIGHT_COLOUR)
		_dot(Vector2(guard.global_position.x, guard.global_position.z), ENEMY_COLOUR)

	_draw_player()
	draw_arc(_centre, _radius, 0.0, TAU, CIRCLE_SEGMENTS, RIM_COLOUR, 2.0)


## The wedge a guard can see: its cone of vision out to its sight range.
func _sight_cone(guard: Node3D) -> PackedVector2Array:
	var here := Vector2(guard.global_position.x, guard.global_position.z)
	var facing: float = guard.rotation.y
	var half := deg_to_rad(guard.sight_angle)
	var reach: float = guard.sight_range

	var out := PackedVector2Array([here])
	var steps := 12
	for i in steps + 1:
		var a: float = facing - half + (2.0 * half) * float(i) / float(steps)
		out.append(here + Vector2(sin(a), cos(a)) * reach)
	return out


# The player is always at the centre, always pointing up.
func _draw_player() -> void:
	var nose := _centre + Vector2(0, -8)
	var left := _centre + Vector2(-5.5, 5)
	var right := _centre + Vector2(5.5, 5)
	draw_colored_polygon(PackedVector2Array([nose, right, left]), PLAYER_COLOUR)


func _dot(world: Vector2, colour: Color) -> void:
	var at := _to_map(world)
	if at.distance_to(_centre) > _radius:
		return
	draw_circle(at, 4.0, colour)


# Draws a world-space footprint, trimmed to the circle so nothing spills out
# of the map into the rest of the screen.
func _blot(world_points: PackedVector2Array, colour: Color) -> void:
	if world_points.size() < 3:
		return

	var mapped := PackedVector2Array()
	var nearest := INF
	var furthest := 0.0
	for p in world_points:
		var m := _to_map(p)
		mapped.append(m)
		var d := m.distance_to(_centre)
		nearest = minf(nearest, d)
		furthest = maxf(furthest, d)

	if furthest <= _radius:
		draw_colored_polygon(mapped, colour)
		return

	# A shape whose every corner is outside can still cross the circle, so
	# only skip it when it is clear of the map altogether.
	if nearest > _radius + _shape_span(mapped):
		return

	for piece in Geometry2D.intersect_polygons(mapped, _clip):
		if piece.size() >= 3:
			draw_colored_polygon(piece, colour)


func _shape_span(points: PackedVector2Array) -> float:
	var span := 0.0
	for i in points.size():
		span = maxf(span, points[i].distance_to(points[(i + 1) % points.size()]))
	return span
