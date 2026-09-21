<!-- QUPIL_CI_MANAGED -->
# Qupil CI-Builds

Linux bleibt lokal in Qt Creator. GitHub Actions baut auf Wunsch Windows, macOS,
Android und iOS.

Start im Browser: **Actions -> Qupil on-demand builds -> Run workflow**.

Oder lokal:

```bash
./scripts/ci-trigger.sh windows
./scripts/ci-trigger.sh macos
./scripts/ci-trigger.sh android
./scripts/ci-trigger.sh ios
./scripts/ci-trigger.sh all
```

Optional ist Argument 2 ein Branch/Tag/Commit, z.B.:

```bash
./scripts/ci-trigger.sh android main
```

**Artifacts** sind temporaere Downloads eines einzelnen CI-Laufs (hier 14 Tage)
und ideal fuer Test-APK, Windows-ZIP oder Simulator-App. **GitHub Releases** sind
spaeter fuer dauerhafte, versionierte Downloads an Tags wie `v1.5.0` gedacht.

iOS baut zunaechst eine unsigned Simulator-App. Eine IPA fuer ein echtes iPhone
oder TestFlight braucht Apple-Code-Signing und wird spaeter separat ergaenzt.

Android baut zunaechst ein ARM64-Debug-APK fuer schnelle Tests.

CI verwendet Qt 6.11.2; dein lokales Qt 6/Qt Creator wird nicht veraendert.
