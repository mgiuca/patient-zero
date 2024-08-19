extends RigidBody2D

class_name Agent

enum AgentType {BOT, VIRUS, CELL, UNKNOWN = -1}

## What type of agent this is.
# TODO: There's probably a better way to essentially get which scene this
# object belongs to than having it stored as a separate enum. But I can't
# figure it out in a hurry.
@export var agent_type : AgentType = AgentType.UNKNOWN

## The maximum speed at which the agent can move. If it moves faster than this,
## it will be artificially slowed down.
@export var terminal_velocity : float = 4000

## The maximum distance at which two bots can interact with each other (i.e.
## the distance at which the tensor "snaps").
@export var tensor_max_range : float = 0

## The distance at which two bots will neither attract nor repel one another.
@export var resting_distance : float = 0

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
  assert(agent_type != AgentType.UNKNOWN, "Agent type not set")

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
  # Limit to terminal velocity.
  var excess_speed = linear_velocity.length() - terminal_velocity
  if excess_speed > 0:
    apply_impulse(-linear_velocity.normalized() * excess_speed)

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
  # Note: This applies to bots and viruses, not cells which have no tensor.
  # Originally this concept (called a "tensor" because it acts like a rubber
  # band) was meant to be how bots pull and push one another like fluid.
  # It's also used for making viruses chase cells (they are only attracted,
  # not repelled, due to having a 0 resting distance). This is a bit of a hack
  # - it's weird behaviour for essentially a "chase" directive to accelerate
  # more when you're further away. But it kind of looks cool as long as the
  # tensor max radius is small enough (if it's too large, viruses will slingshot
  # themselves towards cells).

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
  # Damage the other body, if cooldown and agent type allows it.
  if body is not Agent:
    return

  # WTF: body_entered seems to be emitted bidirectionally, even when the
  # collision property is uni-directional. For example, if I have an object
  # in layer 4 with a collision mask on 6, and the other object is on layer 6
  # with NO collision mask on 4, it will still fire the event in both
  # directions. I don't really understand why, and it's not helpful. But for
  # now, we just explicitly control for this by checking the agent type (using
  # can_hit).
  #
  # This also helps us change the collision logic across phases.
  if not can_hit(agent_type, body.agent_type):
    return

  if last_attack_time_ms + (attack_cooldown * 1000) < Time.get_ticks_msec():
    last_attack_time_ms = Time.get_ticks_msec()
    body.kill()
    if clone_self_when_killing(agent_type, body.agent_type):
      get_parent().spawn_agent(agent_type, body.position)

## Determines whether an agent of type |from| can hit an agent of type |to|.
## Takes the game phase into account, where the rules can change.
func can_hit(from: AgentType, to: AgentType) -> bool:
  # TODO: Take phase into account.
  if from == AgentType.BOT:
    return to == AgentType.VIRUS
  elif from == AgentType.VIRUS:
    return to == AgentType.BOT or to == AgentType.CELL

  return false

## Determines whether an agent of type |from| will spawn a clone of itself
## after killing an agent of type |to|. (It's presumed can_hit returned true.)
func clone_self_when_killing(from: AgentType, to: AgentType) -> bool:
  if from == AgentType.BOT:
    return true
  elif from == AgentType.VIRUS:
    return to == AgentType.CELL

  return false

## Let self be killed (by an attack).
func kill():
  queue_free()
