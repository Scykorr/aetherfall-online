extends RefCounted

const ENTITY_REGISTRY_SCRIPT: Script = preload("res://scripts/entity_registry.gd")
const SESSION_REGISTRY_SCRIPT: Script = preload("res://scripts/session_registry.gd")
const HANDSHAKE_SERVICE_SCRIPT: Script = preload("res://scripts/network/handshake_service.gd")
const MOVEMENT_SYSTEM_SCRIPT: Script = preload("res://scripts/movement/movement_system.gd")
const LOADER_SCRIPT: Script = preload("res://scripts/monsters/monster_template_loader.gd")
const MONSTER_SYSTEM_SCRIPT: Script = preload("res://scripts/monsters/monster_system.gd")
const TEMPLATE_PATH := "shared/data/monsters/training_wisp.json"

func run(suite) -> void:
    _spawn_tests(suite)
    _ai_tests(suite)
    _replication_tests(suite)
    _ownership_tests(suite)
    _cleanup_tests(suite)

func _context(seed: int = 1337) -> Dictionary:
    var entities = ENTITY_REGISTRY_SCRIPT.new()
    var system = MONSTER_SYSTEM_SCRIPT.new(entities, seed)
    var template: Dictionary = LOADER_SCRIPT.load_template(TEMPLATE_PATH)
    var monster_id: int = system.spawn_monster(template, Vector3(6.0, 0.1, -2.0), 10)
    return {"entities": entities, "system": system, "template": template, "id": monster_id}

func _free(c: Dictionary) -> void:
    (c.entities as Node).free()

func _spawn_tests(suite) -> void:
    var c := _context()
    var metadata: Dictionary = c.entities.get_entity(c.id)
    var state: Dictionary = c.system.get_state(c.id)
    suite.check("MON-001 spawn creates monster entity", c.id > 0 and c.entities.get_entity_count() == 1)
    suite.check("MON-002 entity type is monster", metadata.entity_type == &"monster")
    suite.check("MON-003 template ID", metadata.template_id == "training_wisp")
    suite.check("MON-004 HP initialized", state.current_hp == state.max_hp and state.max_hp == 100)
    var second_id: int = c.system.spawn_monster(c.template, Vector3.ZERO, 11)
    suite.check("MON-005 unique entity ID", second_id != c.id)
    var position: Vector3 = state.position
    suite.check("MON-006 finite spawn position", is_finite(position.x) and is_finite(position.y) and is_finite(position.z))
    _free(c)

func _ai_tests(suite) -> void:
    var c := _context()
    suite.check("MON-AI-001 valid initial state", c.system.get_state(c.id).movement_state == &"IDLE")
    for _tick in 31:
        c.system.simulate_tick(1.0 / 30.0)
    var wandering: Dictionary = c.system.get_state(c.id)
    suite.check("MON-AI-002 IDLE transitions to WANDER", wandering.movement_state == &"WANDER")
    var target_offset: Vector3 = wandering.wander_target - wandering.spawn_position
    suite.check("MON-AI-003 target within radius", target_offset.length() <= wandering.wander_radius + 0.001)
    var before: Vector3 = wandering.position
    c.system.simulate_tick(1.0 / 30.0)
    var step: float = c.system.get_state(c.id).position.distance_to(before)
    suite.check("MON-AI-004 respects template move speed", step <= 2.5 / 30.0 + 0.001 and step > 0.0)
    var a := _context(77)
    var b := _context(77)
    for _tick in 120:
        a.system.simulate_tick(1.0 / 30.0)
        b.system.simulate_tick(1.0 / 30.0)
    suite.check("MON-AI-005 deterministic fixed seed", a.system.get_state(a.id).position.is_equal_approx(b.system.get_state(b.id).position))
    var reached_idle := false
    for _tick in 600:
        c.system.simulate_tick(1.0 / 30.0)
        if c.system.get_state(c.id).movement_state == &"IDLE":
            reached_idle = true
            break
    suite.check("MON-AI-006 arrival returns to IDLE", reached_idle)
    _free(a); _free(b); _free(c)

func _replication_tests(suite) -> void:
    var c := _context()
    var snapshot: Dictionary = c.system.create_world_snapshot(42)
    var replicated: Dictionary = snapshot.entities[0]
    suite.check("MON-NET-001 spawn state has authoritative ID", replicated.entity_id == c.id)
    suite.check("MON-NET-002 late join snapshot contains monster", snapshot.entities.size() == 1 and replicated.entity_type == "monster")
    var client_a_id: int = snapshot.entities[0].entity_id
    var client_b_id: int = c.system.create_world_snapshot(43).entities[0].entity_id
    suite.check("MON-NET-003 clients reference same monster ID", client_a_id == client_b_id)
    suite.check("MON-NET-004 snapshot contains server tick", snapshot.server_tick == 42)
    _free(c)

func _ownership_tests(suite) -> void:
    var c := _context()
    var sessions = SESSION_REGISTRY_SCRIPT.new()
    var handshake = HANDSHAKE_SERVICE_SCRIPT.new(c.entities, sessions, 1)
    sessions.create_pending_session(2, 0, 100)
    handshake.process_handshake(2, {"protocol_version": 1}, 1)
    var movement = MOVEMENT_SYSTEM_SCRIPT.new(sessions, c.entities, 5.0)
    movement.register_ready_player(2, Vector3.ZERO)
    var before: Vector3 = c.system.get_state(c.id).position
    movement.process_intent(2, {"command": "FOLLOW_CURSOR", "sequence": 1, "direction": Vector3.RIGHT, "entity_id": c.id}, 1)
    movement.simulate_tick(0.1)
    suite.check("MON-OWN-001 player intent cannot move monster", c.system.get_state(c.id).position == before)
    suite.check("MON-OWN-002 monster has no player session", sessions.get_session(2).entity_id != c.id)
    suite.check("MON-OWN-003 unknown peer cannot mutate monster", not movement.process_intent(404, {"command": "STOP", "sequence": 1, "entity_id": c.id}, 2) and c.system.get_state(c.id).position == before)
    sessions.free(); _free(c)

func _cleanup_tests(suite) -> void:
    var c := _context()
    var sessions = SESSION_REGISTRY_SCRIPT.new()
    var handshake = HANDSHAKE_SERVICE_SCRIPT.new(c.entities, sessions, 1)
    sessions.create_pending_session(2, 0, 100)
    handshake.process_handshake(2, {"protocol_version": 1}, 1)
    handshake.cleanup_peer(2)
    suite.check("MON-CLEAN-001 player disconnect preserves monster", not c.system.get_state(c.id).is_empty() and c.entities.get_entity_count() == 1)
    suite.check("MON-CLEAN-002 despawn removes entity", c.system.despawn_monster(c.id) and c.entities.get_entity_count() == 0)
    suite.check("MON-CLEAN-003 double despawn idempotent", not c.system.despawn_monster(c.id) and c.entities.get_entity_count() == 0)
    var c2 := _context()
    var sessions2 = SESSION_REGISTRY_SCRIPT.new()
    var handshake2 = HANDSHAKE_SERVICE_SCRIPT.new(c2.entities, sessions2, 1)
    for peer_id in [2, 3]:
        sessions2.create_pending_session(peer_id, 0, 100)
        handshake2.process_handshake(peer_id, {"protocol_version": 1}, 1)
        handshake2.cleanup_peer(peer_id)
    suite.check("MON-CLEAN-004 reconnects do not duplicate monster", c2.system.get_monster_count() == 1 and c2.entities.get_entity_count() == 1)
    sessions.free(); sessions2.free(); _free(c); _free(c2)
