class_name InventorySystem
extends RefCounted

const EMPTY_SLOT: Dictionary = {}

var _items: Dictionary
var _slot_count: int
var _states: Dictionary = {}

func _init(items: Dictionary, slot_count: int = 24) -> void:
    _items = items.duplicate(true)
    _slot_count = maxi(1, slot_count)

func register_player(owner_entity_id: int) -> bool:
    if owner_entity_id <= 0 or _states.has(owner_entity_id):
        return false
    var slots: Array[Dictionary] = []
    slots.resize(_slot_count)
    for index in _slot_count:
        slots[index] = EMPTY_SLOT.duplicate()
    _states[owner_entity_id] = {
        "owner_entity_id": owner_entity_id,
        "slot_count": _slot_count,
        "slots": slots,
        "inventory_revision": 0,
        "last_command_sequence": 0,
    }
    return true

func remove_player(owner_entity_id: int) -> bool:
    return _states.erase(owner_entity_id)

func get_state(owner_entity_id: int) -> Dictionary:
    if not _states.has(owner_entity_id):
        return {}
    return (_states[owner_entity_id] as Dictionary).duplicate(true)

func create_client_state(owner_entity_id: int) -> Dictionary:
    var state := get_state(owner_entity_id)
    state.erase("last_command_sequence")
    var definitions: Dictionary = {}
    for item_id: String in _items:
        definitions[item_id] = {
            "display_name": String((_items[item_id] as Dictionary).get("display_name", item_id)),
            "max_stack": _max_stack(item_id),
        }
    state["item_definitions"] = definitions
    return state

func can_insert(owner_entity_id: int, item_id: String, quantity: int) -> bool:
    return not _plan_insert(owner_entity_id, item_id, quantity).is_empty()

func insert_item(owner_entity_id: int, item_id: String, quantity: int) -> Dictionary:
    var planned_slots := _plan_insert(owner_entity_id, item_id, quantity)
    if planned_slots.is_empty():
        return _rejected("INVENTORY_FULL")
    var state: Dictionary = _states[owner_entity_id]
    state["slots"] = planned_slots
    _increment_revision(state)
    return _accepted(state)

func process_command(peer_id: int, payload: Variant, sessions: Node) -> Dictionary:
    var session: Dictionary = sessions.get_session(peer_id)
    if not session.get("handshake_complete", false):
        return _rejected("NOT_READY")
    var owner_entity_id: int = session.get("entity_id", 0)
    if not _states.has(owner_entity_id) or not payload is Dictionary:
        return _rejected("INVALID_COMMAND")
    var sequence: Variant = payload.get("sequence")
    var state: Dictionary = _states[owner_entity_id]
    if not sequence is int or sequence <= int(state["last_command_sequence"]):
        return _rejected("STALE_SEQUENCE")
    state["last_command_sequence"] = sequence
    var command: Variant = payload.get("command")
    if not command is String:
        return _rejected("INVALID_COMMAND")
    match command:
        "MOVE_SLOT":
            return _move_slot(state, payload.get("source_slot"), payload.get("destination_slot"))
        "SPLIT_STACK":
            return _split_stack(state, payload.get("source_slot"), payload.get("destination_slot"), payload.get("quantity"))
        "DESTROY_ITEM":
            return _destroy_item(state, payload.get("slot"), payload.get("quantity"))
        _:
            return _rejected("UNKNOWN_COMMAND")

func validate_inventory(owner_entity_id: int) -> Dictionary:
    if not _states.has(owner_entity_id):
        return {"valid": false, "reason": "MISSING_INVENTORY"}
    var state: Dictionary = _states[owner_entity_id]
    var slots: Variant = state.get("slots")
    if not slots is Array or slots.size() != int(state.get("slot_count", -1)) or slots.size() != _slot_count:
        return {"valid": false, "reason": "INVALID_SLOT_COUNT"}
    for slot: Variant in slots:
        if not slot is Dictionary:
            return {"valid": false, "reason": "MALFORMED_STACK"}
        if slot.is_empty():
            continue
        var item_id: Variant = slot.get("item_id")
        var quantity: Variant = slot.get("quantity")
        if not item_id is String or not _items.has(item_id):
            return {"valid": false, "reason": "INVALID_ITEM"}
        if not quantity is int or quantity <= 0 or quantity > _max_stack(item_id):
            return {"valid": false, "reason": "INVALID_QUANTITY"}
    return {"valid": true, "reason": ""}

func clear() -> void:
    _states.clear()

func _plan_insert(owner_entity_id: int, item_id: String, quantity: int) -> Array[Dictionary]:
    if not _states.has(owner_entity_id) or not _items.has(item_id) or quantity <= 0:
        return []
    var slots: Array[Dictionary] = (_states[owner_entity_id]["slots"] as Array).duplicate(true)
    var remaining := quantity
    var max_stack := _max_stack(item_id)
    for index in slots.size():
        var slot: Dictionary = slots[index]
        if slot.get("item_id", "") != item_id or int(slot.get("quantity", 0)) >= max_stack:
            continue
        var amount := mini(remaining, max_stack - int(slot["quantity"]))
        slot["quantity"] += amount
        remaining -= amount
        if remaining == 0:
            return slots
    for index in slots.size():
        if not slots[index].is_empty():
            continue
        var amount := mini(remaining, max_stack)
        slots[index] = {"item_id": item_id, "quantity": amount}
        remaining -= amount
        if remaining == 0:
            return slots
    return []

func _move_slot(state: Dictionary, source_value: Variant, destination_value: Variant) -> Dictionary:
    if not _valid_indices(source_value, destination_value) or source_value == destination_value:
        return _rejected("INVALID_SLOT")
    var source: int = source_value
    var destination: int = destination_value
    var slots: Array = state["slots"]
    if slots[source].is_empty():
        return _rejected("EMPTY_SOURCE")
    if slots[destination].is_empty():
        slots[destination] = slots[source]
        slots[source] = {}
    elif slots[source]["item_id"] == slots[destination]["item_id"]:
        var capacity := _max_stack(slots[source]["item_id"]) - int(slots[destination]["quantity"])
        if capacity <= 0:
            return _rejected("STACK_FULL")
        var moved := mini(capacity, int(slots[source]["quantity"]))
        slots[destination]["quantity"] += moved
        slots[source]["quantity"] -= moved
        if slots[source]["quantity"] == 0:
            slots[source] = {}
    else:
        var temporary: Dictionary = slots[source]
        slots[source] = slots[destination]
        slots[destination] = temporary
    _increment_revision(state)
    return _accepted(state)

func _split_stack(state: Dictionary, source_value: Variant, destination_value: Variant, quantity_value: Variant) -> Dictionary:
    if not _valid_indices(source_value, destination_value) or source_value == destination_value or not quantity_value is int:
        return _rejected("INVALID_SPLIT")
    var source: int = source_value
    var destination: int = destination_value
    var quantity: int = quantity_value
    var slots: Array = state["slots"]
    if slots[source].is_empty() or not slots[destination].is_empty() or quantity <= 0 or quantity >= int(slots[source]["quantity"]):
        return _rejected("INVALID_SPLIT")
    if quantity > _max_stack(slots[source]["item_id"]):
        return _rejected("INVALID_SPLIT")
    slots[source]["quantity"] -= quantity
    slots[destination] = {"item_id": slots[source]["item_id"], "quantity": quantity}
    _increment_revision(state)
    return _accepted(state)

func _destroy_item(state: Dictionary, slot_value: Variant, quantity_value: Variant) -> Dictionary:
    if not slot_value is int or slot_value < 0 or slot_value >= _slot_count or not quantity_value is int:
        return _rejected("INVALID_DESTROY")
    var slots: Array = state["slots"]
    if slots[slot_value].is_empty() or quantity_value <= 0 or quantity_value > int(slots[slot_value]["quantity"]):
        return _rejected("INVALID_DESTROY")
    slots[slot_value]["quantity"] -= quantity_value
    if slots[slot_value]["quantity"] == 0:
        slots[slot_value] = {}
    _increment_revision(state)
    return _accepted(state)

func _valid_indices(source: Variant, destination: Variant) -> bool:
    return source is int and destination is int and source >= 0 and source < _slot_count and destination >= 0 and destination < _slot_count

func _max_stack(item_id: String) -> int:
    return maxi(1, int((_items[item_id] as Dictionary).get("max_stack", 1)))

func _increment_revision(state: Dictionary) -> void:
    state["inventory_revision"] = int(state["inventory_revision"]) + 1

func _accepted(state: Dictionary) -> Dictionary:
    return {"accepted": true, "reason": "", "inventory_state": create_client_state(state["owner_entity_id"])}

func _rejected(reason: String) -> Dictionary:
    return {"accepted": false, "reason": reason}
