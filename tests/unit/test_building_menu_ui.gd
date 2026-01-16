## Unit tests for Building Menu UI (Story 3-4)
## Tests BuildingMenuPanel, BuildingMenuItem, and BuildButton functionality.
extends GutTest

# =============================================================================
# CONSTANTS
# =============================================================================

const BUILDING_MENU_PANEL_SCENE := "res://scenes/ui/building_menu_panel.tscn"
const BUILDING_MENU_ITEM_SCENE := "res://scenes/ui/building_menu_item.tscn"
const BUILD_BUTTON_SCENE := "res://scenes/ui/build_button.tscn"

# =============================================================================
# TEST FIXTURES
# =============================================================================

var _panel: BuildingMenuPanel = null
var _item: BuildingMenuItem = null
var _button: BuildButton = null
var _test_building_data: BuildingData = null


func before_each() -> void:
	# Reset ResourceManager for clean tests
	ResourceManager._resources.clear()
	ResourceManager._warning_emitted.clear()
	ResourceManager._gathering_paused.clear()


func after_each() -> void:
	if _panel and is_instance_valid(_panel):
		_panel.queue_free()
		_panel = null
	if _item and is_instance_valid(_item):
		_item.queue_free()
		_item = null
	if _button and is_instance_valid(_button):
		_button.queue_free()
		_button = null
	_test_building_data = null


func _create_panel() -> BuildingMenuPanel:
	var scene := load(BUILDING_MENU_PANEL_SCENE) as PackedScene
	if not scene:
		return null
	var panel := scene.instantiate() as BuildingMenuPanel
	if panel:
		add_child_autoqfree(panel)
	return panel


func _create_item() -> BuildingMenuItem:
	var scene := load(BUILDING_MENU_ITEM_SCENE) as PackedScene
	if not scene:
		return null
	var item := scene.instantiate() as BuildingMenuItem
	if item:
		add_child_autoqfree(item)
	return item


func _create_button() -> BuildButton:
	var scene := load(BUILD_BUTTON_SCENE) as PackedScene
	if not scene:
		return null
	var button := scene.instantiate() as BuildButton
	if button:
		add_child_autoqfree(button)
	return button


func _create_test_building_data(building_id: String = "test_building", cost: Dictionary = {}) -> BuildingData:
	var data := BuildingData.new()
	data.building_id = building_id
	data.display_name = building_id.capitalize()
	data.building_type = BuildingTypes.BuildingType.GATHERER
	data.max_workers = 1
	data.build_cost = cost
	return data

# =============================================================================
# BuildingMenuPanel Tests
# =============================================================================

func test_building_menu_panel_scene_loads() -> void:
	_panel = _create_panel()
	assert_not_null(_panel, "BuildingMenuPanel scene should load")


func test_building_menu_panel_initially_hidden() -> void:
	_panel = _create_panel()
	if not _panel:
		pending("BuildingMenuPanel not loaded - uid files need to be generated")
		return

	await get_tree().process_frame
	assert_false(_panel.visible, "BuildingMenuPanel should be initially hidden")


func test_building_menu_panel_show_menu() -> void:
	_panel = _create_panel()
	if not _panel:
		pending("BuildingMenuPanel not loaded - uid files need to be generated")
		return

	await get_tree().process_frame
	_panel.show_menu()
	await get_tree().process_frame

	assert_true(_panel.visible, "Panel should be visible after show_menu()")


func test_building_menu_panel_hide_menu() -> void:
	_panel = _create_panel()
	if not _panel:
		pending("BuildingMenuPanel not loaded - uid files need to be generated")
		return

	await get_tree().process_frame
	_panel.show_menu()
	await get_tree().process_frame
	_panel.hide_menu()
	await get_tree().process_frame

	assert_false(_panel.visible, "Panel should be hidden after hide_menu()")


func test_building_menu_panel_is_showing() -> void:
	_panel = _create_panel()
	if not _panel:
		pending("BuildingMenuPanel not loaded - uid files need to be generated")
		return

	await get_tree().process_frame
	assert_false(_panel.is_showing(), "is_showing() should return false initially")

	_panel.show_menu()
	await get_tree().process_frame

	assert_true(_panel.is_showing(), "is_showing() should return true after show_menu()")


func test_building_menu_panel_emits_menu_opened_signal() -> void:
	_panel = _create_panel()
	if not _panel:
		pending("BuildingMenuPanel not loaded - uid files need to be generated")
		return

	await get_tree().process_frame

	watch_signals(EventBus)
	_panel.show_menu()
	await get_tree().process_frame

	assert_signal_emitted(EventBus, "menu_opened", "menu_opened signal should be emitted")
	assert_signal_emitted_with_parameters(EventBus, "menu_opened", ["building_menu"])


func test_building_menu_panel_emits_menu_closed_signal() -> void:
	_panel = _create_panel()
	if not _panel:
		pending("BuildingMenuPanel not loaded - uid files need to be generated")
		return

	await get_tree().process_frame
	_panel.show_menu()
	await get_tree().process_frame

	watch_signals(EventBus)
	_panel.hide_menu()
	await get_tree().process_frame

	assert_signal_emitted(EventBus, "menu_closed", "menu_closed signal should be emitted")
	assert_signal_emitted_with_parameters(EventBus, "menu_closed", ["building_menu"])


func test_building_menu_panel_populates_buildings() -> void:
	_panel = _create_panel()
	if not _panel:
		pending("BuildingMenuPanel not loaded - uid files need to be generated")
		return

	await get_tree().process_frame
	_panel.show_menu()
	await get_tree().process_frame

	var menu_items: Array[BuildingMenuItem] = _panel.get_menu_items()
	assert_gt(menu_items.size(), 0, "Menu should have at least one building item")

# =============================================================================
# BuildingMenuItem Tests
# =============================================================================

func test_building_menu_item_scene_loads() -> void:
	_item = _create_item()
	assert_not_null(_item, "BuildingMenuItem scene should load")


func test_building_menu_item_setup() -> void:
	_item = _create_item()
	if not _item:
		pending("BuildingMenuItem not loaded - uid files need to be generated")
		return

	await get_tree().process_frame

	_test_building_data = _create_test_building_data("test_farm", {"wood": 10})
	_item.setup(_test_building_data)
	await get_tree().process_frame

	assert_eq(_item.get_building_data(), _test_building_data, "Building data should be stored")


func test_building_menu_item_affordability_with_resources() -> void:
	_item = _create_item()
	if not _item:
		pending("BuildingMenuItem not loaded - uid files need to be generated")
		return

	await get_tree().process_frame

	_test_building_data = _create_test_building_data("test_farm", {"wood": 10})

	# Give player enough resources
	ResourceManager.add_resource("wood", 20)

	_item.setup(_test_building_data)
	await get_tree().process_frame

	assert_true(_item.is_affordable(), "Building should be affordable with enough resources")


func test_building_menu_item_not_affordable_without_resources() -> void:
	_item = _create_item()
	if not _item:
		pending("BuildingMenuItem not loaded - uid files need to be generated")
		return

	await get_tree().process_frame

	_test_building_data = _create_test_building_data("test_farm", {"wood": 10})

	# No resources given
	_item.setup(_test_building_data)
	await get_tree().process_frame

	assert_false(_item.is_affordable(), "Building should not be affordable without resources")


func test_building_menu_item_update_affordability() -> void:
	_item = _create_item()
	if not _item:
		pending("BuildingMenuItem not loaded - uid files need to be generated")
		return

	await get_tree().process_frame

	_test_building_data = _create_test_building_data("test_farm", {"wood": 10})
	_item.setup(_test_building_data)
	await get_tree().process_frame

	assert_false(_item.is_affordable(), "Initially not affordable")

	# Add resources
	ResourceManager.add_resource("wood", 15)
	_item.update_affordability()

	assert_true(_item.is_affordable(), "Should be affordable after getting resources")


func test_building_menu_item_free_building_always_affordable() -> void:
	_item = _create_item()
	if not _item:
		pending("BuildingMenuItem not loaded - uid files need to be generated")
		return

	await get_tree().process_frame

	# Building with no cost
	_test_building_data = _create_test_building_data("test_free", {})
	_item.setup(_test_building_data)
	await get_tree().process_frame

	assert_true(_item.is_affordable(), "Free building should always be affordable")


func test_building_menu_item_emits_selected_signal() -> void:
	_item = _create_item()
	if not _item:
		pending("BuildingMenuItem not loaded - uid files need to be generated")
		return

	await get_tree().process_frame

	_test_building_data = _create_test_building_data("test_farm", {"wood": 10})
	ResourceManager.add_resource("wood", 20)

	_item.setup(_test_building_data)
	await get_tree().process_frame

	watch_signals(_item)

	# Call the internal button handler directly
	_item._on_button_pressed()

	assert_signal_emitted(_item, "selected", "selected signal should be emitted")
	var params: Array = get_signal_parameters(_item, "selected", 0)
	assert_eq(params.size(), 1, "Signal should have one parameter")
	if params.size() > 0:
		assert_eq(params[0], _test_building_data, "Received data should match")


func test_building_menu_item_no_selection_when_unaffordable() -> void:
	_item = _create_item()
	if not _item:
		pending("BuildingMenuItem not loaded - uid files need to be generated")
		return

	await get_tree().process_frame

	_test_building_data = _create_test_building_data("test_farm", {"wood": 10})
	# No resources - unaffordable

	_item.setup(_test_building_data)
	await get_tree().process_frame

	var signal_emitted := false
	var handler := func(_data: BuildingData):
		signal_emitted = true

	_item.selected.connect(handler)

	# Simulate button press on disabled item
	_item._on_button_pressed()

	assert_false(signal_emitted, "selected signal should NOT be emitted for unaffordable building")

	_item.selected.disconnect(handler)

# =============================================================================
# BuildButton Tests
# =============================================================================

func test_build_button_scene_loads() -> void:
	_button = _create_button()
	assert_not_null(_button, "BuildButton scene should load")


func test_build_button_emits_pressed_signal() -> void:
	_button = _create_button()
	if not _button:
		pending("BuildButton not loaded - uid files need to be generated")
		return

	await get_tree().process_frame

	watch_signals(_button)

	# Call the internal handler directly
	_button._on_button_pressed()

	assert_signal_emitted(_button, "pressed", "pressed signal should be emitted")

# =============================================================================
# EventBus Integration Tests
# =============================================================================

func test_building_placement_started_signal_exists() -> void:
	assert_true(EventBus.has_signal("building_placement_started"),
		"EventBus should have building_placement_started signal")


func test_building_placement_ended_signal_exists() -> void:
	assert_true(EventBus.has_signal("building_placement_ended"),
		"EventBus should have building_placement_ended signal")


func test_building_selection_emits_placement_started() -> void:
	_panel = _create_panel()
	if not _panel:
		pending("BuildingMenuPanel not loaded - uid files need to be generated")
		return

	await get_tree().process_frame

	# Give resources and show menu
	ResourceManager.add_resource("wood", 100)
	ResourceManager.add_resource("stone", 100)
	_panel.show_menu()
	await get_tree().process_frame

	watch_signals(EventBus)

	# Select first affordable building
	var menu_items: Array[BuildingMenuItem] = _panel.get_menu_items()
	if menu_items.size() > 0:
		var first_item: BuildingMenuItem = menu_items[0]
		if first_item.is_affordable():
			first_item._on_button_pressed()

	assert_signal_emitted(EventBus, "building_placement_started", "building_placement_started signal should be emitted on selection")

# =============================================================================
# Resource Change Response Tests
# =============================================================================

func test_panel_updates_affordability_on_resource_change() -> void:
	_panel = _create_panel()
	if not _panel:
		pending("BuildingMenuPanel not loaded - uid files need to be generated")
		return

	await get_tree().process_frame

	_panel.show_menu()
	await get_tree().process_frame

	var menu_items: Array[BuildingMenuItem] = _panel.get_menu_items()
	if menu_items.size() > 0:
		var first_item: BuildingMenuItem = menu_items[0]
		var _initial_affordable: bool = first_item.is_affordable()

		# Add lots of resources
		ResourceManager.add_resource("wood", 100)
		ResourceManager.add_resource("stone", 100)
		await get_tree().process_frame

		# Panel should have updated via signal
		var new_affordable: bool = first_item.is_affordable()
		assert_true(new_affordable, "Item should be affordable after getting resources")
	else:
		fail_test("No menu items found")
