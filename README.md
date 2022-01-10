# Overview

NYPLAudiobookToolkit provides utilities and UI components for audiobook playback.  It provides audio players based on AVFoundation for Open Access and DRM systems such as Overdrive and LCP. It is also possible to extend it externally with additional DRM systems. 

# Build

Requirements: 
- Xcode 13

The recommended way to work and integrate this project into others is to use Swift Package Manager. We currently still maintain an Xcode project, but this might be deprecated soon. 

## Carthage Build

If you can't use SPM, you can still use carthage v0.38. First build carthage dependencies:
```bash
carthage update --use-xcframeworks --platform ios --cache-builds
```
Then open the Xcode project and build normally.

# Integration

## Integrate NYPLAudioToolkit via SPM

There's nothing special about integrating NYPLAudioToolkit via SPM.

## Integrate NYPLAudioToolkit via carthage

1) Edit your Cartfile and add: `github "NYPL-Simplified/NYPLAudiobookToolkit" "master"`
2) Open Access Support is built-in. Other DRM providers will require licenses. Example: NYPL supports the Findaway Audioengine SDK with `NYPLAEToolkit`, which requires a license paid to Findaway.
3) Ensure host has "Background Modes" enabled in Build Settings: Allow audio playback and airplay from the background
