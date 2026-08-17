class_name LootPresentation
extends Node3D

@export var item_label: Label3D
@export var ownership_label: Label3D
@export var owned_marker: Node3D
@export var locked_marker: Node3D

var entity_id: int = 0

func apply_authoritative_state(
    state: Dictionary,
    local_entity_id: int,
    item_definition: Dictionary
) -> void:
    entity_id = int(state.get("entity_id", 0))
    var item_id: String = state.get("item_id", "unknown_item")
    var display_name: String = item_definition.get("display_name", item_id)
    var quantity: int = int(state.get("quantity", 1))
    var rarity: String = item_definition.get("rarity", "common")
    var is_owned := int(state.get("owner_entity_id", 0)) == local_entity_id

    item_label.text = display_name + (" x%d" % quantity if quantity > 1 else "")
    ownership_label.text = "[E] PICK UP" if is_owned else "LOCKED"
    owned_marker.visible = is_owned
    locked_marker.visible = not is_owned
    item_label.modulate = _rarity_color(rarity) if is_owned else Color(0.58, 0.62, 0.64)
    ownership_label.modulate = Color(0.72, 0.95, 0.82) if is_owned else Color(0.72, 0.72, 0.74)

func _rarity_color(rarity: String) -> Color:
    match rarity:
        "uncommon":
            return Color(0.48, 0.92, 0.78)
        "rare":
            return Color(0.55, 0.72, 1.0)
        _:
            return Color(0.94, 0.88, 0.7)
