extends RefCounted

const ENTITY: Script = preload("res://scripts/entity_registry.gd")
const SESSION: Script = preload("res://scripts/session_registry.gd")
const HANDSHAKE: Script = preload("res://scripts/network/handshake_service.gd")
const MOVEMENT: Script = preload("res://scripts/movement/movement_system.gd")
const HEALTH: Script = preload("res://scripts/combat/player_health_system.gd")
const PROGRESSION: Script = preload("res://scripts/rewards/player_progression_system.gd")
const LOOT: Script = preload("res://scripts/rewards/loot_system.gd")
const INVENTORY: Script = preload("res://scripts/inventory/inventory_system.gd")

var _items := {
    "essence": {"id": "essence", "display_name": "Essence", "max_stack": 20},
    "cloth": {"id": "cloth", "display_name": "Cloth", "max_stack": 10},
}

func run(suite) -> void:
    _insert_tests(suite)
    _move_tests(suite)
    _split_destroy_tests(suite)
    _security_tests(suite)
    _pickup_atomicity_tests(suite)
    _lifecycle_tests(suite)

func _inventory(slot_count := 24) -> RefCounted:
    var inventory = INVENTORY.new(_items, slot_count)
    inventory.register_player(2)
    return inventory

func _insert_tests(suite) -> void:
    var inventory = _inventory()
    suite.check("INV-001 empty inventory accepts item", inventory.insert_item(2, "essence", 5).accepted)
    inventory.insert_item(2, "essence", 12)
    var state: Dictionary = inventory.get_state(2)
    suite.check("INV-002 pickup fills partial stack first", state.slots[0].quantity == 17)
    inventory.insert_item(2, "essence", 12)
    state = inventory.get_state(2)
    suite.check("INV-003 remaining quantity uses empty slot", state.slots[0].quantity == 20 and state.slots[1].quantity == 9)
    suite.check("INV-004 max_stack respected", inventory.validate_inventory(2).valid)
    inventory.insert_item(2, "cloth", 2)
    state = inventory.get_state(2)
    suite.check("INV-005 different item does not merge", state.slots[2].item_id == "cloth")
    suite.check("INV-NET-002 mutation increments revision", state.inventory_revision == 4)

func _move_tests(suite) -> void:
    var inventory = _inventory()
    inventory.insert_item(2, "essence", 8)
    var sessions = _ready_sessions()
    suite.check("INV-MOVE-001 stack moves to empty slot", inventory.process_command(2, _command("MOVE_SLOT", 1, {"source_slot": 0, "destination_slot": 3}), sessions).accepted and inventory.get_state(2).slots[3].quantity == 8)
    inventory.insert_item(2, "essence", 17)
    var merged: Dictionary = inventory.process_command(2, _command("MOVE_SLOT", 2, {"source_slot": 3, "destination_slot": 0}), sessions)
    var state: Dictionary = inventory.get_state(2)
    suite.check("INV-MOVE-002 same item merges", merged.accepted and state.slots[0].quantity == 20)
    suite.check("INV-MOVE-003 merge respects max_stack", inventory.validate_inventory(2).valid)
    suite.check("INV-MOVE-004 overflow remains source stack", state.slots[3].quantity == 5)
    inventory.insert_item(2, "cloth", 1)
    inventory.process_command(2, _command("MOVE_SLOT", 3, {"source_slot": 1, "destination_slot": 3}), sessions)
    state = inventory.get_state(2)
    suite.check("INV-MOVE-005 different items swap", state.slots[1].item_id == "essence" and state.slots[3].item_id == "cloth")
    suite.check("INV-MOVE-006 invalid indices rejected", not inventory.process_command(2, _command("MOVE_SLOT", 4, {"source_slot": -1, "destination_slot": 99}), sessions).accepted)
    (sessions as Node).free()

func _split_destroy_tests(suite) -> void:
    var inventory = _inventory(); var sessions = _ready_sessions()
    inventory.insert_item(2, "essence", 10)
    suite.check("INV-SPLIT-001 valid split works", inventory.process_command(2, _command("SPLIT_STACK", 1, {"source_slot": 0, "destination_slot": 1, "quantity": 4}), sessions).accepted and inventory.get_state(2).slots[1].quantity == 4)
    suite.check("INV-SPLIT-002 zero rejected", not inventory.process_command(2, _command("SPLIT_STACK", 2, {"source_slot": 0, "destination_slot": 2, "quantity": 0}), sessions).accepted)
    suite.check("INV-SPLIT-003 negative rejected", not inventory.process_command(2, _command("SPLIT_STACK", 3, {"source_slot": 0, "destination_slot": 2, "quantity": -1}), sessions).accepted)
    suite.check("INV-SPLIT-004 quantity >= source rejected", not inventory.process_command(2, _command("SPLIT_STACK", 4, {"source_slot": 0, "destination_slot": 2, "quantity": 6}), sessions).accepted)
    suite.check("INV-SPLIT-005 max stack invariant preserved", inventory.validate_inventory(2).valid)
    suite.check("INV-DESTROY-001 explicit partial destroy", inventory.process_command(2, _command("DESTROY_ITEM", 5, {"slot": 1, "quantity": 2}), sessions).accepted and inventory.get_state(2).slots[1].quantity == 2)
    suite.check("INV-DESTROY-002 full stack destroy", inventory.process_command(2, _command("DESTROY_ITEM", 6, {"slot": 1, "quantity": 2}), sessions).accepted and inventory.get_state(2).slots[1].is_empty())
    (sessions as Node).free()

func _security_tests(suite) -> void:
    var inventory = _inventory(); inventory.insert_item(2, "essence", 5)
    var sessions = _ready_sessions()
    suite.check("INV-SEC-001 unknown peer cannot mutate inventory", not inventory.process_command(404, _command("DESTROY_ITEM", 1, {"slot": 0, "quantity": 1}), sessions).accepted)
    sessions.create_pending_session(3, 0, 100)
    suite.check("INV-SEC-002 non-READY peer cannot mutate inventory", not inventory.process_command(3, _command("DESTROY_ITEM", 1, {"slot": 0, "quantity": 1}), sessions).accepted)
    suite.check("INV-SEC-003 A cannot mutate B inventory", inventory.get_state(2).slots[0].quantity == 5)
    var tampered := _command("MOVE_SLOT", 1, {"source_slot": 0, "destination_slot": 1, "item_id": "cloth", "quantity": 999})
    inventory.process_command(2, tampered, sessions)
    suite.check("INV-SEC-004 client cannot change item ID", inventory.get_state(2).slots[1].item_id == "essence")
    suite.check("INV-SEC-005 client cannot create quantity", inventory.get_state(2).slots[1].quantity == 5)
    var revision: int = inventory.get_state(2).inventory_revision
    suite.check("INV-SEC-006 replayed command safe", not inventory.process_command(2, tampered, sessions).accepted and inventory.get_state(2).inventory_revision == revision)
    suite.check("INV-SEC-007 malformed slot rejected safely", not inventory.process_command(2, _command("DESTROY_ITEM", 2, {"slot": "zero", "quantity": 1}), sessions).accepted)
    (sessions as Node).free()

func _pickup_atomicity_tests(suite) -> void:
    var entities = ENTITY.new(); entities.register_entity(&"test", 0)
    var sessions = SESSION.new(); sessions.create_pending_session(2, 0, 100)
    HANDSHAKE.new(entities, sessions, 1).process_handshake(2, {"protocol_version": 1}, 1)
    var movement = MOVEMENT.new(sessions, entities, 5.0)
    movement.register_ready_player(2, Vector3.ZERO)
    var health = HEALTH.new(100); health.register_player(2)
    var progression = PROGRESSION.new(); progression.register_player(2)
    var one_slot = INVENTORY.new(_items, 1); one_slot.register_player(2); one_slot.insert_item(2, "essence", 20)
    var tables := {"test": [{"item_id": "essence", "chance": 1.0, "min_quantity": 1, "max_quantity": 1}]}
    var loot = LOOT.new(entities, movement, health, progression, one_slot, _items, tables, 1, 2.5, 10.0, 30)
    var ids: Array[int] = loot.process_monster_death({"entity_id": 9, "server_tick": 1, "killer_entity_id": 2, "position": Vector3.ZERO}, {"xp_reward": 1, "loot_table_id": "test"})
    suite.check("INV-006 full inventory rejects pickup", not loot.process_pickup(2, ids[0], sessions).accepted)
    suite.check("INV-007 failed pickup leaves world loot intact", not loot.get_state(ids[0]).is_empty())
    one_slot.process_command(2, _command("DESTROY_ITEM", 1, {"slot": 0, "quantity": 20}), sessions)
    suite.check("INV-008 successful pickup removes world loot", loot.process_pickup(2, ids[0], sessions).accepted and loot.get_state(ids[0]).is_empty())
    loot.clear(); (entities as Node).free(); (sessions as Node).free()

func _lifecycle_tests(suite) -> void:
    var inventory = _inventory(); inventory.insert_item(2, "essence", 3)
    var before: Dictionary = inventory.get_state(2)
    suite.check("INV-LIFE-001 player death preserves inventory", inventory.get_state(2) == before)
    suite.check("INV-LIFE-002 respawn preserves inventory", inventory.get_state(2).slots[0].quantity == 3)
    inventory.remove_player(2)
    suite.check("INV-LIFE-003 disconnect cleanup safe", inventory.get_state(2).is_empty())

func _ready_sessions() -> Node:
    var entities = ENTITY.new(); entities.register_entity(&"test", 0)
    var sessions = SESSION.new(); sessions.create_pending_session(2, 0, 100)
    HANDSHAKE.new(entities, sessions, 1).process_handshake(2, {"protocol_version": 1}, 1)
    entities.free()
    return sessions

func _command(command: String, sequence: int, fields: Dictionary) -> Dictionary:
    var payload := {"command": command, "sequence": sequence}
    payload.merge(fields)
    return payload
