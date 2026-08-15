class_name MovementSystem
extends RefCounted

const MODE_STOP: StringName = &"STOP"
const MODE_MOVE_TO_POINT: StringName = &"MOVE_TO_POINT"
const MODE_FOLLOW_CURSOR: StringName = &"FOLLOW_CURSOR"

var _sessions: Node
var _entities: Node
var _states: Dictionary = {}
var _move_speed: float
var _arrival_distance: float

func _init(
    sessions: Node,
    entities: Node,
    move_speed: float = 5.0,
    arrival_distance: float = 0.1
) -> void:
    _sessions = sessions
    _entities = entities
    _move_speed = move_speed
    _arrival_distance = arrival_distance

func register_ready_player(peer_id: int, spawn_position: Vector3) -> bool:
    var session: Dictionary = _sessions.get_session(peer_id)
    if not session.get("handshake_complete", false):
        return false
    var entity_id: int = session.get("entity_id", 0)
    if entity_id <= 0 or _entities.get_entity(entity_id).is_empty():
        return false
    _states[entity_id] = {
        "entity_id": entity_id,
        "peer_id": peer_id,
        "position": spawn_position,
        "velocity": Vector3.ZERO,
        "movement_mode": MODE_STOP,
        "move_speed": _move_speed,
        "current_destination": spawn_position,
        "direction": Vector3.ZERO,
        "last_processed_input_sequence": 0,
        "last_input_tick": -1,
    }
    return true

func process_intent(peer_id: int, payload: Variant, current_tick: int) -> bool:
    var session: Dictionary = _sessions.get_session(peer_id)
    if not session.get("handshake_complete", false):
        return false
    var entity_id: int = session.get("entity_id", 0)
    if not _states.has(entity_id) or _entities.get_entity(entity_id).is_empty():
        return false
    if not payload is Dictionary:
        return false
    var sequence: Variant = payload.get("sequence")
    var command: Variant = payload.get("command")
    if not sequence is int or not command is String:
        return false
    var state: Dictionary = _states[entity_id]
    if sequence <= state["last_processed_input_sequence"]:
        return false
    if state["last_input_tick"] == current_tick and command != String(MODE_STOP):
        return false

    match StringName(command):
        MODE_STOP:
            state["movement_mode"] = MODE_STOP
            state["direction"] = Vector3.ZERO
            state["velocity"] = Vector3.ZERO
        MODE_MOVE_TO_POINT:
            var destination: Variant = payload.get("destination")
            if not destination is Vector3 or not _is_finite_vector(destination):
                return false
            state["movement_mode"] = MODE_MOVE_TO_POINT
            state["current_destination"] = Vector3(destination.x, state["position"].y, destination.z)
        MODE_FOLLOW_CURSOR:
            var direction: Variant = payload.get("direction")
            if not direction is Vector3 or not _is_finite_vector(direction):
                return false
            var horizontal := Vector3(direction.x, 0.0, direction.z)
            if horizontal.is_zero_approx():
                return false
            state["direction"] = horizontal.normalized()
            state["movement_mode"] = MODE_FOLLOW_CURSOR
        _:
            return false

    state["last_processed_input_sequence"] = sequence
    state["last_input_tick"] = current_tick
    return true

func simulate_tick(delta: float) -> void:
    for entity_id: int in _states:
        var state: Dictionary = _states[entity_id]
        var direction := Vector3.ZERO
        if state["movement_mode"] == MODE_MOVE_TO_POINT:
            var offset: Vector3 = state["current_destination"] - state["position"]
            offset.y = 0.0
            var max_step: float = state["move_speed"] * delta
            if offset.length() <= maxf(_arrival_distance, max_step):
                state["position"] += offset
                state["velocity"] = Vector3.ZERO
                state["movement_mode"] = MODE_STOP
                continue
            direction = offset.normalized()
        elif state["movement_mode"] == MODE_FOLLOW_CURSOR:
            direction = state["direction"]
        else:
            state["velocity"] = Vector3.ZERO
            continue
        state["velocity"] = direction * float(state["move_speed"])
        state["position"] += state["velocity"] * delta

func create_snapshot(server_tick: int) -> Dictionary:
    var players: Array[Dictionary] = []
    for entity_id: int in _states:
        var state: Dictionary = _states[entity_id]
        players.append({
            "entity_id": entity_id,
            "position": state["position"],
            "velocity": state["velocity"],
            "movement_mode": String(state["movement_mode"]),
            "last_processed_input_sequence": state["last_processed_input_sequence"],
        })
    return {"server_tick": server_tick, "players": players}

func remove_player(entity_id: int) -> bool:
    return _states.erase(entity_id)

func get_state(entity_id: int) -> Dictionary:
    if not _states.has(entity_id):
        return {}
    return (_states[entity_id] as Dictionary).duplicate(true)

func get_player_count() -> int:
    return _states.size()

func clear() -> void:
    _states.clear()

func _is_finite_vector(value: Vector3) -> bool:
    return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)
