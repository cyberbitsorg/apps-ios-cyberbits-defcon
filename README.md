# Cyberbits Defcon Dash (iOS)

Surfaces the current cyber threat level with supporting indicators and a feed of recent security articles. Android companion lives at [apps-android-cyberbits-defcon](https://github.com/cyberbitsorg/apps-android-cyberbits-defcon).

## Stack

- Swift 5.9 + SwiftUI
- BackgroundTasks for periodic refresh (`com.cyberbits.defcon.refresh`)
- UserNotifications for threat-level alerts
- SwiftData persistence, with store accessors in [Data/](CyberbitsDefcon/Data/)
- iOS 17+, iPhone & iPad

## Project generation

The Xcode project is generated from [project.yml](project.yml) using [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```bash
brew install xcodegen
xcodegen generate
```

Re-run `xcodegen` after editing `project.yml` or adding files outside Xcode.

## Build & run

Open `CyberbitsDefcon.xcodeproj` in Xcode and run the `CyberbitsDefcon` scheme on a simulator or device.

CLI build:

```bash
xcodebuild -project CyberbitsDefcon.xcodeproj \
  -scheme CyberbitsDefcon \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  build
```

## Tests

```bash
xcodebuild -project CyberbitsDefcon.xcodeproj \
  -scheme CyberbitsDefcon \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  test
```

## Project layout

- [CyberbitsDefcon/App/](CyberbitsDefcon/App/) App entry point
- [CyberbitsDefcon/Views/](CyberbitsDefcon/Views/) SwiftUI views
- [CyberbitsDefcon/Models/](CyberbitsDefcon/Models/) Domain models
- [CyberbitsDefcon/Pipeline/](CyberbitsDefcon/Pipeline/) Fetch / parse / score pipeline
- [CyberbitsDefcon/Data/](CyberbitsDefcon/Data/) Persistence
- [CyberbitsDefcon/Shared/](CyberbitsDefcon/Shared/) Shared utilities
- [CyberbitsDefconTests/](CyberbitsDefconTests/) Unit tests
- [store/](store/) App Store assets
