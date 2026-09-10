import SwiftUI
import UIKit
import Security

@main
struct ThreeOneOSFiveApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var patchDraftCoordinator = PatchDraftCoordinator()
    @StateObject private var fileOperationCoordinator = FileOperationCoordinator()
    @AppStorage(AppLanguage.storageKey) private var languageCode = AppLanguage.english.rawValue
    @State private var showOnboarding = OnboardingStore.shouldShow()
    @AppStorage("greeg.license.supabaseUnlocked") private var licenseUnlocked = false
    @State private var showAttribution = false
    @State private var updateOffer: AppUpdateChecker.Offer?
    @Environment(\.scenePhase) private var scenePhase

    init() {
        setupLogCapture()
        log("app: 3105 launching — iOS \(AppInfo.osVersion) (\(AppInfo.osBuild)) \(AppInfo.machineName)")
    }

    private var language: AppLanguage {
        AppLanguage(rawValue: languageCode) ?? .english
    }

    private func checkForUpdate() {
        Task {
            guard let offer = await AppUpdateChecker.check() else { return }
            await MainActor.run { updateOffer = offer }
        }
    }

    private func refreshLicenseStatus() {
        _ = DeviceInstallationID.current()
        guard licenseUnlocked else { return }
        let storedKey = UserDefaults.standard.string(forKey: "greeg.license.key")?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() ?? ""
        guard !storedKey.isEmpty else {
            licenseUnlocked = false
            return
        }
        Task {
            do {
                let response = try await SupabaseLicenseClient().activate(licenseKey: storedKey, deviceID: DeviceInstallationID.current())
                await MainActor.run {
                    licenseUnlocked = response.success
                    if !response.success {
                        UserDefaults.standard.set(false, forKey: "greeg.license.supabaseUnlocked")
                    }
                }
            } catch {
                log("license: refresh failed: \(error.localizedDescription)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                if licenseUnlocked {
                    ContentView()
                    .environmentObject(appState)
                    .environmentObject(patchDraftCoordinator)
                    .environmentObject(fileOperationCoordinator)
                    .environment(\.appLanguage, language)
                    .environment(\.locale, language.locale)
                    .opacity(showOnboarding ? 0 : 1)
                    .allowsHitTesting(!showOnboarding)

                    if showOnboarding {
                    OnboardingView {
                        OnboardingStore.markCompleted()
                        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                            showOnboarding = false
                        }
                        appState.detectSupport()
                        checkForUpdate()
                    }
                    .environment(\.appLanguage, language)
                    .environment(\.locale, language.locale)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .zIndex(1)
                    }
                } else {
                    GreegLicenseView {
                        licenseUnlocked = true
                    }
                }
            }
            .preferredColorScheme(.dark)
            .displayIdentityAttribution(isPresented: $showAttribution, enabled: licenseUnlocked && !showOnboarding)
            .sheet(isPresented: $showAttribution) {
                DisplayAttributionSheet()
            }
            .alert(item: $updateOffer) { offer in
                Alert(
                    title: Text(language.text("update.title")),
                    message: Text(language.text("update.message", offer.version)),
                    primaryButton: .default(Text(language.text("update.agree"))) {
                        UIApplication.shared.open(offer.url)
                    },
                    secondaryButton: .cancel(Text(language.text("update.dismiss"))) {
                        AppUpdateChecker.dismiss(version: offer.version)
                    }
                )
            }
            .onAppear {
                refreshLicenseStatus()
                if licenseUnlocked && !showOnboarding {
                    appState.detectSupport()
                    checkForUpdate()
                }
            }
            .onChange(of: scenePhase) { phase in
                guard phase == .active else { return }
                refreshLicenseStatus()
                guard licenseUnlocked, !showOnboarding else { return }
                appState.detectSupport()
            }
            .onOpenURL { url in
                patchDraftCoordinator.presentImport(url)
            }
        }
    }
}

class AppState: ObservableObject {
    @Published var exploitStatus: ExploitStatus = .notStarted
    @Published var unsupportedMessage: String?
    @Published var kernelExploitRunning = false

    private var autoRunAttempted = false

    var kernelExploitApplicable: Bool {
        KernelExploit.isApplicable(
            major: AppInfo.versionTuple.major,
            minor: AppInfo.versionTuple.minor,
            patch: AppInfo.versionTuple.patch,
            build: AppInfo.osBuild
        )
    }

    var isSupported: Bool { unsupportedMessage == nil }

    func detectSupport() {
        let v = AppInfo.versionTuple
        let supported = ExploitSupportPolicy.isSupported(
            major: v.major,
            minor: v.minor,
            patch: v.patch,
            build: AppInfo.osBuild
        )
#if targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("--simulate-access") {
            exploitStatus = .success(method: "Simulator preview")
        }
#endif

        unsupportedMessage = supported ? nil : "iOS \(AppInfo.osVersion) (\(AppInfo.osBuild))"
        if let unsupportedMessage {
            exploitStatus = .unsupported(unsupportedMessage)
            return
        }

        let applicable = KernelExploit.isApplicable(
            major: v.major,
            minor: v.minor,
            patch: v.patch,
            build: AppInfo.osBuild
        )
        guard applicable else { return }

        refreshKernelExploitStatus()
        maybeAutoRunKernelExploit()
    }

    private func maybeAutoRunKernelExploit() {
        guard !kernelExploitRunning,
              !exploitStatus.isSuccess,
              !exploitStatus.isFailed,
              !autoRunAttempted else { return }
        autoRunAttempted = true
        log("app: starting kernel exploit automatically")
        runKernelExploitIfNeeded()
    }

    private func refreshKernelExploitStatus() {
        guard !kernelExploitRunning else { return }

        // iOS < 26: kernel R/W success persists (no sandbox probe)
        // iOS >= 26: verify full sandbox escape is still active
        if KernelExploit.requiresSandboxEscape {
            if KernelExploit.hasSandboxAccess() {
                if !exploitStatus.isSuccess {
                    exploitStatus = .success(method: "kexploit")
                    log("app: existing sandbox access is still active; skipping kernel exploit")
                }
            } else if exploitStatus.isSuccess {
                exploitStatus = .notStarted
                log("app: sandbox access is no longer active")
            }
        }
    }

    func runKernelExploitIfNeeded() {
        refreshKernelExploitStatus()
        guard !kernelExploitRunning,
              !exploitStatus.isSuccess,
              !exploitStatus.isFailed else { return }
        kernelExploitRunning = true
        exploitStatus = .notStarted
        log("app: running kernel exploit on background...")
        DispatchQueue.global(qos: .userInitiated).async {
            let ok = KernelExploit.run()
            DispatchQueue.main.async {
                self.kernelExploitRunning = false
                if ok {
                    self.exploitStatus = .success(method: "kexploit")
                    if KernelExploit.requiresSandboxEscape {
                        log("app: kernel exploit success — sandbox access verified")
                    } else {
                        log("app: kernel exploit success — kernel access active")
                    }
                } else {
                    self.exploitStatus = .failed(method: "kexploit", code: -1)
                    log("app: kernel exploit failed — relaunch the app before retrying")
                }
            }
        }
    }
}


private struct GreegLicenseView: View {
    @State private var key = ""
    @State private var messageText = ""
    @State private var didActivate = false
    @State private var isLoading = false
    let onSuccess: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 22) {
                Spacer()
                AppLogo(size: 104)
                    .shadow(color: AppTheme.accent.opacity(0.55), radius: 24)
                VStack(spacing: 7) {
                    Text("GREEG APP")
                        .font(.system(size: 31, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Acceso exclusivo para clientes")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "key.fill").foregroundStyle(AppTheme.accent)
                        TextField("GREEG-1", text: $key)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .foregroundStyle(.white)
                            .disabled(isLoading || didActivate)
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 54)
                    .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 15))
                    .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.white.opacity(0.12)))

                    Button(action: primaryAction) {
                        HStack(spacing: 10) {
                            if isLoading { ProgressView().tint(.white) }
                            else { Image(systemName: didActivate ? "checkmark.circle.fill" : "arrow.right") }
                            Text(didActivate ? "Continuar" : "Entrar").font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 15))
                        .foregroundStyle(.white)
                    }
                    .disabled(isLoading)

                    if !messageText.isEmpty {
                        Text(messageText)
                            .font(.footnote)
                            .foregroundStyle(didActivate ? .green : AppTheme.accent)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 30)

                Text("Activación segura con Supabase")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                Spacer()
                Text("GREEG APP • STAY PRIVATE")
                    .font(.caption2.weight(.semibold))
                    .tracking(2)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 24)
            }
        }
    }

    private func primaryAction() {
        if didActivate { onSuccess(); return }
        Task { await validate() }
    }

    @MainActor
    private func validate() async {
        let normalized = key.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !normalized.isEmpty else { messageText = "Ingresa una key para continuar."; return }
        key = normalized
        isLoading = true
        defer { isLoading = false }
        do {
            let deviceID = DeviceInstallationID.current()
            let response = try await SupabaseLicenseClient().activate(licenseKey: normalized, deviceID: deviceID)
            messageText = response.message
            if response.success {
                UserDefaults.standard.set(normalized, forKey: "greeg.license.key")
                UserDefaults.standard.set(deviceID, forKey: "greeg.license.device")
                UserDefaults.standard.set(true, forKey: "greeg.license.supabaseUnlocked")
                didActivate = true
            }
        } catch {
            messageText = error.localizedDescription
        }
    }
}

private enum SupabaseLicenseConfig {
    static let projectURL = URL(string: "https://qlfugpumolehqzzuvocn.supabase.co")!
    static let publishableKey = "sb_publishable_EAsMdYoIsenDI9ZYxKMcFA_3nuPXW5y"
}

private struct SupabaseLicenseResponse: Decodable {
    let success: Bool
    let message: String
}

private enum SupabaseLicenseError: LocalizedError {
    case invalidResponse
    case server(String)
    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Supabase no devolvió una respuesta válida."
        case .server(let message): return message
        }
    }
}

private final class SupabaseLicenseClient {
    func activate(licenseKey: String, deviceID: String) async throws -> SupabaseLicenseResponse {
        let url = SupabaseLicenseConfig.projectURL.appendingPathComponent("rest/v1/rpc/activate_license")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 25
        request.setValue(SupabaseLicenseConfig.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(SupabaseLicenseConfig.publishableKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "p_license_key": licenseKey,
            "p_device_id": deviceID
        ])
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SupabaseLicenseError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["message"] as? String
            throw SupabaseLicenseError.server(message ?? "Error del servidor (HTTP \(http.statusCode)).")
        }
        return try JSONDecoder().decode(SupabaseLicenseResponse.self, from: data)
    }
}

private enum DeviceInstallationID {
    private static let service = "com.apple.mobile.MobileHouseArrest.greeg-license"
    private static let account = "installation-id"
    private static let fallbackKey = "greeg.license.installationID"

    static func current() -> String {
        if let value = readKeychain(), !value.isEmpty { return value }
        if let value = UserDefaults.standard.string(forKey: fallbackKey), !value.isEmpty {
            saveKeychain(value)
            return value
        }
        let value = "ios-\(UUID().uuidString.lowercased())"
        UserDefaults.standard.set(value, forKey: fallbackKey)
        saveKeychain(value)
        return value
    }

    private static func readKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func saveKeychain(_ value: String) {
        let data = Data(value.utf8)
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(base as CFDictionary)
        var add = base
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(add as CFDictionary, nil)
    }
}
