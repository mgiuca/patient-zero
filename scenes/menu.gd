extends CanvasLayer

func _ready() -> void:
  open_menu()

func open_menu() -> void:
  $MarginContainer/VBoxContainer/BtnResume.grab_focus()

func _input(event: InputEvent) -> void:
  # Handle inputs that are meant to trigger whether the game is paused or not.
  if event.is_action_pressed('menu'):
    get_parent().paused = not get_parent().paused
  elif event.is_action_pressed('toggle_fullscreen'):
    get_parent().fullscreen = not get_parent().fullscreen

func _process(_delta: float) -> void:
  if visible:
    $MarginContainer/VBoxContainer/ChkFullscreen.button_pressed = get_parent().fullscreen

func _on_btn_resume_pressed() -> void:
  get_parent().paused = false

func _on_chk_fullscreen_toggled(toggled_on: bool) -> void:
  get_parent().fullscreen = toggled_on

func _on_btn_restart_pressed() -> void:
  get_parent().restart_game()

func _on_btn_quit_pressed() -> void:
  get_parent().quit_game()

func in_bounds(control: Control, position: Vector2):
  var bound_rect : Rect2 = Rect2(Vector2.ZERO, control.get_size())
  return bound_rect.has_point(position)

# Used to detect if a touch event is an "up" event within a control, implying
# that the control was pressed like a button from a touch event.
func event_touch_in_bounds(control: Control, event: InputEvent):
  return event is InputEventScreenTouch and not event.pressed and \
         in_bounds(control, event.position)

# Manually detect touch events on buttons and enact them.
# WTF: I should not have to do this. It's very weird that buttons do not respond
# to touch events at all and it's my responsibility to write this logic...??

func _on_btn_resume_gui_input(event: InputEvent) -> void:
  if event_touch_in_bounds($MarginContainer/VBoxContainer/BtnResume, event):
    _on_btn_resume_pressed()

func _on_chk_fullscreen_gui_input(event: InputEvent) -> void:
  var chk = $MarginContainer/VBoxContainer/ChkFullscreen
  if event_touch_in_bounds(chk, event):
    chk.button_pressed = not chk.button_pressed

func _on_btn_restart_gui_input(event: InputEvent) -> void:
  if event_touch_in_bounds($MarginContainer/VBoxContainer/BtnRestart, event):
    _on_btn_restart_pressed()

func _on_btn_quit_gui_input(event: InputEvent) -> void:
  if event_touch_in_bounds($MarginContainer/VBoxContainer/BtnQuit, event):
    _on_btn_quit_pressed()
