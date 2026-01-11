# AnimalsCraft Android Export Guide

## Overview

This guide documents the Android export configuration for AnimalsCraft, a Godot 4.5.1 mobile game targeting Android 9.0+ (API 28).

**Target Platform:** Android (Google Play)
**Engine:** Godot 4.5.1 with Mobile renderer
**Architecture:** ARM (armeabi-v7a, arm64-v8a)

---

## Prerequisites

### Required Software

| Software | Version | Purpose |
|----------|---------|---------|
| Godot Engine | 4.5.1 | Game engine |
| Android SDK | Platform 34 | Android build tools |
| Android NDK | r23+ | Native development |
| OpenJDK | 17 | Java runtime for Android tools |
| ADB | Latest | Device communication |

### Environment Variables

Set these environment variables in your shell profile (`.bashrc`, `.zshrc`, etc.):

```bash
# Android SDK
export ANDROID_HOME=/path/to/android/sdk
export ANDROID_SDK_ROOT=$ANDROID_HOME

# Add to PATH
export PATH=$PATH:$ANDROID_HOME/platform-tools
export PATH=$PATH:$ANDROID_HOME/tools
export PATH=$PATH:$ANDROID_HOME/tools/bin

# Java (OpenJDK 17)
export JAVA_HOME=/path/to/jdk-17
export PATH=$PATH:$JAVA_HOME/bin
```

**macOS Example:**
```bash
export ANDROID_HOME=~/Library/Android/sdk
export JAVA_HOME=/Library/Java/JavaVirtualMachines/openjdk-17.jdk/Contents/Home
```

**Linux Example:**
```bash
export ANDROID_HOME=~/Android/Sdk
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk
```

---

## Godot Editor Configuration

### Step 1: Configure Android Settings

1. Open Godot Editor
2. Go to **Editor > Editor Settings**
3. Navigate to **Export > Android**
4. Configure the following:

| Setting | Value | Notes |
|---------|-------|-------|
| Android SDK Path | `/path/to/android/sdk` | Your ANDROID_HOME path |
| Debug Keystore | `~/.android/debug.keystore` | Default debug keystore location |
| Debug Keystore User | `androiddebugkey` | Default alias |
| Debug Keystore Pass | `android` | Default password |

### Step 2: Install Export Templates

1. Go to **Editor > Manage Export Templates**
2. Click **Download and Install**
3. Wait for Godot 4.5.1 templates to download
4. Verify "Android" appears in the installed templates

### Step 3: Generate Debug Keystore (if missing)

If the debug keystore doesn't exist, generate it:

```bash
# Create .android directory if it doesn't exist
mkdir -p ~/.android

# Generate debug keystore
keytool -genkey -v \
  -keystore ~/.android/debug.keystore \
  -alias androiddebugkey \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -dname "CN=Android Debug,O=Android,C=US" \
  -storepass android \
  -keypass android
```

---

## Export Configuration

### Current Project Settings

**project.godot:**
```ini
[display]
window/size/viewport_width=1080
window/size/viewport_height=1920
window/stretch/mode="canvas_items"
window/stretch/aspect="keep_width"
window/handheld/orientation=1

[rendering]
renderer/rendering_method="mobile"
textures/vram_compression/import_etc2_astc=true
```

**export_presets.cfg:**
```ini
[preset.0]
name="Android"
platform="Android"
export_path="export/android/animalscraft.apk"

[preset.0.options]
gradle_build/min_sdk="28"
gradle_build/target_sdk="34"
architectures/armeabi-v7a=true
architectures/arm64-v8a=true
package/unique_name="com.bmadprojects.animalscraft"
package/name="AnimalsCraft"
package/signed=true
screen/immersive_mode=true
```

### Key Settings Explained

| Setting | Value | Rationale |
|---------|-------|-----------|
| Min SDK 28 | Android 9.0 | NFR6 requirement |
| Target SDK 34 | Android 14 | Play Store requirement |
| ARM architectures | Both enabled | Wide device compatibility |
| Immersive mode | Enabled | Full-screen gameplay |
| Mobile renderer | Enabled | Optimized for mobile GPUs |
| Portrait orientation | Locked | Game design requirement |

---

## Export Process

### Debug Build (Development)

1. Open project in Godot Editor 4.5.1
2. Go to **Project > Export**
3. Select **Android** preset
4. Click **Export Project**
5. Choose output: `export/android/animalscraft.apk`
6. Wait for export to complete

### Install on Device

```bash
# List connected devices
adb devices

# Install APK
adb install export/android/animalscraft.apk

# Install with replacement (if already installed)
adb install -r export/android/animalscraft.apk

# Launch the app
adb shell am start -n com.bmadprojects.animalscraft/com.godot.game.GodotApp
```

### Release Build (Production)

For Play Store releases, you'll need:

1. **Release Keystore:** Generate a production signing key
2. **App Bundle:** Use AAB format instead of APK
3. **Gradle Build:** Enable for production builds

```bash
# Generate release keystore
keytool -genkey -v \
  -keystore animalscraft-release.keystore \
  -alias animalscraft \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000
```

**Store this keystore securely!** Loss means you cannot update your app.

---

## Pre-Export Checklist

Run through this checklist before each export:

### Environment
- [ ] ANDROID_HOME environment variable set
- [ ] JAVA_HOME environment variable set
- [ ] Android SDK installed with Platform 34
- [ ] Android NDK installed

### Godot Editor Settings
- [ ] Android SDK Path configured
- [ ] Debug Keystore path configured
- [ ] Debug Keystore credentials set
- [ ] Export templates installed (4.5.1)

### Project Settings
- [ ] Mobile renderer enabled
- [ ] Viewport 1080x1920
- [ ] Portrait orientation (orientation=1)
- [ ] ETC2/ASTC compression enabled

### Export Preset
- [ ] Min SDK = 28
- [ ] Target SDK = 34
- [ ] ARM architectures enabled
- [ ] Package name correct
- [ ] Signed = true
- [ ] Immersive mode enabled

---

## Troubleshooting

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| "No export template found" | Templates not installed | Editor > Manage Export Templates > Download |
| "JDK not found" | Java not configured | Install OpenJDK 17, set JAVA_HOME |
| "Android SDK not found" | SDK path wrong | Check Editor Settings > Export > Android |
| "Keystore not found" | Missing debug.keystore | Generate with keytool command above |
| "ADB device not found" | USB debugging off | Enable in Android Settings > Developer Options |
| Export fails silently | Check Output panel | Look for detailed error messages |
| APK won't install | Architecture mismatch | Ensure ARM architectures enabled |
| Black screen on device | Missing export templates | Reinstall export templates |

### Debug Logging

Enable verbose logging during export:

1. Open Godot Editor
2. Go to **Editor > Editor Settings > Network > Debug**
3. Enable **Remote Debug**
4. Connect device and check Output panel

### ADB Commands

```bash
# Check device connection
adb devices

# View device logs (filter for Godot)
adb logcat | grep -i godot

# Clear app data
adb shell pm clear com.bmadprojects.animalscraft

# Uninstall app
adb uninstall com.bmadprojects.animalscraft

# Check APK info
aapt dump badging export/android/animalscraft.apk
```

---

## Performance Targets

| Metric | Target | Notes |
|--------|--------|-------|
| Frame Rate | 60 FPS stable | NFR1 |
| APK Size (placeholder) | < 10 MB | Current milestone |
| APK Size (full) | < 50 MB | NFR2 |
| Memory Usage | < 500 MB | NFR3 |
| Cold Start | < 5 seconds | NFR4 |
| Draw Calls | < 100/frame | NFR5 |

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 0.1.0 | 2026-01-11 | Initial Android export configuration |

---

## References

- [Godot Docs - Exporting for Android](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html)
- [Godot Docs - Android Plugin](https://docs.godotengine.org/en/stable/tutorials/platform/android/android_plugin.html)
- [Android Developers - SDK Setup](https://developer.android.com/studio)
- [Play Store Publishing Requirements](https://developer.android.com/distribute/best-practices/launch/launch-checklist)
