import Foundation
import Observation

struct ReleaseTag: Codable, Hashable, Comparable, CustomStringConvertible {
    let major: Int
    let minor: Int
    let patch: Int
    static var destination: ReleaseTag { fromSystemVersion(ProcessInfo.processInfo.operatingSystemVersion) }
    static func fromSystemVersion(_ version: OperatingSystemVersion) -> ReleaseTag {
        ReleaseTag(major: version.majorVersion, minor: version.minorVersion, patch: version.patchVersion)
    }
    static func < (lhs: Self, rhs: Self) -> Bool {
        [lhs.major, lhs.minor, lhs.patch].lexicographicallyPrecedes([rhs.major, rhs.minor, rhs.patch])
    }
    var description: String { "\(major).\(minor).\(patch)" }
    var isValid: Bool { (1...99).contains(major) && (0...99).contains(minor) && (0...99).contains(patch) }
    static func parse(_ input: String) -> Self? {
        let parts = input.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ".", omittingEmptySubsequences: false)
        guard (2...3).contains(parts.count), parts.allSatisfy({ !$0.isEmpty && $0.utf8.allSatisfy { (48...57).contains($0) } }) else { return nil }
        let values = parts.compactMap { Int($0) }
        guard values.count == parts.count else { return nil }
        let tag = Self(major: values[0], minor: values[1], patch: values.count == 3 ? values[2] : 0)
        return tag.isValid ? tag : nil
    }
    var numbers: [NSNumber] { [major, minor, patch].map(NSNumber.init(value:)) }
}
struct AppEntry: Identifiable {
    let id: String
    let title: String
    let version: ReleaseTag
}
struct RestorePoint: Codable {
    let original: ReleaseTag
    let written: ReleaseTag
}
enum ChangeKind {
    case change
    case restore
    // Verified from a backup before a different tool changed the SDK tag.
    case verifiedRecovery
}
struct ChangeRequest: Identifiable {
    let app: AppEntry
    let target: ReleaseTag
    let kind: ChangeKind
    var id: String { app.id }
    var restoring: Bool { kind == .restore }
    var verifiedRecovery: Bool { kind == .verifiedRecovery }
}
struct ActivityEntry: Codable, Identifiable {
    var id = UUID()
    let date: Date
    let title: String
    let detail: String
}
struct WorkspaceArchive: Codable {
    var recovery: [String: RestorePoint] = [:]
    var activity: [ActivityEntry] = []
}

@MainActor @Observable
final class ShiftWorkspace {
    let defaultSDK: ReleaseTag
    var inventory: [AppEntry] = []
    var requests: [String: ChangeRequest] = [:]
    var busy = false
    var notice: String?
    var report = "No checks have run yet."
    var archive = WorkspaceArchive()
    private let storage: UserDefaults
    private let archiveKey = "sdkshift.workspace.v2"
    var queue: [ChangeRequest] { requests.values.sorted { $0.app.title.localizedStandardCompare($1.app.title) == .orderedAscending } }
    init(defaults: UserDefaults = .standard, defaultSDK: ReleaseTag = .destination) {
        self.defaultSDK = defaultSDK
        storage = defaults
        if let data = storage.data(forKey: archiveKey), let saved = try? JSONDecoder().decode(WorkspaceArchive.self, from: data) {
            archive = saved
        } else {
            // Preserve restoration information from earlier SDKShift builds.
            let originals = decodeLegacy("originals")
            let applied = decodeLegacy("appliedVersions")
            let forced = Set(storage.stringArray(forKey: "forced") ?? [])
            for (id, original) in originals {
                if let written = applied[id] ?? (forced.contains(id) ? ReleaseTag(major: 27, minor: 1, patch: 0) : nil) {
                    archive.recovery[id] = RestorePoint(original: original, written: written)
                }
            }
            save()
        }
    }
    private func decodeLegacy(_ key: String) -> [String: ReleaseTag] {
        guard let data = storage.data(forKey: key) else { return [:] }
        return (try? JSONDecoder().decode([String: ReleaseTag].self, from: data)) ?? [:]
    }
    func recovery(for app: AppEntry) -> RestorePoint? {
        guard let point = archive.recovery[app.id], point.written == app.version, point.original != app.version else { return nil }
        return point
    }
    func enqueue(_ app: AppEntry, target custom: ReleaseTag? = nil, restoring: Bool = false) {
        guard !busy else { return }
        let target: ReleaseTag
        if restoring { guard let point = recovery(for: app) else { return }; target = point.original }
        else {
            if let custom { target = custom }
            else { guard app.version < defaultSDK else { return }; target = defaultSDK }
        }
        guard target.isValid else { return }
        guard target != app.version else { requests[app.id] = nil; return }
        requests[app.id] = ChangeRequest(app: app, target: target, kind: restoring ? .restore : .change)
    }
    /// External recovery never treats the currently overridden tag as the original.
    @discardableResult func enqueueVerifiedRecovery(_ app: AppEntry, verifiedSDK: ReleaseTag) -> Bool {
        guard !busy, verifiedSDK.isValid, verifiedSDK != app.version else { return false }
        requests[app.id] = ChangeRequest(app: app, target: verifiedSDK, kind: .verifiedRecovery)
        return true
    }
    func scan() async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        do {
            inventory = try await CacheGateway.shared.inventory()
            // Invalidate queued snapshots after every scan; require deliberate reselection.
            requests.removeAll()
            report = await CacheGateway.shared.log()
        } catch { notice = error.localizedDescription; report = await CacheGateway.shared.log() }
    }
    func execute(preview: Bool) async {
        guard !busy, !queue.isEmpty else { return }
        let batch = queue
        let previousRecovery = archive.recovery
        notice = nil
        busy = true
        defer { busy = false }
        do {
            // Durable recovery intent precedes writing. Retain it even if the operation fails.
            if !preview {
                // Only ordinary changes create restore points. External recovery
                // must not record an already-overridden value as the original.
                for change in batch where change.kind == .change {
                    let prior = recovery(for: change.app)?.original ?? change.app.version
                    archive.recovery[change.id] = RestorePoint(original: prior, written: change.target)
                }
                save()
            }
            let summary = try await CacheGateway.shared.execute(batch, preview: preview)
            report = summary + "\n" + (await CacheGateway.shared.log())
            if !preview {
                // Do not erase old points until the write is confirmed.
                // Save before refreshing so a refresh failure cannot undo the cleanup.
                for change in batch where change.restoring || change.verifiedRecovery {
                    archive.recovery[change.id] = nil
                }
                save()
                requests.removeAll()
                do {
                    inventory = try await CacheGateway.shared.inventory()
                } catch {
                    inventory = []
                    report += "\nApp list refresh failed: " + error.localizedDescription
                    notice = "Write succeeded, but refreshing the app list failed. Restart and scan again."
                }
            }
            record(preview ? "Check completed" : "Applied · Restart required", report)
            if notice == nil {
                notice = preview ? "The system database was not written. Review write-access and lock results in the report." : "The database was written. Restart your iPhone, then check the display behavior."
            }
        } catch {
            // A failed write that left the old value intact must retain its earlier restore point.
            if !preview, let current = try? await CacheGateway.shared.inventory() {
                for change in batch where current.contains(where: { $0.id == change.id && $0.version == change.app.version }) {
                    archive.recovery[change.id] = previousRecovery[change.id]
                }
            }
            report = error.localizedDescription + "\n" + (await CacheGateway.shared.log())
            record("Operation incomplete", report)
            notice = error.localizedDescription
        }
    }
    private func record(_ title: String, _ detail: String) {
        archive.activity.insert(ActivityEntry(date: Date(), title: title, detail: detail), at: 0)
        archive.activity = Array(archive.activity.prefix(30))
        save()
    }
    private func save() { storage.set(try? JSONEncoder().encode(archive), forKey: archiveKey) }
}

/// Sort by display names, never by an inferred app interface language.
enum LibraryOrder: String, CaseIterable {
    case nameAscending = "Name · A–Z"
    case nameDescending = "Name · Z–A"
    case writingSystem = "Name writing system"
    case sdk = "SDK · Highest first"

    func sorted(_ apps: [AppEntry], locale: Locale) -> [AppEntry] {
        apps.sorted { lhs, rhs in
            if self == .sdk, lhs.version != rhs.version { return lhs.version > rhs.version }
            if self == .writingSystem {
                let a = Self.script(lhs.title), b = Self.script(rhs.title)
                if a != b { return a < b }
            }
            let comparison = lhs.title.compare(rhs.title, options: [.caseInsensitive, .diacriticInsensitive, .numeric], locale: locale)
            if comparison == .orderedSame { return lhs.id < rhs.id }
            return self == .nameDescending ? comparison == .orderedDescending : comparison == .orderedAscending
        }
    }
    static func initial(_ name: String) -> String {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let latin = (name.applyingTransform(.toLatin, reverse: false) ?? name)
            .folding(options: [.diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "en"))
            .uppercased(with: Locale(identifier: "en"))
        guard let first = latin.unicodeScalars.first, (65...90).contains(first.value) else { return "#" }
        return String(first)
    }
    static func script(_ name: String) -> Int {
        let scalars = name.unicodeScalars.map(\.value)
        // Kana before Han: a mixed Japanese name belongs with kana names.
        if scalars.contains(where: { (0x3040...0x30FF).contains($0) || (0xFF66...0xFF9D).contains($0) }) { return 2 }
        if scalars.contains(where: { (0xAC00...0xD7AF).contains($0) || (0x1100...0x11FF).contains($0) || (0x3130...0x318F).contains($0) }) { return 3 }
        if scalars.contains(where: { (0x3400...0x9FFF).contains($0) || (0x20000...0x323AF).contains($0) }) { return 1 }
        if scalars.contains(where: { (0x0400...0x052F).contains($0) }) { return 4 }
        if scalars.contains(where: { (0x0600...0x06FF).contains($0) }) { return 5 }
        if scalars.contains(where: { (0x0041...0x005A).contains($0) || (0x0061...0x007A).contains($0) || (0x00C0...0x024F).contains($0) || (0x1E00...0x1EFF).contains($0) }) { return 0 }
        return 6
    }
    static func scriptLabel(_ name: String) -> String {
        ["Latin", "Han characters", "Japanese kana", "Hangul", "Cyrillic", "Arabic", "Other scripts"][script(name)]
    }
}
