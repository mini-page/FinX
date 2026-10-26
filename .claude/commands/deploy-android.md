# deploy-android — Build & Release for Android

## Purpose
Step-by-step guide to building and releasing the Expensioa APK or App Bundle for Android.

## Prerequisites
- Flutter SDK installed and on PATH.
- Android SDK with build tools configured.
- Keystore file configured in `android/key.properties` (do **not** commit this file).

## Build Commands

### Debug APK (for testing)
```bash
flutter build apk --debug
# Output: build/app/outputs/flutter-apk/app-debug.apk
```

### Release APK (split by ABI — smaller downloads)
```bash
flutter build apk --release --split-per-abi
# Outputs:
#   app-armeabi-v7a-release.apk
#   app-arm64-v8a-release.apk
#   app-x86_64-release.apk
```

### Release App Bundle (recommended for Play Store)
```bash
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

## Signing Setup
1. Generate a keystore (one-time):
   ```bash
   keytool -genkey -v -keystore ~/Expensioa-release.jks \
     -keyalg RSA -keysize 2048 -validity 10000 -alias Expensioa
   ```
2. Create `android/key.properties` (excluded from git):
   ```
   storePassword=<password>
   keyPassword=<password>
   keyAlias=Expensioa
   storeFile=<path-to>/Expensioa-release.jks
   ```
3. Reference in `android/app/build.gradle` (already configured if set up).

## Pre-Release Checklist
- [ ] `flutter analyze` passes with zero issues.
- [ ] `flutter test` passes.
- [ ] Version bumped in `pubspec.yaml` (`version: X.Y.Z+build`).
- [ ] `CHANGELOG` updated.
- [ ] Release APK/AAB tested on a physical device.

## Upload to Play Store
Use the Play Console or `fastlane supply` to upload the `.aab`.
