# Pocket Scanner for iPhone

Original local document scanner informed by the Android PDF Scanner investigation. All product code, dependencies, caches, tests and verification output are contained in this folder. Source APK and analysis remain in the parent PDF Scanner project.

## Current evidence

The TypeScript application and local Swift module are written. Windows checks cover shared logic, TypeScript, Expo configuration/dependency compatibility, native-module discovery and JavaScript bundling. They do not compile Swift, prove camera/OCR/PDF behavior, or establish device readiness. See `verification/claim-ledger.json` and `verification/device-checklist.md`.

Duke confirmed no Apple Developer Program membership on 2026-10-16. Signed physical-device testing through the selected EAS route is blocked by that prerequisite. No account login, enrollment, cloud upload/build or paid quota use has occurred. Expo Go cannot run this custom scanner module.

## Implemented source paths

- Library, name/date/OCR text search, categories, grid/list, selection, rename and confirmed deletion.
- Native single/multipage document camera, gallery import, color-preserving photo capture and recoverable document drafts.
- Auto cleanup, grayscale, black/white, rotation, draggable/manual crop and retained base images.
- Vision recognition and searchable A4 PDF renderer, local Quick Look preview, image/PDF sharing.
- Explicit ID front/back review/composition with retained editable sides, QR review/copy, signature drawing/library/placements.

Use `src/app` for route files, feature folders for screens and shared logic, and `modules/scanner/ios` for native storage/processing. Swift owns metadata publication and app-owned files. File paths are stored relative to the scanner root to survive iOS container relocation.

## Local development

Existing Node 24.19.0 is compatible. Expo is pinned to 58.0.12 and dependencies are locked; npm cache is `.npm-cache/`. No global install is needed.

```powershell
Set-Location 'F:\Codex\Projects\rea\Projects\PDF Scanner\ios-app'
npm ci --ignore-scripts
npm test
npm run typecheck
$env:EXPO_NO_TELEMETRY = '1'
npx --no-install expo install --check
npm run config:check
npm run bundle:check
```

These are bounded local checks, not an iOS native build. `dist/` contains the exported iOS JavaScript/assets, not an installable `.ipa`. No development server is started by these commands. Project-local logs live in `verification/`.

The local module is autolinked as `PocketScanner` using `modules/scanner/ios/PocketScanner.podspec`. Native XCTest source is declared as the pod's `Tests` test spec; it needs an authorized macOS test target/lane and is not executed by `npm test`.

## Next physical-device step

After signing prerequisites and cloud effects are approved, use EAS's `development` profile for iteration and `preview` for an installed application with bundled JavaScript. Register both iPhones. `preview` is required for the airplane-mode/restart checks; a development server is not an offline product dependency. The app identifier is currently `com.duke.pocketscanner`; confirm ownership before any store submission, which is outside current scope.

If a development server is later authorized, reserve a dedicated high port and approve LAN access separately so the phones can connect. Nothing is listening now on the app's behalf.

## Limits requiring verification

System scans retain VisionKit's corrected output, not a raw uncropped camera original. Imported originals are retained as app-owned normalized copies. Physical tests must tune filters, verify OCR languages/accuracy, PDF Unicode/selection placement, gestures, orientation, permissions, interruption handling and iPhone 13 memory use. Intermediate edit/staging files are retained conservatively; deleting a document removes its document-owned history, while automatic orphan/staging reclamation is not implemented yet. Storage errors must remain visible and preserve saved metadata.

The original Android native math and five source-unknown groups remain unresolved. This independent iPhone implementation makes no exact filter or Android runtime parity claim.
