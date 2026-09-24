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

            PatchProjectsView()
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
                VStack(alignment: .leading, spacing: 22) {
                    heroCard
                    sectionTitle("ARCHIVOS PRINCIPALES")
                    mainFilesCard
                    sectionTitle("ACTUALIZACIONES")
                    updatesCard
                    sectionTitle("REDES")
                    compactSocialCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 36)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { remoteContentStore.loadLocalState() }
        }
    }

    private var heroCard: some View {
        GreegPanel {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 16) {
                    AppLogo(size: 76)
                        .shadow(color: AppTheme.accent.opacity(0.35), radius: 16)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("GREEG APP")
                            .font(.system(size: 34, weight: .black, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                        Text("Control privado\nde archivos")
                            .font(.title3.weight(.medium))
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 8)

                    Label(appState.isSupported ? "Listo" : "Revisar", systemImage: appState.isSupported ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .font(.headline.weight(.bold))
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
            Button(action: onOpenFiles) {
                Label("Abrir centro de archivos", systemImage: "arrow.right.circle.fill")
                    .font(.title2.weight(.black))
                    .foregroundStyle(AppTheme.accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            VStack(spacing: 13) {
                HomePatchRow(icon: "scope", title: "Aimbot Drag", subtitle: "Archivo de avatar")
                HomePatchRow(icon: "link.circle", title: "Aimbot Cuello", subtitle: "Preset integrado")
                HomePatchRow(icon: "target", title: "Aimbot Pecho", subtitle: "Listo para aplicar")
            }
            .padding(.top, 8)
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
            .font(.headline.weight(.black))
            .foregroundStyle(.secondary)
            .tracking(1.5)
            .padding(.leading, 4)
    }
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
            .padding(22)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Color(red: 0.09, green: 0.085, blue: 0.095))
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
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
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.title2.weight(.bold))
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
                .font(.title.weight(.black))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}
