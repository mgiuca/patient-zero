extends RigidBody2D

class_name Agent

## The maximum distance at which two bots can interact with each other (i.e.
## the distance at which the tensor "snaps").
@export var tensor_max_range : float = 0

## The distance at which two bots will neither attract nor repel one another.
@export var resting_distance : float = 200

## Multiplier for the attraction force bots exert on one another.
@export var attraction_multiplier : float = 20

## Multiplier for the repulsion force bots exert on one another.
@export var repulsion_multiplier : float = 80

## Maximum impulse to move in a random direction.
@export var random_movement : float = 0

## Amount of time (s) in between being able to damage an enemy.
@export var attack_cooldown : float = 0.5

# Time of the last attack in ms (for cooldown).
var last_attack_time_ms : float

func _ready():
  if tensor_max_range > 0:
    # This will crash if there is no TensorCollider. (Note: some agents have
    # no TensorCollider, but they also have tensor_max_range == 0.)
    $TensorCollider/CollisionShape2D.shape.radius = tensor_max_range

  # Animated sprites: start on a random frame.
  var sprite = $Sprite2D
  if sprite is AnimatedSprite2D:
    var num_frames = sprite.sprite_frames.get_frame_count(sprite.animation)
    sprite.frame = randi_range(0, num_frames - 1)

func _process(delta: float):
  # Attract/repel every nearby bot.
  # The TensorCollider is an Area2D with a huge radius collider (as opposed to
  # the Bot's own collider, which is just the size of the bot). This is used to
  # interact with every nearby bot, to apply forces to it.
  # Note: I tried using a DampedSpringJoint2D but it just acted really weird,
  # and besides, we'd need to create one of them for every pair of bots.

  # Only apply the force on the other body (not to self); the inverse force
  # will be done by the other body on us.

  var collider : Area2D = $TensorCollider
  if collider != null:
    for other : Agent in collider.get_overlapping_bodies():
      if other != self:
        apply_tensor(other, delta)

  # Apply random movement, in the form of instantaneous impulse on random ticks.
  if random_movement > 0:
    if randf() * delta < 0.01:
      var impulse = Vector2(randf_range(-random_movement, random_movement),
                            randf_range(-random_movement, random_movement))
      self.apply_impulse(impulse)

## Applies an attraction or repulsion force on this agent, based on the
## proximity of another agent.
##
## Assumes the two agents are within the maximum tensor range (the radius of
## TensorCollider's collision circle).
##
## Rule for bots (different for other types):
## When bots are at the resting distance, no force is applied.
## When bots are further than the resting distance, an attraction force is
## applied; further away = greater force (like a rubber band).
## When bots are closer than the resting distance, a repulsion force is applied;
## closer = greater force (like a squashed material resisting).
func apply_tensor(other: Agent, delta: float):
  var displacement : Vector2 = other.position - position
  var distance : float = displacement.length()
  var attraction : float  # Negative attraction = repulsion
  if distance > resting_distance:
    # Attraction
    attraction = (distance - resting_distance) * attraction_multiplier
  else:
    # Repulsion
    attraction = (distance - resting_distance) * repulsion_multiplier
    # TODO: Currently, this is exactly the same (if we are in the repulsion
    # range, attraction just goes negative). Might want to change this, making
    # it a reciprocal so it goes towards infinity as they get closer).
    #attraction = -resting_distance*resting_distance / (distance * distance) - 1
  var force : Vector2 = displacement.normalized() * attraction * delta
  apply_central_force(force)

func _on_body_entered(body: Node) -> void:
  # Damage the other body, if cooldown allows it.
  if body is not Agent:
    return

  if last_attack_time_ms + (attack_cooldown * 1000) < Time.get_ticks_msec():
    last_attack_time_ms = Time.get_ticks_msec()
    body.kill()

## Let self be killed (by an attack).
func kill():
  queue_free()
