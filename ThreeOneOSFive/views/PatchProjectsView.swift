import SwiftUI

struct PatchProjectsView: View {
    @Environment(\.appLanguage) private var language
    @StateObject private var store = PatchProjectStore()
    @State private var searchText = ""

    private var filteredItems: [PatchLibraryItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return store.items }
        return store.items.filter { item in
            if item.packageURL.lastPathComponent.localizedCaseInsensitiveContains(query) {
                return true
            }
            guard let project = item.project else { return false }
            return project.name.localizedCaseInsensitiveContains(query)
                || project.allBundleIdentifiers.contains {
                    $0.localizedCaseInsensitiveContains(query)
                }
                || project.rules.contains {
                    $0.relativePath.localizedCaseInsensitiveContains(query)
                        || $0.replacementFilename.localizedCaseInsensitiveContains(query)
                }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.pageBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    PatchListHeader(count: store.items.count)
                        .padding(.horizontal, AppTheme.pageInset)
                        .padding(.top, 8)
                        .padding(.bottom, 4)

                    AppSearchField(
                        text: $searchText,
                        prompt: language.text("patch.search"),
                        clearLabel: language.text("common.clear")
                    )

                    List {
                        if store.items.isEmpty && !store.isBusy {
                            emptyState
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                        } else if filteredItems.isEmpty && !store.isBusy {
                            searchEmptyState
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                        } else {
                            Section {
                                ForEach(filteredItems) { item in
                                    itemRow(item)
                                }
                            } header: {
                                Text("Built-in patches")
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle(language.text("patch.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if store.isBusy {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        ProgressView()
                    }
                }
            }
            .sheet(item: $store.passwordRequest, onDismiss: store.cancelUnlock) { _ in
                PatchUnlockView(store: store)
            }
            .alert(item: $store.alert) { alert in
                Alert(
                    title: Text(language.text(alert.titleKey)),
                    message: Text(alert.message(language: language)),
                    dismissButton: .default(Text(language.text("common.ok")))
                )
            }
            .onAppear {
                BundledPatchSeeder.seedIfNeeded()
                store.reload()
            }
        }
    }

    @ViewBuilder
    private func itemRow(_ item: PatchLibraryItem) -> some View {
        if item.isLocked {
            Button { store.requestUnlock(for: item) } label: {
                PatchProjectRow(item: item, language: language)
            }
            .buttonStyle(.plain)
        } else {
            NavigationLink {
                PatchProjectDetailView(store: store, projectID: item.id)
            } label: {
                PatchProjectRow(item: item, language: language)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "shippingbox")
                .font(.system(size: AppTheme.emptyIconSize, weight: .light))
                .foregroundStyle(AppTheme.accent)
            Text(language.text("patch.empty_title"))
                .font(.headline)
            Text(language.text("patch.bundled_missing_message"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 64)
    }

    private var searchEmptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: AppTheme.emptyIconSize, weight: .light))
                .foregroundStyle(.secondary)
            Text(language.text("patch.search_empty"))
                .font(.headline)
            Text(language.text("patch.search_empty_message"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 64)
    }
}

private struct PatchListHeader: View {
    let count: Int

    var body: some View {
        HStack(spacing: 14) {
            AppLogo(size: 46)
                .shadow(color: AppTheme.accent.opacity(0.35), radius: 12)

            VStack(alignment: .leading, spacing: 4) {
                Text("GREEG client")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                Text("Asset Indexer, Shaders, and 144 fps")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(count)")
                    .font(.title3.weight(.black))
                    .foregroundStyle(AppTheme.accent)
                Text(count == 1 ? "patch" : "patches")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(15)
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

private struct PatchProjectRow: View {
    let item: PatchLibraryItem
    let language: AppLanguage

    private var fileCount: Int {
        guard let project = item.project else { return 0 }
        return project.rules.count + project.directories.count
    }

    private var style: PatchVisualStyle {
        PatchVisualStyle(item: item)
    }

    var body: some View {
        HStack(spacing: 14) {
            PatchVisualIcon(style: style, size: 42, symbolSize: 18)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.project?.name ?? language.text("patch.locked_project"))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Text(item.isLocked ? language.text("patch.tap_to_unlock") : style.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 10)

            if item.summary.isPasswordProtected {
                Image(systemName: "key.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(language.text("patch.password_protected"))
            } else if !item.isLocked {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(fileCount)")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.primary)
                    Text(fileCount == 1 ? "file" : "files")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

private struct PatchUnlockView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: PatchProjectStore
    @State private var password = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField(language.text("patch.password"), text: $password)
                        .textContentType(.password)
                        .submitLabel(.done)
                        .onSubmit(unlock)
                        .onChange(of: password) { _ in
                            store.clearUnlockError()
                        }
                    if let errorKey = store.unlockErrorKey {
                        Text(language.text(errorKey))
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                } footer: {
                    Text(language.text("patch.password_once_message"))
                }
            }
            .navigationTitle(language.text("patch.unlock"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(language.text("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(language.text("patch.unlock"), action: unlock)
                        .disabled(password.isEmpty || store.isBusy)
                }
            }
        }
    }

    private func unlock() {
        guard !password.isEmpty else { return }
        store.unlock(password: password)
    }
}

private struct PatchProjectDetailView: View {
    @Environment(\.appLanguage) private var language
    @ObservedObject var store: PatchProjectStore
    let projectID: UUID
    @State private var isWorking = false
    @State private var showNameEditor = false
    @State private var actionAlert: PatchStoreAlert?

    private var item: PatchLibraryItem? {
        store.items.first(where: { $0.id == projectID })
    }

    private var receipt: PatchTransactionReceipt? {
        DevicePatchService.latestReceipt(projectID: projectID)
    }

    var body: some View {
        Group {
            if let item, let project = item.project {
                detailContent(project: project)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppTheme.pageBackground)
            }
        }
        .navigationTitle(item?.project?.name ?? language.text("patch.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isWorking {
                ToolbarItem(placement: .navigationBarTrailing) {
                    ProgressView()
                }
            } else {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(language.text("patch.edit_name")) {
                        showNameEditor = true
                    }
                    .disabled(item?.project == nil)
                }
            }
        }
        .sheet(isPresented: $showNameEditor) {
            if let project = item?.project {
                PatchNameEditorView(name: project.name) { newName in
                    rename(to: newName)
                }
            }
        }
        .alert(item: $actionAlert) { alert in
            Alert(
                title: Text(language.text(alert.titleKey)),
                message: Text(alert.message(language: language)),
                dismissButton: .default(Text(language.text("common.ok")))
            )
        }
    }

    private func detailContent(project: PatchProject) -> some View {
        let style = PatchVisualStyle(project: project)

        return ZStack {
            AppTheme.pageBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    detailHero(project: project, style: style)
                    targetPanel(project: project, style: style)
                    rulesPanel(project: project, style: style)
                    actionPanel()
                }
                .padding(.horizontal, AppTheme.pageInset)
                .padding(.top, 12)
                .padding(.bottom, 34)
            }
        }
    }

    private func detailHero(project: PatchProject, style: PatchVisualStyle) -> some View {
        HStack(spacing: 14) {
            PatchVisualIcon(style: style, size: 56, symbolSize: 23)

            VStack(alignment: .leading, spacing: 5) {
                Text(project.name)
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(style.detail)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text(project.rules.count == 1 ? "1 file" : "\(project.rules.count) files")
                .font(.caption.weight(.bold))
                .foregroundStyle(style.tint)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(style.tint.opacity(0.14), in: Capsule())
        }
        .greegPatchPanel(padding: 18)
    }

    private func targetPanel(project: PatchProject, style: PatchVisualStyle) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(language.text("patch.target_bundle"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.bottom, 10)

            ForEach(project.allBundleIdentifiers, id: \.self) { bundleID in
                HStack(spacing: 12) {
                    Image(systemName: "app.dashed")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(style.tint)
                        .frame(width: 30, height: 30)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(bundleID)
                            .font(.headline.monospaced())
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                        Text("Free Fire TH")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding(.vertical, 4)
            }
        }
        .greegPatchPanel()
    }

    private func rulesPanel(project: PatchProject, style: PatchVisualStyle) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(language.text("patch.rules"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            ForEach(project.rules) { rule in
                PatchRuleCard(rule: rule, style: style)
            }

            Text(language.text("patch.client_rules_footer"))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 2)
        }
        .greegPatchPanel()
    }

    private func actionPanel() -> some View {
        VStack(spacing: 12) {
            patchActionButton(
                title: language.text("patch.apply"),
                subtitle: "Write the selected preset",
                systemImage: "checkmark.shield.fill",
                tint: AppTheme.accent,
                action: apply
            )
            .disabled(isWorking)

            if receipt != nil {
                patchActionButton(
                    title: language.text("patch.restore"),
                    subtitle: "Bring back the saved original",
                    systemImage: "arrow.uturn.backward.circle.fill",
                    tint: Color.secondary,
                    action: restore
                )
                .disabled(isWorking)
            }

            Text(language.text("patch.apply_footer"))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func patchActionButton(
        title: String,
        subtitle: String,
        systemImage: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 13) {
                Image(systemName: systemImage)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.72))
                }

                Spacer()

                if isWorking {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.75))
                }
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 66)
            .background(tint, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func rename(to newName: String) {
        guard var project = item?.project else { return }
        project.name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        project.updatedAt = Date()
        do {
            try PatchPackageCodec.validate(project)
            store.update(project: project)
        } catch let error as PatchPackageError {
            actionAlert = PatchStoreAlert(
                titleKey: "common.failed",
                messageKey: error.localizationKey,
                messageArgument: error.localizationArgument
            )
        } catch {
            actionAlert = PatchStoreAlert(
                titleKey: "common.failed",
                messageKey: "patch.error.invalid_project"
            )
        }
    }

    private func apply() {
        guard let item, let project = item.project else { return }
        isWorking = true
        Task.detached(priority: .userInitiated) {
            do {
                _ = try DevicePatchService.apply(project: project)
                await MainActor.run {
                    store.reload()
                    isWorking = false
                    actionAlert = PatchStoreAlert(titleKey: "common.done", messageKey: "patch.applied_message")
                }
            } catch let error as PatchPackageError {
                await MainActor.run {
                    isWorking = false
                    actionAlert = PatchStoreAlert(
                        titleKey: "common.failed",
                        messageKey: error.localizationKey,
                        messageArgument: error.localizationArgument
                    )
                }
            } catch {
                await MainActor.run {
                    isWorking = false
                    actionAlert = PatchStoreAlert(titleKey: "common.failed", messageKey: "patch.error.apply")
                }
            }
        }
    }

    private func restore() {
        guard let receipt else { return }
        isWorking = true
        Task.detached(priority: .userInitiated) {
            do {
                try DevicePatchService.restore(receipt: receipt)
                await MainActor.run {
                    isWorking = false
                    actionAlert = PatchStoreAlert(titleKey: "common.done", messageKey: "patch.restored_message")
                }
            } catch let error as PatchPackageError {
                await MainActor.run {
                    isWorking = false
                    actionAlert = PatchStoreAlert(
                        titleKey: "common.failed",
                        messageKey: error.localizationKey,
                        messageArgument: error.localizationArgument
                    )
                }
            } catch {
                await MainActor.run {
                    isWorking = false
                    actionAlert = PatchStoreAlert(titleKey: "common.failed", messageKey: "patch.error.restore")
                }
            }
        }
    }
}

private struct PatchRuleCard: View {
    let rule: PatchRule
    let style: PatchVisualStyle

    private var targetFilename: String {
        rule.relativePath.components(separatedBy: "/").last ?? rule.relativePath
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(style.tint)
                    .frame(width: 30, height: 30)
                    .background(style.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    Text(targetFilename)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Text(rule.relativePath)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "doc.fill")
                    .font(.caption)
                    .foregroundStyle(style.tint)
                Text(rule.replacementFilename)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(style.tint)
                    .lineLimit(2)
            }
            .padding(.leading, 42)
        }
        .padding(12)
        .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct PatchVisualIcon: View {
    let style: PatchVisualStyle
    let size: CGFloat
    let symbolSize: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(style.tint.opacity(0.14))
            Image(systemName: style.icon)
                .font(.system(size: symbolSize, weight: .semibold))
                .foregroundStyle(style.tint)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

private struct PatchVisualStyle {
    let icon: String
    let tint: Color
    let subtitle: String
    let detail: String

    init(item: PatchLibraryItem) {
        if let project = item.project {
            self.init(project: project)
        } else {
            icon = "lock.doc.fill"
            tint = Color.secondary
            subtitle = "Locked preset"
            detail = "Password protected"
        }
    }

    init(project: PatchProject) {
        let searchable = ([project.name] + project.rules.flatMap {
            [$0.relativePath, $0.replacementFilename]
        })
        .joined(separator: " ")
        .lowercased()

        if searchable.contains("plist") || searchable.contains("144") {
            icon = "speedometer"
            tint = .green
            subtitle = "FPS preferences"
            detail = "Library preferences"
        } else if searchable.contains("shader") {
            icon = "sparkles"
            tint = Color(red: 0.26, green: 0.72, blue: 1.0)
            subtitle = "Shader bundle"
            detail = "Optional visual content"
        } else {
            icon = "shippingbox.fill"
            tint = AppTheme.accent
            subtitle = "Avatar asset bundle"
            detail = "Compulsory avatar content"
        }
    }
}

private struct PatchNameEditorView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    let onSave: (String) -> Void

    init(name: String, onSave: @escaping (String) -> Void) {
        _name = State(initialValue: name)
        self.onSave = onSave
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(language.text("patch.project")) {
                    TextField(language.text("patch.project_name"), text: $name)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .onSubmit(save)
                }
            }
            .navigationTitle(language.text("patch.edit_name"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(language.text("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(language.text("common.done"), action: save)
                        .fontWeight(.semibold)
                        .disabled(trimmedName.isEmpty)
                }
            }
        }
    }

    private func save() {
        guard !trimmedName.isEmpty else { return }
        onSave(trimmedName)
        dismiss()
    }
}

private struct GreegPatchPanelModifier: ViewModifier {
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
    func greegPatchPanel(padding: CGFloat = 16) -> some View {
        modifier(GreegPatchPanelModifier(padding: padding))
    }
}
