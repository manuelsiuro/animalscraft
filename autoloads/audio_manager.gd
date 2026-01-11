## Audio system manager for AnimalsCraft.
## Autoload singleton - access via AudioManager.play_*
##
## Architecture: autoloads/audio_manager.gd
## Order: 6 (depends on Settings)
## Source: game-architecture.md#Audio
##
## Handles music playback, SFX, and volume control.
## Respects Settings for volume and mute state.
## NOTE: No class_name to avoid conflict with autoload singleton
extends Node

# =============================================================================
# AUDIO BUSES
# =============================================================================

## Audio bus names
const BUS_MASTER: String = "Master"
const BUS_MUSIC: String = "Music"
const BUS_SFX: String = "SFX"

# =============================================================================
# INTERNAL STATE
# =============================================================================

## Music player node
var _music_player: AudioStreamPlayer = null

## SFX player pool for overlapping sounds
var _sfx_players: Array[AudioStreamPlayer] = []

## Maximum concurrent SFX sounds
const MAX_SFX_PLAYERS: int = 8

## Current music track path (for resuming)
var _current_music_path: String = ""

## Music fade tween
var _music_tween: Tween = null

## Cached SFX resources for quick access
var _sfx_cache: Dictionary = {}

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	_setup_audio_players()
	_apply_settings()

	# Listen for settings changes
	EventBus.setting_changed.connect(_on_setting_changed)

	GameLogger.info("AudioManager", "Audio system initialized")


# =============================================================================
# MUSIC PLAYBACK
# =============================================================================

## Play background music.
## @param stream The AudioStream to play
## @param fade_in If true, fade in the music
func play_music(stream: AudioStream, fade_in: bool = true) -> void:
	if stream == null:
		GameLogger.warn("AudioManager", "Attempted to play null music stream")
		return

	if Settings.is_muted():
		return

	# Stop any current fade
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()

	var target_volume := _get_music_volume_db()

	if fade_in:
		_music_player.volume_db = -60.0
		_music_player.stream = stream
		_music_player.play()

		_music_tween = create_tween()
		_music_tween.tween_property(_music_player, "volume_db", target_volume, GameConstants.MUSIC_FADE_DURATION)
	else:
		_music_player.volume_db = target_volume
		_music_player.stream = stream
		_music_player.play()

	GameLogger.debug("AudioManager", "Playing music: %s" % stream.resource_path)


## Play music from a file path.
## @param path The path to the audio file (e.g., "res://assets/audio/music/plains_theme.ogg")
## @param fade_in If true, fade in the music
func play_music_from_path(path: String, fade_in: bool = true) -> void:
	if path.is_empty():
		return

	_current_music_path = path

	var stream := load(path) as AudioStream
	if stream == null:
		GameLogger.error("AudioManager", "Failed to load music: %s" % path)
		return

	play_music(stream, fade_in)


## Stop the current music.
## @param fade_out If true, fade out before stopping
func stop_music(fade_out: bool = true) -> void:
	if not _music_player.playing:
		return

	# Stop any current fade
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()

	if fade_out:
		_music_tween = create_tween()
		_music_tween.tween_property(_music_player, "volume_db", -60.0, GameConstants.MUSIC_FADE_DURATION)
		_music_tween.tween_callback(_music_player.stop)
	else:
		_music_player.stop()

	GameLogger.debug("AudioManager", "Stopping music")


## Pause music playback.
func pause_music() -> void:
	_music_player.stream_paused = true


## Resume music playback.
func resume_music() -> void:
	_music_player.stream_paused = false


## Check if music is currently playing.
func is_music_playing() -> bool:
	return _music_player.playing and not _music_player.stream_paused


# =============================================================================
# SFX PLAYBACK
# =============================================================================

## Play a sound effect.
## @param stream The AudioStream to play
## @param volume_offset Volume adjustment in dB (0 = normal)
func play_sfx(stream: AudioStream, volume_offset: float = 0.0) -> void:
	if stream == null:
		return

	if Settings.is_muted():
		return

	var player := _get_available_sfx_player()
	if player == null:
		GameLogger.debug("AudioManager", "No available SFX players")
		return

	player.volume_db = _get_sfx_volume_db() + volume_offset
	player.stream = stream
	player.play()


## Play a sound effect from a file path.
## Caches the stream for repeated use.
## @param path The path to the audio file
## @param volume_offset Volume adjustment in dB
func play_sfx_from_path(path: String, volume_offset: float = 0.0) -> void:
	if path.is_empty():
		return

	var stream: AudioStream

	# Check cache first
	if _sfx_cache.has(path):
		stream = _sfx_cache[path]
	else:
		stream = load(path) as AudioStream
		if stream == null:
			GameLogger.error("AudioManager", "Failed to load SFX: %s" % path)
			return
		_sfx_cache[path] = stream

	play_sfx(stream, volume_offset)


## Play a UI sound effect (click, hover, etc).
## @param sfx_name The name of the UI SFX (e.g., "click", "hover")
func play_ui_sfx(sfx_name: String) -> void:
	var path := "res://assets/audio/sfx/sfx_ui_%s.ogg" % sfx_name
	play_sfx_from_path(path)


# =============================================================================
# VOLUME CONTROL
# =============================================================================

## Set the master volume.
## @param volume Volume between 0.0 and 1.0
func set_master_volume(volume: float) -> void:
	var bus_idx := AudioServer.get_bus_index(BUS_MASTER)
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(volume))


## Set the music volume.
## @param volume Volume between 0.0 and 1.0
func set_music_volume(volume: float) -> void:
	Settings.set_music_volume(volume)
	_update_music_volume()


## Set the SFX volume.
## @param volume Volume between 0.0 and 1.0
func set_sfx_volume(volume: float) -> void:
	Settings.set_sfx_volume(volume)


## Toggle mute state.
func toggle_mute() -> void:
	Settings.set_muted(not Settings.is_muted())
	_apply_mute_state()


## Set mute state.
## @param muted True to mute all audio
func set_muted(muted: bool) -> void:
	Settings.set_muted(muted)
	_apply_mute_state()


# =============================================================================
# SYSTEM METHODS
# =============================================================================

## Reset audio system to default state.
## Called by ErrorHandler during recovery.
func reset() -> void:
	stop_music(false)
	_stop_all_sfx()
	_apply_settings()
	GameLogger.info("AudioManager", "Audio system reset")


# =============================================================================
# INTERNAL METHODS
# =============================================================================

## Setup audio player nodes.
func _setup_audio_players() -> void:
	# Create music player
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.bus = BUS_MUSIC
	add_child(_music_player)

	# Create SFX player pool
	for i in MAX_SFX_PLAYERS:
		var player := AudioStreamPlayer.new()
		player.name = "SFXPlayer%d" % i
		player.bus = BUS_SFX
		add_child(player)
		_sfx_players.append(player)


## Apply current settings to audio system.
func _apply_settings() -> void:
	_update_music_volume()
	_apply_mute_state()


## Update music player volume from settings.
func _update_music_volume() -> void:
	if _music_player.playing:
		_music_player.volume_db = _get_music_volume_db()


## Apply mute state to audio buses.
func _apply_mute_state() -> void:
	var muted := Settings.is_muted()

	var master_idx := AudioServer.get_bus_index(BUS_MASTER)
	if master_idx >= 0:
		AudioServer.set_bus_mute(master_idx, muted)


## Get music volume in decibels.
func _get_music_volume_db() -> float:
	return linear_to_db(Settings.get_music_volume())


## Get SFX volume in decibels.
func _get_sfx_volume_db() -> float:
	return linear_to_db(Settings.get_sfx_volume())


## Get an available SFX player from the pool.
func _get_available_sfx_player() -> AudioStreamPlayer:
	for player in _sfx_players:
		if not player.playing:
			return player
	# All busy, return the first one (will interrupt oldest sound)
	return _sfx_players[0]


## Stop all SFX players.
func _stop_all_sfx() -> void:
	for player in _sfx_players:
		player.stop()


## Handle setting changes from EventBus.
func _on_setting_changed(setting_name: String, _new_value: Variant) -> void:
	match setting_name:
		"audio.music_volume":
			_update_music_volume()
		"audio.sfx_volume":
			pass  # SFX volume is applied per-sound
		"audio.muted":
			_apply_mute_state()
