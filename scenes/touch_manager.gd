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
## Passes the initial and current coordinates of each finger in screen space.
signal pinch(f1_init: Vector2, f2_init: Vector2,
             f1_current: Vector2, f2_current: Vector2)

# Currently in a one-finger drag.
var in_drag: bool = false
# Currently in a two-finger pinch.
var in_pinch: bool = false

# Bit pattern.
var active_fingers: int = 0

# Initial coordinates of each finger when they touched down.
var finger_init_coord: Array[Vector2]
# Last known coordinates of each finger.
var finger_current_coord: Array[Vector2]

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

## Gets the indices of the first two active fingers.
## Assumes pop_count(active_fingers) >= 2.
func get_two_finger_indices(fingers: int) -> Vector2i:
  var i : int = 0
  var fst : int

  while true:
    if fingers == 0:
      assert(false, 'get_two_finger_indices: no bits set')
      return Vector2i.ZERO
    if fingers & 1:
      fst = i
      fingers >>= 1
      i += 1
      break
    fingers >>= 1
    i += 1

  while fingers != 0:
    if fingers & 1:
      return Vector2i(fst, i)
    fingers >>= 1
    i += 1

  assert(false, 'get_two_finger_indices: only one bit set')
  return Vector2i.ZERO

func _unhandled_input(event: InputEvent) -> void:
  if event is InputEventScreenTouch:
    # Record which fingers are pressed and their start coordinates.
    if finger_init_coord.size() <= event.index:
      finger_init_coord.resize(event.index + 1)
    if event.pressed:
      active_fingers |= 1 << event.index
      finger_init_coord[event.index] = event.position
    else:
      active_fingers &= ~(1 << event.index)
      finger_init_coord[event.index] = Vector2.ZERO

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
      if finger_current_coord.size() <= event.index:
        finger_current_coord.resize(event.index + 1)
      finger_current_coord[event.index] = event.position

      var indices = get_two_finger_indices(active_fingers)
      var f1_init = finger_init_coord[indices.x]
      var f2_init = finger_init_coord[indices.y]
      var f1_current = finger_current_coord[indices.x]
      var f2_current = finger_current_coord[indices.y]
      pinch.emit(f1_init, f2_init, f1_current, f2_current)
