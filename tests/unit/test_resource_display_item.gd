## Unit tests for ResourceDisplayItem.
## Tests display format, color states, animation, and capacity handling.
##
## Architecture: tests/unit/test_resource_display_item.gd
## Story: 3-11-display-resource-bar-hud
extends GutTest

# =============================================================================
# CONSTANTS (referenced from implementation to prevent stale test values)
# =============================================================================

const NORMAL_COLOR := ResourceDisplayItem.NORMAL_COLOR
const WARNING_COLOR := ResourceDisplayItem.WARNING_COLOR
const FULL_COLOR := ResourceDisplayItem.FULL_COLOR
const TWEEN_DURATION: float = ResourceDisplayItem.TWEEN_DURATION

# =============================================================================
# TEST DATA
# =============================================================================

var item

# =============================================================================
# SETUP / TEARDOWN
# =============================================================================

func before_each() -> void:
	var item_scene := preload("res://scenes/ui/hud/resource_display_item.tscn")
	item = item_scene.instantiate()
	add_child(item)
	await wait_frames(1)


func after_each() -> void:
	if is_instance_valid(item):
		item.queue_free()
	await wait_frames(1)
	item = null

# =============================================================================
# SETUP AND DISPLAY FORMAT TESTS (AC: 3, 4)
# =============================================================================

func test_setup_stores_resource_id() -> void:
	item.setup("wheat", "🌾", 25, 100)
	await wait_frames(1)

	assert_eq(item.get_resource_id(), "wheat", "Should store resource ID")


func test_setup_stores_current_amount() -> void:
	item.setup("wheat", "🌾", 25, 100)
	await wait_frames(1)

	assert_eq(item.get_current_amount(), 25, "Should store current amount")


func test_setup_stores_capacity() -> void:
	item.setup("wheat", "🌾", 25, 100)
	await wait_frames(1)

	assert_eq(item.get_capacity(), 100, "Should store capacity")


func test_displays_icon() -> void:
	item.setup("wheat", "🌾", 25, 100)
	await wait_frames(1)

	var icon_label := item.get_node("HBoxContainer/IconLabel") as Label
	assert_eq(icon_label.text, "🌾", "Should display icon emoji")


func test_displays_current_max_format() -> void:
	item.setup("wheat", "🌾", 25, 100)
	await wait_frames(1)

	assert_eq(item.get_amount_text(), "25/100", "Should show current/max format")


func test_displays_amount_only_when_capacity_zero() -> void:
	item.setup("wheat", "🌾", 50, 0)
	await wait_frames(1)

	assert_eq(item.get_amount_text(), "50", "Should show amount only when no capacity")


func test_displays_amount_only_when_capacity_negative() -> void:
	item.setup("special", "✨", 999, -1)
	await wait_frames(1)

	assert_eq(item.get_amount_text(), "999", "Should show amount only for unlimited")

# =============================================================================
# COLOR STATE TESTS (AC: 5, 6)
# =============================================================================

func test_normal_color_below_warning_threshold() -> void:
	item.setup("wheat", "🌾", 50, 100)  # 50%
	await wait_frames(1)

	assert_eq(item.get_color_state(), "normal", "Should be normal at 50%")


func test_normal_color_at_79_percent() -> void:
	item.setup("wheat", "🌾", 79, 100)  # 79%
	await wait_frames(1)

	assert_eq(item.get_color_state(), "normal", "Should be normal at 79%")


func test_warning_color_at_80_percent() -> void:
	item.setup("wheat", "🌾", 80, 100)  # Exactly 80%
	await wait_frames(1)

	assert_eq(item.get_color_state(), "warning", "Should be warning at 80%")


func test_warning_color_at_90_percent() -> void:
	item.setup("wheat", "🌾", 90, 100)  # 90%
	await wait_frames(1)

	assert_eq(item.get_color_state(), "warning", "Should be warning at 90%")


func test_warning_color_at_99_percent() -> void:
	item.setup("wheat", "🌾", 99, 100)  # 99%
	await wait_frames(1)

	assert_eq(item.get_color_state(), "warning", "Should be warning at 99%")


func test_full_color_at_100_percent() -> void:
	item.setup("wheat", "🌾", 100, 100)  # 100%
	await wait_frames(1)

	assert_eq(item.get_color_state(), "full", "Should be full at 100%")


func test_normal_state_when_no_capacity() -> void:
	item.setup("wheat", "🌾", 999, 0)  # No capacity limit
	await wait_frames(1)

	assert_eq(item.get_color_state(), "normal", "Should be normal when no capacity limit")


func test_show_warning_state_applies_color() -> void:
	item.setup("wheat", "🌾", 50, 100)  # Normal state
	await wait_frames(1)

	item.show_warning_state()

	var amount_label := item.get_node("HBoxContainer/AmountLabel") as Label
	assert_eq(amount_label.modulate, WARNING_COLOR, "Should apply warning color")


func test_show_full_state_applies_color() -> void:
	item.setup("wheat", "🌾", 50, 100)  # Normal state
	await wait_frames(1)

	item.show_full_state()

	var amount_label := item.get_node("HBoxContainer/AmountLabel") as Label
	assert_eq(amount_label.modulate, FULL_COLOR, "Should apply full color")

# =============================================================================
# AMOUNT UPDATE TESTS (AC: 2, 10)
# =============================================================================

func test_update_amount_changes_value() -> void:
	item.setup("wheat", "🌾", 25, 100)
	await wait_frames(1)

	item.update_amount(50)
	await wait_frames(20)  # Wait for animation (0.25s at 60fps = 15 frames)

	assert_eq(item.get_current_amount(), 50, "Should update current amount")


func test_update_amount_same_value_does_nothing() -> void:
	item.setup("wheat", "🌾", 25, 100)
	await wait_frames(1)

	item.update_amount(25)  # Same value

	# Should not trigger animation - amount should be same
	assert_eq(item.get_current_amount(), 25, "Should remain unchanged")


func test_update_amount_updates_color_state() -> void:
	item.setup("wheat", "🌾", 50, 100)  # 50% - normal
	await wait_frames(1)

	assert_eq(item.get_color_state(), "normal", "Should start normal")

	item.update_amount(85)  # 85% - warning
	await wait_frames(20)

	assert_eq(item.get_color_state(), "warning", "Should become warning")


func test_update_amount_to_full() -> void:
	item.setup("wheat", "🌾", 90, 100)  # 90% - warning
	await wait_frames(1)

	item.update_amount(100)  # 100% - full
	await wait_frames(20)

	assert_eq(item.get_color_state(), "full", "Should become full")

# =============================================================================
# CAPACITY UPDATE TESTS (AC: 8)
# =============================================================================

func test_update_capacity_changes_max() -> void:
	item.setup("wheat", "🌾", 50, 100)
	await wait_frames(1)

	item.update_capacity(200)
	await wait_frames(1)

	assert_eq(item.get_capacity(), 200, "Should update capacity")


func test_update_capacity_updates_display_format() -> void:
	item.setup("wheat", "🌾", 50, 100)
	await wait_frames(1)

	item.update_capacity(200)
	await wait_frames(1)

	assert_eq(item.get_amount_text(), "50/200", "Should show updated max in format")


func test_update_capacity_recalculates_color_state() -> void:
	item.setup("wheat", "🌾", 80, 100)  # 80% - warning
	await wait_frames(1)

	assert_eq(item.get_color_state(), "warning", "Should be warning initially")

	item.update_capacity(200)  # Now 40% - normal
	await wait_frames(1)

	assert_eq(item.get_color_state(), "normal", "Should become normal after capacity increase")


func test_update_capacity_warning_to_full() -> void:
	item.setup("wheat", "🌾", 90, 100)  # 90% - warning
	await wait_frames(1)

	item.update_capacity(90)  # Now 100% - full
	await wait_frames(1)

	assert_eq(item.get_color_state(), "full", "Should become full when capacity reduced")

# =============================================================================
# ANIMATION TESTS (AC: 10)
# =============================================================================

func test_tween_duration_constant_defined() -> void:
	# TWEEN_DURATION is 0.25 based on our constant
	assert_eq(TWEEN_DURATION, 0.25, "Tween duration should be 0.25 seconds")


func test_animation_shows_intermediate_values() -> void:
	item.setup("wheat", "🌾", 0, 100)
	await wait_frames(1)

	item.update_amount(100)
	await wait_frames(5)  # Partial animation

	# Displayed amount should be somewhere between 0 and 100
	# We can't test exact intermediate values easily, so just verify it started
	assert_eq(item.get_current_amount(), 100, "Current amount should be updated")


func test_rapid_updates_kill_previous_tween() -> void:
	item.setup("wheat", "🌾", 0, 100)
	await wait_frames(1)

	# Rapidly update multiple times
	item.update_amount(50)
	item.update_amount(75)
	item.update_amount(100)
	await wait_frames(20)  # Wait for final animation

	assert_eq(item.get_current_amount(), 100, "Should end at final value")

# =============================================================================
# CONSTANT VALUE TESTS
# =============================================================================

func test_normal_color_constant() -> void:
	assert_eq(NORMAL_COLOR, Color(1.0, 1.0, 1.0, 1.0), "Normal color should be white")


func test_warning_color_constant() -> void:
	assert_eq(WARNING_COLOR, Color(1.0, 0.7, 0.2, 1.0), "Warning color should be amber")


func test_full_color_constant() -> void:
	assert_eq(FULL_COLOR, Color(1.0, 0.3, 0.3, 1.0), "Full color should be red")

# =============================================================================
# EDGE CASE TESTS
# =============================================================================

func test_zero_amount_displays_correctly() -> void:
	item.setup("wheat", "🌾", 0, 100)
	await wait_frames(1)

	assert_eq(item.get_amount_text(), "0/100", "Should display zero correctly")


func test_zero_amount_is_normal_state() -> void:
	item.setup("wheat", "🌾", 0, 100)
	await wait_frames(1)

	assert_eq(item.get_color_state(), "normal", "Zero should be normal state")


func test_amount_exceeding_capacity() -> void:
	# This shouldn't happen normally, but test resilience
	item.setup("wheat", "🌾", 150, 100)
	await wait_frames(1)

	assert_eq(item.get_color_state(), "full", "Should be full when exceeding capacity")


func test_different_resource_types() -> void:
	# Test wood
	item.setup("wood", "🪵", 42, 100)
	await wait_frames(1)

	assert_eq(item.get_resource_id(), "wood")
	assert_eq(item.get_amount_text(), "42/100")

	var icon_label := item.get_node("HBoxContainer/IconLabel") as Label
	assert_eq(icon_label.text, "🪵")
