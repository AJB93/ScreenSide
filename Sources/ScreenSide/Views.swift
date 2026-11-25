import SwiftUI

// MARK: - Menu bar panel

struct MenuContent: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if model.externals.isEmpty {
                EmptyState()
            } else {
                ForEach(model.externals) { d in DisplayCard(display: d) }
            }

            OtherDisplaysRow()

            Text(model.lastAction)
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Button { Task { await model.applyRules() } } label: {
                    Label("Arrange Now", systemImage: "arrow.triangle.2.circlepath")
                }
                .glassButton(prominent: true)
                Button { openWindow(id: "settings"); NSApp.activate(ignoringOtherApps: true) } label: {
                    Label("Rules", systemImage: "slider.horizontal.3")
                }
                .glassButton()
                Spacer()
                Button { NSApp.terminate(nil) } label: { Image(systemName: "power") }
                    .glassButton().help("Quit ScreenSide")
            }
            .controlSize(.regular)
        }
        .padding(16)
        .frame(width: 372)
        .task { await model.refreshNetwork() }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 30, height: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text("ScreenSide").font(.headline)
                Label(model.hereName, systemImage: model.currentPlace != nil ? "mappin.circle.fill" : "wifi")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Toggle("Auto", isOn: $model.settings.autoApply)
                .toggleStyle(.switch).controlSize(.small).labelsHidden()
                .help("Arrange automatically whenever a display is plugged in")
        }
    }
}

struct EmptyState: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "cable.connector.horizontal").font(.system(size: 28)).foregroundStyle(Brand.gradient)
            Text("Plug in a display").font(.callout.weight(.medium))
            Text("ScreenSide will recognise it and put it on the right side.")
                .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 18)
        .glassSurface(cornerRadius: 18)
    }
}

/// One connected external monitor with a visual side picker.
struct DisplayCard: View {
    @EnvironmentObject var model: AppModel
    let display: ConnectedDisplay
    @State private var onlyHere = false

    var body: some View {
        let rule = model.activeRule(for: display)
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "display").foregroundStyle(Brand.gradient)
                VStack(alignment: .leading, spacing: 1) {
                    Text(display.name).font(.callout.weight(.semibold))
                    Text(verbatim: display.hasSerial ? "Serial \(display.serial)" : "No serial · matches any \(display.name)")
                        .font(.caption2).foregroundStyle(.secondary)
                        .help(display.identityDescription)
                }
                Spacer()
                if let rule {
                    Text(model.describePlace(rule))
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .glassSurface(cornerRadius: 10, tint: Brand.violet.opacity(0.4))
                }
            }

            ArrangementPicker(side: rule?.side, alignment: rule?.alignment ?? .center) { side, align in
                Task { await model.setSide(side, alignment: align, for: display, onlyHere: onlyHere) }
            }

            Toggle(isOn: $onlyHere) {
                Text("Only at \(model.hereName)").font(.caption)
            }
            .toggleStyle(.checkbox)
            .help("Save this choice just for where you are now – e.g. left at home, right at the office")
        }
        .padding(12)
        .glassSurface(cornerRadius: 20)
    }
}

/// Default for monitors without a rule of their own, e.g. meeting-room screens.
struct OtherDisplaysRow: View {
    @EnvironmentObject var model: AppModel
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button { withAnimation(.snappy) { expanded.toggle() } } label: {
                HStack {
                    Image(systemName: "rectangle.dashed")
                    Text("Any other display at \(model.hereName)").font(.caption.weight(.medium))
                    Spacer()
                    Image(systemName: "chevron.down").rotationEffect(.degrees(expanded ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if expanded {
                ArrangementPicker(side: nil, alignment: .center, compact: true) { side, align in
                    Task { await model.setSide(side, alignment: align, for: nil, onlyHere: true) }
                }
            }
        }
        .padding(12)
        .glassSurface(cornerRadius: 16)
    }
}

/// A miniature of the display arrangement: tap a slot to put the monitor there.
struct ArrangementPicker: View {
    let side: Side?
    let alignment: Alignment
    var compact = false
    let onChange: (Side, Alignment) -> Void
    @Namespace private var ns
    @State private var hovered: Side?

    private var laptop: CGSize { compact ? CGSize(width: 56, height: 36) : CGSize(width: 70, height: 44) }
    private var slot: CGSize { compact ? CGSize(width: 50, height: 32) : CGSize(width: 62, height: 40) }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                laptopShape
                ForEach(Side.allCases) { s in slotView(s).offset(offset(for: s)) }
            }
            .frame(maxWidth: .infinity)
            .frame(height: laptop.height + slot.height * 2 + 16)

            if let side {
                Picker("Alignment", selection: Binding(get: { alignment }, set: { onChange(side, $0) })) {
                    ForEach(Alignment.allCases) { a in Text(a.label(for: side)).tag(a) }
                }
                .pickerStyle(.segmented).labelsHidden().controlSize(.small)
            }
        }
    }

    private var laptopShape: some View {
        VStack(spacing: 2) {
            RoundedRectangle(cornerRadius: 6)
                .fill(LinearGradient(colors: [Brand.violet.opacity(0.8), Brand.violet.opacity(0.45)], startPoint: .top, endPoint: .bottom))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.white.opacity(0.5), lineWidth: 1))
                .frame(width: laptop.width, height: laptop.height)
                .overlay(Image(systemName: "apple.logo").font(.system(size: 11)).foregroundStyle(.white.opacity(0.8)))
            Capsule().fill(.white.opacity(0.6)).frame(width: laptop.width + 14, height: 3)
        }
        .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
    }

    private func offset(for s: Side) -> CGSize {
        let gapX = (laptop.width + slot.width) / 2 + 10, gapY = (laptop.height + slot.height) / 2 + 8
        switch s {
        case .left: return CGSize(width: -gapX, height: 0)
        case .right: return CGSize(width: gapX, height: 0)
        case .above: return CGSize(width: 0, height: -gapY)
        case .below: return CGSize(width: 0, height: gapY)
        }
    }

    @ViewBuilder
    private func slotView(_ s: Side) -> some View {
        let selected = s == side
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { onChange(s, alignment) }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.2, dash: [4, 3]))
                    .foregroundStyle(.secondary.opacity(hovered == s ? 0.9 : 0.45))
                Image(systemName: s.symbol).font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary.opacity(hovered == s ? 1 : 0.6))
                if selected {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(LinearGradient(colors: [Brand.teal, Brand.teal.opacity(0.6)], startPoint: .top, endPoint: .bottom))
                        .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(.white.opacity(0.7), lineWidth: 1))
                        .overlay(Image(systemName: "display").font(.caption).foregroundStyle(.white))
                        .shadow(color: Brand.teal.opacity(0.6), radius: 8)
                        .matchedGeometryEffect(id: "monitor", in: ns)
                }
            }
            .frame(width: slot.width, height: slot.height)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 ? s : (hovered == s ? nil : hovered) }
        .help("Put the screen \(s == .left || s == .right ? "to the \(s.rawValue) of" : "\(s.rawValue)") your Mac")
    }
}

// MARK: - Rules & Places window

struct SettingsView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        Form {
            Section {
                if model.settings.rules.isEmpty {
                    Text("No rules yet. Click a side for a display in the menu bar.").foregroundStyle(.secondary)
                }
                ForEach($model.settings.rules) { $rule in
                    HStack(spacing: 10) {
                        Image(systemName: rule.display == nil ? "rectangle.dashed" : "display")
                            .foregroundStyle(Brand.gradient).frame(width: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(model.describeTarget(rule)).fontWeight(.medium)
                            Text(model.describe(rule)).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $rule.enabled).labelsHidden().toggleStyle(.switch).controlSize(.small)
                        Button(role: .destructive) { model.deleteRule(rule) } label: { Image(systemName: "trash") }
                            .buttonStyle(.borderless)
                    }
                }
            } header: {
                Text("Rules")
            } footer: {
                Text("The most specific rule wins: this exact monitor beats the same model, which beats “any other display”. A rule for a place only applies there.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section {
                if model.settings.places.isEmpty {
                    Text("Places are created when you tick “Only at …” on a display.").foregroundStyle(.secondary)
                }
                ForEach($model.settings.places) { $place in
                    HStack(spacing: 10) {
                        Image(systemName: place.id == model.currentPlace?.id ? "mappin.circle.fill" : "mappin.circle")
                            .foregroundStyle(Brand.gradient).frame(width: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            TextField("Name", text: $place.name).textFieldStyle(.plain).fontWeight(.medium)
                            Text(place.detail).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if place.hasLocation {
                            Stepper("\(Int(place.radius)) m", value: $place.radius, in: 50...5000, step: 50)
                                .font(.caption).fixedSize()
                        }
                        Button(role: .destructive) { model.deletePlace(place) } label: { Image(systemName: "trash") }
                            .buttonStyle(.borderless)
                            .help("Forget this place and its rules")
                    }
                }
            } header: {
                Text("Places")
            }

            Section("Recognising places") {
                LabeledContent {
                    Text(model.network?.displayName.capitalizedFirst ?? "Not connected").foregroundStyle(.secondary)
                } label: {
                    Label("Network", systemImage: "wifi")
                    Text("Always on. Uses your router’s ID – no permission needed.").font(.caption)
                }
                LabeledContent {
                    LocationButton(location: model.location)
                } label: {
                    Label("Location", systemImage: "location")
                    Text("Optional. Recognises a place even on a new network.").font(.caption)
                }
            }

            Section {
                Toggle("Arrange automatically when a display is connected", isOn: $model.settings.autoApply)
                Toggle("Launch at login", isOn: $model.launchAtLogin)
                Button("Show Welcome Tour…") { model.showOnboarding() }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 560, minHeight: 520)
        .task { await model.refreshNetwork() }
    }
}

struct LocationButton: View {
    @ObservedObject var location: LocationProvider

    var body: some View {
        if location.isAuthorized {
            Label("Allowed", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
        } else if location.isDenied {
            VStack(alignment: .leading, spacing: 4) {
                Button(location.servicesEnabled ? "Allow in System Settings…" : "Turn On Location Services…") {
                    location.openPrivacySettings()
                }
                .glassButton()
                Text(location.statusText).font(.caption2).foregroundStyle(.secondary)
            }
        } else {
            Button("Allow Location…") { location.requestAccess() }.glassButton(prominent: true)
        }
    }
}

extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
