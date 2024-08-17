extends Node

func _ready():
  pass # Replace with function body.

func _process(delta):
  var mouse_pos = get_viewport().get_mouse_position()
  $Cursor.position = mouse_pos
