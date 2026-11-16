# SDKShift for Duo

**English** | [简体中文](README.zh-CN.md)

Change the SDK version tag recorded in LaunchServices to explore app display compatibility on iPhone Duo. The quick-action default follows the device’s current iOS version (27.1 → 27.1.0; 27.2.1 → 27.2.1); each app can also use a custom SDK tag. This does not recompile apps, upgrade iOS, or guarantee native Duo layouts.

> **Restart your iPhone after applying changes.** Respringing SpringBoard does not guarantee that SDK-related services and application state reload. A verified database write is not proof of a visible layout change. This project has no validated reboot-free refresh method.

## Features

- Three-page interface: Apps, History, and About. Pending changes, review, preflight and apply controls are integrated into Apps. The bottom panel appears only when changes are queued; expand its count to review or remove entries. The report remains available from the Apps toolbar.
- Set a different SDK tag for each app, including apps already at or above the current default. Queue changes or restorations and review old/new versions before writing.
- Accept `major.minor` or `major.minor.patch` (major 1–99; minor/patch 0–99). Two-part input normalizes to a zero patch. Invalid and unchanged values cannot be queued in the editor. Downgrades are explicitly labeled. These are format limits, not a list of released or compatible SDKs.
- Check without writing: validates the candidate database and reports write-access and lock results. This still creates temporary files inside the app and accesses the cache; it is not an offline, side-effect-free operation.
- Original SDK values and last-written values are stored separately, with migration from earlier SDKShift builds.
- Fresh SDK snapshot checks before applying, serialized engine access, and up to 30 local activity records.
- On-device letter avatars; no network icon lookup.
- **English by default**, plus Simplified Chinese, Traditional Chinese, Japanese, Korean, Spanish, French, German, and Vietnamese. Select **Apps → App language** at the top of the home page. The choice persists and takes effect immediately without changing SDK settings or recovery records. The seven additional languages cover the interface and operation notices; engine errors currently fall back to English. Simplified Chinese also translates engine errors. Technical traces and existing report snapshots remain verbatim for troubleshooting.

## Build and sign

1. Open `SDKShift.xcodeproj` in Xcode. The project has been built with Xcode 27.2; its deployment target is iOS 27.0.
2. Select your own development Team under Signing & Capabilities. The local project currently contains its owner's Team configuration; other developers must replace it.
3. Register a Bundle ID and App Group authorized for your Team.
4. Keep `SDKShift.entitlements`, `FDAppGroup` in `Sources/FDEngine.m`, and your provisioning profile consistent. `group.com.sheldonfornet.sdkshift` is the current configured identifier, not a universally authorized group.
5. Keep `project.yml` synchronized with signing changes if you regenerate the project.
6. Connect and trust your iPhone, enable Developer Mode, then build and run.

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

Both app groups can be collapsed, with their state remembered. The sorting menu remembers name ascending/descending, name writing system, or SDK highest first. Writing-system groups describe the display name, not the app’s interface language; Han-only names cannot reliably distinguish Chinese from Japanese. A fixed vertical A–Z / # index sits on the right edge, outside the scrolling content. Tap or drag up and down to jump to the first matching app in the current order; a large letter appears while dragging. Unavailable letters are dimmed and scrubbing them jumps to the nearest populated letter. The rail uses a 44-point UIKit touch surface; an eager adaptive card layout keeps off-screen jump targets measurable. This increases initial layout work compared with a lazy grid. Tap the Modified SDK or Other apps title to select and expand that group; the highlighted title owns the index. The separate chevron folds the group. Collapsing the selected group or filtering it to zero apps hides the index without switching to another group. The selected group is remembered; the icon above the rail is only an indicator. The rail reserves space beside the cards and stays above the pending-change panel. Names are transliterated to Latin initials (including Han-to-pinyin); numbers and symbols use `#`. Search and filters update the index.

## Architecture

| File | Responsibility |
| --- | --- |
| `Sources/ShiftInterface.swift` | Card-based app library with integrated pending-change panel, history, settings and language picker |
| `Sources/ShiftWorkspace.swift` | Change requests, recovery points, persistence and legacy-data migration |
| `Sources/CacheGateway.swift` | Serialized engine adapter, fresh version checks and runtime localization |
| `Sources/FDEngine.m/.h` | Attributed upstream-derived database access, parsing and verified writes |
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

## Validation and limits

An earlier build successfully read 604-byte Bundle records and parsed 400 apps on an iPhone Duo running iOS 27.2. The earlier SDKShift build was signed, installed and launched. The rewritten UI and bilingual build have passed local compilation; this is not proof of every target app's behavior or of visual QA on every device size.

Custom SDK and multilingual changes pass an unsigned iOS build and local model regression checks. This revision has not yet been installed or tested on the iPhone. Regression checks cover parsing and bounds, per-app targets, downgrades, preview, repeated edits, failed-write recovery, migration, restoration, SDK drift, busy-state guards, persistence and scan invalidation. No automatic SDK writes are performed at launch. Keep recovery data before uninstalling.

Run the model checks on macOS without device access or cache writes:

```sh
swiftc -parse-as-library Sources/ShiftWorkspace.swift Tests/WorkspaceChecks.swift -o /tmp/sdkshift-workspace-checks
/tmp/sdkshift-workspace-checks
python3 Tests/check_localizations.py
```

## Attribution and publication status

- [ForceDuoApp](https://github.com/34306/ForceDuoApp), baseline `65e8b68`: source of the cache engine and earlier UI. No LICENSE file was found in that downloaded snapshot. Attribution alone does not establish redistribution permission; clarify authorization or independently replace the relevant implementation before publishing.
- [worse_query](https://github.com/forcequitOS/worse_query): bundled source declares GPL-3.0-or-later. Original copyright notices remain intact; distribution must account for that license.
- [Community SDK experiment](https://www.reddit.com/r/sideloaded/comments/1xvhqh4/release_experimental_duo_sdk_remove_the_black/): inspiration, not a universal compatibility guarantee.

No new blanket MIT license is assigned to upstream code. This remains a local derivative prototype; no public repository has been created by this task.

### Index navigation verification

The index now measures card positions in the scroll content and sets the owning UIScrollView offset directly, replacing the ineffective nested ScrollViewReader jump. A 260-app simulator fixture confirmed M → Z → A offsets of 26465.67 → 54805.67 → 305.67 points. Touch delivery and the old jump callback were observed before the change. End-to-end drag verification of the revised build remains incomplete because Device Hub window automation timed out; these offset checks are not a claim of physical-device verification.

The default is derived locally from `ProcessInfo.operatingSystemVersion`, including the patch component. It does not query the latest downloadable SDK or use the Xcode build SDK. After an iOS update, the next app launch uses the new system version; previously written per-app tags and restore points are not automatically changed.
