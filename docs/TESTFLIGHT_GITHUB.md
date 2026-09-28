# Qupil 1.5.28 - GitHub TestFlight-ready CI

This package adds a **separate, explicit TestFlight distribution job** while leaving the existing unsigned SideStore IPA job intact.

## What changes

- Bundle ID remains `org.qupil.app`.
- Existing `target=ios` continues to create the unsigned SideStore IPA.
- Existing `target=all` still builds normal platform artifacts and **never uploads to App Store Connect**.
- New `target=ios-testflight`:
  - builds the same Qt 6.11.2 iOS source with Xcode 26,
  - uses a unique numeric `CFBundleVersion` from `GITHUB_RUN_NUMBER.GITHUB_RUN_ATTEMPT`,
  - imports an Apple Distribution `.p12` into an ephemeral keychain,
  - validates and installs the App Store Connect provisioning profile for `org.qupil.app`,
  - prebuilds Release and creates a real `.xcarchive`,
  - exports an App Store Connect IPA,
  - verifies bundle ID/version/build/signature,
  - preserves the signed IPA and dSYMs as GitHub artifacts,
  - validates and uploads the IPA with `xcrun altool` and an App Store Connect API key,
  - deletes signing material from the runner in an `always()` cleanup step.

No Apple credential, certificate, provisioning profile or API key is committed to Git.

## Apply

```bash
cd ~/Downloads/qupil-testflight-ready-1.5.28
./apply-testflight-ready.sh --dry-run
./apply-testflight-ready.sh
```

The normal apply run creates and pushes:

```text
feat(ci): add TestFlight distribution workflow
```

## One-time Apple setup later

Before running `target=ios-testflight`, the organization needs:

1. Explicit App ID / Bundle ID: `org.qupil.app`.
2. App record in App Store Connect for Qupil using that Bundle ID.
3. Apple Distribution certificate and its private key exported as `.p12`.
4. App Store Connect distribution provisioning profile for `org.qupil.app` using that distribution certificate.
5. App Store Connect **team API key** (`.p8`) with a role allowed to upload builds.

The App Store provisioning profile is intentionally validated in CI. Development, Ad Hoc, expired, Enterprise, wrong-Team and wrong-Bundle profiles are rejected before compilation.

## GitHub repository secrets

Add these in **Settings -> Secrets and variables -> Actions -> Repository secrets**:

```text
APPLE_TEAM_ID
IOS_DISTRIBUTION_CERTIFICATE_P12_BASE64
IOS_DISTRIBUTION_CERTIFICATE_PASSWORD
IOS_APP_STORE_PROFILE_BASE64
APP_STORE_CONNECT_KEY_ID
APP_STORE_CONNECT_ISSUER_ID
APP_STORE_CONNECT_API_KEY_P8_BASE64
```

On macOS, create the Base64 values without line breaks, for example:

```bash
base64 < Qupil-Distribution.p12 | tr -d '\n'
base64 < Qupil-AppStore.mobileprovision | tr -d '\n'
base64 < AuthKey_XXXXXXXXXX.p8 | tr -d '\n'
```

Store the matching `.p12` password as `IOS_DISTRIBUTION_CERTIFICATE_PASSWORD`.

`APPLE_TEAM_ID` is the 10-character Developer Team ID. `APP_STORE_CONNECT_KEY_ID` and `APP_STORE_CONNECT_ISSUER_ID` come from the App Store Connect API key page.

## First TestFlight run

In GitHub Actions choose **Qupil on-demand builds -> Run workflow** and select:

```text
target:     ios-testflight
source_ref: main
```

The job first validates all signing material. Only after creating and verifying the signed IPA does it contact App Store Connect. A successful upload still has to be processed by Apple before the build appears in the TestFlight tab.

## Deliberately not automated yet

This v1 does **not** create the App Store Connect app record, assign TestFlight groups, submit for Beta App Review, or fill store metadata. Those are account-level operations and are best done after the organization account and roles are final.

It also does not set `ITSAppUsesNonExemptEncryption`. That should be decided after an export-compliance audit rather than guessed in CI.
