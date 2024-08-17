extends Area2D

## Color of the circle displayed under the mouse cursor.
@export var draw_color : Color = Color('4db04d')
## Thickness of the line (px) drawn around the mouse cursor when inactive.
@export var inactive_draw_thickness : float = 5

## Multiplier for the amount of force to exert on bots.
@export var force_multiplier : float = 0.7

var active : bool = false

func _ready():
  pass # Replace with function body.

func _draw():
  var collision_radius = $CollisionShape2D.shape.radius
  if active:
    draw_circle(Vector2(0, 0), collision_radius, draw_color)
  else:
    draw_arc(Vector2(0, 0), collision_radius, 0, TAU, 128, draw_color,
             inactive_draw_thickness)

func _input(event):
  if event is InputEventMouseMotion and active:
    # TODO: This is in screen space, not global coordinates. (Which means
    # when the camera is zoomed out, the force is much lower.)
    var velocity : Vector2 = event.velocity
    gravity_direction = velocity

func _process(delta):
  var was_active : bool = active
  active = Input.is_action_pressed("push")
  if active != was_active:
    queue_redraw()

  if active:
    gravity_space_override = Area2D.SPACE_OVERRIDE_COMBINE
  else:
    gravity_space_override = Area2D.SPACE_OVERRIDE_DISABLED
