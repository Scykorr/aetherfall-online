class_name RemotePlayerManager
extends Node

@export var local_player: CharacterBody3D
@export var interpolation_speed: float = 12.0

var _remote_players: Dictionary = {}
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

func get_remote_count() -> int:
    return _remote_players.size()

func _on_snapshot_received(snapshot: Dictionary) -> void:
    var present: Dictionary = {}
    for player: Dictionary in snapshot["players"]:
        var entity_id: int = player["entity_id"]
        present[entity_id] = true
        _target_positions[entity_id] = player["position"]
        if entity_id != Network.assigned_entity_id and not _remote_players.has(entity_id):
            _spawn_remote(entity_id, player["position"])
    for entity_id: int in _remote_players.keys():
        if not present.has(entity_id):
            _remote_players[entity_id].queue_free()
            _remote_players.erase(entity_id)
            _target_positions.erase(entity_id)
            print("[Aetherfall Client] Remote despawned: entity=%d" % entity_id)

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
