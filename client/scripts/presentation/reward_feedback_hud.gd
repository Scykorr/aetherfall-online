class_name RewardFeedbackHud
extends CanvasLayer

signal feed_entry_added(text: String)
signal level_up_presented(level: int)

const MAX_FEED_ENTRIES: int = 5
const FEED_LIFETIME_SECONDS: float = 3.5

@export var level_label: Label
@export var xp_label: Label
@export var xp_bar: ProgressBar
@export var feed: VBoxContainer
@export var level_up_panel: Control
@export var level_up_label: Label

var _has_progression: bool = false
var _level: int = 1
var _current_xp: int = 0
var _xp_to_next: int = 100

func _ready() -> void:
    layer = 20
    _set_mouse_filter_recursive(get_child(0) as Control)
    level_up_panel.visible = false
    Network.snapshot_received.connect(_on_snapshot_received)
    Network.pickup_confirmed.connect(_on_pickup_confirmed)
    Network.pickup_rejection_received.connect(_on_pickup_rejected)

func _on_snapshot_received(snapshot: Dictionary) -> void:
    for entity: Dictionary in snapshot.get("entities", []):
        if (
            entity.get("entity_type") == "player"
            and int(entity.get("entity_id", 0)) == Network.assigned_entity_id
        ):
            apply_authoritative_progression(entity)
            return

func apply_authoritative_progression(state: Dictionary) -> void:
    var next_level: int = int(state.get("level", 1))
    var next_xp: int = int(state.get("current_xp", 0))
    var next_required: int = maxi(1, int(state.get("xp_to_next_level", 100)))
    if _has_progression:
        if next_level == _level and next_xp > _current_xp:
            add_feed_entry("+%d XP" % (next_xp - _current_xp))
        elif next_level == _level + 1:
            var confirmed_delta := (_xp_to_next - _current_xp) + next_xp
            if confirmed_delta > 0:
                add_feed_entry("+%d XP" % confirmed_delta)
            _show_level_up(next_level)
        elif next_level > _level:
            add_feed_entry("XP UPDATED")
            _show_level_up(next_level)
    _has_progression = true
    _level = next_level
    _current_xp = next_xp
    _xp_to_next = next_required
    level_label.text = "Level %d" % _level
    xp_label.text = "XP %d / %d" % [_current_xp, _xp_to_next]
    xp_bar.max_value = _xp_to_next
    xp_bar.value = _current_xp

func _on_pickup_confirmed(result: Dictionary) -> void:
    if int(result.get("player_entity_id", 0)) != Network.assigned_entity_id:
        return
    var item_id: String = result.get("item_id", "unknown_item")
    var display_name: String = _get_item_display_name(item_id)
    add_feed_entry("RECEIVED: %s x%d" % [display_name, int(result.get("quantity", 1))])

func _on_pickup_rejected(_loot_entity_id: int, reason: String) -> void:
    var message: String = {
        "INVENTORY_FULL": "INVENTORY FULL",
        "NOT_OWNER": "NOT YOUR LOOT",
        "TOO_FAR": "TOO FAR AWAY",
        "REJECTED": "PICKUP REJECTED",
    }.get(reason, "PICKUP FAILED: %s" % reason)
    add_feed_entry(message)

func add_feed_entry(message: String) -> void:
    while feed.get_child_count() >= MAX_FEED_ENTRIES:
        feed.get_child(0).queue_free()
        feed.remove_child(feed.get_child(0))
    var entry := Label.new()
    entry.mouse_filter = Control.MOUSE_FILTER_IGNORE
    entry.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    entry.add_theme_font_size_override("font_size", 18)
    entry.add_theme_color_override("font_outline_color", Color(0.04, 0.06, 0.08, 0.9))
    entry.add_theme_constant_override("outline_size", 6)
    entry.text = message
    feed.add_child(entry)
    feed_entry_added.emit(message)
    var tween := create_tween()
    tween.tween_interval(FEED_LIFETIME_SECONDS - 0.6)
    tween.tween_property(entry, "modulate:a", 0.0, 0.6)
    tween.tween_callback(entry.queue_free)

func _show_level_up(next_level: int) -> void:
    level_up_panel.visible = true
    level_up_panel.modulate = Color(1, 1, 1, 0)
    level_up_panel.scale = Vector2(0.82, 0.82)
    level_up_label.text = "LEVEL UP\nLevel %d" % next_level
    level_up_presented.emit(next_level)
    var tween := create_tween()
    tween.set_parallel(true)
    tween.tween_property(level_up_panel, "modulate:a", 1.0, 0.18)
    tween.tween_property(level_up_panel, "scale", Vector2.ONE, 0.22)
    tween.chain().tween_interval(1.15)
    tween.chain().tween_property(level_up_panel, "modulate:a", 0.0, 0.35)
    tween.chain().tween_callback(level_up_panel.hide)

func _get_item_display_name(item_id: String) -> String:
    var inventory := Network.get_inventory_state()
    var definitions: Dictionary = inventory.get("item_definitions", {})
    var definition: Dictionary = definitions.get(item_id, {})
    return definition.get("display_name", item_id)

func _set_mouse_filter_recursive(control: Control) -> void:
    control.mouse_filter = Control.MOUSE_FILTER_IGNORE
    for child: Node in control.get_children():
        if child is Control:
            _set_mouse_filter_recursive(child)
