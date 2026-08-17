class_name SnapshotStore
extends RefCounted

var latest_server_tick: int = -1
var entity_states: Dictionary = {}

func apply_snapshot(snapshot: Variant) -> bool:
    if not snapshot is Dictionary:
        return false
    var tick: Variant = snapshot.get("server_tick")
    var entities: Variant = snapshot.get("entities")
    if not tick is int or not entities is Array or tick <= latest_server_tick:
        return false
    var next_states: Dictionary = {}
    for entity: Variant in entities:
        if not entity is Dictionary:
            return false
        var entity_id: Variant = entity.get("entity_id")
        var entity_type: Variant = entity.get("entity_type")
        var position: Variant = entity.get("position")
        var velocity: Variant = entity.get("velocity")
        if not entity_id is int or entity_id <= 0:
            return false
        if not entity_type is String or entity_type not in ["player", "monster", "loot"]:
            return false
        if not position is Vector3 or not velocity is Vector3:
            return false
        next_states[entity_id] = entity.duplicate(true)
    latest_server_tick = tick
    entity_states = next_states
    return true

func get_state(entity_id: int) -> Dictionary:
    if not entity_states.has(entity_id):
        return {}
    return (entity_states[entity_id] as Dictionary).duplicate(true)
