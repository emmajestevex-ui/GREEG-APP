import Foundation

enum BundledPatchSeeder {

    // MARK: - Legacy bundled projects

    // Estos proyectos antes venían integrados dentro de la IPA.
    // Ahora el PANEL / SUPABASE será la única fuente de contenido.
    //
    // Conservamos los UUID únicamente para poder limpiar instalaciones
    // antiguas que todavía tengan estos proyectos guardados localmente.

    private static let retiredBundledProjectIDs: Set<UUID> = [
        UUID(uuidString: "A55E0001-3105-4A55-9001-00000000BEEF")!, // Asset Indexer
        UUID(uuidString: "A55E0003-3105-4A55-9001-00000000BEEF")!, // Shaders
        UUID(uuidString: "A55E0002-0144-4A55-9001-00000000BEEF")!, // 144 fps
        UUID(uuidString: "A55E0004-3105-4A55-9001-00000000BEEF")!  // TIO GREEG
    ]

    // Nombres antiguos conocidos.
    // Se usan como respaldo durante la limpieza de instalaciones viejas.
    private static let retiredBundledNames: Set<String> = [
        "asset indexer",
        "asse",
        "shaders",
        "144 fps",
        "tio greeg"
    ]

    // MARK: - Public API

    // Ya NO existen proyectos obligatorios integrados en la IPA.
    //
    // Todo debe venir del manifiesto remoto publicado desde el panel.
    static var projectIDs: Set<UUID> {
        []
    }

    // Como ya no hay proyectos bundled que ordenar,
    // todos los proyectos normales quedan fuera de este ranking especial.
    static func sortRank(for id: UUID) -> Int {
        Int.max
    }

    // Esta función se mantiene porque RemoteContentSyncService
    // todavía llama BundledPatchSeeder.seedIfNeeded().
    //
    // Pero ahora NO crea archivos.
    // Su única función es limpiar los proyectos antiguos integrados
    // por versiones anteriores de GREEG APP.
    static func seedIfNeeded(
        fileManager: FileManager = .default
    ) {

        cleanupRetiredBundledProjects(
            fileManager: fileManager
        )
    }

    // MARK: - Cleanup

    private static func cleanupRetiredBundledProjects(
        fileManager: FileManager
    ) {

        let items = PatchProjectLibrary.load(
            fileManager: fileManager
        )

        var removedCount = 0

        for item in items {

            let project = item.project

            let normalizedName = project.name
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()

            let matchesOldID =
                retiredBundledProjectIDs.contains(project.id)

            let matchesOldName =
                retiredBundledNames.contains(normalizedName)

            // Preferimos el UUID como identificación principal.
            //
            // El nombre queda como respaldo para versiones antiguas
            // donde pudiera haberse guardado uno de estos proyectos
            // con información legacy.
            guard matchesOldID || matchesOldName else {
                continue
            }

            do {

                // Eliminar el paquete guardado.
                try PatchProjectLibrary.delete(
                    item,
                    fileManager: fileManager
                )

                // Eliminar también cualquier workspace asociado.
                try? PatchWorkspaceService.deleteWorkspace(
                    projectID: project.id,
                    fileManager: fileManager
                )

                removedCount += 1

                log(
                    "patch cleanup: eliminado proyecto bundled antiguo: " +
                    "\(project.name); id=\(project.id.uuidString)"
                )

            } catch {

                log(
                    "patch cleanup: ERROR eliminando " +
                    "\(project.name): \(error.localizedDescription)"
                )
            }
        }

        if removedCount > 0 {

            log(
                "patch cleanup: \(removedCount) proyecto(s) bundled antiguo(s) eliminado(s)"
            )

        } else {

            log(
                "patch cleanup: no quedan proyectos bundled antiguos"
            )
        }
    }
}
