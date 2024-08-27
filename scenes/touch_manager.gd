extends Node

# The TouchManager handles all touch input, translates it into more useful
# states like "drag" (one-finger action) and "pinch" (two-finger action), and
# sends those out as signals.

## Emitted when a one-finger drag starts.
## Passes the InputEventScreenTouch with the details.
signal start_drag(event: InputEvent)
## Emitted when a one-finger drag ends.
signal end_drag
## Emitted when there is movement within a one-finger drag.
## Passes the InputEventScreenDrag with the details.
signal drag(event: InputEvent)
## Emitted when a two-finger pinch starts.
signal start_pinch
## Emitted when a two-finger pinch ends.
signal end_pinch
## Emitted when there is movement within a two-finger pinch.
## Passes the position of the other (stationary) finger, and the
## previous and new positions of the moving finger.
signal pinch(other_position: Vector2, old_position: Vector2,
             new_position: Vector2)

# Currently in a one-finger drag.
var in_drag: bool = false
# Currently in a two-finger pinch.
var in_pinch: bool = false

# Bit pattern.
var active_fingers: int = 0

# Last known coordinates of each finger.
var finger_positions: Array[Vector2]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
  pass # Replace with function body.

## Determines the number of "1" bits in an integer.
func pop_count(x: int) -> int:
  var cnt : int = 0
  while x != 0:
    if x & 1:
      cnt += 1
    x >>= 1
  return cnt

## Gets the active finger position that is nearest to the given index.
## There must be at least two active fingers.
func nearest_finger_position(index: int) -> Vector2:
  var this_position : Vector2 = finger_positions[index]
  var closest_position : Vector2
  var closest_distance : float = INF

  for i in finger_positions.size():
    if i != index and active_fingers & (1 << i):
      var dist = this_position.distance_to(finger_positions[i])
      if dist < closest_distance:
        closest_position = finger_positions[i]
        closest_distance = dist

  assert(closest_distance < INF, "nearest_finger_position: no other active fingers")

  return closest_position

func _unhandled_input(event: InputEvent) -> void:
  if event is InputEventScreenTouch:
    # Record which fingers are pressed and their start coordinates.
    if finger_positions.size() <= event.index:
      finger_positions.resize(event.index + 1)
    if event.pressed:
      active_fingers |= 1 << event.index
      finger_positions[event.index] = event.position
    else:
      active_fingers &= ~(1 << event.index)
      finger_positions[event.index] = Vector2.ZERO

    var num_fingers = pop_count(active_fingers)

    # Start by ending existing gestures that no longer apply.
    if in_drag and num_fingers != 1:
      end_drag.emit()
      in_drag = false
    if in_pinch and num_fingers < 2:
      end_pinch.emit()
      in_pinch = false

    # Now start new gestures that have begun to apply.
    if not in_drag and num_fingers == 1:
      start_drag.emit(event)
      in_drag = true
    if not in_pinch and num_fingers >= 2:
      start_pinch.emit()
      in_pinch = true

  elif event is InputEventScreenDrag:
    if in_drag:
      drag.emit(event)
    elif in_pinch:
      assert(finger_positions.size() > event.index,
             "old finger position not recorded")
      var old_position : Vector2 = finger_positions[event.index]
      var new_position : Vector2 = event.position
      finger_positions[event.index] = event.position

      var other_finger_position : Vector2 = nearest_finger_position(event.index)

      pinch.emit(other_finger_position, old_position, new_position)
