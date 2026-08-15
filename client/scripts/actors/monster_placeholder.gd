class_name MonsterPlaceholder
extends Node3D

@onready var debug_label: Label3D = $DebugLabel

func apply_state(state: Dictionary) -> void:
    debug_label.text = "Training Wisp\nEntity %d\nHP: %d / %d\n%s" % [
        state["entity_id"],
        state["current_hp"],
        state["max_hp"],
        state["movement_state"],
    ]
