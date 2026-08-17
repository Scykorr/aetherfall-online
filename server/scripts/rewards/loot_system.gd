class_name LootSystem
extends RefCounted

var _entities: Node
var _movement: RefCounted
var _health: RefCounted
var _progression: RefCounted
var _inventory: RefCounted
var _items: Dictionary
var _tables: Dictionary
var _loot: Dictionary = {}
var _rewarded_deaths: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _pickup_range: float
var _lifetime_ticks: int

func _init(entities: Node, movement: RefCounted, health: RefCounted, progression: RefCounted, inventory: RefCounted, items: Dictionary, tables: Dictionary, seed: int, pickup_range: float, lifetime_seconds: float, tick_rate: int) -> void:
    _entities = entities; _movement = movement; _health = health; _progression = progression
    _inventory = inventory; _items = items; _tables = tables; _rng.seed = seed; _pickup_range = pickup_range
    _lifetime_ticks = maxi(1, int(ceil(lifetime_seconds * tick_rate)))

func process_monster_death(event: Dictionary, monster_state: Dictionary) -> Array[int]:
    var key := "%d:%d" % [event["entity_id"], event["server_tick"]]
    if _rewarded_deaths.has(key): return []
    _rewarded_deaths[key] = true
    var killer: int = event["killer_entity_id"]
    if killer <= 0 or not _progression.grant_xp(killer, int(monster_state.get("xp_reward", 0))): return []
    var spawned: Array[int] = []
    var entries: Array = _tables.get(monster_state.get("loot_table_id", ""), [])
    for entry: Dictionary in entries:
        if _rng.randf() > float(entry["chance"]): continue
        var item_id: String = entry["item_id"]
        if not _items.has(item_id): continue
        var quantity := _rng.randi_range(int(entry["min_quantity"]), int(entry["max_quantity"]))
        var id: int = _entities.register_entity(&"loot", event["server_tick"], {"item_id": item_id})
        _loot[id] = {"entity_id": id, "entity_type": "loot", "item_id": item_id, "quantity": quantity, "position": event["position"], "velocity": Vector3.ZERO, "owner_entity_id": killer, "spawn_tick": event["server_tick"], "despawn_tick": event["server_tick"] + _lifetime_ticks}
        spawned.append(id)
    return spawned

func process_pickup(peer_id: int, loot_id: Variant, sessions: Node) -> Dictionary:
    var session: Dictionary = sessions.get_session(peer_id)
    if not session.get("handshake_complete", false) or not loot_id is int: return {"accepted": false}
    var player_id: int = session["entity_id"]
    if not _health.is_alive(player_id) or not _loot.has(loot_id): return {"accepted": false}
    var loot: Dictionary = _loot[loot_id]
    var player: Dictionary = _movement.get_state(player_id)
    if loot["owner_entity_id"] != player_id or player.is_empty() or player.position.distance_to(loot.position) > _pickup_range: return {"accepted": false}
    if not _items.has(loot["item_id"]) or loot["quantity"] <= 0: return {"accepted": false, "reason": "INVALID_LOOT"}
    var insertion: Dictionary = _inventory.insert_item(player_id, loot["item_id"], loot["quantity"])
    if not insertion["accepted"]:
        return {"accepted": false, "reason": insertion["reason"]}
    _loot.erase(loot_id); _entities.remove_entity(loot_id)
    return {"accepted": true, "loot_entity_id": loot_id, "player_entity_id": player_id, "item_id": loot["item_id"], "quantity": loot["quantity"], "inventory_state": insertion["inventory_state"]}

func simulate_tick(tick: int) -> void:
    for id: int in _loot.keys():
        if tick >= int(_loot[id]["despawn_tick"]): _loot.erase(id); _entities.remove_entity(id)

func create_snapshot_entities() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for id: int in _loot: result.append((_loot[id] as Dictionary).duplicate(true))
    return result
func get_state(id: int) -> Dictionary: return (_loot[id] as Dictionary).duplicate(true) if _loot.has(id) else {}
func get_count() -> int: return _loot.size()
func clear() -> void:
    for id: int in _loot.keys(): _entities.remove_entity(id)
    _loot.clear(); _rewarded_deaths.clear()
