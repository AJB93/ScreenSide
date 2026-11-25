import SwiftUI

/// First-launch tour. Explains what ScreenSide does and asks for Location only
/// as an optional extra, with the reason shown before macOS's own prompt.
struct OnboardingView: View {
    @EnvironmentObject var model: AppModel
    @State var step = 0

    var body: some View {
        ZStack {
            AuroraBackground()
            VStack(spacing: 0) {
                Group {
                    switch step {
                    case 0: welcome
                    case 1: places
                    default: ready
                    }
                }
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .move(edge: .leading).combined(with: .opacity)))
                .frame(maxHeight: .infinity)

                footer
            }
            .padding(36)
        }
        .frame(width: 560, height: 600)
        .environment(\.colorScheme, .dark)
        .task { await model.refreshNetwork() }
    }

    // MARK: Steps

    private var welcome: some View {
        VStack(spacing: 18) {
            Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 128, height: 128)
                .shadow(color: Brand.violet.opacity(0.6), radius: 30)
            Text("Your screens, always\non the right side.")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
            Text("ScreenSide recognises the monitor you plug in and puts it where it belongs — left at home, right at the office — automatically.")
                .font(.body).foregroundStyle(.secondary).multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            HStack(spacing: 12) {
                feature("cable.connector.horizontal", "Knows your monitor", "Reads its ID over HDMI, DisplayPort or USB‑C")
                feature("mappin.and.ellipse", "Knows your places", "Home, office, meeting rooms")
                feature("bolt.fill", "Instant", "Rearranges the moment you plug in")
            }
            .padding(.top, 6)
        }
    }

    private var places: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recognising where you are")
                .font(.system(size: 26, weight: .bold, design: .rounded))
            Text("Some monitors look identical, and some go on a different side in different places. ScreenSide can tie a choice to a place.")
                .foregroundStyle(.secondary)

            permissionCard(icon: "wifi", title: "Network", tint: Brand.teal,
                           body: "Recognises a place by your Wi‑Fi or dock’s router. No permission needed.") {
                Label(model.network.map { "On \($0.displayName)" } ?? "Not connected", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.medium)).foregroundStyle(.green)
            }

            permissionCard(icon: "location.fill", title: "Location  ·  Optional", tint: Brand.violet,
                           body: "Also recognise a place on a different network, and show your Wi‑Fi names. Your location never leaves your Mac.") {
                LocationButton(location: model.location)
            }
        }
    }

    private var ready: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle().fill(Brand.gradient).frame(width: 96, height: 96).blur(radius: 30).opacity(0.7)
                Image(nsImage: MenuBarIcon.image).resizable().renderingMode(.template)
                    .foregroundStyle(.white).frame(width: 66, height: 48)
            }
            Text("You’re all set")
                .font(.system(size: 30, weight: .bold, design: .rounded))
            Text("ScreenSide lives in your menu bar. Plug in a display, click the icon and pick a side — once. After that it just happens.")
                .foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 420)
            Toggle("Open ScreenSide when I log in", isOn: $model.launchAtLogin)
                .toggleStyle(.switch)
                .padding(.horizontal, 18).padding(.vertical, 12)
                .glassSurface(cornerRadius: 16)
        }
    }

    // MARK: Pieces

    private var footer: some View {
        HStack {
            HStack(spacing: 6) {
                ForEach(0..<3) { i in
                    Capsule().fill(i == step ? AnyShapeStyle(Brand.gradient) : AnyShapeStyle(.white.opacity(0.25)))
                        .frame(width: i == step ? 22 : 7, height: 7)
                }
            }
            Spacer()
            if step > 0 {
                Button("Back") { withAnimation(.snappy) { step -= 1 } }.glassButton()
            }
            Button(step == 2 ? "Get Started" : "Continue") {
                if step == 2 { model.finishOnboarding() } else { withAnimation(.snappy) { step += 1 } }
            }
            .glassButton(prominent: true)
            .keyboardShortcut(.defaultAction)
        }
        .controlSize(.large)
    }

    private func feature(_ icon: String, _ title: String, _ text: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.title2).foregroundStyle(Brand.gradient).frame(height: 28)
            Text(title).font(.callout.weight(.semibold))
            Text(text).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .padding(12)
        .glassSurface(cornerRadius: 20)
    }

    private func permissionCard<Accessory: View>(icon: String, title: String, tint: Color, body: String,
                                                 @ViewBuilder accessory: () -> Accessory) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon).font(.title3).foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(tint.gradient, in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.headline)
                Text(body).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                accessory().padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .glassSurface(cornerRadius: 22)
    }
}
