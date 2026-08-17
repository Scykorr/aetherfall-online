class_name InventoryStateStore
extends RefCounted

var inventory_revision: int = -1
var slot_count: int = 0
var slots: Array = []
var item_definitions: Dictionary = {}

func apply_state(state: Variant) -> bool:
    if not state is Dictionary:
        return false
    var revision: Variant = state.get("inventory_revision")
    var next_slot_count: Variant = state.get("slot_count")
    var next_slots: Variant = state.get("slots")
    var definitions: Variant = state.get("item_definitions", {})
    if not revision is int or revision <= inventory_revision:
        return false
    if not next_slot_count is int or next_slot_count <= 0 or not next_slots is Array or next_slots.size() != next_slot_count or not definitions is Dictionary:
        return false
    for slot: Variant in next_slots:
        if not slot is Dictionary:
            return false
        if slot.is_empty():
            continue
        if not slot.get("item_id") is String or not slot.get("quantity") is int or slot["quantity"] <= 0:
            return false
    inventory_revision = revision
    slot_count = next_slot_count
    slots = next_slots.duplicate(true)
    item_definitions = definitions.duplicate(true)
    return true

func reset() -> void:
    inventory_revision = -1
    slot_count = 0
    slots.clear()
    item_definitions.clear()

func get_state() -> Dictionary:
    return {"inventory_revision": inventory_revision, "slot_count": slot_count, "slots": slots.duplicate(true), "item_definitions": item_definitions.duplicate(true)}
