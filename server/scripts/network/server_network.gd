extends Node

const PROTOCOL_VERSION: int = 1
const HANDSHAKE_SERVICE_SCRIPT: Script = preload("res://scripts/network/handshake_service.gd")
const MOVEMENT_SYSTEM_SCRIPT: Script = preload("res://scripts/movement/movement_system.gd")
const MONSTER_TEMPLATE_LOADER_SCRIPT: Script = preload("res://scripts/monsters/monster_template_loader.gd")
const MONSTER_SYSTEM_SCRIPT: Script = preload("res://scripts/monsters/monster_system.gd")
const TARGETING_SYSTEM_SCRIPT: Script = preload("res://scripts/targeting/targeting_system.gd")

var _config: Resource
var _simulation_clock: Node
var _entity_registry: Node
var _session_registry: Node
var _peer: ENetMultiplayerPeer
var _handshake_service: RefCounted
var _movement_system: RefCounted
var _snapshot_interval_ticks: int = 3
var _monster_system: RefCounted
var _training_monster_id: int = 0
var _targeting_system: RefCounted

func start_server(
    config: Resource,
    simulation_clock: Node,
    entity_registry: Node,
    session_registry: Node
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
    _movement_system = MOVEMENT_SYSTEM_SCRIPT.new(
        _session_registry,
        _entity_registry,
        _config.player_move_speed,
        0.1,
        _config.get_movement_blockers(),
        _config.WORLD_HALF_EXTENT,
        _config.PLAYER_COLLISION_RADIUS
    )
    _monster_system = MONSTER_SYSTEM_SCRIPT.new(
        _entity_registry,
        _config.monster_random_seed
    )
    _targeting_system = TARGETING_SYSTEM_SCRIPT.new(
        _session_registry,
        _entity_registry,
        _movement_system,
        _monster_system,
        _config.target_selection_range
    )
    var monster_template: Dictionary = MONSTER_TEMPLATE_LOADER_SCRIPT.load_template(
        _config.monster_template_path
    )
    _training_monster_id = _monster_system.spawn_monster(
        monster_template,
        _config.monster_spawn_position,
        _simulation_clock.tick_number
    )
    if _training_monster_id <= 0:
        push_error("Cannot load or spawn training monster.")
        return false
    print(
        "[Aetherfall Zone] Monster spawned: entity=%d template=%s position=%s" % [
            _training_monster_id,
            monster_template["id"],
            _config.monster_spawn_position,
        ]
    )
    _snapshot_interval_ticks = maxi(
        1,
        int(round(float(_config.simulation_tick_rate) / float(_config.snapshot_rate)))
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
    if _movement_system != null:
        _movement_system.clear()
    if _monster_system != null:
        _monster_system.clear()
    if _targeting_system != null:
        _targeting_system.clear()

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
    var spawn_position := Vector3(float(entity_id - 1) * 1.5, 0.1, 0.0)
    if not _movement_system.register_ready_player(sender_peer_id, spawn_position):
        _handshake_service.cleanup_peer(sender_peer_id)
        _reject_handshake(sender_peer_id, "movement state creation failed")
        return
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

@rpc("any_peer", "call_remote", "unreliable_ordered")
func movement_intent(payload: Variant) -> void:
    if not multiplayer.is_server():
        return
    var sender_peer_id := multiplayer.get_remote_sender_id()
    _movement_system.process_intent(
        sender_peer_id,
        payload,
        _simulation_clock.tick_number
    )

@rpc("authority", "call_remote", "unreliable_ordered")
func movement_snapshot(_snapshot: Dictionary) -> void:
    pass

@rpc("any_peer", "call_remote", "reliable")
func target_intent(candidate_entity_id: Variant) -> void:
    if multiplayer.is_server():
        _targeting_system.request_target(
            multiplayer.get_remote_sender_id(),
            candidate_entity_id
        )

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
    var session: Dictionary = _session_registry.get_session(peer_id)
    var controlled_entity_id: int = session.get("entity_id", 0)
    if controlled_entity_id > 0:
        _movement_system.remove_player(controlled_entity_id)
        _targeting_system.remove_player(controlled_entity_id)
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
    _movement_system.simulate_tick(_simulation_delta)
    _monster_system.simulate_tick(_simulation_delta)
    _targeting_system.cleanup_invalid_targets()
    if current_tick % _snapshot_interval_ticks == 0:
        var player_snapshot: Dictionary = _movement_system.create_snapshot(current_tick)
        _targeting_system.decorate_player_snapshot(player_snapshot["entities"])
        var snapshot: Dictionary = _monster_system.create_world_snapshot(
            current_tick,
            player_snapshot["entities"]
        )
        movement_snapshot.rpc(snapshot)
    if (
        _training_monster_id > 0
        and _config.monster_despawn_after_seconds > 0.0
        and current_tick >= int(
            _config.monster_despawn_after_seconds
            * float(_config.simulation_tick_rate)
        )
    ):
        _targeting_system.clear_entity_references(_training_monster_id)
        if _monster_system.despawn_monster(_training_monster_id):
            print("[Aetherfall Zone] Monster despawned: entity=%d" % _training_monster_id)
        _training_monster_id = 0
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
