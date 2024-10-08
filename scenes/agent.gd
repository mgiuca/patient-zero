extends RigidBody2D

class_name Agent

enum AgentType {BOT, VIRUS, CELL, UNKNOWN = -1}

## What type of agent this is.
# TODO: There's probably a better way to essentially get which scene this
# object belongs to than having it stored as a separate enum. But I can't
# figure it out in a hurry.
@export var agent_type : AgentType = AgentType.UNKNOWN

@export_group("Movement")

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

## Maximum number of tensors to apply to each agent. 0 = no limit.
@export var max_tensors_applied : int = 0

## Maximum impulse to move in a random direction.
@export var random_movement : float = 0

@export_group("Combat")

## Strength multiplier for this agent type. Determines their relative strength
## in combat.
@export var strength_multiplier : float = 1

## Amount of time (s) in between being able to damage an enemy.
# TODO: I don't think we need this system, it just looks wrong when things
# bounce. Instead we have the new combat system. So I just set this to 0.
@export var attack_cooldown : float = 0

## Amount of time (s) after being spawned before being able to feed on cells.
@export var spawn_cooldown : float = 0

@export_group("Debug")

## Show the friend count on the agent.
@export var debug_show_friend_count : bool = false

# Earliest time this can attack in ms-since-startup (for cooldown).
var next_attack_time_ms : float

# Earliest time this can "feed" (attack cells) in ms-since-startup (for
# cooldown).
# Note: This only applies for virus-cell interaction. All other kills use
# next_attack_time_ms.
var next_feed_time_ms : float

## The number of nearby (tensor range) agents of the same type.
var num_friends : int

# Stored copy of the tensor collision mask. The real collision mask
# ($TensorCollider/collision_mask) is constantly being turned off and on
# to enable and disable tensors per-frame.
var tensor_collision_mask : int

# Time since last tensor update for this bot.
var tensor_delta : float

# Amount of time spent contiguously colliding with a wall, or -1 if not.
# (For deletion if it spends too long.)
var in_wall_time : float = -1

func _ready():
  assert(agent_type != AgentType.UNKNOWN, "Agent type not set")
  $LblDebugFriends.visible = debug_show_friend_count

  if has_node('TensorCollider'):
    tensor_collision_mask = $TensorCollider.collision_mask

  var spawn_cd = spawn_cooldown
  # Hack: In FARM_VIRUS, much longer cooldown.
  if get_parent().current_phase == Level.Phase.FARM_VIRUS:
    if agent_type == AgentType.VIRUS:
      spawn_cd = 45
  next_feed_time_ms = Time.get_ticks_msec() + (spawn_cd * 1000)

  # Hack: Set collision mask for bots based on phase.
  if agent_type == AgentType.BOT:
    set_collision_mask_based_on_phase(get_parent().current_phase)

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
  # Stuck-in-wall detection.
  var in_wall : bool = false
  for body in get_colliding_bodies():
    if body.name == 'Walls':
      in_wall = true
      if in_wall_time < 0:
        in_wall_time = 0
      else:
        in_wall_time += delta
        if in_wall_time > 1.0:
          # Inside wall for > 1 second, delete.
          queue_free()
  if not in_wall:
    in_wall_time = -1

  # Hide move tutorial prompt.
  if get_parent().showing_move_tutorial and agent_type == AgentType.BOT:
    if linear_velocity.length() > 1000:
      get_parent().finished_move_tutorial()

  # Limit to terminal velocity.
  var excess_speed = linear_velocity.length() - terminal_velocity
  if excess_speed > 0:
    apply_impulse(-linear_velocity.normalized() * excess_speed)

  num_friends = 0

  # Attract/repel every nearby bot.
  # The TensorCollider is an Area2D with a huge radius collider (as opposed to
  # the Bot's own collider, which is just the size of the bot). This is used to
  # interact with every nearby bot, to apply forces to it.
  # Note: I tried using a DampedSpringJoint2D but it just acted really weird,
  # and besides, we'd need to create one of them for every pair of bots.

  # Only apply the force on the other body (not to self); the inverse force
  # will be done by the other body on us.

  if has_node('TensorCollider'):
    var collider : Area2D = $TensorCollider
    var collision_mask_was_on : bool = collider.collision_mask != 0
    # Keep track of tensor delta.
    tensor_delta += delta

    # Dynamically enable or disable tensor collisions for the next tick,
    # by random probability based on the global percentage.
    # (It's too late to affect collision detection for this tick, which has
    # already been computed, so this will set up for the next tick.)
    if randf() <= get_parent().tensor_update_percent:
      collider.collision_mask = tensor_collision_mask
    else:
      collider.collision_mask = 0

    var num_tensors_applied = 0
    for other : Agent in collider.get_overlapping_bodies():
      if other != self:
        if tensor_applies(agent_type, other.agent_type):
          apply_tensor(other, tensor_delta)
        # Also count as a friend if the same type.
        if other.agent_type == agent_type:
          num_friends += 1
        # Also transitively extend the "active cluster".
        if is_in_group('active_cluster') and other.agent_type == AgentType.BOT:
          other.add_to_group('active_cluster')
        # Also transition from MOVE_TUTORIAL to ATTACK_TUTORIAL phase.
        if get_parent().current_phase == Level.Phase.MOVE_TUTORIAL:
          if agent_type == AgentType.BOT and other.agent_type == AgentType.VIRUS:
            get_parent().change_phase(Level.Phase.ATTACK_TUTORIAL)

      num_tensors_applied += 1
      if max_tensors_applied > 0 and num_tensors_applied >= max_tensors_applied:
        break

    if collision_mask_was_on:
      tensor_delta = 0

  # Apply random movement, in the form of instantaneous impulse on random ticks.
  if random_movement > 0:
    if randf() * delta < 0.01:
      var impulse = Vector2(randf_range(-random_movement, random_movement),
                            randf_range(-random_movement, random_movement))
      self.apply_impulse(impulse)

  $LblDebugFriends.text = str(strength())

# Only for bots.
func set_collision_mask_based_on_phase(phase: Level.Phase):
  # Set or clear bit 3 (i.e. bitvalue 8).
  if phase == Level.Phase.MOVE_TUTORIAL:
    tensor_collision_mask |= 8
  else:
    # Note: -9 is the bitwise inverse of 8.
    tensor_collision_mask &= -9

  # In CONSUME_ALL, we need bots to be able to collide with cells.
  # Set or clear bit 5 (i.e. bitvalue 32).
  if phase == Level.Phase.CONSUME_ALL:
    collision_mask |= 32
  else:
    # Note: -33 is the bitwise inverse of 32.
    collision_mask &= -33

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

  # Which timer to use? For virus-cell, use the "feed" time, which limits
  # when viruses can feed on cells.
  var relevant_next_time = next_attack_time_ms
  if agent_type == AgentType.VIRUS and body.agent_type == AgentType.CELL:
    relevant_next_time = next_feed_time_ms

  # Can't attack if we're still on cooldown (either from having recently
  # spawned, or recently attacked).
  if relevant_next_time > Time.get_ticks_msec():
    return

  next_attack_time_ms = Time.get_ticks_msec() + (attack_cooldown * 1000)
  next_feed_time_ms = Time.get_ticks_msec() + (attack_cooldown * 1000)

  # Can only attack if we are stronger than the opponent.
  if strength() < body.strength():
    return

  body.kill()
  if clone_self_when_killing(agent_type, body.agent_type):
    get_parent().call_deferred('spawn_agent', agent_type, body.position)

## Determines the combat "strength" of this agent.
## This is based on the number of friends nearby (within tensor range),
## multiplied by a per-type multiple, to let viruses be stronger than bots.
func strength() -> float:
  # Viruses have strength 0.1 except in phase DESTROY_VIRUS.
  # 0.1 allows them to kill cells, but not even one bot.
  if agent_type == AgentType.VIRUS:
    if get_parent().current_phase != Level.Phase.DESTROY_VIRUS:
      return 0.1

  return (num_friends + 1) * strength_multiplier

## Determines whether an agent of type |from| should respond via a tensor to
## a nearby agent of type |to|.
## Takes the game phase into account, where the rules can change.
func tensor_applies(from: AgentType, to: AgentType) -> bool:
  var phase = get_parent().current_phase
  if from == AgentType.BOT:
    return to == AgentType.BOT
  elif from == AgentType.VIRUS:
    if phase == Level.Phase.FARM_VIRUS:
      return to == AgentType.CELL
    elif phase == Level.Phase.DESTROY_VIRUS:
      return to == AgentType.VIRUS or to == AgentType.CELL

  return false

## Determines whether an agent of type |from| can hit an agent of type |to|.
## Takes the game phase into account, where the rules can change.
func can_hit(from: AgentType, to: AgentType) -> bool:
  var phase = get_parent().current_phase
  if from == AgentType.BOT:
    if phase == Level.Phase.CONSUME_ALL:
      return to == AgentType.CELL
    else:
      return to == AgentType.VIRUS
  elif from == AgentType.VIRUS:
    if phase == Level.Phase.FARM_VIRUS:
      return to == AgentType.CELL
    elif phase == Level.Phase.DESTROY_VIRUS:
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
  if get_parent().current_phase == Level.Phase.ATTACK_TUTORIAL:
    if agent_type == AgentType.VIRUS:
      get_parent().change_phase(Level.Phase.FARM_VIRUS)
  elif get_parent().current_phase == Level.Phase.DESTROY_VIRUS:
    if agent_type == AgentType.VIRUS:
      if get_tree().get_node_count_in_group('viruses') <= 1:  # pre kill
        get_parent().change_phase(Level.Phase.CONSUME_ALL)

  queue_free()
