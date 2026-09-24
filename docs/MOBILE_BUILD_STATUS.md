# Mobile build status

Qupil's mobile CI is consolidated in `.github/workflows/qupil-build-on-demand.yml`.
Start **Qupil on-demand builds** manually in GitHub Actions and choose `android`, `ios`, or `all` (or another desktop target when needed). The selected `source_ref` is checked out and built directly.

The project also keeps reproducible packaging/build scripts where they are useful locally:

- `scripts/build-android-release.sh` produces `dist/Qupil-android-arm64.apk` when used by the standalone/local packaging path.
- `scripts/build-ios-unsigned.sh` produces `dist/Qupil-ios-unsigned.ipa` on macOS/Xcode when used by the standalone/local packaging path.
- `.github/workflows/qupil-build-on-demand.yml` is the single GitHub Actions entry point for Windows, macOS, Android, and iOS builds and artifacts.

The former `.github/workflows/mobile-build.yml` workflow was removed because it duplicated the Android/iOS CI path and had drifted from the maintained on-demand workflow.

## Signing

The Android CI artifact is intended as a development/test package unless signing is configured separately.
The iOS artifact is intentionally unsigned. A device-installable or App Store IPA requires an Apple Developer signing identity and provisioning profile.

## Local build host requirements

Android requires Qt for Android, Android SDK/NDK and the JDK version expected by the active build path.
iOS requires macOS, Xcode and a Qt iOS kit; Apple does not provide the iOS SDK/toolchain for Linux.
