extends Node

const PROTOCOL_VERSION: int = 1
const HANDSHAKE_SERVICE_SCRIPT: Script = preload("res://scripts/network/handshake_service.gd")
const MOVEMENT_SYSTEM_SCRIPT: Script = preload("res://scripts/movement/movement_system.gd")
const MONSTER_TEMPLATE_LOADER_SCRIPT: Script = preload("res://scripts/monsters/monster_template_loader.gd")
const MONSTER_SYSTEM_SCRIPT: Script = preload("res://scripts/monsters/monster_system.gd")
const TARGETING_SYSTEM_SCRIPT: Script = preload("res://scripts/targeting/targeting_system.gd")
const COMBAT_SYSTEM_SCRIPT: Script = preload("res://scripts/combat/combat_system.gd")
const PLAYER_HEALTH_SYSTEM_SCRIPT: Script = preload("res://scripts/combat/player_health_system.gd")
const PROGRESSION_SYSTEM_SCRIPT: Script = preload("res://scripts/rewards/player_progression_system.gd")
const REWARD_DATA_LOADER_SCRIPT: Script = preload("res://scripts/rewards/reward_data_loader.gd")
const LOOT_SYSTEM_SCRIPT: Script = preload("res://scripts/rewards/loot_system.gd")
const INVENTORY_SYSTEM_SCRIPT: Script = preload("res://scripts/inventory/inventory_system.gd")

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
var _combat_system: RefCounted
var _player_health_system: RefCounted
var _progression_system: RefCounted
var _loot_system: RefCounted
var _inventory_system: RefCounted
var _item_definitions: Dictionary

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
    _player_health_system = PLAYER_HEALTH_SYSTEM_SCRIPT.new(
        _config.player_max_hp,
        _config.player_respawn_delay_seconds,
        _config.simulation_tick_rate
    )
    _progression_system = PROGRESSION_SYSTEM_SCRIPT.new()
    _movement_system.configure_player_lifecycle(_player_health_system)
    _monster_system.configure_ai(
        _movement_system,
        _config.monster_aggro_interval_ticks,
        _player_health_system
    )
    _targeting_system = TARGETING_SYSTEM_SCRIPT.new(
        _session_registry,
        _entity_registry,
        _movement_system,
        _monster_system,
        _config.target_selection_range
    )
    _targeting_system.configure_player_lifecycle(_player_health_system)
    _combat_system = COMBAT_SYSTEM_SCRIPT.new(
        _session_registry,
        _entity_registry,
        _movement_system,
        _monster_system,
        _targeting_system,
        _config.basic_attack_damage,
        _config.basic_attack_range,
        _config.basic_attack_cooldown_seconds,
        _config.simulation_tick_rate,
        _player_health_system
    )
    var items: Variant = REWARD_DATA_LOADER_SCRIPT.load_json(_config.item_catalog_path)
    var loot_doc: Variant = REWARD_DATA_LOADER_SCRIPT.load_json(_config.monster_loot_table_path)
    if not items is Dictionary or not loot_doc is Dictionary:
        push_error("Cannot load reward data."); return false
    _item_definitions = items
    var tables := {String(loot_doc.get("id", "")): loot_doc.get("entries", [])}
    if _config.loot_test_mode:
        var test_entries: Array = (tables[String(loot_doc.get("id", ""))] as Array).duplicate(true)
        if not test_entries.is_empty():
            test_entries[0]["min_quantity"] = 4
            test_entries[0]["max_quantity"] = 4
            tables[String(loot_doc.get("id", ""))] = test_entries
    _inventory_system = INVENTORY_SYSTEM_SCRIPT.new(items, _config.inventory_slot_count)
    _loot_system = LOOT_SYSTEM_SCRIPT.new(
        _entity_registry, _movement_system, _player_health_system, _progression_system, _inventory_system,
        items, tables, _config.loot_random_seed, _config.loot_pickup_range,
        _config.loot_lifetime_seconds, _config.simulation_tick_rate
    )
    var monster_template: Dictionary = MONSTER_TEMPLATE_LOADER_SCRIPT.load_template(
        _config.monster_template_path
    )
    if _config.loot_test_mode:
        monster_template = monster_template.duplicate(true)
        monster_template["combat"]["attack_damage"] = 1
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
    if _combat_system != null:
        _combat_system.clear()
    if _player_health_system != null:
        _player_health_system.clear()
    if _loot_system != null: _loot_system.clear()
    if _inventory_system != null: _inventory_system.clear()
    _item_definitions.clear()
    if _progression_system != null: _progression_system.clear()

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
    if not _player_health_system.register_player(entity_id, spawn_position):
        _movement_system.remove_player(entity_id)
        _handshake_service.cleanup_peer(sender_peer_id)
        _reject_handshake(sender_peer_id, "health state creation failed")
        return
    if not _progression_system.register_player(entity_id):
        _player_health_system.remove_player(entity_id); _movement_system.remove_player(entity_id)
        _handshake_service.cleanup_peer(sender_peer_id)
        _reject_handshake(sender_peer_id, "progression state creation failed"); return
    if not _inventory_system.register_player(entity_id):
        _progression_system.remove_player(entity_id); _player_health_system.remove_player(entity_id)
        _movement_system.remove_player(entity_id); _handshake_service.cleanup_peer(sender_peer_id)
        _reject_handshake(sender_peer_id, "inventory state creation failed"); return
    if _config.inventory_full_test_mode:
        var item_id: String = String(_item_definitions.keys()[0])
        var max_stack: int = int((_item_definitions[item_id] as Dictionary)["max_stack"])
        for _index in _config.inventory_slot_count:
            _inventory_system.insert_item(entity_id, item_id, max_stack)
    handshake_accepted.rpc_id(sender_peer_id, {
        "entity_id": entity_id,
        "zone_id": String(_config.zone_id),
        "server_tick": _simulation_clock.tick_number,
        "protocol_version": PROTOCOL_VERSION,
    })
    inventory_state.rpc_id(sender_peer_id, _inventory_system.create_client_state(entity_id))
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

@rpc("authority", "call_remote", "reliable")
func movement_snapshot(_snapshot: Dictionary) -> void:
    pass

@rpc("any_peer", "call_remote", "reliable")
func target_intent(candidate_entity_id: Variant) -> void:
    if multiplayer.is_server():
        _targeting_system.request_target(
            multiplayer.get_remote_sender_id(),
            candidate_entity_id
        )

@rpc("any_peer", "call_remote", "reliable")
func attack_intent(payload: Variant) -> void:
    if not multiplayer.is_server():
        return
    var peer_id := multiplayer.get_remote_sender_id()
    var result: Dictionary = _combat_system.process_attack(
        peer_id,
        payload,
        _simulation_clock.tick_number
    )
    if result["accepted"]:
        var event: Dictionary = result["event"]
        print(
            "[Aetherfall Zone] Combat HIT: attacker=%d target=%d damage=%d hp=%d tick=%d sequence=%d" % [
                event["attacker_entity_id"],
                event["target_entity_id"],
                event["damage"],
                event["target_current_hp"],
                event["server_tick"],
                event["attack_sequence"],
            ]
        )
        combat_result.rpc(result["event"])
    else:
        print(
            "[Aetherfall Zone] Combat rejected: peer=%d reason=%s"
            % [peer_id, result["reason"]]
        )
        combat_rejected.rpc_id(peer_id, result["reason"])

@rpc("any_peer", "call_remote", "reliable")
func pickup_intent(loot_entity_id: Variant) -> void:
    if not multiplayer.is_server(): return
    var peer_id := multiplayer.get_remote_sender_id()
    var result: Dictionary = _loot_system.process_pickup(peer_id, loot_entity_id, _session_registry)
    if result["accepted"]:
        print("[Aetherfall Zone] Loot picked: player=%d loot=%d item=%s quantity=%d" % [result.player_entity_id, result.loot_entity_id, result.item_id, result.quantity])
        pickup_result.rpc(result)
        inventory_state.rpc_id(peer_id, result["inventory_state"])
    else: pickup_rejected.rpc_id(peer_id, int(loot_entity_id) if loot_entity_id is int else 0, result.get("reason", "REJECTED"))

@rpc("authority", "call_remote", "reliable")
func pickup_result(_result: Dictionary) -> void: pass
@rpc("authority", "call_remote", "reliable")
func pickup_rejected(_loot_entity_id: int, _reason: String) -> void: pass

@rpc("any_peer", "call_remote", "reliable")
func inventory_intent(payload: Variant) -> void:
    if not multiplayer.is_server():
        return
    var peer_id := multiplayer.get_remote_sender_id()
    var result: Dictionary = _inventory_system.process_command(peer_id, payload, _session_registry)
    if result["accepted"]:
        inventory_state.rpc_id(peer_id, result["inventory_state"])
    else:
        inventory_rejected.rpc_id(peer_id, result["reason"])

@rpc("authority", "call_remote", "reliable")
func inventory_state(_state: Dictionary) -> void: pass

@rpc("authority", "call_remote", "reliable")
func inventory_rejected(_reason: String) -> void: pass

@rpc("authority", "call_remote", "reliable")
func combat_result(_event: Dictionary) -> void:
    pass

@rpc("authority", "call_remote", "reliable")
func combat_rejected(_reason: String) -> void:
    pass

@rpc("authority", "call_remote", "reliable")
func player_lifecycle_event(_event: Dictionary) -> void:
    pass

@rpc("authority", "call_remote", "reliable")
func monster_lifecycle_event(_event: Dictionary) -> void:
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
    var session: Dictionary = _session_registry.get_session(peer_id)
    var controlled_entity_id: int = session.get("entity_id", 0)
    if controlled_entity_id > 0:
        _movement_system.remove_player(controlled_entity_id)
        _targeting_system.remove_player(controlled_entity_id)
        _combat_system.remove_player(controlled_entity_id)
        _player_health_system.remove_player(controlled_entity_id)
        _progression_system.remove_player(controlled_entity_id)
        _inventory_system.remove_player(controlled_entity_id)
        _monster_system.clear_aggro_target(controlled_entity_id)
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
    _loot_system.simulate_tick(current_tick)
    _player_health_system.simulate_tick(current_tick)
    _replicate_player_lifecycle_events()
    _movement_system.simulate_tick(_simulation_delta)
    _monster_system.simulate_tick(
        _simulation_delta,
        current_tick
    )
    for request: Dictionary in _monster_system.drain_attack_requests():
        var result: Dictionary = _combat_system.process_monster_attack(
            request["attacker_entity_id"],
            request["target_entity_id"],
            current_tick
        )
        if result["accepted"]:
            var event: Dictionary = result["event"]
            print(
                "[Aetherfall Zone] Monster attack: attacker=%d target=%d damage=%d hp=%d tick=%d" % [
                    event["attacker_entity_id"], event["target_entity_id"],
                    event["damage"], event["target_current_hp"], event["server_tick"],
                ]
            )
            combat_result.rpc(event)
    _replicate_player_lifecycle_events()
    _targeting_system.cleanup_invalid_targets()
    for event: Dictionary in _monster_system.drain_lifecycle_events():
        if event["event_type"] == "DIED":
            _targeting_system.clear_entity_references(event["entity_id"])
            var monster_state: Dictionary = _monster_system.get_state(event["entity_id"])
            var spawned: Array[int] = _loot_system.process_monster_death(event, monster_state)
            var progression: Dictionary = _progression_system.get_state(event["killer_entity_id"])
            if not progression.is_empty(): print("[Aetherfall Zone] XP granted: player=%d level=%d xp=%d" % [event["killer_entity_id"], progression.level, progression.current_xp])
            if not spawned.is_empty(): print("[Aetherfall Zone] Loot spawned: ids=%s owner=%d" % [spawned, event["killer_entity_id"]])
        print(
            "[Aetherfall Zone] Monster %s: entity=%d tick=%d killer=%d" % [
                event["event_type"],
                event["entity_id"],
                event["server_tick"],
                event["killer_entity_id"],
            ]
        )
        monster_lifecycle_event.rpc(event)
    if current_tick % _snapshot_interval_ticks == 0:
        var player_snapshot: Dictionary = _movement_system.create_snapshot(current_tick)
        _player_health_system.decorate_player_snapshot(player_snapshot["entities"])
        _progression_system.decorate_player_snapshot(player_snapshot["entities"])
        _targeting_system.decorate_player_snapshot(player_snapshot["entities"])
        var snapshot: Dictionary = _monster_system.create_world_snapshot(
            current_tick,
            player_snapshot["entities"]
        )
        snapshot["entities"].append_array(_loot_system.create_snapshot_entities())
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

func _replicate_player_lifecycle_events() -> void:
    for event: Dictionary in _player_health_system.drain_lifecycle_events():
        var player_id: int = event["player_entity_id"]
        if event["event_type"] == "DIED":
            _movement_system.stop_player(player_id)
            _targeting_system.clear_player_target(player_id)
            _monster_system.clear_aggro_target(player_id)
        else:
            _movement_system.respawn_player(player_id, event["respawn_position"])
            _targeting_system.clear_player_target(player_id)
        print(
            "[Aetherfall Zone] Player %s: entity=%d tick=%d killer=%d" % [
                event["event_type"], player_id, event["server_tick"],
                event["killer_entity_id"],
            ]
        )
        player_lifecycle_event.rpc(event)

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
