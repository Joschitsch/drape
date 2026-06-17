//
//  DebugDatasetFolderSource.swift
//  drape
//
//  DEBUG-ONLY. Reads a folder of real garment images into DebugImageItems for the
//  importer. Built for the layout of permissive datasets like
//  alexeygrigorev/clothing-dataset-small (CC0):
//
//      <root>/{train,validation,test}/<class>/<image>.jpg
//
//  The class folder name becomes the ground-truth category (via DatasetLabelMap);
//  the split folder maps to dev (train) vs holdout (validation/test). Also accepts
//  a flat <root>/<class>/<image> layout. Reads a per-class sample so an import
//  stays interactive; raise the cap for a full accuracy run.
//

#if DEBUG
import Foundation

@MainActor
enum DebugDatasetFolderSource {
    static let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "heic"]

    /// Loads up to `perClassLimit` images per class, deterministically (folders and
    /// files are sorted). `datasetID` scopes splits/metrics; "train" → dev,
    /// "validation"/"test" → holdout. Returns [] if the directory is unreadable.
    static func load(directory: URL, datasetID: String, perClassLimit: Int = 20) -> [DebugImageItem] {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: directory.path, isDirectory: &isDir), isDir.boolValue else { return [] }

        let splitDirs = ["train", "validation", "test"].compactMap { name -> (URL, DebugSplit)? in
            let url = directory.appendingPathComponent(name)
            guard fm.fileExists(atPath: url.path) else { return nil }
            return (url, name == "train" ? .dev : .holdout)
        }

        var items: [DebugImageItem] = []
        if splitDirs.isEmpty {
            // Flat <root>/<class>/<image> layout — hash decides the split.
            items += classItems(in: directory, datasetID: datasetID, splitLabel: "", split: nil, perClassLimit: perClassLimit, fm: fm)
        } else {
            for (url, split) in splitDirs {
                items += classItems(in: url, datasetID: datasetID, splitLabel: url.lastPathComponent,
                                    split: split, perClassLimit: perClassLimit, fm: fm)
            }
        }
        return items.sorted { $0.id < $1.id }
    }

    private static func classItems(
        in dir: URL, datasetID: String, splitLabel: String, split: DebugSplit?,
        perClassLimit: Int, fm: FileManager
    ) -> [DebugImageItem] {
        let classDirs = (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.isDirectoryKey]))?
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .sorted { $0.lastPathComponent < $1.lastPathComponent } ?? []

        var items: [DebugImageItem] = []
        for classDir in classDirs {
            let className = classDir.lastPathComponent
            let category = DatasetLabelMap.category(forArticleType: className)
            let images = ((try? fm.contentsOfDirectory(at: classDir, includingPropertiesForKeys: nil)) ?? [])
                .filter { imageExtensions.contains($0.pathExtension.lowercased()) }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
                .prefix(perClassLimit)

            for url in images {
                guard let data = try? Data(contentsOf: url) else { continue }
                let id = [splitLabel, className, url.lastPathComponent]
                    .filter { !$0.isEmpty }.joined(separator: "/")
                items.append(DebugImageItem(
                    id: id,
                    imageData: data,
                    groundTruth: DebugGroundTruth(datasetID: datasetID, rawCategory: className, category: category),
                    split: split))
            }
        }
        return items
    }
}
#endif
