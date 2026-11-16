import SwiftUI

@main
struct SDKShiftApplication: App {
    @State private var workspace = ShiftWorkspace()
    @AppStorage("sdkshift.language") private var language = "en"
    var body: some Scene {
        WindowGroup { ShiftHome().environment(workspace).environment(\.locale, Locale(identifier: language)).task { await workspace.scan() } }
    }
}
private enum ShiftSection: String, CaseIterable {
    case library = "Apps", journal = "History", about = "About"
    var symbol: String {
        switch self { case .library: "square.grid.2x2"; case .journal: "clock"; case .about: "info.circle" }
    }
}
private struct ShiftHome: View {
    @Environment(ShiftWorkspace.self) private var workspace
    @State private var section = ShiftSection.library
    var body: some View {
        TabView(selection: $section) {
            ForEach(ShiftSection.allCases, id: \.self) { item in
                NavigationStack {
                    Group {
                        switch item {
                        case .library: LibraryScreen()
                        case .journal: JournalScreen()
                        case .about: AboutScreen()
                        }
                    }
                    .navigationTitle(Text(LocalizedStringKey(item == .library ? "SDKShift" : item.rawValue)))
                    .toolbar {
                        if workspace.busy { ProgressView() }
                        else if item == .library {
                            Button("Scan", systemImage: "arrow.clockwise") { Task { await workspace.scan() } }
                        }
                    }
                }
                .tabItem { Label(LocalizedStringKey(item.rawValue), systemImage: item.symbol) }
                .tag(item)
                .badge(item == .library ? workspace.queue.count : 0)
            }
        }
        .tint(.teal)
        .alert("SDKShift", isPresented: Binding(get: { workspace.notice != nil }, set: { if !$0 { workspace.notice = nil } })) {
            Button("OK") { workspace.notice = nil }
        } message: { Text(LocalizedStringKey(workspace.notice ?? "")) }
    }
}
private struct LibraryScreen: View {
    @AppStorage("sdkshift.language") private var language = "en"
    @Environment(ShiftWorkspace.self) private var workspace
    @State private var query = ""
    @State private var scrollDriver = LibraryScrollDriver()
    @State private var legacyOnly = false
    @AppStorage("sdkshift.indexGroup") private var indexGroup = "other"
    @AppStorage("sdkshift.modifiedGroupExpanded") private var modifiedExpanded = true
    @AppStorage("sdkshift.otherGroupExpanded") private var otherExpanded = true
    @AppStorage("sdkshift.libraryOrder") private var orderValue = LibraryOrder.nameAscending.rawValue
    @Environment(\.locale) private var locale
    private var order: LibraryOrder { LibraryOrder(rawValue: orderValue) ?? .nameAscending }
    private var matchingApps: [AppEntry] {
        order.sorted(workspace.inventory.filter {
            query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) || $0.id.localizedCaseInsensitiveContains(query)
        }, locale: locale)
    }
    private var modifiedApps: [AppEntry] {
        matchingApps.filter { workspace.recovery(for: $0) != nil }
    }
    private var otherApps: [AppEntry] {
        matchingApps.filter { workspace.recovery(for: $0) == nil && (!legacyOnly || $0.version < workspace.defaultSDK) }
    }
    private var indexedGroup: String { indexGroup == "modified" ? "modified" : "other" }
    private var indexApps: [AppEntry] {
        if indexedGroup == "modified" { return modifiedExpanded ? modifiedApps : [] }
        return otherExpanded ? otherApps : []
    }
    private var indexTargets: [String: String] {
        var targets: [String: String] = [:]
        for app in indexApps {
            let initial = LibraryOrder.initial(app.title)
            if targets[initial] == nil { targets[initial] = indexedGroup + app.id }
        }
        return targets
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Label("App language", systemImage: "globe").font(.subheadline.weight(.semibold))
                    Spacer()
                    Menu {
                        Picker("App language", selection: $language) {
                            ForEach(ShiftLanguage.options, id: \.code) { option in
                                Text(verbatim: option.name).tag(option.code)
                            }
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Text(verbatim: ShiftLanguage.options.first(where: { $0.code == language })?.name ?? "English")
                            Image(systemName: "chevron.down").font(.caption2)
                        }.font(.subheadline.weight(.medium)).padding(.vertical, 10).padding(.horizontal, 12)
                    }
                    .background(.teal.opacity(0.1), in: Capsule())
                    .accessibilityLabel(Text("App language"))
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Change the tag. Explore more space.")
                        .font(.subheadline.weight(.medium)).foregroundStyle(.teal)
                        .lineLimit(1).minimumScaleFactor(0.65)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 8) {
                        Image(systemName: "arrow.triangle.swap").foregroundStyle(.teal)
                        Text("Default SDK").foregroundStyle(.secondary)
                        Text(workspace.defaultSDK.description).monospacedDigit().fontWeight(.semibold)
                    }
                    .font(.subheadline)
                    Label("Restart your iPhone after applying", systemImage: "restart")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.teal.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
                Text("\(modifiedApps.count + otherApps.count) apps · On-device, no icon downloads")
                    .font(.caption).foregroundStyle(.secondary)
                Picker("Sort apps", selection: $orderValue) {
                    ForEach(LibraryOrder.allCases, id: \.rawValue) { value in
                        Text(LocalizedStringKey(value.rawValue)).tag(value.rawValue)
                    }
                }.pickerStyle(.menu)
                if order == .writingSystem {
                    Text("Groups use the app name’s writing system, not its interface language.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                DisclosureGroup(isExpanded: $modifiedExpanded) {
                    IndexedApps(apps: modifiedApps, groupID: "modified", order: order)
                        .padding(.top, 10)
                    if modifiedApps.isEmpty {
                        Text("No modified apps match. Apps with a confirmed SDKShift override appear here.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                } label: {
                    HStack {
                        Label("Modified SDK", systemImage: "checkmark.seal.fill").foregroundStyle(.teal)
                        Spacer()
                        Text(modifiedApps.count, format: .number).foregroundStyle(.secondary)
                    }.font(.headline)
                }
                .disclosureGroupStyle(IndexBoundGroupStyle(title: "Modified SDK", isActive: indexedGroup == "modified") { indexGroup = "modified" })
                Divider()
                DisclosureGroup(isExpanded: $otherExpanded) {
                    VStack(alignment: .leading, spacing: 14) {
                        Toggle("Only apps below SDK \(workspace.defaultSDK.description)", isOn: $legacyOnly)
                        if otherApps.isEmpty {
                            ContentUnavailableView("No matching apps", systemImage: "magnifyingglass", description: Text("Adjust the filter, change your search, or scan again."))
                        }
                        IndexedApps(apps: otherApps, groupID: "other", order: order)
                    }.padding(.top, 10)
                } label: {
                    HStack {
                        Text("Other apps")
                        Spacer()
                        Text(otherApps.count, format: .number).foregroundStyle(.secondary)
                    }.font(.headline)
                }
                .disclosureGroupStyle(IndexBoundGroupStyle(title: "Other apps", isActive: indexedGroup == "other") { indexGroup = "other" })
            }.padding(20).padding(.trailing, indexTargets.isEmpty ? 0 : 44)
                .coordinateSpace(name: "libraryContent")
                .background(LibraryScrollResolver(driver: scrollDriver))
                .onPreferenceChange(AppOffsetPreference.self) { scrollDriver.offsets = $0 }
        }
        .overlay(alignment: .trailing) {
            if !indexTargets.isEmpty {
                VerticalNameIndex(targets: indexTargets) { id in
                    scrollDriver.jump(to: id)
                } scope: {
                    Image(systemName: indexedGroup == "modified" ? "checkmark.seal" : "square.grid.2x2")
                        .font(.caption).frame(width: 44, height: 32)
                        .accessibilityLabel(Text(LocalizedStringKey(indexedGroup == "modified" ? "Modified SDK" : "Other apps")))
                }
                .id(indexedGroup)
                .padding(.trailing, 2).padding(.vertical, 8)
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .searchable(text: $query, prompt: "Search names or bundle IDs")
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !workspace.queue.isEmpty { PendingChangesPanel() }
        }
        .toolbar {
            NavigationLink { ReportScreen(text: workspace.report) } label: {
                Label("View report", systemImage: "doc.text.magnifyingglass")
            }
        }
    }
}
private struct AppOffsetPreference: PreferenceKey {
    static var defaultValue: [String: CGFloat] = [:]
    static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, next in next })
    }
}
private final class LibraryScrollDriver {
    weak var scrollView: UIScrollView?
    var offsets: [String: CGFloat] = [:]
    func jump(to id: String) {
        guard let scrollView, let y = offsets[id] else { return }
        let minimum = -scrollView.adjustedContentInset.top
        let maximum = max(minimum, scrollView.contentSize.height - scrollView.bounds.height + scrollView.adjustedContentInset.bottom)
        let target = min(maximum, max(minimum, y - scrollView.adjustedContentInset.top))
        scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: target), animated: false)
    }
}
private struct LibraryScrollResolver: UIViewRepresentable {
    let driver: LibraryScrollDriver
    func makeUIView(context: Context) -> Probe { Probe(driver: driver) }
    func updateUIView(_ view: Probe, context: Context) { view.resolve() }
    final class Probe: UIView {
        let driver: LibraryScrollDriver
        init(driver: LibraryScrollDriver) {
            self.driver = driver
            super.init(frame: .zero)
            isUserInteractionEnabled = false
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        override func didMoveToWindow() { super.didMoveToWindow(); resolve() }
        override func layoutSubviews() { super.layoutSubviews(); resolve() }
        func resolve() {
            var ancestor = superview
            while let view = ancestor {
                if let scroll = view as? UIScrollView { driver.scrollView = scroll; return }
                ancestor = view.superview
            }
        }
    }
}
/// The title selects and opens the group; the chevron independently folds it.
private struct IndexBoundGroupStyle: DisclosureGroupStyle {
    let title: LocalizedStringKey
    let isActive: Bool
    let activate: () -> Void
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Button {
                    activate()
                    configuration.isExpanded = true
                } label: {
                    configuration.label
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isActive ? [.isSelected] : [])
                Button {
                    activate()
                    configuration.isExpanded.toggle()
                } label: {
                    Image(systemName: configuration.isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption.weight(.semibold)).frame(width: 44, height: 44)
                }
                .accessibilityLabel(Text(title))
            }
            .padding(.horizontal, 8)
            .background(isActive ? Color.teal.opacity(0.09) : Color.clear, in: RoundedRectangle(cornerRadius: 10))
            if configuration.isExpanded { configuration.content }
        }
    }
}
/// A fixed viewport rail. Tapping or dragging selects a letter without scrolling the rail.
private struct VerticalNameIndex<Scope: View>: View {
    let targets: [String: String]
    let jump: (String) -> Void
    @ViewBuilder let scope: () -> Scope
    @State private var selected: String?
    private let letters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ").map(String.init) + ["#"]
    var body: some View {
        GeometryReader { geometry in
            let railHeight = min(540.0, max(1, geometry.size.height - 32))
            VStack(spacing: 0) {
                scope()
                VStack(spacing: 0) {
                    ForEach(letters, id: \.self) { letter in
                        Text(letter)
                            .font(.system(size: min(12, railHeight / 27 * 0.72), weight: .semibold))
                            .foregroundStyle(selected == letter ? Color.white : (targets[letter] == nil ? Color.secondary.opacity(0.35) : Color.teal))
                            .frame(width: 44, height: railHeight / 27)
                            .background(selected == letter ? Color.teal : Color.clear, in: Capsule())
                            .accessibilityAddTraits(.isButton)
                            .accessibilityLabel(Text("Name index") + Text(" " + letter))
                            .accessibilityAction { select(letter) }
                    }
                }
                .overlay {
                    IndexTouchSurface(onPosition: { fraction in
                        let offset = min(26, max(0, Int(fraction * 27)))
                        select(letters[offset])
                    }, onEnd: { selected = nil })
                    .accessibilityHidden(true)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .frame(width: 44)
        .overlay(alignment: .leading) {
            if let selected {
                Text(selected).font(.system(size: 36, weight: .semibold))
                    .frame(width: 68, height: 68)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .offset(x: -80).allowsHitTesting(false).accessibilityHidden(true)
            }
        }
    }
    private func select(_ letter: String) {
        guard selected != letter else { return }
        selected = letter
        // Empty buckets use the nearest available letter instead of silently doing nothing.
        let position = letters.firstIndex(of: letter) ?? 0
        let available = letters.indices.filter { targets[letters[$0]] != nil }
        let closest = available.min { abs($0 - position) < abs($1 - position) }
        if let closest, let target = targets[letters[closest]] { jump(target) }
    }
}
/// UIKit receives the full touch sequence without competing with SwiftUI's scroll gesture.
private struct IndexTouchSurface: UIViewRepresentable {
    let onPosition: (CGFloat) -> Void
    let onEnd: () -> Void
    func makeUIView(context: Context) -> TouchView { TouchView() }
    func updateUIView(_ view: TouchView, context: Context) {
        view.onPosition = onPosition
        view.onEnd = onEnd
    }
    final class TouchView: UIView {
        var onPosition: ((CGFloat) -> Void)?
        var onEnd: (() -> Void)?
        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = .clear
            isMultipleTouchEnabled = false
            isExclusiveTouch = true
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        private func update(_ touches: Set<UITouch>) {
            guard bounds.height > 0, let touch = touches.first else { return }
            onPosition?(min(0.999999, max(0, touch.location(in: self).y / bounds.height)))
        }
        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) { update(touches) }
        override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) { update(touches) }
        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { update(touches); onEnd?() }
        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { onEnd?() }
    }
}
/// Eager adaptive layout keeps off-screen IDs measurable for ScrollViewReader.
private struct IndexableCardLayout: Layout {
    private let spacing: CGFloat = 14
    private func dimensions(_ proposal: ProposedViewSize, _ subviews: Subviews) -> (CGFloat, Int, CGFloat, [CGFloat]) {
        let width = max(1, proposal.width ?? 320)
        let columns = max(1, Int((width + spacing) / (290 + spacing)))
        let cellWidth = max(1, (width - CGFloat(columns - 1) * spacing) / CGFloat(columns))
        var heights: [CGFloat] = []
        for index in subviews.indices {
            let height = subviews[index].sizeThatFits(ProposedViewSize(width: cellWidth, height: nil)).height
            if index % columns == 0 { heights.append(height) }
            else { heights[heights.count - 1] = max(heights.last ?? 0, height) }
        }
        return (width, columns, cellWidth, heights)
    }
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let (width, _, _, heights) = dimensions(proposal, subviews)
        return CGSize(width: width, height: heights.reduce(0, +) + CGFloat(max(0, heights.count - 1)) * spacing)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let (_, columns, cellWidth, heights) = dimensions(ProposedViewSize(width: bounds.width, height: nil), subviews)
        var y = bounds.minY
        for index in subviews.indices {
            let row = index / columns
            if index > 0 && index % columns == 0 { y += heights[row - 1] + spacing }
            subviews[index].place(at: CGPoint(x: bounds.minX + CGFloat(index % columns) * (cellWidth + spacing), y: y),
                                 anchor: .topLeading, proposal: ProposedViewSize(width: cellWidth, height: nil))
        }
    }
}
private struct IndexedApps: View {
    let apps: [AppEntry]
    let groupID: String
    let order: LibraryOrder
    var body: some View {
        IndexableCardLayout {
            ForEach(apps) { app in
                VStack(alignment: .leading, spacing: 6) {
                    if order == .writingSystem {
                        Text(LocalizedStringKey(LibraryOrder.scriptLabel(app.title)))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    ApplicationTile(app: app)
                }
                .background {
                    GeometryReader { geometry in
                        Color.clear.preference(key: AppOffsetPreference.self,
                            value: [groupID + app.id: geometry.frame(in: .named("libraryContent")).minY])
                    }
                }
                .id(groupID + app.id)
            }
        }
    }
}
private struct ApplicationTile: View {
    @Environment(ShiftWorkspace.self) private var workspace
    let app: AppEntry
    @State private var editing = false
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(String(app.title.prefix(1))).font(.title2.bold())
                    .frame(width: 44, height: 44).background(.teal.opacity(0.13), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading) {
                    Text(app.title).font(.headline).lineLimit(1)
                    Text(app.version.description).font(.caption.monospaced()).foregroundStyle(.secondary)
                }
                Spacer()
                if workspace.requests[app.id] != nil { Image(systemName: "checkmark.circle.fill").foregroundStyle(.teal) }
            }
            Text(app.id).font(.caption2.monospaced()).foregroundStyle(.secondary).lineLimit(1)
            if let point = workspace.recovery(for: app) {
                Text("\(point.original.description) → \(app.version.description)")
                    .font(.caption.monospaced()).foregroundStyle(.teal)
            }
            Button("Customize SDK", systemImage: "slider.horizontal.3") { editing = true }
                .buttonStyle(.borderedProminent).disabled(workspace.busy)
            if let request = workspace.requests[app.id] {
                Text("\(app.version.description) → \(request.target.description)").font(.caption.monospaced())
            }
            HStack {
                if app.version < workspace.defaultSDK {
                    Button("Queue change", systemImage: "plus") { workspace.enqueue(app) }
                        .buttonStyle(.bordered)
                } else { Text("SDK up to date").font(.caption).foregroundStyle(.secondary) }
                Spacer()
                if workspace.recovery(for: app) != nil {
                    Button("Restore") { workspace.enqueue(app, restoring: true) }.font(.subheadline)
                }
            }.disabled(workspace.busy)
        }
        .padding(18).background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
        .sheet(isPresented: $editing) { SDKEditor(app: app).environment(workspace) }
    }
}
private struct SDKEditor: View {
    @Environment(ShiftWorkspace.self) private var workspace
    @Environment(\.dismiss) private var dismiss
    let app: AppEntry
    @State private var input = ""
    private var target: ReleaseTag? { ReleaseTag.parse(input) }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(app.title).font(.headline)
                    Text(app.id).font(.caption.monospaced())
                    LabeledContent("Current SDK", value: app.version.description)
                }
                Section("Target SDK") {
                    TextField("SDK version", text: $input).keyboardType(.decimalPad)
                        .autocorrectionDisabled().textInputAutocapitalization(.never)
                    Button("Use \(workspace.defaultSDK.description)") { input = workspace.defaultSDK.description }
                    Text("Enter major.minor or major.minor.patch. Major: 1–99; minor and patch: 0–99.")
                        .font(.footnote).foregroundStyle(.secondary)
                    if let target {
                        Text("\(app.version.description) → \(target.description)").monospaced()
                        if target == app.version { Text("This matches the current SDK. No change is needed.").foregroundStyle(.secondary) }
                        if target < app.version { Text("This will lower the SDK tag. Review compatibility after restarting.").foregroundStyle(.orange) }
                    } else { Text("Invalid SDK version").foregroundStyle(.red) }
                }
                Section {
                    Text("Each app can use a different target. Changing this tag does not add APIs or guarantee compatibility with a newer SDK.")
                    Text("Restart your iPhone after applying")
                }.font(.footnote)
            }
            .navigationTitle("Customize SDK")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Queue change") {
                        if let target { workspace.enqueue(app, target: target); dismiss() }
                    }.disabled(workspace.busy || target == nil || target == app.version)
                }
            }
        }
        .onAppear { input = (workspace.requests[app.id]?.target ?? app.version).description }
    }
}
/// Review and apply in the app library; no separate changes destination.
private struct PendingChangesPanel: View {
    @Environment(ShiftWorkspace.self) private var workspace
    @State private var confirming = false
    @State private var expanded = false
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            DisclosureGroup(isExpanded: $expanded) {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(workspace.queue) { request in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(request.app.title).font(.subheadline.weight(.semibold))
                                    Text("\(request.app.version.description) → \(request.target.description)")
                                        .font(.caption.monospaced()).foregroundStyle(.secondary)
                                    if request.restoring { Text("Restore original value").font(.caption).foregroundStyle(.orange) }
                                }
                                Spacer()
                                Button("Remove", systemImage: "minus.circle") { workspace.requests[request.id] = nil }
                                    .labelStyle(.iconOnly).disabled(workspace.busy)
                            }
                        }
                    }.padding(.vertical, 8)
                }.frame(maxHeight: 180)
            } label: {
                Text("Pending · \(workspace.queue.count)").font(.subheadline.weight(.semibold))
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { actions }
                VStack(alignment: .leading, spacing: 8) { actions }
            }
            .buttonStyle(.bordered)
            .disabled(workspace.busy || workspace.queue.isEmpty)
            Label("Restart your iPhone after applying", systemImage: "restart")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(.regularMaterial)
        .confirmationDialog("Apply these SDK changes?", isPresented: $confirming, titleVisibility: .visible) {
            Button("Apply and save recovery data", role: .destructive) { Task { await workspace.execute(preview: false) } }
        } message: {
            Text("Save your work in other apps first. Restart your iPhone after applying.")
        }
    }
    @ViewBuilder private var actions: some View {
        Button("1. Check without writing", systemImage: "checkmark.shield") { Task { await workspace.execute(preview: true) } }
        Button("2. Apply changes", systemImage: "square.and.arrow.down") { confirming = true }
            .buttonStyle(.borderedProminent)
    }
}
private struct JournalScreen: View {
    @Environment(ShiftWorkspace.self) private var workspace
    var body: some View {
        List {
            if workspace.archive.activity.isEmpty {
                ContentUnavailableView("No activity yet", systemImage: "clock", description: Text("Check and apply results stay on this device. Up to 30 entries are kept."))
            }
            ForEach(workspace.archive.activity) { entry in
                NavigationLink { ReportScreen(text: entry.detail) } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(LocalizedStringKey(entry.title)).font(.headline)
                        Text(entry.date, style: .date).font(.caption)
                        Text(entry.date, style: .time).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
private struct ReportScreen: View {
    let text: String
    var body: some View {
        ScrollView { Text(text).font(.footnote.monospaced()).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding() }
            .navigationTitle("Report")
            .toolbar { ShareLink(item: text) { Image(systemName: "square.and.arrow.up") } }
    }
}
private struct AboutScreen: View {
    @Environment(ShiftWorkspace.self) private var workspace
    var body: some View {
        List {
            Section("SDKShift for Duo") {
                LabeledContent("Default SDK", value: workspace.defaultSDK.description)
                LabeledContent("System", value: UIDevice.current.systemVersion)
                Text("Change app SDK version tags to explore display compatibility. This does not recompile apps or upgrade iOS.")
            }
            Section("Developer & contact") {
                Link(destination: URL(string: "https://x.com/dreamer_in_ca")!) {
                    Label {
                        Text(verbatim: "X · @dreamer_in_ca")
                    } icon: { Image(systemName: "person.crop.circle") }
                }
                Link(destination: URL(string: "mailto:beinglida@gmail.com")!) {
                    Label {
                        Text(verbatim: "beinglida@gmail.com")
                    } icon: { Image(systemName: "envelope") }
                }
                Link(destination: URL(string: "https://github.com/beinglida/SDKShift-for-Duo")!) {
                    Label {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("GitHub project")
                            Text(verbatim: "beinglida/SDKShift-for-Duo")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    } icon: { Image(systemName: "chevron.left.forwardslash.chevron.right") }
                }
            }
            Section("Recovery and privacy") {
                Text("Existing SDKShift recovery data is migrated. Original values from other tools are not imported automatically.")
                Text("App listings, reports, and recovery data stay on your device. Review app identifiers and paths before sharing reports.")
            }
            Section("Credits") {
                Text("The interface, change queue, history, and service adapter were rewritten for SDKShift. The cache engine derives from ForceDuoApp; worse_query retains its copyright and GPL notices.")
                Link("ForceDuoApp", destination: URL(string: "https://github.com/34306/ForceDuoApp")!)
                Link("worse_query", destination: URL(string: "https://github.com/forcequitOS/worse_query")!)
            }
        }
    }
}
