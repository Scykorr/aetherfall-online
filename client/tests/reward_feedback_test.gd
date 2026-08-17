extends Node

const HUD_SCENE: PackedScene = preload("res://scenes/ui/reward_feedback_hud.tscn")
const LOOT_SCENE: PackedScene = preload(
    "res://scenes/presentation/loot_presentation.tscn"
)

var _failures: int = 0
var _feed_messages: Array[String] = []
var _level_ups: Array[int] = []

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    var hud := HUD_SCENE.instantiate() as RewardFeedbackHud
    add_child(hud)
    await get_tree().process_frame
    hud.feed_entry_added.connect(_feed_messages.append)
    hud.level_up_presented.connect(_level_ups.append)

    hud.apply_authoritative_progression(_progression(1, 0, 100))
    _check(_feed_messages.is_empty(), "initial progression is silent")
    hud.apply_authoritative_progression(_progression(1, 25, 100))
    _check(_feed_messages.back() == "+25 XP", "authoritative XP delta")
    hud.apply_authoritative_progression(_progression(2, 5, 200))
    _check(_feed_messages.back() == "+80 XP", "level boundary XP delta")
    _check(_level_ups == [2], "authoritative level increase")
    for index in 7:
        hud.add_feed_entry("entry %d" % index)
    _check(hud.feed.get_child_count() <= 5, "reward feed cap")

    var loot := LOOT_SCENE.instantiate() as LootPresentation
    add_child(loot)
    await get_tree().process_frame
    var state := {
        "entity_id": 40,
        "item_id": "small_aether_shard",
        "quantity": 2,
        "owner_entity_id": 7,
    }
    var definition := {
        "display_name": "Small Aether Shard",
        "rarity": "uncommon",
    }
    loot.apply_authoritative_state(state, 7, definition)
    _check(loot.item_label.text == "Small Aether Shard x2", "loot display name")
    _check(loot.owned_marker.visible and not loot.locked_marker.visible, "owned shape")
    loot.apply_authoritative_state(state, 8, definition)
    _check(not loot.owned_marker.visible and loot.locked_marker.visible, "locked shape")
    _check(loot.ownership_label.text == "LOCKED", "ownership is not color-only")

    print("Reward feedback tests: %s" % ("PASS" if _failures == 0 else "FAIL"))
    get_tree().quit(_failures)

func _progression(level: int, xp: int, required: int) -> Dictionary:
    return {
        "level": level,
        "current_xp": xp,
        "xp_to_next_level": required,
    }

func _check(condition: bool, label: String) -> void:
    if condition:
        print("PASS: %s" % label)
    else:
        _failures += 1
        push_error("FAIL: %s" % label)
