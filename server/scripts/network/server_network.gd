extends Node

const PROTOCOL_VERSION: int = 1
const HANDSHAKE_SERVICE_SCRIPT: Script = preload("res://scripts/network/handshake_service.gd")

var _config: ZoneConfig
var _simulation_clock: SimulationClock
var _entity_registry: EntityRegistry
var _session_registry: SessionRegistry
var _peer: ENetMultiplayerPeer
var _handshake_service: RefCounted

func start_server(
    config: ZoneConfig,
    simulation_clock: SimulationClock,
    entity_registry: EntityRegistry,
    session_registry: SessionRegistry
) -> bool:
    _config = config
    _simulation_clock = simulation_clock
    _entity_registry = entity_registry
    _session_registry = session_registry
    _handshake_service = HANDSHAKE_SERVICE_SCRIPT.new(
        _entity_registry,
        _session_registry,
        PROTOCOL_VERSION
    )
    _peer = ENetMultiplayerPeer.new()
    _peer.set_bind_ip(_config.network_bind_address)
    var error := _peer.create_server(_config.network_port, _config.max_players)
    if error != OK:
        push_error("Cannot listen on port %d: %s" % [_config.network_port, error_string(error)])
        return false
    multiplayer.multiplayer_peer = _peer
    multiplayer.peer_connected.connect(_on_peer_connected)
    multiplayer.peer_disconnected.connect(_on_peer_disconnected)
    _simulation_clock.tick.connect(_on_simulation_tick)
    print("[Aetherfall Zone] Listening on %s:%d" % [
        _config.network_bind_address,
        _config.network_port,
    ])
    return true

func stop_server() -> void:
    if _simulation_clock != null and _simulation_clock.tick.is_connected(_on_simulation_tick):
        _simulation_clock.tick.disconnect(_on_simulation_tick)
    if multiplayer.peer_connected.is_connected(_on_peer_connected):
        multiplayer.peer_connected.disconnect(_on_peer_connected)
    if multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
        multiplayer.peer_disconnected.disconnect(_on_peer_disconnected)
    if _peer != null:
        _peer.close()
    multiplayer.multiplayer_peer = null
    _peer = null

@rpc("any_peer", "call_remote", "reliable")
func request_handshake(payload: Variant) -> void:
    if not multiplayer.is_server():
        return
    var sender_peer_id := multiplayer.get_remote_sender_id()
    var result: Dictionary = _handshake_service.process_handshake(
        sender_peer_id,
        payload,
        _simulation_clock.tick_number
    )
    if not result["accepted"]:
        _reject_handshake(sender_peer_id, result["reason"])
        return

    var entity_id: int = result["entity_id"]
    handshake_accepted.rpc_id(sender_peer_id, {
        "entity_id": entity_id,
        "zone_id": String(_config.zone_id),
        "server_tick": _simulation_clock.tick_number,
        "protocol_version": PROTOCOL_VERSION,
    })
    print(
        "[Aetherfall Zone] Handshake accepted: peer=%d entity=%d entities=%d sessions=%d" % [
            sender_peer_id,
            entity_id,
            _entity_registry.get_entity_count(),
            _session_registry.get_session_count(),
        ]
    )

@rpc("authority", "call_remote", "reliable")
func handshake_accepted(_payload: Dictionary) -> void:
    pass

@rpc("authority", "call_remote", "reliable")
func handshake_rejected(_reason: String) -> void:
    pass

func _on_peer_connected(peer_id: int) -> void:
    var timeout_ticks := maxi(
        1,
        int(ceil(_config.handshake_timeout_seconds * _config.simulation_tick_rate))
    )
    _session_registry.create_pending_session(
        peer_id,
        _simulation_clock.tick_number,
        _simulation_clock.tick_number + timeout_ticks
    )
    print("[Aetherfall Zone] Peer connected: %d" % peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
    var entity_id: int = _handshake_service.cleanup_peer(peer_id)
    print(
        "[Aetherfall Zone] Peer disconnected: peer=%d entity=%d entities=%d sessions=%d" % [
            peer_id,
            entity_id,
            _entity_registry.get_entity_count(),
            _session_registry.get_session_count(),
        ]
    )

func _on_simulation_tick(current_tick: int, _simulation_delta: float) -> void:
    for peer_id in _handshake_service.cleanup_expired_sessions(current_tick):
        print(
            "[Aetherfall Zone] Handshake timeout: peer=%d entities=%d sessions=%d" % [
                peer_id,
                _entity_registry.get_entity_count(),
                _session_registry.get_session_count(),
            ]
        )
        _peer.disconnect_peer(peer_id)

func _reject_handshake(peer_id: int, reason: String) -> void:
    print(
        "[Aetherfall Zone] Handshake rejected: peer=%d reason=%s entities=%d sessions=%d" % [
            peer_id,
            reason,
            _entity_registry.get_entity_count(),
            _session_registry.get_session_count(),
        ]
    )
    handshake_rejected.rpc_id(peer_id, reason)
    get_tree().create_timer(0.1).timeout.connect(
        _disconnect_rejected_peer.bind(peer_id),
        CONNECT_ONE_SHOT
    )

func _disconnect_rejected_peer(peer_id: int) -> void:
    if not _session_registry.get_session(peer_id).is_empty():
        _peer.disconnect_peer(peer_id)
