class_name MonsterPlaceholder
extends Node3D

@onready var debug_label: Label3D = $DebugLabel
@onready var targetable_area: Node = $TargetableArea
@onready var selection_ring: MeshInstance3D = $SelectionRing
@onready var presentation: TrainingWispPresentation = $MonsterPresentation

var _is_alive: bool = true

func apply_state(state: Dictionary) -> void:
    targetable_area.set_target_entity_id(state["entity_id"])
    _is_alive = state.get("life_state", "ALIVE") == "ALIVE"
    targetable_area.collision_layer = 4 if _is_alive else 0
    targetable_area.monitorable = _is_alive
    presentation.apply_replicated_state(state)
    debug_label.text = "Training Wisp\nEntity %d\nHP: %d / %d\n%s / %s" % [
        state["entity_id"],
        state["current_hp"],
        state["max_hp"],
        state["movement_state"],
        state.get("life_state", "ALIVE"),
    ]

func set_selected(selected: bool) -> void:
    selection_ring.visible = selected and _is_alive
