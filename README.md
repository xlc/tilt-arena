# Tilt Arena

Tilt Arena is an iPhone-only SpriteKit arcade survival game.

## Project Generation

This repository uses XcodeGen to generate the Xcode project from `project.yml`.
The SwiftPM lockfile is committed at
`TiltArena.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`
so local and CI builds use the same package revisions.

```sh
xcodegen generate
```

Intentional dependency updates should include the generated `Package.resolved`
diff in the same change as any `project.yml` package edits.

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
