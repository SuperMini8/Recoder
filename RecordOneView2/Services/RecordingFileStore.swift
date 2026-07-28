//
//  RecordingFileStore.swift
//  Record_02
//
//  Owns recording file paths and file-system operations.
//

import Foundation

final class RecordingFileStore {
    static let shared = RecordingFileStore()

    private let folderName = "Recordings"
    private let fileExtension = "wav"

    private init() {}
    /// 用 id 取得錄音檔的 URL
    func fileURL(for recordID: String, createDirectory: Bool = false) throws -> URL {
        guard let docURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw URLError(.badURL)
        }

        let directoryURL = docURL.appendingPathComponent(folderName, isDirectory: true)

        if createDirectory {
            try FileManager.default.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true
            )
        }

        return directoryURL.appendingPathComponent(recordID).appendingPathExtension(fileExtension)
    }
    /// 用 id 刪除錄音檔
    func deleteFile(for recordID: String) throws {
        let recordURL = try fileURL(for: recordID)
        guard FileManager.default.fileExists(atPath: recordURL.path) else { return }
        try FileManager.default.removeItem(at: recordURL)
    }
}
