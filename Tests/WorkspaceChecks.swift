import Foundation

// Compiled alongside the actual ShiftWorkspace.swift; never links the device engine.
actor CacheGateway {
    static let shared = CacheGateway()
    private var apps: [AppEntry] = []
    private var fail = false
    func configure(_ values: [AppEntry], fail: Bool = false) { apps = values; self.fail = fail }
    func inventory() throws -> [AppEntry] { apps }
    func execute(_ requests: [ChangeRequest], preview: Bool) throws -> String {
        if fail { throw NSError(domain: "Test", code: 1) }
        if !preview {
            apps = apps.map { app in
                guard let change = requests.first(where: { $0.id == app.id }) else { return app }
                return AppEntry(id: app.id, title: app.title, version: change.target)
            }
        }
        return "mock report"
    }
    func log() -> String { "mock log" }
}
extension ReleaseTag {
    static let fixtureDestination = ReleaseTag(major: 27, minor: 2, patch: 0)
}
@main struct WorkspaceChecks {
    @MainActor static func main() async throws {
        for (major, minor, patch) in [(27, 1, 0), (27, 2, 1), (28, 0, 0), (28, 3, 2)] {
            let actual = ReleaseTag.fromSystemVersion(OperatingSystemVersion(majorVersion: major, minorVersion: minor, patchVersion: patch))
            assert(actual == ReleaseTag(major: major, minor: minor, patch: patch))
        }
        assert(ReleaseTag.destination == ReleaseTag.fromSystemVersion(ProcessInfo.processInfo.operatingSystemVersion))
        let locale = Locale(identifier: "en")
        let tags = ReleaseTag.fixtureDestination
        let names = ["App 10", "App 2", "Éclair", "抖音", "日本語アプリ", "한국 앱", "123", ""]
        let apps = names.enumerated().map { AppEntry(id: String($0.offset), title: $0.element, version: tags) }
        let ascending = LibraryOrder.nameAscending.sorted(apps, locale: locale)
        assert(ascending.firstIndex(where: { $0.title == "App 2" })! < ascending.firstIndex(where: { $0.title == "App 10" })!)
        assert(LibraryOrder.nameDescending.sorted(apps, locale: locale).map(\.id) == ascending.reversed().map(\.id))
        assert(LibraryOrder.initial("Éclair") == "E")
        assert(LibraryOrder.initial("抖音") == "D")
        assert(LibraryOrder.initial("  apple") == "A")
        assert(LibraryOrder.initial("123") == "#" && LibraryOrder.initial("") == "#")
        assert(LibraryOrder.script("日本語アプリ") == 2)
        assert(LibraryOrder.script("抖音") == 1 && LibraryOrder.script("한국 앱") == 3)
        let grouped = LibraryOrder.writingSystem.sorted(apps, locale: locale).map { LibraryOrder.script($0.title) }
        assert(grouped == grouped.sorted())
        let newer = AppEntry(id: "new", title: "Z", version: ReleaseTag(major: 28, minor: 0, patch: 0))
        assert(LibraryOrder.sdk.sorted(apps + [newer], locale: locale).first?.id == "new")
        let ties = [AppEntry(id: "b", title: "Same", version: tags), AppEntry(id: "a", title: "same", version: tags)]
        assert(LibraryOrder.nameAscending.sorted(ties, locale: locale).map(\.id) == ["a", "b"])
        print("PASS: natural name sorting, reverse order, accents, pinyin index, symbols, script grouping, SDK ordering, deterministic ties")
        let suite = "SDKShift.tests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let original = ReleaseTag(major: 26, minor: 2, patch: 0)
        let prior = ReleaseTag(major: 27, minor: 1, patch: 0)
        let custom = ReleaseTag(major: 27, minor: 3, patch: 1)
        assert(ReleaseTag.parse(" 27.2 \n") == .fixtureDestination)
        assert(ReleaseTag.parse("27.3.1") == custom)
        assert(ReleaseTag.parse("99.99.99") != nil)
        for invalid in ["", "27", "27.", ".2", "27..2", "27.2.0.1", "0.2", "100.0", "27.100", "27.2.100", "-1.2", "+27.2", "27.a", "٢٧.٢", "27 .2", String(repeating: "9", count: 100)+".2"] {
            assert(ReleaseTag.parse(invalid) == nil, invalid)
        }
        defaults.set(try JSONEncoder().encode(["a": original]), forKey: "originals")
        defaults.set(["a"], forKey: "forced")
        let systemDefault = ReleaseTag(major: 28, minor: 3, patch: 2)
        let systemModel = ShiftWorkspace(defaults: defaults, defaultSDK: systemDefault)
        systemModel.enqueue(AppEntry(id: "system-test", title: "System default", version: prior))
        assert(systemModel.queue.first?.target == systemDefault)
        let model = ShiftWorkspace(defaults: defaults, defaultSDK: .fixtureDestination)
        let a = AppEntry(id: "a", title: "A", version: prior)
        let b = AppEntry(id: "b", title: "B", version: .fixtureDestination)
        assert(model.recovery(for: a)?.original == original)
        model.enqueue(a, target: custom)
        model.enqueue(b, target: prior)
        assert(model.queue.count == 2 && model.requests["b"]?.target == prior)
        model.enqueue(b, target: b.version)
        assert(model.requests["b"] == nil)
        model.enqueue(b, target: ReleaseTag(major: 100, minor: 0, patch: 0))
        assert(model.requests["b"] == nil)
        model.busy = true; model.enqueue(b, target: prior)
        assert(model.requests["b"] == nil); model.busy = false
        await CacheGateway.shared.configure([a,b])
        await model.execute(preview: true)
        assert(model.recovery(for: a)?.original == original && model.queue.count == 1)
        await model.execute(preview: false)
        let changed = model.inventory.first(where: { $0.id == "a" })!
        assert(changed.version == custom && model.recovery(for: changed)?.original == original)
        model.enqueue(changed, target: .fixtureDestination)
        await CacheGateway.shared.configure(model.inventory, fail: true)
        await model.execute(preview: false)
        assert(model.recovery(for: changed)?.original == original, "Failed write must retain previous restore point")
        await CacheGateway.shared.configure(model.inventory)
        await model.execute(preview: false)
        let second = model.inventory.first(where: { $0.id == "a" })!
        assert(second.version == .fixtureDestination && model.recovery(for: second)?.original == original)
        let reloaded = ShiftWorkspace(defaults: defaults, defaultSDK: .fixtureDestination)
        assert(reloaded.recovery(for: second)?.original == original)
        let drift = AppEntry(id: "a", title: "A", version: prior)
        assert(reloaded.recovery(for: drift) == nil)
        model.enqueue(second, restoring: true)
        assert(model.queue.first?.target == original)
        await model.execute(preview: false)
        assert(model.inventory.first?.version == original && model.archive.recovery["a"] == nil)
        model.enqueue(b, target: custom)
        await model.scan()
        assert(model.queue.isEmpty)
        print("PASS: parsing, mixed targets, downgrade, no-op, bounds, busy guard, migration, preview, repeated edits, failure recovery, persistence, drift, restore, rescan")

        // Repair a tag modified by another tool using a user-verified backup value.
        let verifiedSuite = "SDKShift.verified." + UUID().uuidString
        let verifiedDefaults = UserDefaults(suiteName: verifiedSuite)!
        defer { verifiedDefaults.removePersistentDomain(forName: verifiedSuite) }
        let verifiedModel = ShiftWorkspace(defaults: verifiedDefaults, defaultSDK: .fixtureDestination)
        let external = AppEntry(id: "external.example", title: "External test app", version: prior)
        let knownBefore = ReleaseTag(major: 18, minor: 1, patch: 0)
        assert(!verifiedModel.enqueueVerifiedRecovery(external, verifiedSDK: prior))
        assert(!verifiedModel.enqueueVerifiedRecovery(external, verifiedSDK: ReleaseTag(major: 100, minor: 1, patch: 0)))
        assert(verifiedModel.enqueueVerifiedRecovery(external, verifiedSDK: knownBefore))
        assert(verifiedModel.requests[external.id]?.verifiedRecovery == true)
        await CacheGateway.shared.configure([external])
        await verifiedModel.execute(preview: true)
        assert(verifiedModel.archive.recovery[external.id] == nil && verifiedModel.queue.count == 1)
        verifiedModel.archive.recovery[external.id] = RestorePoint(original: prior, written: prior)
        await CacheGateway.shared.configure([external], fail: true)
        await verifiedModel.execute(preview: false)
        assert(verifiedModel.archive.recovery[external.id]?.original == prior && verifiedModel.queue.count == 1)
        await CacheGateway.shared.configure([external])
        await verifiedModel.execute(preview: false)
        let recovered = verifiedModel.inventory.first(where: { $0.id == external.id })!
        assert(recovered.version == knownBefore && verifiedModel.archive.recovery[external.id] == nil)
        let reopened = ShiftWorkspace(defaults: verifiedDefaults, defaultSDK: .fixtureDestination)
        assert(reopened.recovery(for: recovered) == nil, "Verified recovery must not offer a bogus undo")
        reopened.enqueue(recovered, target: custom)
        await CacheGateway.shared.configure([recovered])
        await reopened.execute(preview: false)
        let adjusted = reopened.inventory.first(where: { $0.id == external.id })!
        assert(reopened.recovery(for: adjusted)?.original == knownBefore)
        reopened.enqueue(adjusted, restoring: true)
        assert(reopened.queue.first?.target == knownBefore)
        await reopened.execute(preview: false)
        assert(reopened.inventory.first?.version == knownBefore && reopened.archive.recovery[external.id] == nil)
        verifiedModel.enqueueVerifiedRecovery(external, verifiedSDK: knownBefore)
        await verifiedModel.scan()
        assert(verifiedModel.queue.isEmpty)
        print("PASS: verified recovery validation, dry-run isolation, failed-write preservation, cleared old marker, new baseline, rescan")

    }
}
