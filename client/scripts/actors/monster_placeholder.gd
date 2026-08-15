class_name MonsterPlaceholder
extends Node3D

@onready var debug_label: Label3D = $DebugLabel
@onready var targetable_area: Node = $TargetableArea
@onready var selection_ring: MeshInstance3D = $SelectionRing

func apply_state(state: Dictionary) -> void:
    targetable_area.set_target_entity_id(state["entity_id"])
    debug_label.text = "Training Wisp\nEntity %d\nHP: %d / %d\n%s" % [
        state["entity_id"],
        state["current_hp"],
        state["max_hp"],
        state["movement_state"],
    ]

func set_selected(selected: bool) -> void:
    selection_ring.visible = selected
