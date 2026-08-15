class_name HandshakeService
extends RefCounted

var _entity_registry: Node
var _session_registry: Node
var _protocol_version: int

func _init(
    entity_registry: Node,
    session_registry: Node,
    protocol_version: int
) -> void:
    _entity_registry = entity_registry
    _session_registry = session_registry
    _protocol_version = protocol_version

func process_handshake(peer_id: int, payload: Variant, current_tick: int) -> Dictionary:
    var session: Dictionary = _session_registry.get_session(peer_id)
    if session.is_empty():
        return _rejected("missing transport session")
    if session["handshake_complete"]:
        return _rejected("duplicate handshake")
    if not payload is Dictionary or not payload.has("protocol_version"):
        return _rejected("malformed handshake")

    var received_version: Variant = payload["protocol_version"]
    if not received_version is int:
        return _rejected("malformed protocol version")
    if received_version != _protocol_version:
        return _rejected(
            "protocol mismatch client=%d server=%d" % [
                received_version,
                _protocol_version,
            ]
        )

    var entity_id: int = _entity_registry.register_entity(
        &"player",
        current_tick,
        {"peer_id": peer_id}
    )
    if not _session_registry.complete_handshake(
        peer_id,
        entity_id,
        received_version
    ):
        _entity_registry.remove_entity(entity_id)
        return _rejected("session state changed")
    return {
        "accepted": true,
        "reason": "",
        "entity_id": entity_id,
    }

func cleanup_peer(peer_id: int) -> int:
    var session: Dictionary = _session_registry.remove_session(peer_id)
    var entity_id: int = session.get("entity_id", 0)
    if entity_id > 0:
        _entity_registry.remove_entity(entity_id)
    return entity_id

func cleanup_expired_sessions(current_tick: int) -> Array[int]:
    var expired_peers: Array[int] = _session_registry.get_expired_pending_peers(current_tick)
    for peer_id in expired_peers:
        cleanup_peer(peer_id)
    return expired_peers

func _rejected(reason: String) -> Dictionary:
    return {
        "accepted": false,
        "reason": reason,
        "entity_id": 0,
    }
