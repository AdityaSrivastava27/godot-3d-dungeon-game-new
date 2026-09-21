extends Node3D

## Simple auto-swinging door. The leaf is a child of this hinge node; the hinge
## is placed at the door's edge so rotating it about Y swings the leaf open.
## Opens when the player gets within open_distance and closes again when they
## leave. Set open_angle negative in the scene to swing the other way.

@export var open_angle: float = 95.0
@export var open_distance: float = 3.5
@export var speed: float = 5.0

var _closed_y: float = 0.0
var _player: Node3D = null


func _ready() -> void:
	_closed_y = rotation.y
	_player = get_tree().get_first_node_in_group("player")


func _process(delta: float) -> void:
	var want_open := false
	if _player != null:
		if global_position.distance_to(_player.global_position) < open_distance:
			want_open = true

	var target := _closed_y + deg_to_rad(open_angle) if want_open else _closed_y
	rotation.y = lerp_angle(rotation.y, target, speed * delta)
