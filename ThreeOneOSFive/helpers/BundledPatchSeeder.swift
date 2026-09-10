import Foundation

enum BundledPatchSeeder {
    private struct ProjectSpec {
        let id: UUID
        let defaultName: String
        let payloads: [PayloadSpec]
    }

    private struct PayloadSpec {
        let directory: String
        let filenameCandidates: [String]
    }

    private enum SeedError: Error {
        case missingPayload(String)
        case emptyPayload(String)
    }

    private static let bundleID = "com.dts.freefireth"
    private static let payloadDirectoryName = "BundledPatchPayloads"
    private static let seedDate = Date(timeIntervalSince1970: 0)

    private static let projects = [
        ProjectSpec(
            id: UUID(uuidString: "A55E0001-3105-4A55-9001-00000000BEEF")!,
            defaultName: "asse",
            payloads: [
                PayloadSpec(
                    directory: "Documents/contentcache/Compulsory/ios/gameassetbundles/avatar",
                    filenameCandidates: [
                        "assetindexer.H5ak1JM1Eck~2FxRcJrEp~2FMzeuqmY~3D"
                    ]
                ),
                PayloadSpec(
                    directory: "Documents/contentcache/Optional/ios/gameassetbundles",
                    filenameCandidates: [
                        "shaders.HPt9DZviTSXL9hpGW9QNOMigNLA~3D",
                        "shaders.HPt9DZviTSXL9hpGW9QNOMig-NLA~3D"
                    ]
                )
            ]
        ),
        ProjectSpec(
            id: UUID(uuidString: "A55E0002-0144-4A55-9001-00000000BEEF")!,
            defaultName: "144 fps",
            payloads: [
                PayloadSpec(
                    directory: "Library/Preferences",
                    filenameCandidates: [
                        "com.dts.freefireth.plist"
                    ]
                )
            ]
        )
    ]

    static let projectIDs = Set(projects.map { $0.id })

    static func seedIfNeeded(fileManager: FileManager = .default) {
        for spec in projects {
            do {
                try seed(spec, fileManager: fileManager)
                log("patch: bundled GREEG patch \(spec.defaultName) is ready")
            } catch SeedError.missingPayload(let filename) {
                log("patch: bundled payload missing for \(spec.defaultName): \(filename)")
            } catch SeedError.emptyPayload(let filename) {
                log("patch: bundled payload is empty for \(spec.defaultName): \(filename)")
            } catch {
                log("patch: bundled patch \(spec.defaultName) could not be prepared: \(error.localizedDescription)")
            }
        }
    }

    private static func seed(_ spec: ProjectSpec, fileManager: FileManager) throws {
        let existingItem = PatchProjectLibrary.load(fileManager: fileManager)
            .first { $0.id == spec.id }
        let project = try makeProject(
            spec,
            existingProject: existingItem?.project,
            fileManager: fileManager
        )

        if let existingItem {
            try refreshExistingPackage(existingItem, with: project, fileManager: fileManager)
        } else {
            let encoded = try PatchPackageCodec.encodeLegacyV1(project: project, password: nil)
            _ = try PatchProjectLibrary.save(
                data: encoded.data,
                projectName: project.name,
                fileManager: fileManager
            )
        }

        try? PatchWorkspaceService.deleteWorkspace(projectID: spec.id, fileManager: fileManager)
    }

    private static func makeProject(
        _ spec: ProjectSpec,
        existingProject: PatchProject?,
        fileManager: FileManager
    ) throws -> PatchProject {
        let rules = try spec.payloads.map { payload in
            try makeRule(payload, fileManager: fileManager)
        }
        let existingName = existingProject?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let name = existingName.isEmpty ? spec.defaultName : existingName

        return PatchProject(
            id: spec.id,
            name: name,
            createdAt: existingProject?.createdAt ?? seedDate,
            updatedAt: existingProject?.updatedAt ?? seedDate,
            bundleIdentifiers: [bundleID],
            directories: [],
            rules: rules
        )
    }

    private static func makeRule(_ spec: PayloadSpec, fileManager: FileManager) throws -> PatchRule {
        let payloadURL = try payloadURL(for: spec, fileManager: fileManager)
        let data = try Data(contentsOf: payloadURL, options: .mappedIfSafe)
        guard !data.isEmpty else { throw SeedError.emptyPayload(payloadURL.lastPathComponent) }

        return PatchRule(
            bundleID: bundleID,
            relativePath: spec.directory + "/" + payloadURL.lastPathComponent,
            replacementFilename: payloadURL.lastPathComponent,
            replacementData: data
        )
    }

    private static func payloadURL(for spec: PayloadSpec, fileManager: FileManager) throws -> URL {
        guard let payloadRoot = Bundle.main.url(
            forResource: payloadDirectoryName,
            withExtension: nil
        ) else {
            throw SeedError.missingPayload(spec.filenameCandidates[0])
        }

        for filename in spec.filenameCandidates {
            let candidate = payloadRoot.appendingPathComponent(filename, isDirectory: false)
            if fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
        }

        throw SeedError.missingPayload(spec.filenameCandidates[0])
    }

    private static func refreshExistingPackage(
        _ item: PatchLibraryItem,
        with project: PatchProject,
        fileManager: FileManager
    ) throws {
        guard let contentKey = item.contentKey else {
            try PatchProjectLibrary.delete(item, fileManager: fileManager)
            let encoded = try PatchPackageCodec.encodeLegacyV1(project: project, password: nil)
            _ = try PatchProjectLibrary.save(
                data: encoded.data,
                projectName: project.name,
                fileManager: fileManager
            )
            return
        }

        if item.project == project { return }

        let original = try PatchProjectLibrary.readPackage(at: item.packageURL)
        let updated = try PatchPackageCodec.update(
            original,
            project: project,
            contentKey: contentKey,
            schemaVersion: 1
        )
        _ = try PatchProjectLibrary.save(
            data: updated,
            projectName: project.name,
            existingURL: item.packageURL,
            fileManager: fileManager
        )
    }
}
