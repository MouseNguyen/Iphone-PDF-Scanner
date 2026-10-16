#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "$(uname -s)" != Darwin ]]; then
  echo 'This compilation step requires the cloud macOS runner, not Windows.' >&2
  exit 1
fi
export CI=1 EXPO_NO_TELEMETRY=1
mkdir -p verification/cloud-build
xcodebuild -version | tee verification/cloud-build/xcode-version.txt
python3 - <<'PY'
import re, subprocess
version = subprocess.check_output(['xcodebuild', '-version'], text=True)
match = re.search(r'Xcode (\d+)\.(\d+)', version)
if not match or tuple(map(int, match.groups())) < (26, 4):
    raise SystemExit('Expo SDK 58 requires Xcode 26.4 or newer. Stop; do not download a different Xcode automatically.')
PY
command -v pod >/dev/null || { echo 'CocoaPods is missing on this runner.' >&2; exit 1; }
npm ci --ignore-scripts
npm test
npm run typecheck
npx --no-install expo install --check
npx --no-install expo prebuild --platform ios --no-install
(cd ios && pod install)
python3 - <<'PY'
import pathlib, subprocess, shutil, zipfile, plistlib
root = pathlib.Path.cwd()
workspaces = list((root / 'ios').glob('*.xcworkspace'))
if len(workspaces) != 1:
    raise SystemExit('Expected one generated app workspace')
workspace = workspaces[0]
scheme = workspace.stem
out = root / 'verification' / 'cloud-build'
archive = out / 'PocketScanner.xcarchive'
subprocess.run([
    'xcodebuild', '-workspace', str(workspace), '-scheme', scheme,
    '-configuration', 'Release', '-destination', 'generic/platform=iOS',
    '-archivePath', str(archive), 'archive',
    'CODE_SIGNING_ALLOWED=NO', 'CODE_SIGNING_REQUIRED=NO', 'CODE_SIGN_IDENTITY=',
], check=True)
apps = list((archive / 'Products' / 'Applications').glob('*.app'))
if len(apps) != 1:
    raise SystemExit('Expected exactly one archived iPhone app')
app = apps[0]
with (app / 'Info.plist').open('rb') as stream:
    info = plistlib.load(stream)
if info.get('CFBundleSupportedPlatforms') != ['iPhoneOS']:
    raise SystemExit('Archive is not an iPhone device build')
if (app / 'embedded.mobileprovision').exists():
    raise SystemExit('Unexpected provisioning profile in unsigned output')
if not any(p.name.startswith('main.jsbundle') for p in app.rglob('*')):
    raise SystemExit('Release JavaScript bundle missing; do not publish a server-dependent app')
payload = out / 'Payload'
payload.mkdir(exist_ok=False)
shutil.copytree(app, payload / app.name, symlinks=True)
subprocess.run(['/usr/bin/ditto', '-c', '-k', '--sequesterRsrc', '--keepParent', str(payload), str(out / 'PocketScanner-unsigned.ipa')], check=True)
with zipfile.ZipFile(out / 'PocketScanner-unsigned.ipa') as ipa:
    if not any(name.startswith('Payload/') and name.endswith('.app/Info.plist') for name in ipa.namelist()):
        raise SystemExit('Invalid IPA layout')
print('Unsigned iPhone IPA produced. It still needs personal signing through the Windows sideloading tool.')
PY
