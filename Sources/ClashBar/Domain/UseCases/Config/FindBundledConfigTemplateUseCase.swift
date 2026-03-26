import Foundation

struct FindBundledConfigTemplateUseCase {
    private let candidateRelativePaths = [
        "ConfigTemplates/ClashBar.yaml",
        "Resources/ConfigTemplates/ClashBar.yaml",
        "ClashBar.yaml",
    ]

    func execute(
        resourceRoots: [URL],
        fileManager: FileManager = .default) -> URL?
    {
        for root in resourceRoots {
            for relativePath in self.candidateRelativePaths {
                let candidate = root.appendingPathComponent(relativePath, isDirectory: false)
                if fileManager.fileExists(atPath: candidate.path) {
                    return candidate
                }
            }
        }

        return nil
    }
}
