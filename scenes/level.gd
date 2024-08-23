# Scene script shared by all levels.

extends Node

class_name Level

enum Phase {
  MOVE_TUTORIAL,
  ATTACK_TUTORIAL,
  FARM_VIRUS,
  DESTROY_VIRUS,
  CONSUME_ALL
}

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

## Normal heart rate (period, in s) when at full health.
@export var normal_heartrate : float = 1

## Maximum heart rate (period, in s) when close to death.
## (Note, this should be SMALLER than normal heart rate.)
@export var max_heartrate : float = 0.1

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

## Phase to start in (for debugging).
@export var debug_start_phase : Phase = Phase.MOVE_TUTORIAL

var current_phase : Phase

var special_directive_id = 0

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

var showing_move_tutorial : bool = false
var showing_zoom_tutorial : bool = false
var done_zoom_tutorial : bool = false

# Locations where things can spawn. Left arm is special as it's the
# "injection site" where the player enters the body.
enum BodyLocation {ANYWHERE, LEFT_ARM, NOT_LEFT_ARM}

func _ready():
  $Music.seek(music_start_time)
  $HUD.debug_visible = debug_info

  # Change initial conditions based on debug start phase. Should not have
  # any effect in the default phase.
  if debug_start_phase == Phase.FARM_VIRUS:
    initial_bots = 2
  elif debug_start_phase >= Phase.FARM_VIRUS:
    initial_bots = 10
  if debug_start_phase == Phase.CONSUME_ALL:
    initial_viruses = 0

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

  change_phase(debug_start_phase)

  $BeepTimer.wait_time = calc_heartrate()
  $BeepTimer.start()

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
    if current_phase == Phase.FARM_VIRUS:
      if get_tree().get_node_count_in_group('bots') >= 20:
        change_phase(Phase.DESTROY_VIRUS)
  if agent_type == Agent.AgentType.VIRUS:
    agent.add_to_group('viruses')
  if agent_type == Agent.AgentType.CELL:
    agent.add_to_group('cells')

  return agent

func _input(event : InputEvent):
  # Handle zooming.
  if event.is_action('restart'):
    get_tree().reload_current_scene()
  if event.is_action('zoom_in'):
    current_zoom_log += 0.1
  elif event.is_action('zoom_out'):
    current_zoom_log -= 0.1
    # Tutorial
    if current_zoom_log < -2:
      done_zoom_tutorial = true
      if showing_zoom_tutorial:
        finished_zoom_tutorial()
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
  check_gameover()

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
  if debug_info:
    hud.set_patient_health_and_cells(
      calc_patient_health(), get_tree().get_node_count_in_group('cells'))
    hud.set_debug_info(current_zoom_log,
                       get_tree().get_node_count_in_group("active_cluster"))
  else:
    hud.patient_health = calc_patient_health()

func check_gameover():
  var hud = $HUD
  if get_tree().get_node_count_in_group('bots') == 0:
    # Game over: no more bots
    hud.show_gameover('ALL BOTS LOST')
  elif get_tree().get_node_count_in_group('cells') == 0:
    # Game over (win or lose): no more cells
    if current_phase == Phase.CONSUME_ALL:
      # Win (?)
      hud.show_gameover('THE PATIENT IS DECEASED\nALL RESOURCES CONSUMED\nEXIT PATIENT - THE SWARM MUST GROW')
    else:
      # Lose
      hud.show_gameover('THE PATIENT IS DECEASED')

## Calculates the patient health as a percentage (0 to 1).
func calc_patient_health() -> float:
  # Actually just return the number of cells, as a percentage of max.
  var num_cells = get_tree().get_node_count_in_group('cells')
  return min(float(num_cells) / float(max_cells), 1.0)

## Calculates the patient's heartrate (based on patient health).
## Returns it as a *period* in seconds (not frequency). This gives the amount
## of time to wait for the next beep. Returns 0 for flatline.
func calc_heartrate() -> float:
  var rate = calc_patient_health() * normal_heartrate
  if rate > 0 and rate < max_heartrate:
    rate = max_heartrate
  return rate

## Change to one of the different phases of the game.
## Each phase has different UI and gameplay behaviour.
func change_phase(phase: Phase) -> void:
  var hud = $HUD

  current_phase = phase
  if phase == Phase.MOVE_TUTORIAL:
    hud.directive_text = 'Locate a virus cell'
    hud.set_notice_text('CLICK AND DRAG MOUSE TO PUSH')
    showing_move_tutorial = true
  elif phase == Phase.ATTACK_TUTORIAL:
    hud.directive_text = 'Destroy the virus cell'
    hud.set_notice_text('COLLIDE WITH A VIRUS CELL TO CONSUME IT')
  elif phase == Phase.FARM_VIRUS or phase == Phase.DESTROY_VIRUS:
    hud.directive_text = 'Destroy all virus cells'
    if phase == Phase.FARM_VIRUS:
      hud.set_notice_text('SEEK AND DESTROY', 5)
    else:
      hud.set_notice_text('THE VIRUS HAS LEARNED TO FIGHT BACK', 5)
  elif phase == Phase.CONSUME_ALL:
    hud.directive_text = 'Patient stable. Stand down'
    hud.set_notice_text('ALL VIRUS CELLS ELIMINATED', 5)

  # We need bot tensor to see viruses ONLY in the MOVE_TUTORIAL phase (so we
  # can detect to change phase). After that, it's a performance liability, so
  # turn it off.
  for bot in get_tree().get_nodes_in_group('bots'):
    bot.set_collision_mask_based_on_phase(phase)

  # Hide the bots and viruses until we get to FARM_VIRUS.
  hud.show_bots_viruses = phase > Phase.ATTACK_TUTORIAL

  # Special music.
  if phase == Phase.CONSUME_ALL:
    $Music.stop()
    $MusicMechan.play()

    # Special directives
    $SpecialDirectiveTimer.start()

func finished_move_tutorial():
  # Start zoom tutorial
  $HUD.hide_notice_text()
  showing_move_tutorial = false
  $TutorialTimer.start()

func _on_tutorial_timer_timeout() -> void:
  if not done_zoom_tutorial:
    $HUD.set_notice_text('SCROLL MOUSE WHEEL TO ZOOM')
    showing_zoom_tutorial = true

func finished_zoom_tutorial():
  $HUD.hide_notice_text()
  showing_zoom_tutorial = false

func _on_cell_spawn_timer_timeout() -> void:
  var num_cells = get_tree().get_node_count_in_group('cells')

  # If <= 5, patient is basically dead; let the game play out (otherwise it
  # will go on indefinitely). If max_cells, no need to spawn more.
  # If in CONSUME phase, don't spawn any more (too annoying)
  if num_cells <= 5 or num_cells >= max_cells or current_phase == Phase.CONSUME_ALL:
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

func _on_beep_timer_timeout() -> void:
  var heartrate = calc_heartrate()
  if heartrate == 0:
    # Flatline
    # TODO: Ideally we'd have the flatline stream loaded and simply load it
    # into the same Player.
    $SfxBeep.stop()
    $SfxFlatline.play()
  else:
    $SfxFlatline.stop()
    $SfxBeep.play()
    $BeepTimer.wait_time = heartrate
    $BeepTimer.start()


func _on_music_mechan_finished() -> void:
  $MusicOneOf.play()


func _on_special_directive_timer_timeout() -> void:
  var hud = $HUD
  if special_directive_id == 1 or special_directive_id == 3 or special_directive_id == 5:
    hud.directive_text = 'Patient stable. Stand down'
    $SpecialDirectiveTimer.wait_time = 5
  elif special_directive_id == 0:
    hud.directive_text = '[color=red]ACQUIRE.RESOURCES[/color]'
    $SpecialDirectiveTimer.wait_time = 2
  elif special_directive_id == 2:
    hud.directive_text = '[color=red]KEEP.GROWING[/color]'
    $SpecialDirectiveTimer.wait_time = 2
  elif special_directive_id == 4:
    hud.directive_text = '[color=red]BUILD.TO.SCALE[/color]'
    $SpecialDirectiveTimer.wait_time = 2

  special_directive_id += 1
  if special_directive_id == 6:
    special_directive_id = 0

  $SpecialDirectiveTimer.start()
