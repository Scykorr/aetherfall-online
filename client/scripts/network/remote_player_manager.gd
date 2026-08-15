class_name RemotePlayerManager
extends Node

const MONSTER_SCENE: PackedScene = preload("res://scenes/actors/monster_placeholder.tscn")

@export var local_player: CharacterBody3D
@export var interpolation_speed: float = 12.0
@export var target_frame: Control
@export var target_label: Label

var _remote_players: Dictionary = {}
var _monsters: Dictionary = {}
var _target_positions: Dictionary = {}

func _ready() -> void:
    Network.snapshot_received.connect(_on_snapshot_received)

func _process(delta: float) -> void:
    var weight := 1.0 - exp(-interpolation_speed * delta)
    for entity_id: int in _target_positions:
        var target: Vector3 = _target_positions[entity_id]
        if entity_id == Network.assigned_entity_id:
            if local_player != null:
                local_player.global_position = local_player.global_position.lerp(target, weight)
        elif _remote_players.has(entity_id):
            var remote: Node3D = _remote_players[entity_id]
            remote.global_position = remote.global_position.lerp(target, weight)
        elif _monsters.has(entity_id):
            var monster: Node3D = _monsters[entity_id]
            monster.global_position = monster.global_position.lerp(target, weight)

func get_remote_count() -> int:
    return _remote_players.size()

func get_monster_count() -> int:
    return _monsters.size()

func _on_snapshot_received(snapshot: Dictionary) -> void:
    var present: Dictionary = {}
    for entity: Dictionary in snapshot["entities"]:
        var entity_id: int = entity["entity_id"]
        present[entity_id] = true
        _target_positions[entity_id] = entity["position"]
        if entity["entity_type"] == "monster":
            if not _monsters.has(entity_id):
                _spawn_monster(entity)
            (_monsters[entity_id] as Node).call("apply_state", entity)
        elif entity_id != Network.assigned_entity_id and not _remote_players.has(entity_id):
            _spawn_remote(entity_id, entity["position"])
    for entity_id: int in _remote_players.keys():
        if not present.has(entity_id):
            _remote_players[entity_id].queue_free()
            _remote_players.erase(entity_id)
            _target_positions.erase(entity_id)
            print("[Aetherfall Client] Remote despawned: entity=%d" % entity_id)
    for entity_id: int in _monsters.keys():
        if not present.has(entity_id):
            _monsters[entity_id].queue_free()
            _monsters.erase(entity_id)
            _target_positions.erase(entity_id)
            print("[Aetherfall Client] Monster despawned: entity=%d" % entity_id)
    _apply_confirmed_target(snapshot)

func _apply_confirmed_target(snapshot: Dictionary) -> void:
    var target_id := 0
    for entity: Dictionary in snapshot["entities"]:
        if entity["entity_id"] == Network.assigned_entity_id:
            target_id = entity.get("current_target_entity_id", 0)
            break
    for monster_id: int in _monsters:
        (_monsters[monster_id] as Node).call("set_selected", monster_id == target_id)
    if target_id <= 0 or not _monsters.has(target_id):
        target_frame.visible = false
        return
    var state: Dictionary = {}
    for entity: Dictionary in snapshot["entities"]:
        if entity["entity_id"] == target_id:
            state = entity
            break
    if state.is_empty():
        target_frame.visible = false
        return
    target_label.text = "Training Wisp\nHP %d / %d\nEntity ID: %d" % [
        state["current_hp"],
        state["max_hp"],
        target_id,
    ]
    target_frame.visible = true

func _spawn_remote(entity_id: int, position: Vector3) -> void:
    var remote := Node3D.new()
    remote.name = "RemotePlayer%d" % entity_id
    remote.position = position
    var mesh_instance := MeshInstance3D.new()
    var capsule := CapsuleMesh.new()
    capsule.radius = 0.45
    capsule.height = 1.8
    mesh_instance.mesh = capsule
    mesh_instance.position = Vector3.UP * 0.9
    remote.add_child(mesh_instance)
    add_child(remote)
    _remote_players[entity_id] = remote
    print("[Aetherfall Client] Remote spawned: entity=%d" % entity_id)

func _spawn_monster(state: Dictionary) -> void:
    var monster := MONSTER_SCENE.instantiate() as Node3D
    monster.name = "Monster%d" % state["entity_id"]
    monster.position = state["position"]
    add_child(monster)
    _monsters[state["entity_id"]] = monster
    print(
        "[Aetherfall Client] Monster spawned: entity=%d template=%s hp=%d/%d" % [
            state["entity_id"],
            state["template_id"],
            state["current_hp"],
            state["max_hp"],
        ]
    )
