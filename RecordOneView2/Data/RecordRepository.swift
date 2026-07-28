//
//  RecordRepository.swift
//  Record_02
//
//  Created by 小八 on 2026/7/26.
//

import Foundation
import CoreData
/// 集中 RecordData 的 儲存/修改/刪除 邏輯
final class RecordRepository {
    private let context = CoreDataHelper.shared.managedObjectContext()
    private let fileStore: RecordingFileStore

    init(fileStore: RecordingFileStore = .shared) {
        self.fileStore = fileStore
    }

    /// 取得已儲存的 RecordData
    func fetchRecords() throws -> [RecordData] {
        let request = NSFetchRequest<RecordData>(entityName: "RecordData")
        request.sortDescriptors = [
            NSSortDescriptor(key: "createdAt", ascending: false),
            NSSortDescriptor(key: "recordID", ascending: false)
        ]
        return try context.fetch(request)
    }
    /// 建立 RecordData
    func createRecord(id: String? = nil, qualityType: SoundQuality) -> RecordData {
        let record = RecordData(context: context)
        if let id { record.recordID = id }
        record.qualityType = qualityType.rawValue
        return record
    }
    /// 更新 Title
    func updateTitle(_ record: RecordData, title: String) throws {
        record.title = title
        try save()
    }
    /// 更新錄音時間
    func updateDuration(_ record: RecordData, duration: Float) {
        record.recordTime = duration
    }
    /// 刪除（先刪除資料再刪檔案 -> 防止看得到卻沒檔案的狀況）
    func delete(_ record: RecordData) throws {
        let recordID = record.recordID
        // 先刪除資料
        context.delete(record)
        try save()
        // 再刪檔案
        do {
            try fileStore.deleteFile(for: recordID)
        } catch {
            print("刪除音檔失敗：\(error.localizedDescription)")
        }
    }
    /// 儲存修改
    func save() throws {
        guard context.hasChanges else { return }
        try context.save()
    }
    
    
}
