class_name SnapshotStore
extends RefCounted

var latest_server_tick: int = -1
var entity_states: Dictionary = {}

func apply_snapshot(snapshot: Variant) -> bool:
    if not snapshot is Dictionary:
        return false
    var tick: Variant = snapshot.get("server_tick")
    var players: Variant = snapshot.get("players")
    if not tick is int or not players is Array or tick <= latest_server_tick:
        return false
    var next_states: Dictionary = {}
    for player: Variant in players:
        if not player is Dictionary:
            return false
        var entity_id: Variant = player.get("entity_id")
        var position: Variant = player.get("position")
        var velocity: Variant = player.get("velocity")
        if not entity_id is int or entity_id <= 0:
            return false
        if not position is Vector3 or not velocity is Vector3:
            return false
        next_states[entity_id] = player.duplicate(true)
    latest_server_tick = tick
    entity_states = next_states
    return true

func get_state(entity_id: int) -> Dictionary:
    if not entity_states.has(entity_id):
        return {}
    return (entity_states[entity_id] as Dictionary).duplicate(true)
