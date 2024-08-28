extends CanvasLayer

@export_group('Labels')

@export var show_bots_viruses : bool:
  set(value):
    show_bots_viruses = value
    $MarginContainer/LeftSide/LblBots.visible = value
    $MarginContainer/LeftSide/LblVirus.visible = value

@export var num_bots : int = -1:
  set(value):
    if num_bots != value:
      $MarginContainer/LeftSide/LblBots.text = "Bots: " + str(value)
    num_bots = value

@export var num_viruses : int = -1:
  set(value):
    if num_viruses != value:
      $MarginContainer/LeftSide/LblVirus.text = "Virus cells: " + str(value)
    num_viruses = value

var _patient_health : float = -1
var _num_cells : int = -1

@export var patient_health : float = -1:
  set(value):
    if _patient_health != value:
      $MarginContainer/LeftSide/LblHealth.text = "Patient health: " + \
        str(snappedf(value * 100, 1)) + "%"
    _patient_health = value

## The text of the "Directive" label, in BBCode format (for e.g. color).
@export var directive_text : String:
  set(value):
    directive_text = value
    $MarginContainer/RightSide/LblDirective.text = "[right]Directive: " + \
      value + "[/right]"

@export_group('Debug')

@export var debug_visible : bool:
  set(value):
    debug_visible = value
    $MarginContainer/RightSide/DebugItems.visible = value

## Sets the text of the screen-centered notice label, with an optional timeout.
func set_notice_text(value: String, timeout: float = 0) -> void:
  $LblNotice.text = value
  $LblNotice.visible = true
  if timeout > 0:
    $NoticeTimer.wait_time = timeout
    $NoticeTimer.start()

func hide_notice_text() -> void:
  $LblNotice.visible = false

func show_gameover(value: String) -> void:
  $LblNotice.text = value
  $LblNotice.visible = true
  $LblRestart.visible = true

# Debugging

# Set patient health and show the number of cells (for debugging).
func set_patient_health_and_cells(value: float, num_cells: int) -> void:
  if _patient_health != value or _num_cells != num_cells:
    $MarginContainer/LeftSide/LblHealth.text = "Patient health: " + \
      str(snappedf(value * 100, 1)) + "% (" + str(num_cells) + " cells)"
    _patient_health = value
    _num_cells = num_cells

func set_debug_info(zoom: float, active_cluster_size: int,
                    framerate: float, tensor_update_percent: float,
                    input_mode: Level.InputMode) -> void:
  $MarginContainer/RightSide/DebugItems/LblPerformance.text = \
    "FPS: " + str(snappedf(framerate, 0.1)) + \
    "; Tensor calc: " + str(snappedf(tensor_update_percent * 100, 1)) + '%'
  var input_mode_str
  if input_mode == Level.InputMode.INPUT_MOUSE:
    input_mode_str = "Mouse"
  elif input_mode == Level.InputMode.INPUT_TOUCH:
    input_mode_str = "Touch"
  elif input_mode == Level.InputMode.INPUT_JOYSTICK:
    input_mode_str = "Joystick"
  $MarginContainer/RightSide/DebugItems/LblDebugInput.text = \
    "Input mode: " + input_mode_str
  $MarginContainer/RightSide/DebugItems/LblDebugZoom.text = \
    "Zoom: " + str(snappedf(zoom, 0.1))
  $MarginContainer/RightSide/DebugItems/LblDebugCluster.text = \
    "Active cluster size: " + str(active_cluster_size)

func _on_btn_menu_pressed() -> void:
  get_parent().paused = true

func _on_btn_menu_gui_input(event: InputEvent) -> void:
  # Handle touch event on this button.
  # See the horrible hack on the buttons in Menu for details.
  if get_parent().get_node('Menu').event_touch_in_bounds($MarginContainer/BtnMenu, event):
    _on_btn_menu_pressed()
