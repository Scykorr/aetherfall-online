extends SceneTree

const SNAPSHOT_STORE_SCRIPT: Script = preload("res://scripts/network/snapshot_store.gd")

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
