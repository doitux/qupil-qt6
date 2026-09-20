# Mobile build status

The project contains reproducible Android and iOS packaging scripts:

- `scripts/build-android-release.sh` produces `dist/Qupil-android-arm64.apk`.
- `scripts/build-ios-unsigned.sh` produces `dist/Qupil-ios-unsigned.ipa` on macOS/Xcode.
- `.github/workflows/mobile-build.yml` provisions Qt 6.11.2 and the Android/iOS host toolchains on appropriate CI runners and uploads both artifacts.

## Signing

The Android CI artifact is intended as a development/test package unless signing is configured separately.
The iOS artifact is intentionally unsigned. A device-installable or App Store IPA requires an Apple Developer signing identity and provisioning profile.

## Local build host requirements

Android requires Qt for Android, Android SDK/NDK and JDK 21.
iOS requires macOS, Xcode and a Qt iOS kit; Apple does not provide the iOS SDK/toolchain for Linux.
