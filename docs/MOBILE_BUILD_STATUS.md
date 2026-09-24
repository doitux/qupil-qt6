# CI build artifacts

`Qupil on-demand builds` is the single GitHub Actions workflow for Windows, macOS, Android and iOS test packages.

Each artifact is uploaded as the native single-file package for its platform. No GitHub Release is created just to download a CI build.

File names include the Qupil version from `CMakeLists.txt` and the 7-character source commit, for example:

- `Qupil-1.5.28-b573a03-Windows-x64-Setup.exe`
- `Qupil-1.5.28-b573a03-macOS-arm64.dmg`
- `Qupil-1.5.28-b573a03-Android-arm64.apk`
- `Qupil-1.5.28-b573a03-iOS-arm64.ipa`

## Packaging

- Windows: `windeployqt` collects Qt runtime files and Inno Setup creates one per-user installer EXE.
- macOS: `macdeployqt` prepares the app bundle and `hdiutil` creates a compressed DMG with an Applications shortcut.
- Android: the generated ARM64 APK is renamed to the version/commit build identity and uploaded directly.
- iOS/iPadOS: the unsigned device app is packed as an IPA and uploaded directly as a workflow artifact.

## Signing

These CI packages are development/test builds. Windows and macOS packages are not code-signed/notarized by this workflow. Android signing is not configured here. The iOS IPA is intentionally unsigned for the existing sideload/test workflow.

## Local build host requirements

Android requires Qt for Android, Android SDK/NDK and a compatible JDK. iOS requires macOS, Xcode and a Qt iOS kit; Apple does not provide the iOS SDK/toolchain for Linux.
