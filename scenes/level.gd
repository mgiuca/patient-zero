extends Node

var bots : Array[Bot]

# Add this much around the edge of the bots when framing the camera.
var zoom_margin : float = 150

func _ready():
  # TODO: Dynamic bots.
  bots = [$Bot1, $Bot2, $Bot3, $Bot4, $Bot5, $Bot6]

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
