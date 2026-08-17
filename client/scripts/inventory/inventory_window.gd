class_name InventoryWindow
extends PanelContainer

@export var slot_grid: GridContainer
@export var status_label: Label
@export var destroy_button: Button

var _buttons: Array[Button] = []
var _selected_slot: int = -1
var _state: Dictionary = {}

func _ready() -> void:
    add_to_group("inventory_ui")
    visible = false
    mouse_filter = Control.MOUSE_FILTER_STOP
    Network.inventory_state_received.connect(_on_inventory_state)
    Network.inventory_rejection_received.connect(_on_inventory_rejected)
    destroy_button.pressed.connect(_destroy_selected)
    if Network.has_inventory_state():
        _on_inventory_state(Network.get_inventory_state())

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("toggle_inventory"):
        visible = not visible
        if not visible:
            _selected_slot = -1
        get_viewport().set_input_as_handled()

func is_world_input_blocked() -> bool:
    return visible

func _on_inventory_state(state: Dictionary) -> void:
    _state = state
    _ensure_buttons(int(state.get("slot_count", 0)))
    var slots: Array = state.get("slots", [])
    var definitions: Dictionary = state.get("item_definitions", {})
    for index in _buttons.size():
        var slot: Dictionary = slots[index] if index < slots.size() else {}
        if slot.is_empty():
            _buttons[index].text = "%02d\nEmpty" % (index + 1)
            _buttons[index].tooltip_text = "Empty slot"
        else:
            var item_id: String = slot["item_id"]
            var definition: Dictionary = definitions.get(item_id, {})
            var display_name: String = definition.get("display_name", item_id)
            _buttons[index].text = "%02d\n%s x%d" % [index + 1, display_name, slot["quantity"]]
            _buttons[index].tooltip_text = "%s (%s), max stack %d" % [display_name, item_id, definition.get("max_stack", 1)]
        _buttons[index].disabled = false
    if _selected_slot >= slots.size() or (_selected_slot >= 0 and slots[_selected_slot].is_empty()):
        _selected_slot = -1
    _refresh_selection()
    status_label.text = "Revision %d — click source, then destination; Shift+destination splits half." % state.get("inventory_revision", 0)

func _ensure_buttons(count: int) -> void:
    while _buttons.size() < count:
        var index := _buttons.size()
        var button := Button.new()
        button.custom_minimum_size = Vector2(122.0, 64.0)
        button.toggle_mode = true
        button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
        button.pressed.connect(_on_slot_pressed.bind(index))
        slot_grid.add_child(button)
        _buttons.append(button)

func _on_slot_pressed(index: int) -> void:
    var slots: Array = _state.get("slots", [])
    if index < 0 or index >= slots.size():
        return
    if _selected_slot < 0:
        if not slots[index].is_empty():
            _selected_slot = index
            _refresh_selection()
        return
    if index == _selected_slot:
        _selected_slot = -1
        _refresh_selection()
        return
    if Input.is_key_pressed(KEY_SHIFT):
        if slots[index].is_empty():
            var quantity := int(slots[_selected_slot]["quantity"]) / 2
            if quantity > 0:
                Network.request_inventory_split(_selected_slot, index, quantity)
    else:
        Network.request_inventory_move(_selected_slot, index)
    _selected_slot = -1
    _refresh_selection()

func _destroy_selected() -> void:
    var slots: Array = _state.get("slots", [])
    if _selected_slot < 0 or _selected_slot >= slots.size() or slots[_selected_slot].is_empty():
        status_label.text = "Select a non-empty slot before destroying."
        return
    Network.request_inventory_destroy(_selected_slot, int(slots[_selected_slot]["quantity"]))
    _selected_slot = -1

func _refresh_selection() -> void:
    for index in _buttons.size():
        _buttons[index].button_pressed = index == _selected_slot
    destroy_button.disabled = _selected_slot < 0

func _on_inventory_rejected(reason: String) -> void:
    status_label.text = "Server rejected inventory command: %s" % reason
