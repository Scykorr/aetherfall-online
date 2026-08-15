extends Label

func _process(_delta: float) -> void:
    text = "Network: %s" % Network.get_state_name()
    if Network.assigned_entity_id > 0:
        text += "\nEntity ID: %d" % Network.assigned_entity_id
    if not Network.zone_id.is_empty():
        text += "\nZone: %s" % Network.zone_id
    text += "\nServer Tick: %d" % Network.server_tick
    text += "\nMovement: %s" % Network.movement_mode
    text += "\nInput/Ack: %d/%d" % [Network.last_input_sequence, Network.last_ack_sequence]
