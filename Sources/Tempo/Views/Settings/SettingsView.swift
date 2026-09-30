import AppKit
import SwiftUI
import TempoCore

struct SettingsView: View {
    @EnvironmentObject var model: TempoModel
    @AppStorage(AppSettings.Keys.idleMinutes) private var idleMinutes = 5
    @AppStorage(AppSettings.Keys.breakEnabled) private var breakEnabled = true
    @AppStorage(AppSettings.Keys.breakMinutes) private var breakMinutes = 90
    @AppStorage(AppSettings.Keys.distractionEnabled) private var distractionEnabled = true
    @AppStorage(AppSettings.Keys.distractionMinutes) private var distractionMinutes = 20
    @AppStorage(AppSettings.Keys.blockEnabled) private var blockEnabled = false
    @AppStorage(AppSettings.Keys.blockWeekdayMask) private var blockWeekdayMask = BlockSchedule.workweekMask
    @AppStorage(AppSettings.Keys.blockStartMinute) private var blockStartMinute = 540
    @AppStorage(AppSettings.Keys.blockEndMinute) private var blockEndMinute = 1020
    @ObservedObject private var blocker = BlockEnforcer.shared
    @State private var openAtLogin = LoginItem.isEnabled
    @State private var apiKey = ""
    @State private var keySaved = Keychain.read() != nil
    @State private var accessibility = PermissionState.notAsked
    @State private var chrome = PermissionState.notAsked
    @State private var safari = PermissionState.notAsked
    @State private var notifications = PermissionState.notAsked
    @State private var showRules = false

    private static let red = Color(hex: "#c0382f")
    private static let redSoft = Color(hex: "#fae8e6")

    /// Monday first, as Calendar weekday numbers.
    private static let weekdayOrder = [2, 3, 4, 5, 6, 7, 1]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                section("General") {
                    row("Open at login", "Starts quietly in the menu bar and restarts itself if it ever crashes.") {
                        Toggle("Open at login", isOn: $openAtLogin).toggleStyle(.switch).labelsHidden().tint(Theme.ink)
                    }
                    divider
                    row("Stop counting after", "Minutes with no keyboard or mouse input. Screen lock and sleep stop it right away.") {
                        MinutesField(value: $idleMinutes, label: "Idle minutes")
                    }
                    divider
                    row("Your data", AppPaths.dataDirectory.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"), monoDetail: true) {
                        SmallButton("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([AppPaths.database]) }
                    }
                }

                section("Nudges") {
                    row("Break nudge", "After this long at the keyboard without a five minute break.") {
                        HStack(spacing: 16) {
                            MinutesField(value: $breakMinutes, label: "Break nudge minutes")
                            Toggle("Break nudge", isOn: $breakEnabled).toggleStyle(.switch).labelsHidden().tint(Theme.ink)
                        }
                    }
                    divider
                    row("Distraction nudge", "After this long in Distraction without switching away.") {
                        HStack(spacing: 16) {
                            MinutesField(value: $distractionMinutes, label: "Distraction nudge minutes")
                            Toggle("Distraction nudge", isOn: $distractionEnabled).toggleStyle(.switch).labelsHidden().tint(Theme.ink)
                        }
                    }
                }

                section("Blocking") {
                    row("Adult sites", "Always blocked in Chrome and Safari, including private windows. SafeSearch is always on for Google, Bing, and DuckDuckGo.") {
                        if blocker.adultListLoaded {
                            StatusChip(text: "\(blocker.adult.count.formatted()) sites")
                        } else {
                            StatusChip(text: "List missing", foreground: Self.red, background: Self.redSoft)
                        }
                    }
                    divider
                    distractionBlockRow
                }

                section("Sorting") {
                    row("Claude API key", "Only used the first time Tempo sees an app or site. It sends the app name, window title, and domain once, then saves the answer as a rule.") {
                        VStack(alignment: .trailing, spacing: 6) {
                            HStack(spacing: 6) {
                                SecureField(keySaved ? "Saved" : "sk-ant-...", text: $apiKey)
                                    .textFieldStyle(.plain).font(Theme.mono(13))
                                    .padding(.horizontal, 10).frame(width: 200, height: 32)
                                    .background(Theme.panel, in: RoundedRectangle(cornerRadius: 8))
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line))
                                    .onSubmit(saveKey)
                                SmallButton("Save") { saveKey() }.disabled(apiKey.isEmpty)
                            }
                            if model.keyRejected {
                                StatusChip(text: "Key rejected", foreground: Self.red, background: Self.redSoft)
                            } else if keySaved {
                                StatusChip(text: "In Keychain")
                            }
                        }
                    }
                    divider
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .center, spacing: 16) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Categories and rules").font(Theme.ui(14, .semibold))
                                Text("9 categories, \(model.rules.filter { $0.category != nil }.count) rules. Change or remove any rule.")
                                    .font(Theme.ui(12.5)).foregroundStyle(Theme.muted)
                            }
                            Spacer()
                            SmallButton("Manage") { showRules = true }
                        }
                        FlowLayout(spacing: 6) {
                            ForEach(CategoryID.allCases, id: \.self) { c in
                                Text(c.name).font(Theme.ui(12.5, .semibold))
                                    .padding(.horizontal, 10).frame(height: 26)
                                    .foregroundStyle(c.labelColor)
                                    .background { CategoryFill(category: c).clipShape(RoundedRectangle(cornerRadius: 7)) }
                            }
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 13)
                }

                section("Permissions") {
                    permissionRow("Accessibility", "Reads the title of the window you are in.", accessibility) {
                        Permissions.openPrivacyPane("Privacy_Accessibility")
                    }
                    divider
                    permissionRow("Chrome", "Reads the current tab, and swaps in the blocked page for blocked sites.", chrome) {
                        Permissions.openPrivacyPane("Privacy_Automation")
                    }
                    divider
                    permissionRow("Safari", "Same as Chrome. Asks the first time Safari runs with Tempo running.", safari) {
                        Permissions.openPrivacyPane("Privacy_Automation")
                    }
                    divider
                    permissionRow("Notifications", "Break and distraction nudges.", notifications) {
                        Permissions.openNotificationSettings()
                    }
                }
            }
            .padding(EdgeInsets(top: 22, leading: 32, bottom: 28, trailing: 32))
        }
        .frame(minWidth: 760, minHeight: 560)
        .background(Theme.bg)
        .foregroundStyle(Theme.ink)
        .environment(\.colorScheme, .light)
        .onChange(of: openAtLogin) { _, on in
            do { if on { try LoginItem.enable() } else { try LoginItem.disable() } } catch { Log.error("login item: \(error)") }
        }
        .onChange(of: idleMinutes) { _, _ in model.applySettings() }
        .onChange(of: breakEnabled) { _, _ in model.applySettings() }
        .onChange(of: breakMinutes) { _, _ in model.applySettings() }
        .onChange(of: distractionEnabled) { _, _ in model.applySettings() }
        .onChange(of: distractionMinutes) { _, _ in model.applySettings() }
        .onChange(of: blockEnabled) { _, _ in BlockEnforcer.shared.refreshWindow() }
        .onChange(of: blockWeekdayMask) { _, _ in BlockEnforcer.shared.refreshWindow() }
        .onChange(of: blockStartMinute) { _, _ in BlockEnforcer.shared.refreshWindow() }
        .onChange(of: blockEndMinute) { _, _ in BlockEnforcer.shared.refreshWindow() }
        .task { await loadPermissions() }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            Task { await loadPermissions() }
        }
        .sheet(isPresented: $showRules) { RulesSheet().environmentObject(model) }
    }

    private func saveKey() {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        keySaved = Keychain.save(key)
        apiKey = ""
        model.setKeyRejected(false)
        model.enqueueUnknownKeys()
        ClassifierWorker.shared.flush()
    }

    private func loadPermissions() async {
        accessibility = Permissions.accessibility()
        chrome = Permissions.automation(bundleID: "com.google.Chrome")
        safari = Permissions.automation(bundleID: "com.apple.Safari")
        notifications = await Permissions.notifications()
    }

    private var divider: some View { Rectangle().fill(Theme.grid).frame(height: 1) }

    private var blockDetail: String {
        let base = "Blocks every site in Distraction during these hours. Locked while it runs."
        return blockEndMinute <= blockStartMinute ? base + " Ends the next day." : base
    }

    private var distractionBlockRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Distraction block").font(Theme.ui(14, .semibold))
                    Text(blockDetail).font(Theme.ui(12.5)).foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: 400, alignment: .leading)
                Spacer(minLength: 12)
                if let w = blocker.distractionWindow {
                    StatusChip(text: "Locked until \(Format.clock(w.end))", foreground: Theme.ink, background: Theme.chip)
                }
                Toggle("Distraction block", isOn: $blockEnabled).toggleStyle(.switch).labelsHidden().tint(Theme.ink)
                    .disabled(blocker.isLocked)
            }
            HStack(spacing: 6) {
                ForEach(Self.weekdayOrder, id: \.self) { day in
                    DayChip(label: Calendar.current.shortWeekdaySymbols[day - 1],
                            on: blockWeekdayMask & (1 << (day - 1)) != 0) {
                        blockWeekdayMask ^= (1 << (day - 1))
                    }
                }
                Spacer(minLength: 16)
                Text("From").font(Theme.ui(12.5)).foregroundStyle(Theme.muted)
                DatePicker("Start", selection: minuteBinding($blockStartMinute), displayedComponents: .hourAndMinute)
                    .labelsHidden()
                Text("To").font(Theme.ui(12.5)).foregroundStyle(Theme.muted)
                DatePicker("End", selection: minuteBinding($blockEndMinute), displayedComponents: .hourAndMinute)
                    .labelsHidden()
            }
            .disabled(blocker.isLocked)
            .opacity(blocker.isLocked ? 0.5 : 1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    /// A minutes-after-midnight setting as today's date at that time, for DatePicker.
    private func minuteBinding(_ minutes: Binding<Int>) -> Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(bySettingHour: minutes.wrappedValue / 60, minute: minutes.wrappedValue % 60,
                                      second: 0, of: Date()) ?? Date()
            },
            set: { date in
                let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                minutes.wrappedValue = (c.hour ?? 0) * 60 + (c.minute ?? 0)
            })
    }

    private func section<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(Theme.display(16)).padding(.leading, 4)
            VStack(spacing: 0) { content() }
                .background(Theme.panel, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.line))
        }
    }

    private func row<Control: View>(_ title: String, _ detail: String, monoDetail: Bool = false,
                                    @ViewBuilder control: () -> Control) -> some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Theme.ui(14, .semibold))
                Text(detail).font(monoDetail ? Theme.mono(12) : Theme.ui(12.5)).foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: 400, alignment: .leading)
            Spacer(minLength: 12)
            control()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    private func permissionRow(_ title: String, _ detail: String, _ state: PermissionState,
                               open: @escaping () -> Void) -> some View {
        row(title, detail) {
            HStack(spacing: 10) {
                switch state {
                case .granted:
                    StatusChip(text: "Granted")
                case .notAsked:
                    StatusChip(text: "Not asked yet", foreground: Theme.muted, background: Theme.chip)
                case .notRunning:
                    StatusChip(text: "Not running", foreground: Theme.muted, background: Theme.chip)
                case .denied:
                    StatusChip(text: "Not granted", foreground: Self.red, background: Self.redSoft)
                    SmallButton("Open System Settings", action: open)
                }
            }
        }
    }
}

struct MinutesField: View {
    @Binding var value: Int
    let label: String
    var body: some View {
        HStack(spacing: 6) {
            TextField(label, value: $value, format: .number)
                .textFieldStyle(.plain)
                .font(Theme.mono(14))
                .multilineTextAlignment(.trailing)
                .padding(.horizontal, 10)
                .frame(width: 64, height: 32)
                .background(Theme.panel, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line))
                .accessibilityLabel(label)
            Text("min").font(Theme.ui(12)).foregroundStyle(Theme.muted)
        }
    }
}
