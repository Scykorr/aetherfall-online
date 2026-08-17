extends Node

const SNAPSHOT_STORE_SCRIPT: Script = preload("res://scripts/network/snapshot_store.gd")
const NETWORK_CONFIG_SCRIPT: Script = preload("res://scripts/network/network_config.gd")
const INVENTORY_STORE_SCRIPT: Script = preload("res://scripts/inventory/inventory_state_store.gd")

signal state_changed(new_state: ConnectionState)
signal snapshot_received(snapshot: Dictionary)
signal combat_event_received(event: Dictionary)
signal combat_rejection_received(reason: String)
signal monster_lifecycle_received(event: Dictionary)
signal player_lifecycle_received(event: Dictionary)
signal inventory_state_received(state: Dictionary)
signal inventory_rejection_received(reason: String)

enum ConnectionState {
    DISCONNECTED,
    CONNECTING,
    CONNECTED,
    HANDSHAKING,
    READY,
    FAILED,
}

var state: ConnectionState = ConnectionState.DISCONNECTED
var assigned_entity_id: int = 0
var zone_id: String = ""
var server_tick: int = 0
var movement_mode: String = "STOP"
var last_input_sequence: int = 0
var last_ack_sequence: int = 0
var confirmed_target_entity_id: int = 0
var last_attack_sequence: int = 0
var last_inventory_sequence: int = 0

var _config = NETWORK_CONFIG_SCRIPT.new()
var _peer: ENetMultiplayerPeer
var _shutdown_after_seconds: float = 0.0
var _duplicate_handshake: bool = false
var _skip_handshake: bool = false
var _malformed_handshake: bool = false
var _snapshot_store = SNAPSHOT_STORE_SCRIPT.new()
var _inventory_store = INVENTORY_STORE_SCRIPT.new()
var _last_follow_sent_usec: int = 0
var _last_follow_direction: Vector3 = Vector3.ZERO
var _movement_test_mode: String = ""
var _target_test_first_monster: bool = false
var _target_test_requested: bool = false
var _combat_test_mode: String = ""
var _combat_test_target_requested: bool = false
var _combat_test_move_requested: bool = false
var _combat_test_attack_count: int = 0
var _combat_test_first_attack_tick: int = -1
var _combat_test_saw_death: bool = false
var _combat_test_saw_respawn: bool = false
var _combat_test_last_attack_tick: int = -1000
var _combat_test_last_chase_tick: int = -1000
var _ai_test_mode: String = ""
var _last_local_hp: int = -1
var _last_monster_ai_state: String = ""
var _last_monster_aggro_target: int = -1
var _player_lifecycle_test: bool = false
var _post_respawn_stage: int = 0
var _observed_player_life_states: Dictionary = {}
var _loot_test_mode: String = ""
var _loot_test_requested: bool = false
var _loot_seen_tick: int = -1
var _inventory_test_mode: String = ""
var _inventory_test_stage: int = 0
var _inventory_full_rejected_loot_id: int = 0
var _inventory_full_rejected_tick: int = -1

func _unhandled_input(event: InputEvent) -> void:
    if _is_world_input_blocked():
        return
    if event.is_action_pressed("basic_attack"):
        request_basic_attack()
    elif event.is_action_pressed("interact"):
        request_first_loot_pickup()

func request_first_loot_pickup() -> void:
    if state != ConnectionState.READY: return
    for entity: Dictionary in _snapshot_store.entity_states.values():
        if entity.get("entity_type") == "loot":
            pickup_intent.rpc_id(1, entity["entity_id"]); return

func request_inventory_move(source_slot: int, destination_slot: int) -> void:
    _send_inventory_command("MOVE_SLOT", {"source_slot": source_slot, "destination_slot": destination_slot})

func request_inventory_split(source_slot: int, destination_slot: int, quantity: int) -> void:
    _send_inventory_command("SPLIT_STACK", {"source_slot": source_slot, "destination_slot": destination_slot, "quantity": quantity})

func request_inventory_destroy(slot: int, quantity: int) -> void:
    _send_inventory_command("DESTROY_ITEM", {"slot": slot, "quantity": quantity})

func has_inventory_state() -> bool:
    return _inventory_store.inventory_revision >= 0

func get_inventory_state() -> Dictionary:
    return _inventory_store.get_state()

func _send_inventory_command(command: String, fields: Dictionary) -> void:
    if state != ConnectionState.READY:
        return
    last_inventory_sequence += 1
    var payload := {"command": command, "sequence": last_inventory_sequence}
    payload.merge(fields)
    inventory_intent.rpc_id(1, payload)

func _ready() -> void:
    _read_development_arguments()
    get_tree().create_timer(0.1).timeout.connect(connect_to_zone)
    if _shutdown_after_seconds > 0.0:
        get_tree().create_timer(_shutdown_after_seconds).timeout.connect(_quit_test_client)

func connect_to_zone() -> void:
    if state != ConnectionState.DISCONNECTED and state != ConnectionState.FAILED:
        return
    assigned_entity_id = 0
    zone_id = ""
    server_tick = 0
    confirmed_target_entity_id = 0
    last_attack_sequence = 0
    last_inventory_sequence = 0
    _inventory_store.reset()
    _combat_test_target_requested = false
    _combat_test_move_requested = false
    _combat_test_attack_count = 0
    _combat_test_first_attack_tick = -1
    _combat_test_saw_death = false
    _combat_test_saw_respawn = false
    _combat_test_last_attack_tick = -1000
    _combat_test_last_chase_tick = -1000
    _last_local_hp = -1
    _last_monster_ai_state = ""
    _last_monster_aggro_target = -1
    _peer = ENetMultiplayerPeer.new()
    var error := _peer.create_client(_config.host, _config.port)
    if error != OK:
        _fail("cannot create ENet client: %s" % error_string(error))
        return
    multiplayer.multiplayer_peer = _peer
    multiplayer.connected_to_server.connect(_on_connected_to_server)
    multiplayer.connection_failed.connect(_on_connection_failed)
    multiplayer.server_disconnected.connect(_on_server_disconnected)
    _set_state(ConnectionState.CONNECTING)
    print("[Aetherfall Client] Connecting to %s:%d" % [_config.host, _config.port])

func disconnect_from_zone() -> void:
    _disconnect_transport()
    _set_state(ConnectionState.DISCONNECTED)

func get_state_name() -> String:
    return ConnectionState.keys()[state]

func send_move_to_point(destination: Vector3) -> void:
    if state != ConnectionState.READY:
        return
    last_input_sequence += 1
    movement_mode = "MOVE_TO_POINT"
    movement_intent.rpc_id(1, {
        "command": movement_mode,
        "sequence": last_input_sequence,
        "destination": destination,
    })

func send_follow_direction(direction: Vector3, force: bool = false) -> void:
    if state != ConnectionState.READY or direction.is_zero_approx():
        return
    var normalized := Vector3(direction.x, 0.0, direction.z).normalized()
    var interval_usec := int(1_000_000.0 / float(_config.movement_send_rate))
    var now := Time.get_ticks_usec()
    var changed := normalized.dot(_last_follow_direction) < 0.995
    if not force and not changed and now - _last_follow_sent_usec < interval_usec:
        return
    last_input_sequence += 1
    movement_mode = "FOLLOW_CURSOR"
    _last_follow_sent_usec = now
    _last_follow_direction = normalized
    movement_intent.rpc_id(1, {
        "command": movement_mode,
        "sequence": last_input_sequence,
        "direction": normalized,
    })

func send_stop() -> void:
    if state != ConnectionState.READY:
        return
    last_input_sequence += 1
    movement_mode = "STOP"
    movement_intent.rpc_id(1, {
        "command": movement_mode,
        "sequence": last_input_sequence,
    })

func request_target(candidate_entity_id: int) -> void:
    if state == ConnectionState.READY:
        target_intent.rpc_id(1, candidate_entity_id)

func request_basic_attack() -> void:
    if state != ConnectionState.READY or confirmed_target_entity_id <= 0:
        return
    last_attack_sequence += 1
    attack_intent.rpc_id(1, {"sequence": last_attack_sequence})

@rpc("any_peer", "call_remote", "reliable")
func request_handshake(_payload: Variant) -> void:
    pass

@rpc("authority", "call_remote", "reliable")
func handshake_accepted(payload: Dictionary) -> void:
    if multiplayer.get_remote_sender_id() != MultiplayerPeer.TARGET_PEER_SERVER:
        return
    if state != ConnectionState.HANDSHAKING:
        _fail("unexpected handshake acceptance")
        return
    if not _is_valid_acceptance(payload):
        _fail("malformed handshake acceptance")
        return
    assigned_entity_id = payload["entity_id"]
    zone_id = payload["zone_id"]
    server_tick = payload["server_tick"]
    _set_state(ConnectionState.READY)
    print("[Aetherfall Client] Handshake accepted")
    print("[Aetherfall Client] Entity ID: %d" % assigned_entity_id)
    print("[Aetherfall Client] Zone: %s" % zone_id)
    print("[Aetherfall Client] Network state: READY")
    if _duplicate_handshake:
        request_handshake.rpc_id(1, {"protocol_version": _config.protocol_version})
    if not _movement_test_mode.is_empty():
        get_tree().create_timer(0.5).timeout.connect(_start_movement_test)

@rpc("authority", "call_remote", "reliable")
func handshake_rejected(reason: String) -> void:
    if multiplayer.get_remote_sender_id() != MultiplayerPeer.TARGET_PEER_SERVER:
        return
    _fail("handshake rejected: %s" % reason)

@rpc("any_peer", "call_remote", "unreliable_ordered")
func movement_intent(_payload: Variant) -> void:
    pass

@rpc("any_peer", "call_remote", "reliable")
func target_intent(_candidate_entity_id: Variant) -> void:
    pass

@rpc("any_peer", "call_remote", "reliable")
func attack_intent(_payload: Variant) -> void:
    pass

@rpc("any_peer", "call_remote", "reliable")
func pickup_intent(_loot_entity_id: Variant) -> void: pass
@rpc("authority", "call_remote", "reliable")
func pickup_result(result: Dictionary) -> void:
    print("[Aetherfall Client] Loot picked: loot=%d player=%d item=%s quantity=%d" % [result.loot_entity_id, result.player_entity_id, result.item_id, result.quantity])
@rpc("authority", "call_remote", "reliable")
func pickup_rejected(loot_entity_id: int, reason: String) -> void:
    print("[Aetherfall Client] Loot pickup rejected: %d reason=%s" % [loot_entity_id, reason])
    if _inventory_test_mode == "full" and reason == "INVENTORY_FULL":
        _inventory_full_rejected_loot_id = loot_entity_id
        _inventory_full_rejected_tick = server_tick

@rpc("any_peer", "call_remote", "reliable")
func inventory_intent(_payload: Variant) -> void: pass

@rpc("authority", "call_remote", "reliable")
func inventory_state(next_state: Dictionary) -> void:
    if multiplayer.get_remote_sender_id() != MultiplayerPeer.TARGET_PEER_SERVER:
        return
    if _inventory_store.apply_state(next_state):
        inventory_state_received.emit(_inventory_store.get_state())
        print("[Aetherfall Client] Inventory revision=%d" % _inventory_store.inventory_revision)
        _run_inventory_test(_inventory_store.get_state())

@rpc("authority", "call_remote", "reliable")
func inventory_rejected(reason: String) -> void:
    inventory_rejection_received.emit(reason)
    print("[Aetherfall Client] Inventory rejected: %s" % reason)

@rpc("authority", "call_remote", "reliable")
func combat_result(event: Dictionary) -> void:
    combat_event_received.emit(event)
    print(
        "[Aetherfall Client] Combat HIT: attacker=%d target=%d damage=%d hp=%d tick=%d sequence=%d" % [
            event["attacker_entity_id"],
            event["target_entity_id"],
            event["damage"],
            event["target_current_hp"],
            event["server_tick"],
            event["attack_sequence"],
        ]
    )

@rpc("authority", "call_remote", "reliable")
func combat_rejected(reason: String) -> void:
    combat_rejection_received.emit(reason)
    print("[Aetherfall Client] Combat rejected: %s" % reason)

@rpc("authority", "call_remote", "reliable")
func player_lifecycle_event(event: Dictionary) -> void:
    if (
        _player_lifecycle_test
        and event.get("player_entity_id") == assigned_entity_id
        and event.get("event_type") == "RESPAWNED"
    ):
        _post_respawn_stage = 1
    player_lifecycle_received.emit(event)
    print(
        "[Aetherfall Client] Player %s: entity=%d tick=%d killer=%d" % [
            event["event_type"], event["player_entity_id"],
            event["server_tick"], event["killer_entity_id"],
        ]
    )

@rpc("authority", "call_remote", "reliable")
func monster_lifecycle_event(event: Dictionary) -> void:
    if event.get("event_type") == "DIED":
        _combat_test_saw_death = true
    elif event.get("event_type") == "RESPAWNED":
        _combat_test_saw_respawn = true
    monster_lifecycle_received.emit(event)
    print(
        "[Aetherfall Client] Monster %s: entity=%d hp=%d/%d tick=%d killer=%d" % [
            event["event_type"],
            event["entity_id"],
            event["current_hp"],
            event["max_hp"],
            event["server_tick"],
            event["killer_entity_id"],
        ]
    )

@rpc("authority", "call_remote", "reliable")
func movement_snapshot(snapshot: Dictionary) -> void:
    if multiplayer.get_remote_sender_id() != MultiplayerPeer.TARGET_PEER_SERVER:
        return
    if state != ConnectionState.READY or not _snapshot_store.apply_snapshot(snapshot):
        return
    server_tick = _snapshot_store.latest_server_tick
    var local_state: Dictionary = _snapshot_store.get_state(assigned_entity_id)
    if not local_state.is_empty():
        var previous_target := confirmed_target_entity_id
        movement_mode = local_state["movement_mode"]
        last_ack_sequence = local_state["last_processed_input_sequence"]
        confirmed_target_entity_id = local_state.get("current_target_entity_id", 0)
        if previous_target != confirmed_target_entity_id:
            print(
                "[Aetherfall Client] Confirmed target: %s" % (
                    str(confirmed_target_entity_id)
                    if confirmed_target_entity_id > 0
                    else "none"
                )
            )
        var local_hp: int = local_state.get("current_hp", -1)
        if local_hp != _last_local_hp:
            _last_local_hp = local_hp
            print(
                "[Aetherfall Client] Authoritative player HP: %d / %d"
                % [local_hp, local_state.get("max_hp", -1)]
            )
        print_progression_if_changed(local_state)
    if not _ai_test_mode.is_empty():
        for entity: Dictionary in snapshot["entities"]:
            if entity["entity_type"] == "player":
                var previous_life: String = _observed_player_life_states.get(
                    entity["entity_id"], ""
                )
                var player_life: String = entity.get("life_state", "ALIVE")
                if previous_life != player_life:
                    _observed_player_life_states[entity["entity_id"]] = player_life
                    print(
                        "[Aetherfall Client] Player state: entity=%d life=%s hp=%d position=%s" % [
                            entity["entity_id"], player_life,
                            entity.get("current_hp", -1), entity["position"],
                        ]
                    )
            if entity["entity_type"] == "monster":
                var ai_state: String = entity["movement_state"]
                var aggro_target: int = entity.get("aggro_target_entity_id", 0)
                if ai_state != _last_monster_ai_state or aggro_target != _last_monster_aggro_target:
                    _last_monster_ai_state = ai_state
                    _last_monster_aggro_target = aggro_target
                    print(
                        "[Aetherfall Client] Monster AI: entity=%d state=%s aggro=%d hp=%d/%d" % [
                            entity["entity_id"], ai_state,
                            aggro_target, entity.get("current_hp", -1),
                            entity.get("max_hp", -1),
                        ]
                    )
                break
    if _player_lifecycle_test:
        _run_player_lifecycle_test(snapshot, local_state)
    _run_loot_test(snapshot)
    _verify_full_inventory_loot(snapshot)
    if _target_test_first_monster and not _target_test_requested:
        for entity: Dictionary in snapshot["entities"]:
            if entity["entity_type"] == "monster":
                _target_test_requested = true
                request_target(entity["entity_id"])
                print(
                    "[Aetherfall Client] Target test requested: %d"
                    % entity["entity_id"]
                )
                break
    snapshot_received.emit(snapshot)
    _run_combat_test(snapshot, local_state)
    if not _movement_test_mode.is_empty() and server_tick % 15 == 0:
        var remote_positions: Array[String] = []
        for entity: Dictionary in snapshot["entities"]:
            if entity["entity_id"] != assigned_entity_id:
                remote_positions.append(
                    "%d/%s:%s" % [
                        entity["entity_id"],
                        entity["entity_type"],
                        entity["position"],
                    ]
                )
        print(
            "[Aetherfall Client] Movement test snapshot: tick=%d local=%s remotes=%s ack=%d" % [
                server_tick,
                local_state.get("position", Vector3.ZERO),
                ",".join(remote_positions),
                last_ack_sequence,
            ]
        )

func print_progression_if_changed(local_state: Dictionary) -> void:
    var key := "%d:%d" % [local_state.get("level", 1), local_state.get("current_xp", 0)]
    if get_meta("progression_key", "") == key: return
    set_meta("progression_key", key)
    print("[Aetherfall Client] Progression: level=%d xp=%d next=%d" % [local_state.get("level", 1), local_state.get("current_xp", 0), local_state.get("xp_to_next_level", 100)])

func _on_connected_to_server() -> void:
    _set_state(ConnectionState.CONNECTED)
    print("[Aetherfall Client] Transport connected")
    if _skip_handshake:
        return
    _set_state(ConnectionState.HANDSHAKING)
    print("[Aetherfall Client] Sending handshake protocol=%d" % _config.protocol_version)
    if _malformed_handshake:
        request_handshake.rpc_id(1, {"unexpected_field": true})
    else:
        request_handshake.rpc_id(1, {"protocol_version": _config.protocol_version})

func _on_connection_failed() -> void:
    _fail("transport connection failed")

func _on_server_disconnected() -> void:
    if state != ConnectionState.FAILED:
        print("[Aetherfall Client] Server disconnected")
        _set_state(ConnectionState.DISCONNECTED)
    _disconnect_transport()

func _is_valid_acceptance(payload: Dictionary) -> bool:
    return (
        payload.get("entity_id", 0) is int
        and payload.get("entity_id", 0) > 0
        and payload.get("zone_id", "") is String
        and payload.get("server_tick", -1) is int
        and payload.get("protocol_version", 0) == NETWORK_CONFIG_SCRIPT.PROTOCOL_VERSION
    )

func _fail(reason: String) -> void:
    print("[Aetherfall Client] Failed: %s" % reason)
    _set_state(ConnectionState.FAILED)

func _set_state(new_state: ConnectionState) -> void:
    if state == new_state:
        return
    state = new_state
    state_changed.emit(state)

func _disconnect_transport() -> void:
    if _peer != null:
        _peer.close()
    multiplayer.multiplayer_peer = null
    _peer = null
    confirmed_target_entity_id = 0
    _inventory_store.reset()

func _is_world_input_blocked() -> bool:
    for node: Node in get_tree().get_nodes_in_group("inventory_ui"):
        if node.has_method("is_world_input_blocked") and node.call("is_world_input_blocked"):
            return true
    return false

func _read_development_arguments() -> void:
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--network-host="):
            _config.host = argument.trim_prefix("--network-host=")
        elif argument.begins_with("--network-port="):
            _config.port = argument.trim_prefix("--network-port=").to_int()
        elif argument.begins_with("--protocol-version="):
            _config.protocol_version = argument.trim_prefix("--protocol-version=").to_int()
        elif argument.begins_with("--shutdown-after="):
            _shutdown_after_seconds = argument.trim_prefix("--shutdown-after=").to_float()
        elif argument == "--duplicate-handshake":
            _duplicate_handshake = true
        elif argument == "--skip-handshake":
            _skip_handshake = true
        elif argument == "--malformed-handshake":
            _malformed_handshake = true
        elif argument.begins_with("--movement-test="):
            _movement_test_mode = argument.trim_prefix("--movement-test=")
        elif argument == "--target-test=first-monster":
            _target_test_first_monster = true
        elif argument.begins_with("--combat-test="):
            _combat_test_mode = argument.trim_prefix("--combat-test=")
        elif argument.begins_with("--ai-test="):
            _ai_test_mode = argument.trim_prefix("--ai-test=")
        elif argument == "--player-lifecycle-test":
            _player_lifecycle_test = true
        elif argument.begins_with("--loot-test="):
            _loot_test_mode = argument.trim_prefix("--loot-test=")
        elif argument.begins_with("--inventory-test="):
            _inventory_test_mode = argument.trim_prefix("--inventory-test=")

func _quit_test_client() -> void:
    disconnect_from_zone()
    get_tree().quit()

func _start_movement_test() -> void:
    if _movement_test_mode == "move_to_point":
        send_move_to_point(Vector3(4.0, 0.1, 0.0))
    elif _movement_test_mode == "follow_cursor":
        send_follow_direction(Vector3.FORWARD, true)
        get_tree().create_timer(3.0).timeout.connect(send_stop)
    elif _movement_test_mode == "leash":
        send_move_to_point(Vector3(-12.0, 0.1, 0.0))

func _run_combat_test(snapshot: Dictionary, local_state: Dictionary) -> void:
    if _combat_test_mode.is_empty() or local_state.is_empty():
        return
    var monster: Dictionary = {}
    for entity: Dictionary in snapshot["entities"]:
        if entity["entity_type"] == "monster":
            monster = entity
            break
    if monster.is_empty():
        return
    if _combat_test_mode == "survivor" and monster.get("aggro_target_entity_id", 0) != assigned_entity_id:
        return
    if _combat_test_mode == "lifecycle" and monster.get("life_state") == "DEAD":
        return
    if (
        _combat_test_mode == "lifecycle"
        and _combat_test_saw_respawn
        and confirmed_target_entity_id <= 0
    ):
        _combat_test_saw_respawn = false
        request_target(monster["entity_id"])
        print("[Aetherfall Client] Lifecycle test retarget requested after respawn")
        return
    if not _combat_test_target_requested:
        _combat_test_target_requested = true
        request_target(monster["entity_id"])
        return
    if confirmed_target_entity_id <= 0:
        return
    if _combat_test_mode == "out-of-range":
        if _combat_test_attack_count == 0:
            _combat_test_attack_count = 1
            request_basic_attack()
        return
    var local_position: Vector3 = local_state["position"]
    var monster_position: Vector3 = monster["position"]
    if not _combat_test_move_requested:
        var away := local_position - monster_position
        away.y = 0.0
        if away.is_zero_approx():
            away = Vector3.LEFT
        _combat_test_move_requested = true
        send_move_to_point(monster_position + away.normalized() * 1.5)
        return
    if local_position.distance_to(monster_position) > 2.4:
        if (
            _combat_test_mode == "lifecycle"
            and server_tick >= _combat_test_last_chase_tick + 15
        ):
            _combat_test_last_chase_tick = server_tick
            send_move_to_point(monster_position)
        return
    if _combat_test_attack_count == 0:
        _combat_test_attack_count = 1
        _combat_test_first_attack_tick = server_tick
        _combat_test_last_attack_tick = server_tick
        request_basic_attack()
        if _combat_test_mode == "cooldown":
            _combat_test_attack_count = 2
            request_basic_attack()
    elif (
        _combat_test_mode in ["lifecycle", "partial"]
        and (_combat_test_mode != "partial" or _combat_test_attack_count < 5)
        and server_tick >= _combat_test_last_attack_tick + 31
    ):
        _combat_test_last_attack_tick = server_tick
        _combat_test_attack_count += 1
        request_basic_attack()
    elif (
        _combat_test_mode == "cooldown"
        and _combat_test_attack_count == 2
        and server_tick >= _combat_test_first_attack_tick + 35
    ):
        _combat_test_attack_count = 3
        request_basic_attack()

func _run_player_lifecycle_test(snapshot: Dictionary, local_state: Dictionary) -> void:
    if _post_respawn_stage == 0 or local_state.get("life_state") != "ALIVE":
        return
    var monster: Dictionary = {}
    for entity: Dictionary in snapshot["entities"]:
        if entity["entity_type"] == "monster" and entity.get("life_state") == "ALIVE":
            monster = entity
            break
    if monster.is_empty():
        return
    if _post_respawn_stage == 1:
        _post_respawn_stage = 2
        send_move_to_point(monster["position"])
        print("[Aetherfall Client] Post-respawn movement requested")
    elif _post_respawn_stage == 2 and local_state["position"].distance_to(monster["position"]) <= 2.4:
        _post_respawn_stage = 3
        send_stop()
        request_target(monster["entity_id"])
        print("[Aetherfall Client] Post-respawn target requested")
    elif _post_respawn_stage == 3 and confirmed_target_entity_id == monster["entity_id"]:
        _post_respawn_stage = 4
        request_basic_attack()
        print("[Aetherfall Client] Post-respawn attack requested")

func _run_loot_test(snapshot: Dictionary) -> void:
    if _loot_test_mode.is_empty() or _loot_test_requested: return
    for entity: Dictionary in snapshot["entities"]:
        if entity["entity_type"] != "loot": continue
        if _loot_seen_tick < 0: _loot_seen_tick = server_tick
        var delay := 12 if _loot_test_mode == "owner" else 0
        if server_tick < _loot_seen_tick + delay: return
        _loot_test_requested = true
        pickup_intent.rpc_id(1, entity["entity_id"])
        print("[Aetherfall Client] Loot test pickup requested: mode=%s loot=%d" % [_loot_test_mode, entity["entity_id"]])
        return

func _run_inventory_test(inventory: Dictionary) -> void:
    if _inventory_test_mode != "owner":
        return
    var slots: Array = inventory.get("slots", [])
    match _inventory_test_stage:
        0:
            if slots.size() > 0 and not slots[0].is_empty() and int(slots[0].get("quantity", 0)) >= 4:
                _inventory_test_stage = 1
                request_inventory_move(0, 1)
                print("[Aetherfall Client] Inventory integration MOVE requested")
        1:
            if slots.size() > 1 and slots[0].is_empty() and int(slots[1].get("quantity", 0)) >= 4:
                _inventory_test_stage = 2
                request_inventory_split(1, 2, 2)
                print("[Aetherfall Client] Inventory integration SPLIT requested")
        2:
            if slots.size() > 2 and int(slots[1].get("quantity", 0)) == 2 and int(slots[2].get("quantity", 0)) == 2:
                _inventory_test_stage = 3
                request_inventory_move(2, 1)
                print("[Aetherfall Client] Inventory integration MERGE requested")
        3:
            if slots.size() > 2 and int(slots[1].get("quantity", 0)) == 4 and slots[2].is_empty():
                _inventory_test_stage = 4
                print("[Aetherfall Client] Inventory integration PASS revision=%d quantity=%d" % [inventory.inventory_revision, slots[1].quantity])

func _verify_full_inventory_loot(snapshot: Dictionary) -> void:
    if _inventory_full_rejected_loot_id <= 0 or server_tick < _inventory_full_rejected_tick + 6:
        return
    for entity: Dictionary in snapshot.get("entities", []):
        if entity.get("entity_id") == _inventory_full_rejected_loot_id and entity.get("entity_type") == "loot":
            print("[Aetherfall Client] Full inventory integration PASS loot remains=%d" % _inventory_full_rejected_loot_id)
            _inventory_full_rejected_loot_id = 0
            return
