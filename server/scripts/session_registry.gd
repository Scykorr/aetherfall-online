class_name SessionRegistry
extends Node

var _sessions: Dictionary = {}

func create_pending_session(
    peer_id: int,
    connected_tick: int,
    timeout_tick: int
) -> bool:
    if peer_id <= 0 or _sessions.has(peer_id):
        return false
    _sessions[peer_id] = {
        "peer_id": peer_id,
        "entity_id": 0,
        "connected_tick": connected_tick,
        "timeout_tick": timeout_tick,
        "handshake_complete": false,
        "protocol_version": 0,
    }
    return true

func complete_handshake(peer_id: int, entity_id: int, protocol_version: int) -> bool:
    if not _sessions.has(peer_id):
        return false
    var session: Dictionary = _sessions[peer_id]
    if session["handshake_complete"]:
        return false
    session["entity_id"] = entity_id
    session["handshake_complete"] = true
    session["protocol_version"] = protocol_version
    return true

func get_session(peer_id: int) -> Dictionary:
    if not _sessions.has(peer_id):
        return {}
    var session: Dictionary = _sessions[peer_id]
    return session.duplicate(true)

func remove_session(peer_id: int) -> Dictionary:
    var session := get_session(peer_id)
    _sessions.erase(peer_id)
    return session

func get_expired_pending_peers(current_tick: int) -> Array[int]:
    var expired_peers: Array[int] = []
    for peer_id: int in _sessions:
        var session: Dictionary = _sessions[peer_id]
        if not session["handshake_complete"] and current_tick >= session["timeout_tick"]:
            expired_peers.append(peer_id)
    return expired_peers

func get_session_count() -> int:
    return _sessions.size()

func clear() -> void:
    _sessions.clear()
