//
//  ReceiptStore.swift
//  ExpenseTracker
//
//  File-on-disk storage for receipt images. Images live in the App Group
//  shared container so future widgets / extensions can access them too.
//  SwiftData models only store the filename string; the bytes never enter
//  the database.
//

import Foundation
import UIKit

enum ReceiptStore {

    /// Directory holding all receipts. Created on first access.
    /// Returns nil if the App Group container isn't available.
    static func receiptsDirectory() -> URL? {
        guard let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: ModelContainerFactory.appGroupID
        ) else {
            return nil
        }
        let receiptsURL = groupURL.appendingPathComponent("Receipts", isDirectory: true)
        if !FileManager.default.fileExists(atPath: receiptsURL.path) {
            try? FileManager.default.createDirectory(
                at: receiptsURL,
                withIntermediateDirectories: true
            )
        }
        return receiptsURL
    }

    /// Resolve a stored filename to its full URL.
    static func url(for filename: String) -> URL? {
        receiptsDirectory()?.appendingPathComponent(filename)
    }

    /// Load a UIImage from disk for the given stored filename.
    static func image(named filename: String) -> UIImage? {
        guard let url = url(for: filename),
              let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    /// Compress and save an image to disk. Returns the stored filename or nil
    /// if anything fails. Downscales to a max edge of 1600pt and JPEG q=0.75
    /// to keep file sizes reasonable (typically <200 KB).
    @discardableResult
    static func save(image: UIImage) -> String? {
        guard let dir = receiptsDirectory() else { return nil }
        let downsized = downscale(image: image, maxEdge: 1600)
        guard let data = downsized.jpegData(compressionQuality: 0.75) else { return nil }
        let filename = "\(UUID().uuidString).jpg"
        let url = dir.appendingPathComponent(filename)
        do {
            try data.write(to: url, options: .atomic)
            return filename
        } catch {
            print("ReceiptStore: write failed: \(error)")
            return nil
        }
    }

    /// Remove a single receipt file. Silent on failure.
    static func delete(filename: String) {
        guard let url = url(for: filename) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    /// Remove the entire Receipts directory (used by the wipe / reset flow).
    static func deleteAll() {
        guard let dir = receiptsDirectory() else { return }
        try? FileManager.default.removeItem(at: dir)
    }

    // MARK: - Helpers

    private static func downscale(image: UIImage, maxEdge: CGFloat) -> UIImage {
        let size = image.size
        let longEdge = max(size.width, size.height)
        guard longEdge > maxEdge else { return image }
        let scale = maxEdge / longEdge
        let target = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: target)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
