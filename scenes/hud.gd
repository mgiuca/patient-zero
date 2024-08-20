extends CanvasLayer

@export_group('Labels')

@export var num_bots : int:
  set(value):
    if num_bots != value:
      $MarginContainer/LeftSide/LblBots.text = "Bots: " + str(value)
    num_bots = value

@export var num_viruses : int:
  set(value):
    if num_viruses != value:
      $MarginContainer/LeftSide/LblVirus.text = "Virus cells: " + str(value)
    num_viruses = value

@export var patient_health : float:
  set(value):
    if patient_health != value:
      $MarginContainer/LeftSide/LblHealth.text = "Patient health: " + \
        str(snappedf(value * 100, 1)) + "%"
    patient_health = value

@export_group('Debug')

@export var debug_visible : bool:
  set(value):
    debug_visible = value
    $MarginContainer/RightSide/LblDebug.visible = value

# Debugging

# As a debug hack, appends the number of cells to the end of the patient
# health row.
func append_num_cells(num_cells: int) -> void:
  $MarginContainer/LeftSide/LblHealth.text += " (" + str(num_cells) + " cells)"

func set_debug_info(zoom: float, active_cluster_size: int) -> void:
  $MarginContainer/RightSide/LblDebug.text = \
    "Zoom: " + str(snappedf(zoom, 0.1)) + \
    "; Active cluster size: " + str(active_cluster_size)
