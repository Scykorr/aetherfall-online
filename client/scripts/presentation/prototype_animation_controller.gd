class_name PrototypeAnimationController
extends Node

signal presentation_state_changed(entity_id: int, state_name: String)

const STATE_IDLE := &"idle"
const STATE_RUN := &"run"
const STATE_ATTACK := &"attack_basic"
const STATE_HIT := &"hit"
const STATE_DEATH := &"death"
const STATE_RESPAWN := &"respawn"
const LOCOMOTION_THRESHOLD_SQUARED: float = 0.01

@export var visual_root: Node3D
@export var character_model: Node3D
@export var animation_player: AnimationPlayer
@export var facing_speed: float = 12.0
@export var run_bob_height: float = 0.08
@export var attack_lunge_distance: float = 0.22
@export var death_drop_distance: float = 0.32
@export var death_rotation_degrees: float = 78.0
@export var death_vertical_scale: float = 0.7

var entity_id: int = 0
var _state: StringName = STATE_IDLE
var _life_state: String = "ALIVE"
var _velocity: Vector3 = Vector3.ZERO
var _target_yaw: float = 0.0
var _has_replicated_state: bool = false

func _ready() -> void:
    _create_animation_library()
    animation_player.animation_finished.connect(_on_animation_finished)
    _play_state(STATE_IDLE, true)

func _process(delta: float) -> void:
    if _life_state == "DEAD":
        return
    var weight := 1.0 - exp(-facing_speed * delta)
    visual_root.rotation.y = lerp_angle(
        visual_root.rotation.y,
        _target_yaw,
        weight
    )

func apply_replicated_state(state: Dictionary) -> void:
    entity_id = state.get("entity_id", entity_id)
    var next_life_state: String = state.get("life_state", "ALIVE")
    _velocity = state.get("velocity", Vector3.ZERO)
    _velocity.y = 0.0
    if next_life_state == "DEAD":
        _life_state = next_life_state
        _has_replicated_state = true
        if _state != STATE_DEATH:
            _play_state(STATE_DEATH)
        return

    var did_respawn := (
        _has_replicated_state
        and _life_state == "DEAD"
        and next_life_state == "ALIVE"
    )
    _life_state = next_life_state
    _has_replicated_state = true
    if not _velocity.is_zero_approx():
        _target_yaw = atan2(_velocity.x, _velocity.z)
    if did_respawn:
        _play_state(STATE_RESPAWN)
    elif _state not in [STATE_ATTACK, STATE_HIT, STATE_RESPAWN]:
        _play_locomotion()

func trigger_attack() -> void:
    if _life_state != "DEAD":
        _play_state(STATE_ATTACK, true)

func trigger_hit() -> void:
    if _life_state != "DEAD":
        _play_state(STATE_HIT, true)

func face_world_position(world_position: Vector3) -> void:
    if _life_state == "DEAD":
        return
    var offset := world_position - visual_root.global_position
    offset.y = 0.0
    if offset.length_squared() > 0.001:
        _target_yaw = atan2(offset.x, offset.z)

func get_presentation_state_name() -> String:
    return String(_state)

func _play_locomotion() -> void:
    if _life_state == "DEAD":
        return
    _play_state(
        STATE_RUN
        if _velocity.length_squared() > LOCOMOTION_THRESHOLD_SQUARED
        else STATE_IDLE
    )

func _play_state(next_state: StringName, restart: bool = false) -> void:
    if _state == STATE_DEATH and next_state not in [STATE_DEATH, STATE_RESPAWN]:
        return
    if _state == next_state and not restart:
        return
    _state = next_state
    animation_player.play(String(next_state), 0.08)
    presentation_state_changed.emit(entity_id, String(next_state))

func _on_animation_finished(animation_name: StringName) -> void:
    if animation_name == STATE_DEATH:
        return
    if animation_name == STATE_RESPAWN:
        _play_locomotion()
    elif animation_name in [STATE_ATTACK, STATE_HIT] and _state == animation_name:
        _play_locomotion()

func _create_animation_library() -> void:
    var library := AnimationLibrary.new()
    library.add_animation(STATE_IDLE, _make_idle_animation())
    library.add_animation(STATE_RUN, _make_run_animation())
    library.add_animation(STATE_ATTACK, _make_attack_animation())
    library.add_animation(STATE_HIT, _make_hit_animation())
    library.add_animation(STATE_DEATH, _make_death_animation())
    library.add_animation(STATE_RESPAWN, _make_respawn_animation())
    animation_player.add_animation_library(&"", library)

func _make_idle_animation() -> Animation:
    var animation := _new_animation(1.6, Animation.LOOP_LINEAR)
    _add_track(animation, "position", [0.0, 0.8, 1.6], [
        Vector3.ZERO, Vector3(0.0, 0.035, 0.0), Vector3.ZERO,
    ])
    _add_track(animation, "scale", [0.0, 0.8, 1.6], [
        Vector3.ONE, Vector3(1.015, 0.985, 1.015), Vector3.ONE,
    ])
    return animation

func _make_run_animation() -> Animation:
    var animation := _new_animation(0.48, Animation.LOOP_LINEAR)
    _add_track(animation, "position", [0.0, 0.12, 0.24, 0.36, 0.48], [
        Vector3.ZERO, Vector3(0.0, run_bob_height, 0.0), Vector3.ZERO,
        Vector3(0.0, run_bob_height, 0.0), Vector3.ZERO,
    ])
    _add_track(animation, "rotation_degrees", [0.0, 0.12, 0.24, 0.36, 0.48], [
        Vector3(4.0, 0.0, -4.0), Vector3(-3.0, 0.0, 0.0),
        Vector3(4.0, 0.0, 4.0), Vector3(-3.0, 0.0, 0.0),
        Vector3(4.0, 0.0, -4.0),
    ])
    return animation

func _make_attack_animation() -> Animation:
    var animation := _new_animation(0.42)
    _add_track(animation, "position", [0.0, 0.12, 0.24, 0.42], [
        Vector3.ZERO, Vector3(0.0, 0.02, -0.08),
        Vector3(0.0, 0.03, attack_lunge_distance), Vector3.ZERO,
    ])
    _add_track(animation, "rotation_degrees", [0.0, 0.12, 0.24, 0.42], [
        Vector3.ZERO, Vector3(-8.0, 0.0, -9.0),
        Vector3(13.0, 0.0, 7.0), Vector3.ZERO,
    ])
    return animation

func _make_hit_animation() -> Animation:
    var animation := _new_animation(0.28)
    _add_track(animation, "position", [0.0, 0.08, 0.18, 0.28], [
        Vector3.ZERO, Vector3(0.0, 0.02, -0.12),
        Vector3(0.0, 0.01, 0.04), Vector3.ZERO,
    ])
    _add_track(animation, "rotation_degrees", [0.0, 0.08, 0.18, 0.28], [
        Vector3.ZERO, Vector3(-7.0, 0.0, 12.0),
        Vector3(3.0, 0.0, -5.0), Vector3.ZERO,
    ])
    return animation

func _make_death_animation() -> Animation:
    var animation := _new_animation(0.62)
    _add_track(animation, "position", [0.0, 0.25, 0.62], [
        Vector3.ZERO, Vector3(0.0, -death_drop_distance * 0.3, 0.0),
        Vector3(0.0, -death_drop_distance, 0.0),
    ])
    _add_track(animation, "rotation_degrees", [0.0, 0.25, 0.62], [
        Vector3.ZERO, Vector3(0.0, 0.0, death_rotation_degrees * 0.35),
        Vector3(0.0, 0.0, death_rotation_degrees),
    ])
    _add_track(animation, "scale", [0.0, 0.62], [
        Vector3.ONE, Vector3(1.0, death_vertical_scale, 1.0),
    ])
    return animation

func _make_respawn_animation() -> Animation:
    var animation := _new_animation(0.55)
    _add_track(animation, "position", [0.0, 0.3, 0.55], [
        Vector3(0.0, -death_drop_distance * 0.45, 0.0),
        Vector3(0.0, 0.06, 0.0), Vector3.ZERO,
    ])
    _add_track(animation, "rotation_degrees", [0.0, 0.3, 0.55], [
        Vector3(0.0, 0.0, death_rotation_degrees), Vector3.ZERO,
        Vector3.ZERO,
    ])
    _add_track(animation, "scale", [0.0, 0.3, 0.55], [
        Vector3(0.35, 0.2, 0.35), Vector3(1.08, 1.08, 1.08),
        Vector3.ONE,
    ])
    return animation

func _new_animation(
    length: float,
    loop_mode: Animation.LoopMode = Animation.LOOP_NONE
) -> Animation:
    var animation := Animation.new()
    animation.length = length
    animation.loop_mode = loop_mode
    return animation

func _add_track(
    animation: Animation,
    property_name: String,
    times: Array[float],
    values: Array[Vector3]
) -> void:
    var track := animation.add_track(Animation.TYPE_VALUE)
    animation.track_set_path(
        track,
        NodePath("VisualRoot/CharacterModel:%s" % property_name)
    )
    animation.value_track_set_update_mode(track, Animation.UPDATE_CONTINUOUS)
    for index in times.size():
        animation.track_insert_key(track, times[index], values[index])
