# SDKShift for Duo

**English** | [简体中文](README.zh-CN.md)

Change the SDK version tag recorded in LaunchServices to explore app display compatibility on iPhone Duo. The quick-action default follows the device’s current iOS version (27.1 → 27.1.0; 27.2.1 → 27.2.1); each app can also use a custom SDK tag. This does not recompile apps, upgrade iOS, or guarantee native Duo layouts.

> **Restart your iPhone after applying changes.** Respringing SpringBoard does not guarantee that SDK-related services and application state reload. A verified database write is not proof of a visible layout change. This project has no validated reboot-free refresh method.

> **How it works depends on an exploit, not a signature.** Writing the LaunchServices store relies on `worse_query` (a sandbox-escape PoC). Signing only decides whether the app installs and launches — it does not grant the ability to write the system database. Whether a write succeeds depends on the exploit being effective on the target iOS version.

## Features

- Three-page interface: Apps, History, and About. Pending changes, review, preflight and apply controls are integrated into Apps. The bottom panel appears only when changes are queued; expand its count to review or remove entries. The report remains available from the Apps toolbar.
- Set a different SDK tag for each app, including apps already at or above the current default. Queue changes or restorations and review old/new versions before writing.
- Accept `major.minor` or `major.minor.patch` (major 1–99; minor/patch 0–99). Two-part input normalizes to a zero patch. Invalid and unchanged values cannot be queued in the editor. Downgrades are explicitly labeled. These are format limits, not a list of released or compatible SDKs.
- Check without writing: validates the candidate database and reports write-access and lock results. This still creates temporary files inside the app and accesses the cache; it is not an offline, side-effect-free operation.
- Original SDK values and last-written values are stored separately, with migration from earlier SDKShift builds.
- Fresh SDK snapshot checks before applying, serialized engine access, and up to 30 local activity records.
- On-device letter avatars; no network icon lookup.
- **English by default**, plus Simplified Chinese, Traditional Chinese, Japanese, Korean, Spanish, French, German, and Vietnamese. Select **Apps → App language** at the top of the home page. The choice persists and takes effect immediately without changing SDK settings or recovery records. The seven additional languages cover the interface and operation notices; engine errors currently fall back to English. Simplified Chinese also translates engine errors. Technical traces and existing report snapshots remain verbatim for troubleshooting.

## Install (prebuilt IPA)

A prebuilt **unsigned** IPA is published on the [Releases](https://github.com/beinglida/SDKShift-for-Duo/releases) page. It is unsigned on purpose so you can sign it with your own certificate.

1. Download `SDKShift-unsigned.ipa` from the latest release.
2. Re-sign it with your own certificate — an enterprise certificate, or a personal/developer account via a tool such as Sideloadly. **Enable the App Groups capability and include any `group.*` identifier registered to your team.** The app reads whichever App Group is present in its signature at launch, so no source edit is required.
3. Install the signed IPA (MDM or an `itms-services://` manifest for enterprise distribution; the signing tool handles personal installs).
4. On the iPhone, trust the certificate under **Settings → General → VPN & Device Management**.
5. Launch the app, queue a change, apply it, then **fully restart the iPhone**.

If the app reports that no App Group is available, the signature is missing the App Groups capability — re-sign with it enabled. The provisioning profile must include the App Groups capability, not just the certificate.

## Build from source

Requires macOS with Xcode 27.2 (iOS 27 SDK). Deployment target is iOS 27.0.

**Run on a device from Xcode:** open `SDKShift.xcodeproj`, select your Team under Signing & Capabilities, add an App Groups capability with your own `group.*`, connect and trust the iPhone, enable Developer Mode, then build and run.

**Produce an unsigned IPA** (for later re-signing and distribution):

```sh
./build-unsigned-ipa.sh      # output: build/SDKShift-unsigned.ipa
```

The script compiles the Release configuration with code signing disabled and packages the `.app` into an unsigned IPA.

### App Group handling

The App Group identifier is **not hardcoded**. At launch the app reads `com.apple.security.application-groups` from its own code signature and uses the first `group.*` entry, so any signer can use their own App Group without editing or recompiling the source. `SDKShift.entitlements` uses `group.$(PRODUCT_BUNDLE_IDENTIFIER)` as a default for source builds; re-signing tools override it with their own group.

The project includes an AI-generated original teal icon: folded dual screens and opposing arrows symbolize SDK compatibility switching. It does not reuse ForceDuo's icon.

## Workflow

1. Scan the Apps page. All apps are shown by default; the optional filter shows only tags below the system-derived default.
2. Choose **Customize SDK** on an app card, enter a value such as `27.3.1`, and select **Queue change**. Reopen the editor to revise a queued target. **Use [version]** fills the current system-derived default; the card’s quick **Queue change** action uses that value for older tags. Expand **Pending** in the bottom panel on **Apps** to review all version pairs. A higher tag does not add APIs or establish compatibility with that SDK.
3. Run **1. Check without writing**. Inspect the report, including write-access and lock results, rather than relying on the completion title alone.
4. Run **2. Apply changes**, confirm, then **fully restart your iPhone**.
5. Check the target app on both displays and in both orientations.
6. To restore, use **Restore** on an eligible app card, review and apply the queued restoration, then restart again.

Scanning clears the pending queue so stale selections cannot be applied accidentally. App updates or database rebuilds can remove overrides. SDKShift uses a separate data container and does not automatically import another tool's original values. Restore earlier changes in the original tool before handing an app over to SDKShift.

The Apps page puts **Modified SDK** first, followed by **Other apps**, without duplicate cards. The modified group requires a saved SDKShift restore point matching the current SDK and differing from the original value. It shows original → current versions. Search applies to both groups; the below-default filter applies only to Other apps. Queued changes alone do not count as applied changes. Restoring an app removes it from the modified group. Changes made solely by other tools cannot be reliably identified without their records.

## Architecture

| File | Responsibility |
| --- | --- |
| `Sources/ShiftInterface.swift` | Card-based app library with integrated pending-change panel, history, settings and language picker |
| `Sources/ShiftWorkspace.swift` | Change requests, recovery points, persistence and legacy-data migration |
| `Sources/CacheGateway.swift` | Serialized engine adapter, fresh version checks and runtime localization |
| `Sources/FDEngine.m/.h` | Attributed upstream-derived database access, parsing and verified writes; resolves the App Group from the signed entitlements at launch |
| `Sources/worse_query.m/.h` | Third-party sandbox-extension implementation |
| `Sources/*.lproj` | Nine interface languages and localized messages |

The application layer was rewritten. The database engine and worse_query remain attributed dependencies; this is not a claim of a wholly independent implementation.

## Why a respring is insufficient as a supported workflow

The engine writes `.csstore` and verifies the file. It does not implement a validated system-wide cache invalidation protocol. SpringBoard, LaunchServices and app processes may retain different state. Restarting the desktop is not equivalent to refreshing all consumers.

This does not establish that respring can never work, or that restarting `lsd` alone must work. Full device restart remains the supported workflow. worse_query provides access to certain directories, not general system-service management permissions.

## Recently tested apps

Recorded on **November 15, 2026**, based on the project owner's two screenshots and reported test list. Environment reported in this session: **iPhone Duo / iOS 27.2**, SDK override **27.2.0**.

The screenshots show the earlier ForceDuo-style interface, not SDKShift's redesigned UI. All 13 unique apps below show **SDK 27.2 / Forced**. This documents the reported test list and displayed override state; the screenshots alone do not verify every app's post-restart layout, landscape behavior, or full functionality. App version/build numbers and per-app visual results were not supplied. Mystro appears in both screenshots and is listed once.

| App | Bundle ID | Observed state |
| --- | --- | --- |
| Amazon | `com.amazon.Amazon` | SDK 27.2 · Forced |
| Apple Store | `com.apple.store.Jolly` | SDK 27.2 · Forced |
| Canvas | `com.instructure.icanvas` | SDK 27.2 · Forced |
| Chrome | `com.google.chrome.ios` | SDK 27.2 · Forced |
| eBay | `com.ebay.iphone` | SDK 27.2 · Forced |
| Honor of Kings (global) | `com.levelinfinite.sgameGlobal` | SDK 27.2 · Forced |
| Mystro | `MystroDriver.MystroDriverMobile` | SDK 27.2 · Forced |
| Poe | `com.quora.app.Experts` | SDK 27.2 · Forced |
| Uber Driver | `com.ubercab.UberPartner` | SDK 27.2 · Forced |
| X | `com.atebits.Tweetie2` | SDK 27.2 · Forced |
| Quark (夸克) | `com.quark.browser` | SDK 27.2 · Forced |
| Douyin (抖音) | `com.ss.iphone.ugc.Aweme` | SDK 27.2 · Forced |
| Honor of Kings (China / 王者荣耀) | `com.tencent.smoba` | SDK 27.2 · Forced |

After app or system updates, recheck the override and display behavior. Apply changes, fully restart the iPhone, then validate each app on both screens and in both orientations.

### iOS 27.3 beta cache discovery diagnostics

This fork adapts the [ForceDuoApp 1.2 fix](https://github.com/34306/ForceDuoApp/commit/5b65200015f7ed0a0fdf34708bd857e4a34e1f80). Instead of scanning upward from inode 16, the fallback creates a temporary local probe file to estimate the current inode high-water mark, scans downward, then checks nearby inodes after the first matching cache. Reports now distinguish scan timeout, cache not found, and cache found but inaccessible.

**Limitations:** This improves cache discovery and diagnostics only. It has not been verified on an iOS 27.3 beta device and cannot guarantee read/write access to the system store. Scanning or performing a dry run does not write SDK changes. Review original SDK records carefully before applying changes: SDKShift cannot automatically recover original values corrupted by another tool.

## Validation and limits

An earlier build successfully read 604-byte Bundle records and parsed 400 apps on an iPhone Duo running iOS 27.2. The earlier SDKShift build was signed, installed and launched. The rewritten UI and bilingual build have passed local compilation; this is not proof of every target app's behavior or of visual QA on every device size.

Regression checks cover parsing and bounds, per-app targets, downgrades, preview, repeated edits, failed-write recovery, migration, restoration, SDK drift, busy-state guards, persistence and scan invalidation. No automatic SDK writes are performed at launch. Keep recovery data before uninstalling.

Run the model checks on macOS without device access or cache writes:

```sh
swiftc -parse-as-library Sources/ShiftWorkspace.swift Tests/WorkspaceChecks.swift -o /tmp/sdkshift-workspace-checks
/tmp/sdkshift-workspace-checks
python3 Tests/check_localizations.py
```

The default is derived locally from `ProcessInfo.operatingSystemVersion`, including the patch component. It does not query the latest downloadable SDK or use the Xcode build SDK. After an iOS update, the next app launch uses the new system version; previously written per-app tags and restore points are not automatically changed.

## Attribution and licensing

- [ForceDuoApp](https://github.com/34306/ForceDuoApp), baseline `65e8b68`: source of the cache engine and earlier UI. No LICENSE file was found in that downloaded snapshot. Attribution alone does not establish redistribution permission; clarify authorization or independently replace the relevant implementation.
- [worse_query](https://github.com/forcequitOS/worse_query): bundled source declares GPL-3.0-or-later. Original copyright notices remain intact; any distribution must comply with that license.
- [Community SDK experiment](https://www.reddit.com/r/sideloaded/comments/1xvhqh4/release_experimental_duo_sdk_remove_the_black/): inspiration, not a universal compatibility guarantee.

This is a derivative prototype distributed as an unsigned IPA for personal re-signing. If you redistribute it, account for the GPL-3.0 terms of worse_query and the unresolved licensing of the ForceDuo-derived engine.
