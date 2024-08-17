extends Node

func _ready():
  pass # Replace with function body.

func _process(delta):
  # Gets the mouse position in global coordinates, based on the location
  # of the camera.
  var mouse_pos = $Camera.get_global_mouse_position()
  $Cursor.position = mouse_pos
