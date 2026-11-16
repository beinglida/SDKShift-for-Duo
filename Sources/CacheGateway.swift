import Foundation

/// Serial boundary around the attributed, upstream cache engine.
/// No network icon lookups or application identifiers leave the device.
actor CacheGateway {
    static let shared = CacheGateway()
    func inventory() throws -> [AppEntry] {
        try FDEngine.shared.loadApps().filter {
            !($0.signer.isEmpty && $0.bundleID.hasPrefix("com.apple."))
        }.map {
            AppEntry(id: $0.bundleID, title: $0.name,
                     version: ReleaseTag(major: $0.sdkMajor, minor: $0.sdkMinor, patch: $0.sdkPatch))
        }
    }
    func execute(_ requests: [ChangeRequest], preview: Bool) throws -> String {
        // A fresh snapshot prevents using a stale UI SDK as a restoration baseline.
        let current = Dictionary(uniqueKeysWithValues: try inventory().map { ($0.id, $0.version) })
        for request in requests where current[request.id] != request.app.version {
            throw NSError(domain: "SDKShift", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: ShiftLanguage.text("App information changed. Scan and select again:") + " " + request.app.title])
        }
        let payload = Dictionary(uniqueKeysWithValues: requests.map { ($0.id, $0.target.numbers) })
        return try FDEngine.shared.applyVersions(payload, dryRun: preview)
    }
    func log() -> String { FDEngine.shared.lastLog }
}


enum ShiftLanguage {
    static let options: [(code: String, name: String)] = [
        ("en", "English"), ("zh-Hans", "简体中文"), ("zh-Hant", "繁體中文"),
        ("ja", "日本語"), ("ko", "한국어"), ("es", "Español"),
        ("fr", "Français"), ("de", "Deutsch"), ("vi", "Tiếng Việt")
    ]
    static func text(_ key: String) -> String {
        let selected = UserDefaults.standard.string(forKey: "sdkshift.language") ?? "en"
        let code = options.contains(where: { $0.code == selected }) ? selected : "en"
        guard let path = Bundle.main.path(forResource: code, ofType: "lproj"),
              let bundle = Bundle(path: path) else { return key }
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }
}
