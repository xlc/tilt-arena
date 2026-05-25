# Tilt Arena

Tilt Arena is an iPhone-only SpriteKit arcade survival game.

## Project Generation

This repository uses XcodeGen to generate the Xcode project from `project.yml`.

```sh
xcodegen generate
```

## Build

```sh
xcodebuild -project TiltArena.xcodeproj \
  -scheme TiltArena \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## Release QA

- [Game Center App Store Connect setup and QA](docs/game-center-release-qa.md)
