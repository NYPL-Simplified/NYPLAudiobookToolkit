[![Build and Unit Tests](https://github.com/NYPL-Simplified/NYPLAudiobookToolkit/Unit%20Tests/badge.svg)](https://github.com/NYPL-Simplified/NYPLAudiobookToolkit/actions?query=workflow%3A%22Unit%20Tests%22) [![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

# Overview

NYPLAudiobookToolkit provides utilities and UI components for audiobook playback.  It provides audio players based on AVFoundation for Open Access and DRM systems such as Overdrive and LCP. It is also possible to extend it externally with additional DRM systems. 

# Build

Requirements: 
- Xcode 13

# Unit Testing

`./scripts/run-unittests.sh` 

Unit testing on CI currently is done via xcodebuild because `swift test` is producing build errors.

# Integration

The only supported way to integrate NYPLAudioToolkit as a dependency is via SPM.

Support for Open Access audiobooks is built-in. Other DRM providers will require licenses. Example: NYPL supports the Findaway Audioengine SDK with `NYPLAEToolkit`, which requires a license paid to Findaway.

Ensure that the host app has "Background Modes" enabled in Build Settings: Allow audio playback and airplay from the background
