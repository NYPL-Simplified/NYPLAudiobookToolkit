# Build

Use Xcode 13 and carthage v0.38.

First build carthage dependencies:
```bash
carthage update --use-xcframeworks --platform ios --cache-builds
```
Open Xcode project and build normally.

# Notes for how to integrate NYPLAudioToolkit into your project

1) Edit your Cartfile and add: `github "NYPL-Simplified/NYPLAudiobookToolkit" "master"`
2) Open Access Support is built-in. Other DRM providers will require licenses. Example: NYPL supports the Findaway Audioengine SDK with `NYPLAEToolkit`, which requires a license paid to Findaway.
3) Ensure host has "Background Modes" enabled in Build Settings: Allow audio playback and airplay from the background
