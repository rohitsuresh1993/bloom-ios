# Bloom

An iOS app for tracking your menstrual cycle and getting insights into your cycle and reproductive health —
period and fertility prediction, symptom/mood logging, and optional HealthKit export — with one rule that
shapes everything else: your cycle and symptom data never touches a server anyone but you controls.

## Why

Built as a direct response to repeated period-tracking app data breaches and reporting that user period data
has been shared with and mishandled by third parties. Bloom keeps all data local to your device by design —
there's no backend, no account required, and no analytics pipeline for your health data to leak through.

## Features

- Period and ovulation/fertile-window prediction, based on your own logged cycle history
- Day-by-day logging across mood, symptoms, flow intensity, sexual activity, physical activity, digestion,
  and more
- Optional, one-way export of logged data to Apple Health (Bloom never reads Health data back — your local
  data stays the single source of truth)
- Optional Sign in with Apple, used only as a future multi-device identity anchor — never required to log
  anything, and no password, ever
- Optional biometric app lock (Face ID / Touch ID)
- Self-reported condition tracking (e.g. PCOS, endometriosis) to adjust prediction defaults — never framed as
  diagnosis

## Tech stack

- **UI**: SwiftUI
- **Persistence**: SwiftData, fully local (`NSFileProtectionComplete` at rest)
- **Prediction**: Swift-native statistics (Bayesian blending over your own cycle history), no on-device ML
- **Auth**: Sign in with Apple (optional, no passwords)
- **Health integration**: HealthKit, write-only

## Requirements

- Xcode 16+
- iOS 18.5+ deployment target

## Building

```bash
# Build for a simulator
xcodebuild -project bloom-ios.xcodeproj -scheme bloom-ios -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Or just open `bloom-ios.xcodeproj` in Xcode and hit Cmd+R.

## License

MIT — see [LICENSE](LICENSE).
