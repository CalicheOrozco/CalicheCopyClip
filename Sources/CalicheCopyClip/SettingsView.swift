import ServiceManagement
import SwiftUI

enum SettingsTab: Hashable {
    case general, about
}

/// Lets the app delegate choose which settings tab is showing.
final class SettingsTabState: ObservableObject {
    @Published var selection: SettingsTab = .general
}

struct SettingsView: View {
    @ObservedObject var store: ClipStore
    @ObservedObject var tab: SettingsTabState
    @AppStorage("hotKeyLetter") private var hotKeyLetter = HotKey.defaultLetter
    @AppStorage("hotKeyModifier") private var hotKeyModifier = HotKey.defaultModifier.rawValue
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    var body: some View {
        TabView(selection: $tab.selection) {
            general.tabItem { Label("General", systemImage: "gearshape") }.tag(SettingsTab.general)
            about.tabItem { Label("Acerca de", systemImage: "person.crop.circle") }.tag(SettingsTab.about)
        }
        .frame(width: 420, height: 280)
        .padding()
    }

    private var general: some View {
        Form {
            Picker("Atajo para abrir la lista", selection: $hotKeyModifier) {
                ForEach(HotKeyModifier.allCases) { Text("\($0.symbol) + \(hotKeyLetter)").tag($0.rawValue) }
            }
            Picker("Letra del atajo", selection: $hotKeyLetter) {
                ForEach(HotKey.letters, id: \.name) { Text($0.name).tag($0.name) }
            }
            Toggle("Iniciar al arrancar la Mac", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { setLaunchAtLogin($0) }
            if let loginError {
                Text(loginError).font(.caption).foregroundStyle(.red)
            }
            Toggle("Lo más copiado arriba", isOn: $store.mostCopiedOnTop)
            Stepper("Guardar hasta \(store.maxItems) elementos", value: $store.maxItems, in: 20...1000, step: 20)
        }
        .padding()
    }

    private var about: some View {
        VStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
            Text("Caliche CopyClip").font(.title2.bold())
            Text("Versión \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev")")
                .foregroundStyle(.secondary)
            Text("El portapapeles personal de Caliche. Todo se guarda solo en esta Mac.")
                .multilineTextAlignment(.center)
                .font(.callout)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginError = nil
        } catch {
            loginError = "No se pudo cambiar: \(error.localizedDescription)"
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
