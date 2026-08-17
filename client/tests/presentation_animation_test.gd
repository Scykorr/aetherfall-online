extends SceneTree

const PLAYER_PRESENTATION := preload(
    "res://scenes/presentation/player_presentation.tscn"
)
const WISP_PRESENTATION := preload(
    "res://scenes/presentation/training_wisp_presentation.tscn"
)
const REQUIRED_ANIMATIONS: Array[StringName] = [
    &"idle", &"run", &"attack_basic", &"hit", &"death", &"respawn",
]

var _failures: int = 0

func _init() -> void:
    call_deferred("_run_tests")

func _run_tests() -> void:
    await _test_player_controller()
    await _test_monster_controller()
    if _failures == 0:
        print("Presentation animation tests: PASS")
    else:
        push_error("Presentation animation tests failed: %d" % _failures)
    quit(_failures)

func _test_player_controller() -> void:
    var presentation := PLAYER_PRESENTATION.instantiate() as Node3D
    root.add_child(presentation)
    await process_frame
    var controller := presentation.get_node(
        "AnimationController"
    ) as PrototypeAnimationController
    _assert_required_clips(controller.animation_player, "player")
    controller.apply_replicated_state(_state(10, Vector3.ZERO, "ALIVE"))
    _assert_state(controller, "idle", "player idle")
    controller.apply_replicated_state(_state(10, Vector3.RIGHT, "ALIVE"))
    _assert_state(controller, "run", "player run from replicated velocity")
    controller.trigger_attack()
    _assert_state(controller, "attack_basic", "player confirmed attack")
    controller.trigger_hit()
    _assert_state(controller, "hit", "player hit overrides attack")
    controller.apply_replicated_state(_state(10, Vector3.RIGHT, "DEAD"))
    _assert_state(controller, "death", "player death overrides velocity")
    controller.trigger_attack()
    controller.trigger_hit()
    _assert_state(controller, "death", "dead player ignores actions")
    controller.apply_replicated_state(_state(10, Vector3.ZERO, "ALIVE"))
    _assert_state(controller, "respawn", "player respawn transition")
    await create_timer(0.7).timeout
    _assert_state(controller, "idle", "player respawn resets locomotion")
    presentation.queue_free()

func _test_monster_controller() -> void:
    var presentation := WISP_PRESENTATION.instantiate() as Node3D
    root.add_child(presentation)
    await process_frame
    var controller := presentation.get_node(
        "AnimationController"
    ) as PrototypeAnimationController
    _assert_required_clips(controller.animation_player, "monster")
    controller.apply_replicated_state(_state(20, Vector3.ZERO, "ALIVE"))
    _assert_state(controller, "idle", "monster idle")
    controller.apply_replicated_state(_state(20, Vector3.FORWARD, "ALIVE"))
    _assert_state(controller, "run", "monster move from replicated velocity")
    controller.trigger_attack()
    _assert_state(controller, "attack_basic", "monster confirmed attack")
    controller.trigger_hit()
    _assert_state(controller, "hit", "monster hit reaction")
    controller.apply_replicated_state(_state(20, Vector3.FORWARD, "DEAD"))
    _assert_state(controller, "death", "monster death priority")
    controller.apply_replicated_state(_state(20, Vector3.ZERO, "ALIVE"))
    _assert_state(controller, "respawn", "monster respawn transition")
    await create_timer(0.7).timeout
    _assert_state(controller, "idle", "monster respawn resets locomotion")
    presentation.queue_free()

func _assert_required_clips(player: AnimationPlayer, subject: String) -> void:
    for animation_name in REQUIRED_ANIMATIONS:
        if not player.has_animation(animation_name):
            _fail("%s missing animation %s" % [subject, animation_name])

func _assert_state(
    controller: PrototypeAnimationController,
    expected: String,
    scenario: String
) -> void:
    var actual := controller.get_presentation_state_name()
    if actual != expected:
        _fail("%s: expected %s, got %s" % [scenario, expected, actual])
    else:
        print("PASS: %s -> %s" % [scenario, actual])

func _state(entity_id: int, velocity: Vector3, life_state: String) -> Dictionary:
    return {
        "entity_id": entity_id,
        "velocity": velocity,
        "life_state": life_state,
    }

func _fail(message: String) -> void:
    _failures += 1
    push_error(message)
