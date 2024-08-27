extends Area2D

## Color of the circle displayed under the mouse cursor.
@export var draw_color : Color = Color('4db04d')
## Thickness of the line (px) drawn around the mouse cursor when inactive.
@export var inactive_draw_thickness : float = 10

## Multiplier for the amount of force to exert on bots.
@export var force_multiplier : float = 2.5

var active : bool = false:
  set(value):
    var was_active : bool = active
    active = value
    if active != was_active:
      queue_redraw()

    if active:
      gravity_space_override = Area2D.SPACE_OVERRIDE_COMBINE
    else:
      gravity_space_override = Area2D.SPACE_OVERRIDE_DISABLED

func _ready():
  pass # Replace with function body.

func _draw():
  var collision_radius = $CollisionShape2D.shape.radius
  if active:
    draw_circle(Vector2(0, 0), collision_radius, draw_color)
  elif get_parent().input_mode != Level.InputMode.INPUT_TOUCH:
    draw_arc(Vector2(0, 0), collision_radius, 0, TAU, 128, draw_color,
             inactive_draw_thickness)

func _input(event):
  # TODO: Need to refactor and use the joystick motion data when in joystick
  # mode.
  if event is InputEventMouseMotion and active:
    var velocity : Vector2 = event.velocity
    # This is in screen space, not global coordinates. (Which means when the
    # camera is zoomed out, the force is much lower.)
    # Bit of a hack, but fix it by dividing by camera zoom.
    set_force(velocity / get_viewport().get_camera_2d().zoom.x)

func _on_touch_start_drag() -> void:
  print('start_drag')

func _on_touch_end_drag() -> void:
  print('end_drag')

func _on_touch_drag(event: InputEvent) -> void:
  print('drag: ', event)

# Set the cursor pushing force, based on cursor velocity.
# Velocity must be in global coordinates, not screen space.
func set_force(velocity: Vector2):
  gravity_direction = velocity * force_multiplier

func _process(_delta):
  active = Input.is_action_pressed("push")
