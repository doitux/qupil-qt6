#!/usr/bin/env python3
from pathlib import Path

root = Path(__file__).resolve().parents[1]
workflow = (root / '.github/workflows/qupil-build-on-demand.yml').read_text(encoding='utf-8')
cmake = (root / 'CMakeLists.txt').read_text(encoding='utf-8')

checks = {
    'bundle id stays org.qupil.app': 'XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER "org.qupil.app"' in cmake,
    'numeric iOS build number cache exists': 'QUPIL_IOS_BUILD_NUMBER' in cmake,
    'iOS bundle version uses CI build number': 'MACOSX_BUNDLE_BUNDLE_VERSION "${QUPIL_IOS_BUILD_NUMBER}"' in cmake,
    'TestFlight dispatch target exists': '          - ios-testflight\n' in workflow,
    'TestFlight job exists': '  ios_testflight:\n' in workflow,
    'TestFlight job is explicit only': "if: ${{ inputs.target == 'ios-testflight' }}" in workflow,
    'unsigned SideStore job remains': 'name: iOS/iPadOS unsigned IPA' in workflow and 'Package unsigned IPA' in workflow,
    'App Store export exists': 'xcodebuild -exportArchive' in workflow,
    'App Store method is current': "'method': 'app-store-connect'" in workflow,
    'App Store validation exists': '--validate-app' in workflow,
    'App Store upload exists': '--upload-app' in workflow,
    'App Store Connect API key secret exists': 'APP_STORE_CONNECT_API_KEY_P8_BASE64' in workflow,
    'distribution certificate secret exists': 'IOS_DISTRIBUTION_CERTIFICATE_P12_BASE64' in workflow,
    'distribution profile secret exists': 'IOS_APP_STORE_PROFILE_BASE64' in workflow,
    'dSYM archive workaround enabled': '-DQT_USE_RISKY_DSYM_ARCHIVING_WORKAROUND=ON' in workflow,
    'TestFlight enables FFmpeg code signing': '-DQUPIL_IOS_DISABLE_FFMPEG_CODE_SIGN_ON_COPY=OFF' in workflow,
    'CMake keeps unsigned FFmpeg signing switch': 'QUPIL_IOS_DISABLE_FFMPEG_CODE_SIGN_ON_COPY' in cmake and 'QT_NO_FFMPEG_XCODE_EMBED_FRAMEWORKS_CODE_SIGN_ON_COPY' in cmake,
    'all target cannot trigger TestFlight': "inputs.target == 'all' || inputs.target == 'ios-testflight'" not in workflow,
}

failed = [name for name, ok in checks.items() if not ok]
if failed:
    raise SystemExit('TestFlight static smoke FAILED:\n- ' + '\n- '.join(failed))
print(f'TestFlight static smoke PASS ({len(checks)} checks)')
