## Data resource defining a biome configuration.
##
## Biomes are unlockable game regions with unique terrain and animals.
## Each biome can be unlocked via milestones or starts unlocked (starting biome).
##
## Architecture: scripts/systems/biome/biome_data.gd
## Story: 6-11-implement-biome-unlock-preparation
class_name BiomeData
extends Resource

# =============================================================================
# EXPORTED PROPERTIES
# =============================================================================

## Unique identifier for this biome (e.g., "plains", "forest")
@export var id: String = ""

## Display name shown to player (e.g., "The Plains")
@export var display_name: String = ""

## Description of the biome for UI display
@export var description: String = ""

## Milestone ID that unlocks this biome (empty for starting biome)
@export var unlock_milestone: String = ""

## Terrain types available in this biome (e.g., ["grass", "forest", "water"])
@export var terrain_types: Array[String] = []

## Animal types that can spawn in this biome (e.g., ["rabbit", "fox"])
@export var animal_types: Array[String] = []

## True if this is the starting biome (always unlocked, e.g., Plains)
@export var is_starting_biome: bool = false
