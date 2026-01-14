## SelectableComponent - Handles tap/click detection for animal selection.
## Stub implementation - full functionality in Story 2-3.
##
## Architecture: scripts/entities/animals/components/selectable_component.gd
## Story: 2-1-create-animal-entity-structure (stub)
## Full Implementation: 2-3-implement-animal-selection
class_name SelectableComponent
extends Node

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when this entity is tapped/clicked
signal tapped()

## Emitted when selection state changes
signal selection_changed(is_selected: bool)

# =============================================================================
# PROPERTIES
# =============================================================================

## Whether this entity is currently selected
var _is_selected: bool = false

# =============================================================================
# PUBLIC API (STUB)
# =============================================================================

## Check if entity is currently selected
func is_selected() -> bool:
	return _is_selected


## Select this entity (stub - full implementation in Story 2-3)
func select() -> void:
	if _is_selected:
		return
	_is_selected = true
	selection_changed.emit(true)


## Deselect this entity (stub - full implementation in Story 2-3)
func deselect() -> void:
	if not _is_selected:
		return
	_is_selected = false
	selection_changed.emit(false)
