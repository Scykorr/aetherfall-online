class_name SimulationClock
extends Node

signal tick(tick_number: int, simulation_delta: float)
signal tick_completed(tick_number: int)

var tick_number: int = 0
var simulation_delta: float = 1.0 / 30.0
var expected_tick_duration: float = 1.0 / 30.0
var last_tick_duration: float = 0.0
var average_tick_duration: float = 0.0
var over_budget_tick_count: int = 0

var _tick_rate: int = 30
var _started_usec: int = 0
var _running: bool = false

func _ready() -> void:
    set_physics_process(false)

func configure(tick_rate: int) -> void:
    _tick_rate = maxi(1, tick_rate)
    simulation_delta = 1.0 / float(_tick_rate)
    expected_tick_duration = simulation_delta
    Engine.physics_ticks_per_second = _tick_rate

func start() -> void:
    tick_number = 0
    last_tick_duration = 0.0
    average_tick_duration = 0.0
    over_budget_tick_count = 0
    _started_usec = Time.get_ticks_usec()
    _running = true
    set_physics_process(true)

func stop() -> void:
    _running = false
    set_physics_process(false)

func get_uptime() -> float:
    if _started_usec == 0:
        return 0.0
    return float(Time.get_ticks_usec() - _started_usec) / 1_000_000.0

func get_monotonic_time() -> float:
    return float(Time.get_ticks_usec()) / 1_000_000.0

func is_running() -> bool:
    return _running

func _physics_process(_delta: float) -> void:
    if not _running:
        return

    var tick_started_usec := Time.get_ticks_usec()
    tick_number += 1
    tick.emit(tick_number, simulation_delta)

    last_tick_duration = (
        float(Time.get_ticks_usec() - tick_started_usec) / 1_000_000.0
    )
    average_tick_duration += (
        last_tick_duration - average_tick_duration
    ) / float(tick_number)
    if last_tick_duration > expected_tick_duration:
        over_budget_tick_count += 1
    tick_completed.emit(tick_number)
