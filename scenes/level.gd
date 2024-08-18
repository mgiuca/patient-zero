# Scene script shared by all levels.

extends Node

## The scene to instantiate a bot.
@export var bot_scene : PackedScene

## Number of bots to spawn at startup.
@export var initial_bots : int

## Seek to this time (s) when starting the music.
@export var music_start_time : float

var bots : Array[Bot] = []

# Add this much around the edge of the bots when framing the camera.
var zoom_margin : float = 500

func _ready():
  $Music.seek(music_start_time)

  # Spawn a bunch of bots.
  for i in initial_bots:
    var pos = Vector2(randf_range(-750, 750), randf_range(-750, 750))
    var rot = randf_range(0, TAU)
    spawn_bot(pos, rot)

func spawn_bot(position: Vector2, rotation : float):
  var bot : Bot = bot_scene.instantiate()
  bot.rotation = rotation
  bot.position = position
  bots.append(bot)
  add_child(bot)

func _process(delta):
  # Gets the mouse position in global coordinates, based on the location
  # of the camera.
  var mouse_pos = $Camera.get_global_mouse_position()
  $Cursor.position = mouse_pos

  update_camera()

## Update the camera to capture a view of all the bots.
func update_camera():
  # Note that the camera position will auto-smooth, but zoom will not.

  # No bots; we can't update the camera so leave as-is.
  if bots.is_empty():
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
  $Camera.zoom = Vector2(zoom, zoom)
