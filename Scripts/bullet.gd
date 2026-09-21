class_name Bullet
extends Node3D

## A bullet in flight.
##
## It sweeps a ray along the ground it covers each frame rather than testing
## only where it lands, so it cannot skip through a guard or a wall between
## one frame and the next however fast it travels. Whatever it hits first
## stops it: anything with take_damage() takes `damage`, everything else just
## absorbs it.

const SPEED := 60.0
const LIFETIME := 2.0     # seconds before a bullet that hit nothing gives up
const IMPACT_TIME := 0.15 # how long the spark at the point of impact lives

var damage: int = 0
var direction: Vector3 = Vector3.FORWARD

## The body that fired, so a bullet cannot hit whoever pulled the trigger.
var shooter: Node3D = null

var _life: float = LIFETIME


func _physics_process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return

	var from: Vector3 = global_position
	var to: Vector3 = from + direction * SPEED * delta

	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 3   # the level on layer 1, the guards on layer 2
	query.collide_with_areas = false
	query.collide_with_bodies = true
	# A ray normally ignores a shape it starts inside, and a bullet can easily
	# end a frame inside a guard that is running towards it -- the next sweep
	# would then begin in there, report nothing, and the bullet would sail out
	# the far side. Counting that as a hit at the muzzle end is what stops
	# shots passing through anyone who is closing on the player.
	query.hit_from_inside = true
	if shooter != null:
		query.exclude = [shooter.get_rid()]

	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		global_position = to
		return

	var struck: Object = hit.collider
	if struck != null and struck.has_method("take_damage"):
		struck.take_damage(damage)

	_spawn_impact(hit.position)
	queue_free()


# A brief spark where the bullet landed, so every shot reads as having gone
# somewhere.
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

	# Parent it to the level, not to this bullet, which is about to be freed.
	get_parent().add_child(spark)
	spark.global_position = at
	get_tree().create_timer(IMPACT_TIME).timeout.connect(spark.queue_free)


## Builds the little glowing body a bullet is drawn as.
static func make() -> Bullet:
	var sphere := SphereMesh.new()
	sphere.radius = 0.045
	sphere.height = 0.09
	sphere.radial_segments = 8
	sphere.rings = 4

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.92, 0.6)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.8, 0.35)
	mat.emission_energy_multiplier = 5.0

	var mesh := MeshInstance3D.new()
	mesh.mesh = sphere
	mesh.material_override = mat

	var bullet := Bullet.new()
	bullet.add_child(mesh)
	return bullet
