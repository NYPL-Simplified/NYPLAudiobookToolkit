# NYPLAudiobookToolkit

## Building

1) Install [Carthage](https://github.com/Carthage/Carthage)
2) Run `carthage bootstrap` at the root
3) Build the toolkit in Xcode

## Integration

1) Add repo to the app's Cartfile
2) Add relevant Player toolkits to repo, currently NYPLAEToolkit is the only player
3) Ensure host has Background Modes enabled
3) Allow audio playback and airplay from the background
