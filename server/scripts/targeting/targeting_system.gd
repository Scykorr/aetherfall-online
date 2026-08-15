class_name TargetingSystem
extends RefCounted

var _sessions: Node
var _entities: Node
var _movement: RefCounted
var _monsters: RefCounted
var _selection_range: float
var _targets: Dictionary = {}

func _init(
    sessions: Node,
    entities: Node,
    movement: RefCounted,
    monsters: RefCounted,
    selection_range: float
) -> void:
    _sessions = sessions
    _entities = entities
    _movement = movement
    _monsters = monsters
    _selection_range = selection_range

func request_target(peer_id: int, candidate: Variant) -> bool:
    var session: Dictionary = _sessions.get_session(peer_id)
    if not session.get("handshake_complete", false):
        return false
    var player_id: int = session.get("entity_id", 0)
    if player_id <= 0 or _entities.get_entity(player_id).is_empty():
        return false
    if not candidate is int:
        return false
    var candidate_id: int = candidate
    if candidate_id == 0:
        _targets[player_id] = 0
        return true
    if candidate_id == player_id:
        return false
    var candidate_entity: Dictionary = _entities.get_entity(candidate_id)
    if candidate_entity.is_empty() or candidate_entity.get("entity_type") != &"monster":
        return false
    var player_state: Dictionary = _movement.get_state(player_id)
    var monster_state: Dictionary = _monsters.get_state(candidate_id)
    if player_state.is_empty() or monster_state.is_empty():
        return false
    if player_state.position.distance_to(monster_state.position) > _selection_range:
        return false
    _targets[player_id] = candidate_id
    return true

func get_target(player_entity_id: int) -> int:
    return int(_targets.get(player_entity_id, 0))

func remove_player(player_entity_id: int) -> void:
    _targets.erase(player_entity_id)

func clear_entity_references(entity_id: int) -> void:
    for player_id: int in _targets:
        if _targets[player_id] == entity_id:
            _targets[player_id] = 0

func cleanup_invalid_targets() -> void:
    for player_id: int in _targets:
        var target_id: int = _targets[player_id]
        if target_id > 0 and _entities.get_entity(target_id).is_empty():
            _targets[player_id] = 0

func decorate_player_snapshot(players: Array) -> void:
    for player: Dictionary in players:
        player["current_target_entity_id"] = get_target(player["entity_id"])

func clear() -> void:
    _targets.clear()
