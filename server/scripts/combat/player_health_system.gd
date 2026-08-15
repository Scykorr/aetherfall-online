class_name PlayerHealthSystem
extends RefCounted

var _states: Dictionary = {}
var _max_hp: int

func _init(max_hp: int) -> void:
    _max_hp = maxi(1, max_hp)

func register_player(entity_id: int) -> bool:
    if entity_id <= 0 or _states.has(entity_id):
        return false
    _states[entity_id] = {
        "entity_id": entity_id,
        "max_hp": _max_hp,
        "current_hp": _max_hp,
    }
    return true

func apply_server_damage(entity_id: int, damage: int) -> Dictionary:
    if not _states.has(entity_id) or damage <= 0:
        return {"applied": false, "current_hp": 0}
    var state: Dictionary = _states[entity_id]
    state["current_hp"] = maxi(1, int(state["current_hp"]) - damage)
    return {"applied": true, "current_hp": state["current_hp"]}

func get_state(entity_id: int) -> Dictionary:
    if not _states.has(entity_id):
        return {}
    return (_states[entity_id] as Dictionary).duplicate(true)

func decorate_player_snapshot(players: Array) -> void:
    for player: Dictionary in players:
        var health := get_state(player["entity_id"])
        if not health.is_empty():
            player["current_hp"] = health["current_hp"]
            player["max_hp"] = health["max_hp"]

func remove_player(entity_id: int) -> bool:
    return _states.erase(entity_id)

func clear() -> void:
    _states.clear()
