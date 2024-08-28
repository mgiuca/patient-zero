extends CanvasLayer

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
  get_parent().paused = false
  get_tree().reload_current_scene()

func _on_btn_quit_pressed() -> void:
  get_tree().quit()
