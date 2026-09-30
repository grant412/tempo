import AppKit
import SwiftUI
import TempoCore

struct RulesSheet: View {
    @EnvironmentObject var model: TempoModel
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var names: [String: String] = [:]
    @ObservedObject private var blocker = BlockEnforcer.shared

    private var rows: [Rule] {
        model.rules
            .filter { $0.category != nil }
            .filter { search.isEmpty || $0.key.key.localizedCaseInsensitiveContains(search)
                || (names[$0.key.key]?.localizedCaseInsensitiveContains(search) ?? false) }
            .sorted { name(for: $0).lowercased() < name(for: $1).lowercased() }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Rules").font(Theme.display(22))
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
            TextField("Search apps and sites", text: $search).textFieldStyle(.roundedBorder)
            List(rows, id: \.key) { rule in
                HStack(spacing: 12) {
                    Image(systemName: rule.key.kind == .domain ? "globe" : "app")
                        .foregroundStyle(Theme.muted).frame(width: 18)
                    Text(name(for: rule)).font(Theme.ui(13.5)).lineLimit(1).truncationMode(.middle)
                    Spacer()
                    Text(sourceLabel(rule.source)).font(Theme.mono(11)).foregroundStyle(Theme.muted)
                    if model.isLocked(rule.key) {
                        LockedBadge(until: blocker.distractionWindow?.end)
                        Image(systemName: "trash").hidden()
                    } else {
                        CategoryMenu(current: rule.category ?? .uncategorized) { model.setCategory(rule.key, $0) }
                        Button { model.deleteRule(rule.key) } label: { Image(systemName: "trash") }
                            .buttonStyle(.borderless)
                            .help("Remove rule")
                            .accessibilityLabel("Remove rule for \(name(for: rule))")
                    }
                }
                .padding(.vertical, 2)
            }
            .listStyle(.inset)
        }
        .padding(20)
        .frame(width: 640, height: 560)
        .background(Theme.bg)
        .environment(\.colorScheme, .light)
        .onAppear(perform: loadNames)
    }

    private func name(for rule: Rule) -> String { names[rule.key.key] ?? rule.key.key }

    private func sourceLabel(_ source: RuleSource) -> String {
        switch source {
        case .defaultRule: "default"
        case .user: "you"
        case .claude: "Claude"
        }
    }

    private func loadNames() {
        var out: [String: String] = [:]
        for rule in model.rules where rule.key.kind == .app {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: rule.key.key) {
                out[rule.key.key] = FileManager.default.displayName(atPath: url.path)
                    .replacingOccurrences(of: ".app", with: "")
            }
        }
        names = out
    }
}
