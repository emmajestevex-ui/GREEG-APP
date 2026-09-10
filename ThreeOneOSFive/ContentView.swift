import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var patchDraftCoordinator: PatchDraftCoordinator
    @State private var tabNavigation: AppTabNavigationState
    @AppStorage(FeatureVisibility.cleanerStorageKey) private var cleanerEnabled = true
    @AppStorage(FeatureVisibility.wallpapersStorageKey) private var wallpapersEnabled = true

    init() {
#if targetEnvironment(simulator)
        let arguments = ProcessInfo.processInfo.arguments
        let initialTab: Int
        if arguments.contains("--simulate-files-tab") {
            initialTab = 1
        } else if arguments.contains("--simulate-patch-tab") {
            initialTab = 2
        } else if arguments.contains("--simulate-cleaner-tab") {
            initialTab = 3
        } else if arguments.contains("--simulate-wallpaper-tab") {
            initialTab = 4
        } else {
            initialTab = AppSection.home.rawValue
        }
        _tabNavigation = State(initialValue: AppTabNavigationState(selectedTab: initialTab))
#else
        _tabNavigation = State(initialValue: AppTabNavigationState())
#endif
    }

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                regularLayout
            } else {
                compactLayout
            }
        }
        .tint(AppTheme.accent)
        .imageScale(.small)
        .onChange(of: patchDraftCoordinator.request?.id) { requestID in
            if requestID != nil { tabNavigation.select(AppSection.patches.rawValue) }
        }
        .onChange(of: patchDraftCoordinator.importRequest?.id) { requestID in
            if requestID != nil { tabNavigation.select(AppSection.patches.rawValue) }
        }
        .onChange(of: cleanerEnabled) { _ in
            tabNavigation.reconcileSelection(with: featureVisibility)
        }
        .onChange(of: wallpapersEnabled) { _ in
            tabNavigation.reconcileSelection(with: featureVisibility)
        }
        .onAppear {
            tabNavigation.reconcileSelection(with: featureVisibility)
        }
    }

    private var compactLayout: some View {
        TabView(selection: tabSelection) {
            ForEach(featureVisibility.visibleSections) { section in
                sectionContent(section)
                    .tabItem {
                        CompactTabLabel(
                            title: language.text(section.titleKey),
                            systemImage: section.systemImage
                        )
                    }
                    .tag(section.rawValue)
            }
        }
    }

    private var regularLayout: some View {
        NavigationSplitView {
            List {
                ForEach(featureVisibility.visibleSections) { section in
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            tabNavigation.select(section.rawValue)
                        }
                    } label: {
                        Label(language.text(section.titleKey), systemImage: section.systemImage)
                            .fontWeight(section.rawValue == tabNavigation.selectedTab ? .semibold : .regular)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(
                        section.rawValue == tabNavigation.selectedTab
                            ? AppTheme.accent.opacity(0.14)
                            : Color.clear
                    )
                    .accessibilityAddTraits(
                        section.rawValue == tabNavigation.selectedTab ? .isSelected : []
                    )
                }
            }
            .navigationTitle("greeg app")
            .navigationSplitViewColumnWidth(min: 210, ideal: 240, max: 300)
        } detail: {
            sectionContent(selectedVisibleSection)
                .id(selectedVisibleSection.rawValue)
        }
        .navigationSplitViewStyle(.balanced)
    }

    @ViewBuilder
    private func sectionContent(_ section: AppSection) -> some View {
        switch section {
        case .home:
            DashboardView(
                cleanerEnabled: $cleanerEnabled,
                wallpapersEnabled: $wallpapersEnabled,
                wallpapersSupported: wallpapersSupported,
                onOpenPatches: {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        tabNavigation.select(AppSection.patches.rawValue)
                    }
                }
            )
        case .files:
            AppDataBrowserView(
                tabSession: filesTabSession
            )
        case .patches:
            PatchProjectsView()
        case .cleaner:
            CleanerView()
        case .wallpapers:
            WallpaperLabView()
        }
    }

    private var tabSelection: Binding<Int> {
        Binding(
            get: { tabNavigation.selectedTab },
            set: { tabNavigation.select($0) }
        )
    }

    private var filesTabSession: Binding<FilesTabSession> {
        Binding(
            get: { tabNavigation.filesTabs },
            set: { tabNavigation.setFilesTabs($0) }
        )
    }

    private var featureVisibility: FeatureVisibility {
        FeatureVisibility(
            cleanerEnabled: cleanerEnabled,
            wallpapersEnabled: wallpapersEnabled,
            wallpapersSupported: wallpapersSupported
        )
    }

    private var wallpapersSupported: Bool {
        WallpaperFeatureSupportPolicy.isSupported(major: AppInfo.versionTuple.major)
    }

    private var selectedVisibleSection: AppSection {
        guard let section = AppSection(rawValue: tabNavigation.selectedTab),
              featureVisibility.isVisible(section) else {
            return .home
        }
        return section
    }
}

private struct CompactTabLabel: View {
    let title: String
    let systemImage: String

    @ViewBuilder
    var body: some View {
        if let image = UIImage(
            systemName: systemImage,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .medium)
        )?.withRenderingMode(.alwaysTemplate) {
            Image(uiImage: image)
        } else {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .medium))
        }
        Text(title)
    }
}

private extension AppSection {
    var titleKey: String {
        switch self {
        case .home: return "tab.home"
        case .files: return "tab.files"
        case .patches: return "tab.patches"
        case .cleaner: return "tab.cleaner"
        case .wallpapers: return "tab.wallpapers"
        }
    }

    var systemImage: String {
        switch self {
        case .home: return "house.fill"
        case .files: return "folder.fill"
        case .patches: return "shippingbox.fill"
        case .cleaner: return "sparkles"
        case .wallpapers: return "photo.on.rectangle.angled"
        }
    }
}

private struct DashboardView: View {
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var appState: AppState
    @State private var showSettings = false
    @State private var showLogs = false
    @Binding var cleanerEnabled: Bool
    @Binding var wallpapersEnabled: Bool
    let wallpapersSupported: Bool
    let onOpenPatches: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.pageBackground.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        heroPanel
                        patchPanel
                        devicePanel

                        if appState.kernelExploitApplicable && AppInfo.versionTuple.major < 26 {
                            kernelPanel
                        }
                    }
                    .padding(.horizontal, AppTheme.pageInset)
                    .padding(.top, 12)
                    .padding(.bottom, 34)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .tint(AppTheme.accent)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showLogs = true } label: {
                        Image(systemName: "apple.terminal")
                    }
                    .accessibilityLabel(language.text("accessibility.open_logs"))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel(language.text("accessibility.open_settings"))
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showLogs) { LogView() }
        }
    }

    private var heroPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 14) {
                AppLogo(size: 68)
                    .shadow(color: AppTheme.accent.opacity(0.45), radius: 18)

                VStack(alignment: .leading, spacing: 5) {
                    Text("greeg app")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    Text("Private patch control")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                HomeStatusPill(
                    title: appState.isSupported ? "Ready" : "Check",
                    color: appState.isSupported ? .green : AppTheme.accent
                )
            }

            Divider().overlay(Color.white.opacity(0.08))

            HStack(spacing: 0) {
                HomeStatBlock(value: "3", title: "Patches")
                HomeDivider()
                HomeStatBlock(value: "1", title: "Bundle")
                HomeDivider()
                HomeStatBlock(
                    value: appState.isSupported ? "Online" : "Limited",
                    title: "Status",
                    tint: appState.isSupported ? .green : AppTheme.accent
                )
            }
        }
        .greegPanel(padding: 18)
        .overlay(alignment: .topLeading) {
            LinearGradient(
                colors: [AppTheme.accent.opacity(0.18), .clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .allowsHitTesting(false)
        }
    }

    private var patchPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Patch Suite", systemImage: "shippingbox.fill")
                    .font(.headline)
                    .foregroundStyle(.white)

                Spacer()

                Text("3 ready")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(AppTheme.accent.opacity(0.13), in: Capsule())
            }

            VStack(spacing: 12) {
                HomeFeatureRow(
                    icon: "cube.box.fill",
                    title: "Asset Indexer",
                    subtitle: "Avatar bundle"
                )
                HomeFeatureRow(
                    icon: "camera.filters",
                    title: "Shaders",
                    subtitle: "Visual bundle"
                )
                HomeFeatureRow(
                    icon: "speedometer",
                    title: "144 fps",
                    subtitle: "Preferences file"
                )
            }

            Button(action: onOpenPatches) {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.right.circle.fill")
                    Text("Open Patches")
                        .fontWeight(.semibold)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .frame(height: 50)
                .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .greegPanel()
    }

    private var devicePanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(language.text("common.device"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.bottom, 10)

            HomeInfoRow(
                title: language.text("dashboard.hardware_model"),
                value: AppInfo.displayMachineName,
                monospaced: true
            )
            GreegRowDivider()
            HomeInfoRow(
                title: language.text("settings.ios_version"),
                value: "\(AppInfo.osVersion) (\(AppInfo.osBuild))",
                monospaced: true
            )
            GreegRowDivider()
            HomeInfoRow(
                title: language.text("settings.compatibility"),
                value: language.text(appState.isSupported ? "settings.supported" : "settings.unsupported"),
                valueColor: appState.isSupported ? .green : AppTheme.accent
            )
        }
        .greegPanel()
    }

    private var kernelPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(language.text("dashboard.exploit_access"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.bottom, 10)

            HStack(spacing: 10) {
                Image(systemName: "apple.terminal")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 28, height: 28)

                Text(language.text("dashboard.kernel_status"))
                    .foregroundStyle(.primary)

                Spacer()

                if appState.kernelExploitRunning {
                    ProgressView()
                        .controlSize(.small)
                    Text(language.text("dashboard.kernel_running"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text(language.text(appState.exploitStatus.isSuccess ? "dashboard.kernel_active" : "dashboard.kernel_inactive"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(appState.exploitStatus.isSuccess ? Color.green : Color.secondary)
                }
            }
        }
        .greegPanel()
    }
}

private struct HomeStatusPill: View {
    let title: String
    let color: Color

    var body: some View {
        Text(title)
            .font(.caption.weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.14), in: Capsule())
            .lineLimit(1)
    }
}

private struct HomeStatBlock: View {
    let value: String
    let title: String
    var tint: Color = .white

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct HomeDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(width: 1, height: 34)
    }
}

private struct HomeFeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            AppRowIcon(systemName: icon, symbolSize: 16, frameSize: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.green)
        }
    }
}

private struct HomeInfoRow: View {
    let title: String
    let value: String
    var valueColor: Color = Color.secondary
    var monospaced = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(title)
                .foregroundStyle(.primary)
            Spacer(minLength: 12)
            Text(value)
                .font(monospaced ? .body.monospaced() : .body)
                .foregroundStyle(valueColor)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .minimumScaleFactor(0.76)
        }
        .padding(.vertical, 10)
    }
}

private struct GreegRowDivider: View {
    var body: some View {
        Divider()
            .overlay(Color.white.opacity(0.08))
    }
}

private struct GreegPanelModifier: ViewModifier {
    let padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AppTheme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
            )
    }
}

private extension View {
    func greegPanel(padding: CGFloat = 16) -> some View {
        modifier(GreegPanelModifier(padding: padding))
    }
}
