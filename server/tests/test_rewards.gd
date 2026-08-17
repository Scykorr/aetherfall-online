extends RefCounted

const ENTITY: Script = preload("res://scripts/entity_registry.gd")
const SESSION: Script = preload("res://scripts/session_registry.gd")
const HANDSHAKE: Script = preload("res://scripts/network/handshake_service.gd")
const MOVEMENT: Script = preload("res://scripts/movement/movement_system.gd")
const HEALTH: Script = preload("res://scripts/combat/player_health_system.gd")
const PROGRESSION: Script = preload("res://scripts/rewards/player_progression_system.gd")
const LOOT: Script = preload("res://scripts/rewards/loot_system.gd")
const INVENTORY: Script = preload("res://scripts/inventory/inventory_system.gd")

func run(suite) -> void:
    _xp_tests(suite); _loot_tests(suite); _pickup_tests(suite); _lifetime_tests(suite)

func _context(two_players := true, seed := 42, lifetime := 10.0) -> Dictionary:
    var entities = ENTITY.new(); var sessions = SESSION.new(); var movement = MOVEMENT.new(sessions, entities, 5.0)
    var health = HEALTH.new(100); var progression = PROGRESSION.new(); var handshake = HANDSHAKE.new(entities, sessions, 1)
    var players: Array[int] = []
    var count := 2 if two_players else 1
    for index in count:
        var peer := index + 2; sessions.create_pending_session(peer, 0, 100)
        var id: int = handshake.process_handshake(peer, {"protocol_version": 1}, 1).entity_id
        movement.register_ready_player(peer, Vector3(float(index), 0.0, 0.0)); health.register_player(id); progression.register_player(id); players.append(id)
    var items := {"essence": {"id": "essence", "max_stack": 99, "rarity": "common"}}
    var tables := {"test": [{"item_id": "essence", "chance": 1.0, "min_quantity": 1, "max_quantity": 2}]}
    var inventory = INVENTORY.new(items, 24)
    for player_id in players: inventory.register_player(player_id)
    var loot = LOOT.new(entities, movement, health, progression, inventory, items, tables, seed, 2.5, lifetime, 30)
    return {"entities": entities, "sessions": sessions, "movement": movement, "health": health, "progression": progression, "inventory": inventory, "loot": loot, "players": players, "items": items}

func _death(c: Dictionary, tick := 10, xp := 60) -> Array[int]:
    return c.loot.process_monster_death({"entity_id": 99, "server_tick": tick, "killer_entity_id": c.players[0], "position": Vector3(0.5, 0.0, 0.0)}, {"xp_reward": xp, "loot_table_id": "test"})

func _xp_tests(suite) -> void:
    var c := _context(); _death(c)
    suite.check("XP-001 kill grants configured XP", c.progression.get_state(c.players[0]).current_xp == 60)
    suite.check("XP-002 non-killer gets none", c.progression.get_state(c.players[1]).current_xp == 0)
    _death(c); suite.check("XP-003 duplicate death no duplicate XP", c.progression.get_state(c.players[0]).current_xp == 60)
    suite.check("XP-004 XP authoritative", c.progression.get_state(c.players[0]).level == 1)
    suite.check("XP-005 client cannot choose reward", not c.progression.grant_xp(999, 9999))
    c.progression.grant_xp(c.players[0], 40); suite.check("XP-006 level threshold", c.progression.get_state(c.players[0]).level == 2 and c.progression.get_state(c.players[0]).current_xp == 0)
    c.progression.grant_xp(c.players[0], 650); suite.check("XP-007 multi-level reward", c.progression.get_state(c.players[0]).level == 4 and c.progression.get_state(c.players[0]).current_xp == 150)
    _free(c)

func _loot_tests(suite) -> void:
    var a := _context(true, 77); var ids := _death(a); var state: Dictionary = a.loot.get_state(ids[0])
    suite.check("LOOT-001 death generates loot", ids.size() >= 1)
    suite.check("LOOT-002 item definition exists", a.items.has(state.item_id))
    suite.check("LOOT-003 quantity in bounds", state.quantity >= 1 and state.quantity <= 2)
    suite.check("LOOT-004 unique server ID", state.entity_id > max(a.players[0], a.players[1]))
    suite.check("LOOT-005 position server-derived", state.position == Vector3(0.5, 0.0, 0.0))
    suite.check("LOOT-006 owner authoritative killer", state.owner_entity_id == a.players[0])
    var b := _context(true, 77); var bid := _death(b)[0]
    suite.check("LOOT-007 deterministic seed", b.loot.get_state(bid).quantity == state.quantity)
    _free(a); _free(b)

func _pickup_tests(suite) -> void:
    var c := _context(); var id: int = _death(c)[0]; var expected: int = c.loot.get_state(id).quantity
    suite.check("PICK-004 other player rejected", not c.loot.process_pickup(3, id, c.sessions).accepted)
    var result: Dictionary = c.loot.process_pickup(2, id, c.sessions)
    suite.check("PICK-001 owner in range pickup", result.accepted)
    suite.check("PICK-002 inventory receives quantity", c.inventory.get_state(c.players[0]).slots[0].quantity == expected)
    suite.check("PICK-003 loot removed", c.loot.get_state(id).is_empty())
    suite.check("PICK-008 duplicate no reward", not c.loot.process_pickup(2, id, c.sessions).accepted and c.inventory.get_state(c.players[0]).slots[0].quantity == expected)
    suite.check("PICK-009 replay safe", not c.loot.process_pickup(2, id, c.sessions).accepted)
    var far := _context(); var far_id: int = _death(far)[0]
    far.movement.process_intent(2, {"command": "MOVE_TO_POINT", "sequence": 1, "destination": Vector3(10.0, 0.0, 0.0)}, 1); far.movement.simulate_tick(2.0)
    suite.check("PICK-005 out of range rejected", not far.loot.process_pickup(2, far_id, far.sessions).accepted)
    var dead := _context(); var dead_id: int = _death(dead)[0]; dead.health.apply_server_damage(dead.players[0], 100, 9, 2)
    suite.check("PICK-006 dead player rejected", not dead.loot.process_pickup(2, dead_id, dead.sessions).accepted)
    suite.check("PICK-007 unknown peer rejected", not dead.loot.process_pickup(404, dead_id, dead.sessions).accepted)
    _free(c); _free(far); _free(dead)

func _lifetime_tests(suite) -> void:
    var c := _context(false, 1, 1.0); var id: int = _death(c, 10)[0]
    c.loot.simulate_tick(39); suite.check("LOOT-LIFE-001 exists before timeout", not c.loot.get_state(id).is_empty())
    suite.check("LOOT-LIFE-004 monster respawn independent", not c.loot.get_state(id).is_empty())
    c.loot.simulate_tick(40); suite.check("LOOT-LIFE-002 removed at timeout", c.loot.get_state(id).is_empty())
    _free(c)

func _free(c: Dictionary) -> void:
    c.loot.clear(); (c.entities as Node).free(); (c.sessions as Node).free()
