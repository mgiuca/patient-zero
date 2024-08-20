# Scene script shared by all levels.

extends Node

@export_group('Gameplay')

## Number of bots to spawn at startup.
@export var initial_bots : int

## Number of viruses to spawn at startup.
@export var initial_viruses : int

## Number of blood cells to spawn at startup, and maximum number to keep alive.
@export var max_cells : int = 100

@export_group('Audio')

## Seek to this time (s) when starting the music.
@export var music_start_time : float

@export_group('Scenes')

## The scene to instantiate a bot.
@export var bot_scene : PackedScene

## The scene to instantiate a virus.
@export var virus_scene : PackedScene

## The scene to instantiate a blood cell.
@export var cell_scene : PackedScene

@export_group('Debug')

## Show debugging info on screen.
@export var debug_info : bool

# Camera-related

# Add this much around the edge of the bots when framing the camera.
var zoom_margin : float = 500

# Minimum (logarithm of) user-controlled zoom.
var min_zoom_log : float = -4

# Current zoom level. Can be pushed out by bots moving far away. Slowly creeps
# back in.
# Stored as a natural log of the actual zoom, so we can apply linear + and - to
# it.
var current_zoom_log : float = 1

# This gets set when the mouse is pushed, and it means the next time a bot is
# affected by the push force, it clears out the active cluster group.
var reset_active_cluster : bool

# Locations where things can spawn. Left arm is special as it's the
# "injection site" where the player enters the body.
enum BodyLocation {ANYWHERE, LEFT_ARM, NOT_LEFT_ARM}

func _ready():
  $Music.seek(music_start_time)
  $HUD.debug_visible = debug_info

  # Spawn a bunch of bots.
  for i in initial_bots:
    var pos = pick_random_location(BodyLocation.LEFT_ARM)
    spawn_agent(Agent.AgentType.BOT, pos)

  # Spawn a bunch of viruses.
  for i in initial_viruses:
    var pos = pick_random_location(BodyLocation.NOT_LEFT_ARM)
    spawn_agent(Agent.AgentType.VIRUS, pos)

  # Spawn a bunch of cells.
  for i in max_cells:
    var pos = pick_random_location(BodyLocation.ANYWHERE)
    spawn_agent(Agent.AgentType.CELL, pos)

  change_phase(0)

## Picks a random valid location somewhere in the level.
func pick_random_location(location: BodyLocation) -> Vector2:
  var shapes = $SpawnAreas.get_children()
  var shape = shapes.pick_random() as CollisionShape2D

  if location == BodyLocation.LEFT_ARM:
    shape = $SpawnAreas/RectShapeLeftArm as CollisionShape2D
  elif location == BodyLocation.NOT_LEFT_ARM:
    # Keep picking until you spawn somewhere other than left arm.
    while shape == $SpawnAreas/RectShapeLeftArm:
      shape = shapes.pick_random() as CollisionShape2D

  # WTF: This is misleading: RectangleShape2D doesn't actually have a rect,
  # just a size. (If you call get_rect it will just return the size, centered.)
  var size = (shape.shape as RectangleShape2D).size
  var pos = shape.position - size / 2
  var rect = Rect2(pos, size)
  return \
    Vector2(randf_range(rect.position.x, rect.position.x + rect.size.x),
            randf_range(rect.position.y, rect.position.y + rect.size.y))

func spawn_agent(agent_type: Agent.AgentType, position: Vector2) -> Agent:
  # Decide what type of scene to instantiate.
  var scene: PackedScene
  if agent_type == Agent.AgentType.BOT:
    scene = bot_scene
  elif agent_type == Agent.AgentType.VIRUS:
    scene = virus_scene
  elif agent_type == Agent.AgentType.CELL:
    scene = cell_scene

  # Spawn the agent.
  var agent : Agent = scene.instantiate()
  agent.rotation = randf_range(0, TAU)
  agent.position = position

  # Add to parent and necessary groups.
  add_child(agent)
  if agent_type == Agent.AgentType.BOT:
    agent.add_to_group('bots')
  if agent_type == Agent.AgentType.VIRUS:
    agent.add_to_group('viruses')
  if agent_type == Agent.AgentType.CELL:
    agent.add_to_group('cells')

  return agent

func _input(event : InputEvent):
  # Handle zooming.
  if event.is_action('zoom_in'):
    current_zoom_log += 0.1
  elif event.is_action('zoom_out'):
    current_zoom_log -= 0.1
  elif event.is_action_pressed('push'):
    reset_active_cluster = true

  if current_zoom_log < min_zoom_log:
    current_zoom_log = min_zoom_log

func _process(delta: float):
  # Gets the mouse position in global coordinates, based on the location
  # of the camera.
  var mouse_pos = $Camera.get_global_mouse_position()
  $Cursor.position = mouse_pos

  update_camera(delta)
  update_hud()

## Update the camera to capture a view of all the bots.
func update_camera(delta: float):
  # Note that the camera position will auto-smooth, but zoom will not.

  # Only focus the active cluster, not all bots (unless it's empty).
  # All bots can result in a massive zoom-out where you can't see anything,
  # because the bots spread out so far.
  var bots = get_tree().get_nodes_in_group('active_cluster')
  if bots.is_empty():
    bots = get_tree().get_nodes_in_group('bots')
    if bots.is_empty():
      # No bots; we can't update the camera so leave as-is.
      return

  # First, make a rect encompassing all the bots' centre points.
  var min_x = bots[0].position.x
  var max_x = min_x
  var min_y = bots[0].position.y
  var max_y = min_y
  for b in bots:
    if b.position.x < min_x:
      min_x = b.position.x
    if b.position.x > max_x:
      max_x = b.position.x
    if b.position.y < min_y:
      min_y = b.position.y
    if b.position.y > max_y:
      max_y = b.position.y
  var target_rect = Rect2(min_x, min_y, max_x - min_x, max_y - min_y)
  target_rect = target_rect.grow(zoom_margin)

  # Now focus the camera on that rect.
  $Camera.position = target_rect.get_center()
  var x_zoom = get_viewport().get_visible_rect().size.x / target_rect.size.x
  var y_zoom = get_viewport().get_visible_rect().size.y / target_rect.size.y
  # These give the zoom required to satisfy each axis. Set the camera zoom to
  # whichever will be the most zoomed out of these two.
  var zoom = min(x_zoom, y_zoom)
  var current_zoom = exp(current_zoom_log)
  if zoom > current_zoom:
    current_zoom_log += 0.01 * delta
  if zoom < current_zoom:
    current_zoom_log = log(zoom)
  current_zoom = exp(current_zoom_log)
  $Camera.zoom = Vector2(current_zoom, current_zoom)

func update_hud():
  var hud = $HUD
  hud.num_bots = get_tree().get_node_count_in_group('bots')
  hud.num_viruses = get_tree().get_node_count_in_group('viruses')
  hud.patient_health = calc_patient_health()
  if debug_info:
    hud.append_num_cells(get_tree().get_node_count_in_group('cells'))
    hud.set_debug_info(current_zoom_log,
                       get_tree().get_node_count_in_group("active_cluster"))

## Calculates the patient health as a percentage (0 to 1).
func calc_patient_health() -> float:
  # Actually just return the number of cells, as a percentage of max.
  var num_cells = get_tree().get_node_count_in_group('cells')
  return min(float(num_cells) / float(max_cells), 1.0)

## Change to one of the different phases of the game.
## Each phase has different UI and gameplay behaviour.
func change_phase(phase: int) -> void:
  # TODO
  $HUD.directive_text = 'Destroy all virus cells.'

func _on_cell_spawn_timer_timeout() -> void:
  var num_cells = get_tree().get_node_count_in_group('cells')

  # If <= 5, patient is basically dead; let the game play out (otherwise it
  # will go on indefinitely). If max_cells, no need to spawn more.
  if num_cells <= 5 or num_cells >= max_cells:
    return

  var pos = pick_random_location(BodyLocation.ANYWHERE)
  var rot = randf_range(0, TAU)
  spawn_agent(Agent.AgentType.CELL, pos)

func _on_cursor_body_entered(body: Node2D) -> void:
  # Technically Cursor should *only* collide with Agent of type BOT, but
  # we don't need to assert this.
  if $Cursor.active and body is Agent and \
      body.agent_type == Agent.AgentType.BOT:
    if reset_active_cluster:
      get_tree().call_group('active_cluster', 'remove_from_group',
                            'active_cluster')
      reset_active_cluster = false

    body.add_to_group('active_cluster')
