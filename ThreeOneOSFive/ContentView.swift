import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject private var patchDraftCoordinator: PatchDraftCoordinator
    @State private var tabNavigation = AppTabNavigationState()

    var body: some View {
        TabView(selection: tabSelection) {
            GreegHomeView {
                withAnimation(.easeInOut(duration: 0.18)) {
                    tabNavigation.select(AppSection.archivos.rawValue)
                }
            }
            .tabItem { CompactTabLabel(title: "Inicio", systemImage: "house.fill") }
            .tag(AppSection.home.rawValue)

            GreegPatchLibraryView()
                .tabItem { CompactTabLabel(title: "Archivos", systemImage: "shippingbox.fill") }
                .tag(AppSection.archivos.rawValue)

            GreegSocialView()
                .tabItem { CompactTabLabel(title: "Redes", systemImage: "link.circle.fill") }
                .tag(AppSection.redes.rawValue)
        }
        .tint(AppTheme.accent)
        .imageScale(.small)
        .onChange(of: patchDraftCoordinator.request?.id) { requestID in
            if requestID != nil { tabNavigation.select(AppSection.archivos.rawValue) }
        }
        .onChange(of: patchDraftCoordinator.importRequest?.id) { requestID in
            if requestID != nil { tabNavigation.select(AppSection.archivos.rawValue) }
        }
    }

    private var tabSelection: Binding<Int> {
        Binding(
            get: { tabNavigation.selectedTab },
            set: { tabNavigation.select($0) }
        )
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

private struct GreegHomeView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var remoteContentStore: RemoteContentStore
    let onOpenFiles: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    heroCard
                    sectionTitle("ARCHIVOS PRINCIPALES")
                    mainFilesCard
                    sectionTitle("ACTUALIZACIONES")
                    updatesCard
                    sectionTitle("REDES")
                    compactSocialCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 36)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { remoteContentStore.loadLocalState() }
        }
    }

    private var heroCard: some View {
        GreegPanel {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 16) {
                    AppLogo(size: 58)
                        .shadow(color: AppTheme.accent.opacity(0.32), radius: 12)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("GREEG APP")
                            .font(.system(size: 27, weight: .black, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.68)
                        Text("Control privado")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 8)

                    Label(appState.isSupported ? "Listo" : "Revisar", systemImage: appState.isSupported ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .font(.subheadline.weight(.black))
                        .foregroundColor(appState.isSupported ? .green : AppTheme.accent)
                        .labelStyle(.titleAndIcon)
                }

                Divider().overlay(Color.white.opacity(0.08))

                HStack(spacing: 0) {
                    HomeMetric(value: "AIM", title: "Archivos")
                    HomeMetric(value: "FF", title: "Destino")
                    HomeMetric(value: appState.isSupported ? "OK" : "WAIT", title: "Estado")
                }
            }
        }
    }

    private var mainFilesCard: some View {
        GreegPanel {
            VStack(spacing: 11) {
                Button(action: onOpenFiles) {
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.title3.weight(.black))
                        Text("Abrir archivos")
                            .font(.headline.weight(.black))
                        Spacer()
                    }
                    .foregroundStyle(AppTheme.accent)
                }
                .buttonStyle(.plain)

                Divider().overlay(Color.white.opacity(0.08))

                HomePatchRow(icon: "scope", title: "Aimbot Drag", subtitle: "Archivo de avatar")
                HomePatchRow(icon: "link.circle", title: "Aimbot Cuello", subtitle: "Preset integrado")
                HomePatchRow(icon: "target", title: "Aimbot Pecho", subtitle: "Listo para aplicar")
            }
        }
    }

    private var updatesCard: some View {
        GreegPanel {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    AppRowIcon(
                        systemName: remoteContentStore.isBusy ? "arrow.triangle.2.circlepath" : "icloud.fill",
                        tint: Color(red: 0.27, green: 0.71, blue: 1),
                        symbolSize: 16,
                        frameSize: 38
                    )
                    VStack(alignment: .leading, spacing: 3) {
                        Text(remoteContentStore.installedFiles.isEmpty ? "Sincronizar archivos" : "Archivos actualizados")
                            .font(.title3.weight(.black))
                        Text(remoteContentStore.detailText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("v\(remoteContentStore.remoteVersion)")
                            .font(.headline.weight(.black))
                            .foregroundColor(AppTheme.accent)
                        Text("\(remoteContentStore.installedFiles.count) files")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                Button {
                    BundledPatchSeeder.seedIfNeeded()
                    remoteContentStore.syncIfPossible(force: true)
                } label: {
                    Label(remoteContentStore.isBusy ? "Sincronizando" : "Sincronizar archivos", systemImage: "arrow.clockwise.circle.fill")
                        .font(.title3.weight(.black))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 14))
                .disabled(remoteContentStore.isBusy)

                if let progress = remoteContentStore.progress, remoteContentStore.isBusy {
                    ProgressView(value: progress)
                        .tint(AppTheme.accent)
                }
            }
        }
    }

    private var compactSocialCard: some View {
        GreegPanel {
            Link(destination: GreegSocialLink.tiktok.url) {
                SocialRow(link: .tiktok)
            }
        }
    }

    private func sectionTitle(_ value: String) -> some View {
        Text(value)
            .font(.caption.weight(.black))
            .foregroundStyle(.secondary)
            .tracking(1.2)
            .padding(.leading, 4)
    }
}

private struct GreegPatchLibraryView: View {
    @EnvironmentObject private var store: PatchProjectStore

    private var visibleItems: [PatchLibraryItem] {
        store.items
            .filter { item in
                guard let name = item.project?.name else { return false }
                return !name.localizedCaseInsensitiveContains("only esp")
                    && !name.localizedCaseInsensitiveContains("wallpaper")
            }
            .sorted { left, right in
                let leftRank = BundledPatchSeeder.sortRank(for: left.id)
                let rightRank = BundledPatchSeeder.sortRank(for: right.id)
                if leftRank != rightRank { return leftRank < rightRank }
                return (left.project?.name ?? "").localizedCaseInsensitiveCompare(right.project?.name ?? "") == .orderedAscending
            }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    headerCard

                    if visibleItems.isEmpty {
                        emptyCard
                    } else {
                        VStack(spacing: 10) {
                            ForEach(visibleItems) { item in
                                NavigationLink {
                                    GreegPatchDetailView(projectID: item.id)
                                } label: {
                                    GreegPatchRow(item: item)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 36)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Archivos")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear(perform: reloadPrivatePatches)
        }
    }

    private var headerCard: some View {
        GreegPanel {
            HStack(spacing: 12) {
                AppLogo(size: 48)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Centro GREEG")
                        .font(.title2.weight(.black))
                    Text("\(visibleItems.count) archivos privados")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "checkmark.seal.fill")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.green)
            }
        }
    }

    private var emptyCard: some View {
        GreegPanel {
            VStack(spacing: 13) {
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(AppTheme.accent)
                Text("Preparando archivos")
                    .font(.title3.weight(.black))
                Text("Toca actualizar en Inicio y vuelve aqui si todavia no aparecen.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Recargar") {
                    reloadPrivatePatches()
                }
                .font(.headline.weight(.bold))
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 14))
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func reloadPrivatePatches() {
        BundledPatchSeeder.seedIfNeeded()
        store.reload()
    }
}

private struct GreegPatchRow: View {
    let item: PatchLibraryItem

    private var project: PatchProject? { item.project }
    private var isApplied: Bool { DevicePatchService.latestReceipt(projectID: item.id) != nil }

    var body: some View {
        GreegPanel {
            HStack(spacing: 13) {
                AppRowIcon(
                    systemName: iconName,
                    tint: iconTint,
                    symbolSize: 17,
                    frameSize: 42
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text(project?.name ?? "Archivo GREEG")
                        .font(.headline.weight(.black))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Text(isApplied ? "Activo" : "Listo para aplicar")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Image(systemName: isApplied ? "checkmark.seal.fill" : "chevron.right")
                    .font(.headline.weight(.black))
                    .foregroundStyle(isApplied ? .green : AppTheme.accent)
            }
        }
    }

    private var iconName: String {
        let name = (project?.name ?? "Archivo GREEG").lowercased()
        if name.contains("holo") || name.contains("visual") || name.contains("shader") {
            return "sparkles"
        }
        if name.contains("fps") {
            return "speedometer"
        }
        if name.contains("cuello") {
            return "link.circle.fill"
        }
        if name.contains("pecho") {
            return "target"
        }
        return "shippingbox.fill"
    }

    private var iconTint: Color {
        iconName == "sparkles" ? Color(red: 0.27, green: 0.71, blue: 1) : AppTheme.accent
    }
}

private struct GreegPatchDetailView: View {
    @EnvironmentObject private var store: PatchProjectStore
    let projectID: UUID
    @State private var isWorking = false
    @State private var actionAlert: GreegPatchActionAlert?

    private var item: PatchLibraryItem? {
        store.items.first(where: { $0.id == projectID })
    }

    private var project: PatchProject? {
        item?.project
    }

    private var receipt: PatchTransactionReceipt? {
        DevicePatchService.latestReceipt(projectID: projectID)
    }

    private var isApplied: Bool {
        receipt != nil
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                statusCard

                Link(destination: GreegSocialLink.tiktok.url) {
                    GreegPanel {
                        SocialRow(link: .tiktok)
                    }
                }

                actionButton(
                    title: isWorking ? "Aplicando" : "Aplicar",
                    subtitle: "Activar archivo",
                    systemImage: "checkmark.shield.fill",
                    isPrimary: true,
                    isDisabled: isWorking || isApplied,
                    action: apply
                )

                actionButton(
                    title: isWorking ? "Restaurando" : "Original",
                    subtitle: "Volver al original",
                    systemImage: "arrow.counterclockwise.circle.fill",
                    isPrimary: false,
                    isDisabled: isWorking || !isApplied,
                    action: restore
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 36)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle(project?.name ?? "Archivo")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            BundledPatchSeeder.seedIfNeeded()
            store.reload()
        }
        .alert(item: $actionAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private var statusCard: some View {
        GreegPanel {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 14) {
                    AppRowIcon(systemName: "shippingbox.fill", tint: AppTheme.accent, symbolSize: 18, frameSize: 46)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(project?.name ?? "Archivo GREEG")
                            .font(.system(size: 30, weight: .black, design: .rounded))
                            .lineLimit(2)
                            .minimumScaleFactor(0.75)
                        Text("Control privado")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                }

                HStack {
                    Label(isApplied ? "Activo" : "Listo", systemImage: isApplied ? "checkmark.seal.fill" : "circle.dotted")
                        .font(.title3.weight(.black))
                        .foregroundStyle(isApplied ? .green : AppTheme.accent)
                    Spacer()
                    Text(isApplied ? "ON" : "OK")
                        .font(.title3.weight(.black))
                        .foregroundStyle(isApplied ? .green : AppTheme.accent)
                }
                .padding(.horizontal, 14)
                .frame(height: 58)
                .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    private func actionButton(
        title: String,
        subtitle: String,
        systemImage: String,
        isPrimary: Bool,
        isDisabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.title2.weight(.black))
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.title2.weight(.black))
                    Text(subtitle)
                        .font(.subheadline.weight(.bold))
                        .opacity(0.82)
                }
                Spacer()
                if isWorking {
                    ProgressView()
                        .tint(.white)
                }
            }
            .foregroundColor(isPrimary ? .white : .secondary)
            .padding(.horizontal, 18)
            .frame(height: 72)
            .background(
                RoundedRectangle(cornerRadius: 19, style: .continuous)
                    .fill(isPrimary ? AppTheme.accent : Color(red: 0.07, green: 0.065, blue: 0.075))
                    .overlay(
                        RoundedRectangle(cornerRadius: 19, style: .continuous)
                            .stroke(AppTheme.accent.opacity(isPrimary ? 0 : 0.2), lineWidth: 1)
                    )
            )
            .opacity(isDisabled ? 0.55 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }

    private func apply() {
        guard let item, let baseProject = item.project else { return }
        isWorking = true
        Task.detached(priority: .userInitiated) {
            do {
                let project = item.summary.schemaVersion >= 2 && item.canInspectContents
                    ? try PatchProjectLibrary.synchronizeWorkspace(item: item)
                    : baseProject
                _ = try DevicePatchService.apply(project: project)
                await MainActor.run {
                    store.reload()
                    isWorking = false
                    actionAlert = GreegPatchActionAlert(title: "Listo", message: "Archivo aplicado correctamente.")
                }
            } catch let error as PatchPackageError {
                await MainActor.run {
                    isWorking = false
                    actionAlert = GreegPatchActionAlert(title: "Failed", message: message(for: error))
                }
            } catch {
                await MainActor.run {
                    isWorking = false
                    actionAlert = GreegPatchActionAlert(title: "Failed", message: "No se pudo aplicar el archivo.")
                }
            }
        }
    }

    private func restore() {
        guard let receipt else { return }
        isWorking = true
        Task.detached(priority: .userInitiated) {
            do {
                try DevicePatchService.restore(receipt: receipt, allowChangedTargets: true)
                await MainActor.run {
                    store.reload()
                    isWorking = false
                    actionAlert = GreegPatchActionAlert(title: "Listo", message: "Archivo original restaurado.")
                }
            } catch let error as PatchPackageError {
                await MainActor.run {
                    isWorking = false
                    actionAlert = GreegPatchActionAlert(title: "Failed", message: message(for: error))
                }
            } catch {
                await MainActor.run {
                    isWorking = false
                    actionAlert = GreegPatchActionAlert(title: "Failed", message: "No se pudo restaurar el original.")
                }
            }
        }
    }

    private func message(for error: PatchPackageError) -> String {
        switch error {
        case .targetAppUnavailable(let bundleID):
            return "La app destino no esta instalada o no se puede abrir: \(bundleID)."
        case .projectAlreadyApplied:
            return "Este archivo ya esta activo. Usa Original si quieres volver atras."
        default:
            return error.localizedDescription
        }
    }
}

private struct GreegPatchActionAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

private struct GreegSocialView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Redes oficiales")
                            .font(.system(size: 40, weight: .black, design: .rounded))
                        Text("Canales de soporte, comunidad y actualizaciones de GREEG APP.")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 34)

                    GreegPanel {
                        Link(destination: GreegSocialLink.tiktok.url) {
                            SocialRow(link: .tiktok)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 36)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Redes")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private enum GreegSocialLink {
    case tiktok

    var title: String { "TikTok" }
    var subtitle: String { "@gregg_top" }
    var systemImage: String { "play.rectangle.fill" }
    var url: URL {
        URL(string: "https://www.tiktok.com/@gregg_top?is_from_webapp=1&sender_device=pc")!
    }
}

private struct SocialRow: View {
    let link: GreegSocialLink

    var body: some View {
        HStack(spacing: 16) {
            AppRowIcon(systemName: link.systemImage, tint: AppTheme.accent, symbolSize: 17, frameSize: 42)
            VStack(alignment: .leading, spacing: 2) {
                Text(link.title)
                    .font(.title2.weight(.black))
                    .foregroundStyle(AppTheme.accent)
                Text(link.subtitle)
                    .font(.headline)
                    .foregroundStyle(AppTheme.accent.opacity(0.72))
            }
            Spacer()
            Image(systemName: "arrow.up.right")
                .font(.headline.weight(.black))
                .foregroundStyle(AppTheme.accent.opacity(0.8))
        }
        .contentShape(Rectangle())
    }
}

private struct GreegPanel<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(red: 0.09, green: 0.085, blue: 0.095))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(AppTheme.accent.opacity(0.28), lineWidth: 1)
                    )
            )
    }
}

private struct HomePatchRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            AppRowIcon(systemName: icon, tint: AppTheme.accent, symbolSize: 16, frameSize: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.headline.weight(.bold))
                .foregroundColor(.green)
        }
    }
}

private struct HomeMetric: View {
    let value: String
    let title: String

    var body: some View {
        VStack(spacing: 5) {
            Text(value)
                .font(.title2.weight(.black))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}
