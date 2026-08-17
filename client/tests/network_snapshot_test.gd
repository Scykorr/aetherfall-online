extends SceneTree

const SNAPSHOT_STORE_SCRIPT: Script = preload("res://scripts/network/snapshot_store.gd")
const INVENTORY_STORE_SCRIPT: Script = preload("res://scripts/inventory/inventory_state_store.gd")

var _passed: int = 0
var _failed: int = 0

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    _snapshot_tick()
    _snapshot_entity_id()
    _old_snapshot_ignored()
    _new_snapshot_replaces()
    _despawn_removes_entity()
    _old_monster_snapshot_ignored()
    _monster_despawn_removes_representation()
    _confirmed_target_replicates()
    _basic_attack_input_exists()
    _monster_lifecycle_snapshot()
    _player_hp_snapshot()
    _player_lifecycle_snapshot()
    _loot_snapshot_lifecycle()
    _inventory_replication()
    _inventory_input_exists()
    print("[TEST SUMMARY] passed=%d failed=%d skipped=0 total=%d" % [_passed, _failed, _passed + _failed])
    call_deferred("_finish")

func _snapshot(tick: int, entity_ids: Array[int]) -> Dictionary:
    var entities: Array[Dictionary] = []
    for entity_id in entity_ids:
        entities.append({
            "entity_id": entity_id,
            "entity_type": "player",
            "position": Vector3(float(tick), 0.0, 0.0),
            "velocity": Vector3.ZERO,
            "movement_mode": "STOP",
            "last_processed_input_sequence": 0,
            "current_target_entity_id": 0,
            "current_hp": 100,
            "max_hp": 100,
            "life_state": "ALIVE",
            "death_tick": -1,
            "respawn_tick": -1,
        })
    return {"server_tick": tick, "entities": entities}

func _check(name: String, condition: bool) -> void:
    if condition:
        _passed += 1
        print("[PASS] %s" % name)
    else:
        _failed += 1
        print("[FAIL] %s" % name)

func _snapshot_tick() -> void:
    var store = SNAPSHOT_STORE_SCRIPT.new()
    store.apply_snapshot(_snapshot(10, [1]))
    _check("SNAP-001 snapshot contains server tick", store.latest_server_tick == 10)

func _snapshot_entity_id() -> void:
    var store = SNAPSHOT_STORE_SCRIPT.new()
    store.apply_snapshot(_snapshot(10, [7]))
    _check("SNAP-002 snapshot contains entity ID", store.get_state(7).entity_id == 7)

func _old_snapshot_ignored() -> void:
    var store = SNAPSHOT_STORE_SCRIPT.new()
    store.apply_snapshot(_snapshot(101, [1]))
    _check("SNAP-003 old snapshot ignored", not store.apply_snapshot(_snapshot(100, [1])) and store.latest_server_tick == 101)

func _new_snapshot_replaces() -> void:
    var store = SNAPSHOT_STORE_SCRIPT.new()
    store.apply_snapshot(_snapshot(100, [1]))
    _check("SNAP-004 newer snapshot replaces state", store.apply_snapshot(_snapshot(101, [1])) and store.get_state(1).position.x == 101.0)

func _despawn_removes_entity() -> void:
    var store = SNAPSHOT_STORE_SCRIPT.new()
    store.apply_snapshot(_snapshot(100, [1, 2]))
    store.apply_snapshot(_snapshot(101, [1]))
    _check("SNAP-005 despawn removes remote entity", store.get_state(2).is_empty())

func _finish() -> void:
    quit(0 if _failed == 0 else 1)

func _monster_snapshot(tick: int, include_monster: bool = true) -> Dictionary:
    var entities: Array[Dictionary] = []
    if include_monster:
        entities.append({
            "entity_id": 1,
            "entity_type": "monster",
            "template_id": "training_wisp",
            "position": Vector3(float(tick), 0.1, 0.0),
            "velocity": Vector3.ZERO,
            "movement_state": "IDLE",
            "current_hp": 100,
            "max_hp": 100,
            "life_state": "ALIVE",
            "killer_entity_id": 0,
            "death_tick": -1,
            "respawn_tick": -1,
        })
    return {"server_tick": tick, "entities": entities}

func _old_monster_snapshot_ignored() -> void:
    var store = SNAPSHOT_STORE_SCRIPT.new()
    store.apply_snapshot(_monster_snapshot(101))
    _check(
        "MON-NET-005 old monster snapshot ignored",
        not store.apply_snapshot(_monster_snapshot(100))
        and store.get_state(1).position.x == 101.0
    )

func _monster_despawn_removes_representation() -> void:
    var store = SNAPSHOT_STORE_SCRIPT.new()
    store.apply_snapshot(_monster_snapshot(100))
    store.apply_snapshot(_monster_snapshot(101, false))
    _check("MON-NET-006 monster despawn removes state", store.get_state(1).is_empty())

func _confirmed_target_replicates() -> void:
    var snapshot := _snapshot(102, [2])
    snapshot.entities[0].current_target_entity_id = 1
    var store = SNAPSHOT_STORE_SCRIPT.new()
    store.apply_snapshot(snapshot)
    _check("TGT-NET-001 confirmed target replicates", store.get_state(2).current_target_entity_id == 1)

func _basic_attack_input_exists() -> void:
    _check("COM-INPUT-001 basic attack uses Input Map", InputMap.has_action("basic_attack"))

func _monster_lifecycle_snapshot() -> void:
    var store = SNAPSHOT_STORE_SCRIPT.new()
    var dead := _monster_snapshot(110)
    dead.entities[0].life_state = "DEAD"
    dead.entities[0].current_hp = 0
    dead.entities[0].killer_entity_id = 7
    store.apply_snapshot(dead)
    _check("DEATH-NET-001 dead state replicates", store.get_state(1).life_state == "DEAD" and store.get_state(1).current_hp == 0)
    var alive := _monster_snapshot(111)
    store.apply_snapshot(alive)
    _check("RESPAWN-NET-001 alive state replaces dead state", store.get_state(1).life_state == "ALIVE" and store.get_state(1).current_hp == 100)

func _player_hp_snapshot() -> void:
    var store = SNAPSHOT_STORE_SCRIPT.new()
    var snapshot := _snapshot(120, [7])
    snapshot.entities[0].current_hp = 60
    store.apply_snapshot(snapshot)
    _check(
        "PHP-006 authoritative HP replicates",
        store.get_state(7).current_hp == 60 and store.get_state(7).max_hp == 100
    )

func _player_lifecycle_snapshot() -> void:
    var store = SNAPSHOT_STORE_SCRIPT.new()
    var dead := _snapshot(130, [7])
    dead.entities[0].current_hp = 0
    dead.entities[0].life_state = "DEAD"
    dead.entities[0].death_tick = 130
    dead.entities[0].respawn_tick = 250
    store.apply_snapshot(dead)
    _check(
        "PDEATH-NET-001 death state replicates",
        store.get_state(7).life_state == "DEAD" and store.get_state(7).current_hp == 0
    )
    var alive := _snapshot(250, [7])
    store.apply_snapshot(alive)
    _check(
        "PRESP-NET-001 respawn state replicates",
        store.get_state(7).life_state == "ALIVE" and store.get_state(7).current_hp == 100
    )

func _loot_snapshot_lifecycle() -> void:
    var store = SNAPSHOT_STORE_SCRIPT.new()
    var loot := {"entity_id": 50, "entity_type": "loot", "item_id": "essence", "quantity": 1, "position": Vector3.ZERO, "velocity": Vector3.ZERO, "owner_entity_id": 2, "spawn_tick": 1, "despawn_tick": 100}
    store.apply_snapshot({"server_tick": 300, "entities": [loot]})
    _check("LOOT-NET-001 loot entity replicates", store.get_state(50).item_id == "essence")
    store.apply_snapshot({"server_tick": 301, "entities": []})
    _check("LOOT-LIFE-003 client receives despawn", store.get_state(50).is_empty())

func _inventory_replication() -> void:
    var store = INVENTORY_STORE_SCRIPT.new()
    var initial := {"inventory_revision": 0, "slot_count": 2, "slots": [{}, {}], "item_definitions": {}}
    _check("INV-NET-001 READY client receives inventory", store.apply_state(initial) and store.slot_count == 2)
    var updated := {"inventory_revision": 1, "slot_count": 2, "slots": [{"item_id": "essence", "quantity": 3}, {}], "item_definitions": {"essence": {"display_name": "Essence", "max_stack": 20}}}
    _check("INV-NET-003 new revision applied", store.apply_state(updated) and store.slots[0].quantity == 3)
    _check("INV-NET-004 old revision ignored client-side", not store.apply_state(initial) and store.inventory_revision == 1 and store.slots[0].quantity == 3)
    _check("INV-NET-005 pickup state matches server", store.get_state().slots[0].item_id == "essence")

func _inventory_input_exists() -> void:
    _check("INV-UI-001 inventory toggle uses Input Map", InputMap.has_action("toggle_inventory"))
