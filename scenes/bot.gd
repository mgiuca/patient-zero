extends RigidBody2D

class_name Bot

## The distance at which two bots will neither attract nor repel one another.
@export var resting_distance : float = 200

## Multiplier for the attraction force bots exert on one another.
@export var attraction_multiplier : float = 20

## Multiplier for the repulsion force bots exert on one another.
@export var repulsion_multiplier : float = 80

func _ready():
  pass

func _physics_process(delta: float):
  # Attract/repel every nearby bot.
  # The TensorCollider is an Area2D with a huge radius collider (as opposed to
  # the Bot's own collider, which is just the size of the bot). This is used to
  # interact with every nearby bot, to apply forces to it.
  # Note: I tried using a DampedSpringJoint2D but it just acted really weird,
  # and besides, we'd need to create one of them for every pair of bots.

  # Only apply the force on the other body (not to self); the inverse force
  # will be done by the other body on us.

  var collider : Area2D = $TensorCollider
  for other : Bot in collider.get_overlapping_bodies():
    if other != self:
      apply_tensor(other, delta)

## Applies an attraction or repulsion force on the other bot, based on
## proximity to this bot.
##
## Assumes the two bots are within the maximum tensor range (the radius of
## TensorCollider's collision circle).
##
## When bots are at the resting distance, no force is applied.
## When bots are further than the resting distance, an attraction force is
## applied; further away = greater force (like a rubber band).
## When bots are closer than the resting distance, a repulsion force is applied;
## closer = greater force (like a squashed material resisting).
func apply_tensor(other: Bot, delta: float):
  var displacement : Vector2 = position - other.position
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
  other.apply_central_force(force)

func _process(_delta: float):
  pass
