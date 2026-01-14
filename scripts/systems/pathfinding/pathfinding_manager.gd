## PathfindingManager - A* pathfinding on hex grid with caching and throttling.
##
## Provides optimal path calculation using Godot's AStar2D adapted for hex topology.
## Implements AR3 (AStar2D), AR8 (caching), AR15 (throttling) requirements.
##
## Architecture: scripts/systems/pathfinding/pathfinding_manager.gd
## Story: 2-5-implement-astar-pathfinding
class_name PathfindingManager
extends Node

# =============================================================================
# CONSTANTS
# =============================================================================

## Maximum path requests per frame (AR15) - uses GameConstants for single source of truth
const MAX_REQUESTS_PER_FRAME: int = GameConstants.MAX_PATH_REQUESTS_PER_FRAME

## Maximum cached paths before LRU eviction
const MAX_CACHE_SIZE: int = 100

## Coordinate offset for handling negative hex coordinates
## Supports grid up to ~2000x2000 hexes
const COORD_OFFSET: int = 1000

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when pathfinding graph is rebuilt
signal graph_rebuilt()

## Emitted when cache is invalidated
signal cache_invalidated()

## Emitted when a path is queued for deferred processing
signal path_queued(from: HexCoord, to: HexCoord)

# =============================================================================
# STATE
# =============================================================================

## AStar2D instance for pathfinding calculations
var _astar: AStar2D = AStar2D.new()

## Reference to WorldManager for terrain/tile data
## Uses Node type to allow mocking in tests
var _world_manager: Node = null

## Path cache: key = "from_q,from_r_to_q,to_r", value = Array[HexCoord]
var _path_cache: Dictionary = {}

## Cache access order for LRU eviction (oldest first)
var _cache_order: Array[String] = []

## Request count this frame
var _request_count: int = 0

## Deferred requests queue for next frame
var _request_queue: Array = []

## Whether graph is initialized
var _initialized: bool = false

## Mapping of point ID to HexCoord for reverse lookup
var _id_to_hex: Dictionary = {}

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	# Connect to EventBus for terrain changes
	if is_instance_valid(EventBus):
		EventBus.territory_claimed.connect(_on_territory_changed)
		EventBus.building_placed.connect(_on_building_placed)
		EventBus.building_removed.connect(_on_building_removed)

	if is_instance_valid(GameLogger):
		GameLogger.info("Pathfinding", "PathfindingManager initialized")


func _process(_delta: float) -> void:
	# Reset request count at frame start
	_request_count = 0

	# Process queued requests from previous frame
	_process_queued_requests()


func _exit_tree() -> void:
	# Clean up EventBus connections
	if is_instance_valid(EventBus):
		if EventBus.territory_claimed.is_connected(_on_territory_changed):
			EventBus.territory_claimed.disconnect(_on_territory_changed)
		if EventBus.building_placed.is_connected(_on_building_placed):
			EventBus.building_placed.disconnect(_on_building_placed)
		if EventBus.building_removed.is_connected(_on_building_removed):
			EventBus.building_removed.disconnect(_on_building_removed)

# =============================================================================
# PUBLIC API
# =============================================================================

## Initialize pathfinding with WorldManager reference.
## Must be called after WorldManager has generated tiles.
##
## @param world_manager The WorldManager instance (or mock with same interface)
func initialize(world_manager: Node) -> void:
	if world_manager == null:
		if is_instance_valid(GameLogger):
			GameLogger.error("Pathfinding", "Cannot initialize with null WorldManager")
		return

	_world_manager = world_manager
	build_graph()
	_initialized = true

	if is_instance_valid(GameLogger):
		GameLogger.info("Pathfinding", "Pathfinding graph built with %d points" % _astar.get_point_count())


## Request a path between two hex coordinates.
## Returns Array of HexCoord or empty array if no path exists.
## Subject to throttling (AR15): requests beyond limit are queued.
##
## @param from Starting hex coordinate
## @param to Destination hex coordinate
## @return Array of HexCoord representing the path, or empty if no path
func request_path(from: HexCoord, to: HexCoord) -> Array:
	if not _initialized:
		if is_instance_valid(GameLogger):
			GameLogger.warn("Pathfinding", "Pathfinding not initialized")
		return []

	# Null safety (AR18)
	if from == null or to == null:
		return []

	# Same start and end
	if from.q == to.q and from.r == to.r:
		return [from]

	# Check throttle limit (AR15)
	if _request_count >= MAX_REQUESTS_PER_FRAME:
		if is_instance_valid(GameLogger):
			GameLogger.debug("Pathfinding", "Request throttled, queuing for next frame")
		_queue_request(from, to)
		return []

	_request_count += 1

	# Check cache first (AR8)
	var cache_key := _make_cache_key(from, to)
	if _path_cache.has(cache_key):
		_update_cache_order(cache_key)
		if is_instance_valid(GameLogger):
			GameLogger.debug("Pathfinding", "Cache hit for path %s" % cache_key)
		return _duplicate_path(_path_cache[cache_key])

	# Calculate path via AStar
	var path := _calculate_path(from, to)

	# Cache result if valid
	if path.size() > 0:
		_cache_path(cache_key, path)

	return path


## Check if a path exists between two hex coordinates without caching.
##
## @param from Starting hex coordinate
## @param to Destination hex coordinate
## @return True if a path exists
func path_exists(from: HexCoord, to: HexCoord) -> bool:
	if not _initialized or from == null or to == null:
		return false

	if from.q == to.q and from.r == to.r:
		return true

	var from_id := _hex_to_point_id(from)
	var to_id := _hex_to_point_id(to)

	if not _astar.has_point(from_id) or not _astar.has_point(to_id):
		return false

	return _astar.get_id_path(from_id, to_id).size() > 0


## Rebuild the entire pathfinding graph.
## Call when major terrain changes occur.
func build_graph() -> void:
	_astar.clear()
	_path_cache.clear()
	_cache_order.clear()
	_id_to_hex.clear()

	if _world_manager == null:
		if is_instance_valid(GameLogger):
			GameLogger.warn("Pathfinding", "Cannot build graph: no WorldManager reference")
		return

	# Add all hex points from tiles
	var tiles: Array = _world_manager.get_all_tiles()
	for tile: Variant in tiles:
		if tile == null or tile.hex_coord == null:
			continue

		var hex: HexCoord = tile.hex_coord
		var point_id := _hex_to_point_id(hex)
		var world_pos := HexGrid.hex_to_world(hex)

		# Add point to AStar (using X and Z for 2D pathfinding on ground plane)
		_astar.add_point(point_id, Vector2(world_pos.x, world_pos.z))
		_id_to_hex[point_id] = hex

	# Connect neighbors
	for tile: Variant in tiles:
		if tile == null or tile.hex_coord == null:
			continue
		_connect_hex_neighbors(tile.hex_coord)

	graph_rebuilt.emit()


## Update a single hex in the graph (for terrain changes).
## More efficient than full rebuild for single tile changes.
##
## @param hex The hex coordinate that changed
func update_hex(hex: HexCoord) -> void:
	if not _initialized or hex == null:
		return

	# Reconnect this hex based on new passability
	_reconnect_hex_neighbors(hex)

	# Invalidate affected cache entries
	_invalidate_paths_through(hex)


## Invalidate all cached paths.
func invalidate_cache() -> void:
	_path_cache.clear()
	_cache_order.clear()
	cache_invalidated.emit()

	if is_instance_valid(GameLogger):
		GameLogger.debug("Pathfinding", "Path cache invalidated")


## Check if a hex is passable for pathfinding.
##
## @param hex The hex coordinate to check
## @return True if the hex is passable
func is_passable(hex: HexCoord) -> bool:
	if _world_manager == null or hex == null:
		return false

	var tile: Variant = _world_manager.get_tile_at(hex)
	if tile == null:
		return false

	# Water and rock are impassable (terrain_type 0 = GRASS)
	return tile.terrain_type == HexTile.TerrainType.GRASS


## Get the current number of cached paths.
func get_cache_size() -> int:
	return _path_cache.size()


## Get the current request count for this frame.
func get_frame_request_count() -> int:
	return _request_count


## Get the number of queued requests.
func get_queue_size() -> int:
	return _request_queue.size()


## Check if pathfinding is initialized.
func is_initialized() -> bool:
	return _initialized

# =============================================================================
# PRIVATE - GRAPH BUILDING
# =============================================================================

## Connect a hex to its passable neighbors.
func _connect_hex_neighbors(hex: HexCoord) -> void:
	if not is_passable(hex):
		return

	var point_id := _hex_to_point_id(hex)
	var neighbors := hex.get_neighbors()

	for neighbor in neighbors:
		# Check if neighbor is a valid tile
		if not _world_manager.has_tile_at(neighbor):
			continue

		# Check if neighbor is passable
		if not is_passable(neighbor):
			continue

		var neighbor_id := _hex_to_point_id(neighbor)

		# Connect if not already connected
		if _astar.has_point(neighbor_id) and not _astar.are_points_connected(point_id, neighbor_id):
			_astar.connect_points(point_id, neighbor_id, true)


## Reconnect a hex after terrain change.
func _reconnect_hex_neighbors(hex: HexCoord) -> void:
	var point_id := _hex_to_point_id(hex)

	if not _astar.has_point(point_id):
		return

	# Disconnect all existing connections
	var connected := _astar.get_point_connections(point_id)
	for connected_id in connected:
		_astar.disconnect_points(point_id, connected_id)

	# Reconnect if passable
	if is_passable(hex):
		_connect_hex_neighbors(hex)

	# Also update neighbors' connections to this hex
	var neighbors := hex.get_neighbors()
	for neighbor in neighbors:
		if _world_manager.has_tile_at(neighbor):
			var neighbor_id := _hex_to_point_id(neighbor)
			if _astar.has_point(neighbor_id):
				# Remove connection from neighbor to this hex
				if _astar.are_points_connected(neighbor_id, point_id):
					_astar.disconnect_points(neighbor_id, point_id)
				# Reconnect if both are passable
				if is_passable(neighbor) and is_passable(hex):
					_astar.connect_points(neighbor_id, point_id, true)

# =============================================================================
# PRIVATE - PATH CALCULATION
# =============================================================================

## Calculate path using AStar2D.
func _calculate_path(from: HexCoord, to: HexCoord) -> Array:
	var from_id := _hex_to_point_id(from)
	var to_id := _hex_to_point_id(to)

	# Check if points exist in graph
	if not _astar.has_point(from_id):
		if is_instance_valid(GameLogger):
			GameLogger.warn("Pathfinding", "Start point not in graph: %s" % from)
		return []

	if not _astar.has_point(to_id):
		if is_instance_valid(GameLogger):
			GameLogger.warn("Pathfinding", "End point not in graph: %s" % to)
		return []

	# Check if destination is passable
	if not is_passable(to):
		return []

	# Get path IDs from AStar
	var id_path: PackedInt64Array = _astar.get_id_path(from_id, to_id)

	if id_path.size() == 0:
		return []

	# Convert IDs to HexCoord array
	var hex_path: Array = []
	for id in id_path:
		if _id_to_hex.has(id):
			hex_path.append(_id_to_hex[id])

	return hex_path

# =============================================================================
# PRIVATE - CACHING
# =============================================================================

## Create cache key from coordinates.
func _make_cache_key(from: HexCoord, to: HexCoord) -> String:
	return "%d,%d_%d,%d" % [from.q, from.r, to.q, to.r]


## Cache a calculated path.
func _cache_path(key: String, path: Array) -> void:
	# Evict LRU entries if at capacity
	while _path_cache.size() >= MAX_CACHE_SIZE and _cache_order.size() > 0:
		var evict_key: String = _cache_order.pop_front()
		_path_cache.erase(evict_key)

	_path_cache[key] = path
	_cache_order.append(key)


## Update cache access order for LRU.
func _update_cache_order(key: String) -> void:
	var idx := _cache_order.find(key)
	if idx >= 0:
		_cache_order.remove_at(idx)
	_cache_order.append(key)


## Duplicate a path array to avoid mutation.
func _duplicate_path(path: Array) -> Array:
	var result: Array = []
	for hex in path:
		result.append(hex)
	return result


## Invalidate cache entries that pass through a hex.
func _invalidate_paths_through(hex: HexCoord) -> void:
	var keys_to_remove: Array[String] = []

	for key in _path_cache.keys():
		var path: Array = _path_cache[key]
		for path_hex in path:
			if path_hex is HexCoord and path_hex.q == hex.q and path_hex.r == hex.r:
				keys_to_remove.append(key)
				break

	for key in keys_to_remove:
		_path_cache.erase(key)
		var idx := _cache_order.find(key)
		if idx >= 0:
			_cache_order.remove_at(idx)

	if keys_to_remove.size() > 0 and is_instance_valid(GameLogger):
		GameLogger.debug("Pathfinding", "Invalidated %d cached paths through hex (%d,%d)" % [keys_to_remove.size(), hex.q, hex.r])

# =============================================================================
# PRIVATE - THROTTLING
# =============================================================================

## Queue a request for next frame processing.
func _queue_request(from: HexCoord, to: HexCoord) -> void:
	_request_queue.append({"from": from, "to": to})
	path_queued.emit(from, to)


## Process queued requests from previous frame.
func _process_queued_requests() -> void:
	if _request_queue.is_empty():
		return

	var to_process := _request_queue.duplicate()
	_request_queue.clear()

	for request in to_process:
		if _request_count >= MAX_REQUESTS_PER_FRAME:
			# Re-queue if still at limit
			_request_queue.append(request)
		else:
			# Process the request (result is discarded for async paths)
			request_path(request["from"], request["to"])

# =============================================================================
# PRIVATE - COORDINATE CONVERSION
# =============================================================================

## Convert HexCoord to unique point ID for AStar.
## Uses Cantor pairing function with offset for negative coordinates.
func _hex_to_point_id(hex: HexCoord) -> int:
	# Offset to handle negative coordinates
	var q := hex.q + COORD_OFFSET
	var r := hex.r + COORD_OFFSET
	# Cantor pairing: (q + r) * (q + r + 1) / 2 + r
	return int((q + r) * (q + r + 1) / 2 + r)


## Convert point ID back to HexCoord.
## Reverses the Cantor pairing function.
func _point_id_to_hex(id: int) -> HexCoord:
	# Reverse Cantor pairing
	var w := int(floor((sqrt(8.0 * float(id) + 1.0) - 1.0) / 2.0))
	var t := (w * w + w) / 2
	var r := id - t
	var q := w - r

	var hex := HexCoord.new()
	hex.q = q - COORD_OFFSET  # Remove offset
	hex.r = r - COORD_OFFSET
	return hex

# =============================================================================
# SIGNAL HANDLERS
# =============================================================================

## Handle territory state changes.
func _on_territory_changed(hex_vec: Vector2i) -> void:
	var hex := HexCoord.from_vector(hex_vec)
	update_hex(hex)


## Handle building placement (buildings may block paths).
func _on_building_placed(_building: Node, hex_vec: Vector2i) -> void:
	var hex := HexCoord.from_vector(hex_vec)
	update_hex(hex)


## Handle building removal (paths may become available).
func _on_building_removed(_building: Node) -> void:
	# Full rebuild may be needed if we don't know which hex
	# For now, just invalidate cache
	invalidate_cache()
