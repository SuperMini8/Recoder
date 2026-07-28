import Foundation
import CoreData
class RecordData : NSManagedObject {
    /// 唯一標示 ID
    @NSManaged var recordID : String
    /// App 內顯示的名稱
    @NSManaged var title : String
    /// 音質種類
    @NSManaged var qualityType : Int
    /// 錄音時間
    @NSManaged var recordTime : Float
    /// 建立時間（目前預設排序使用）
    @NSManaged var createdAt : Date?
    
    override func awakeFromInsert() {
        self.title = "New Record"
        self.qualityType = 0
        self.recordTime = 0
        self.recordID = UUID().uuidString
        self.createdAt = Date()
    }
    
}

extension RecordData {
    static func fileURL(for recordID: String, createDirectory: Bool = false) throws -> URL {
        try RecordingFileStore.shared.fileURL(for: recordID, createDirectory: createDirectory)
    }

    func fileURL() throws -> URL {
        try Self.fileURL(for: recordID)
    }
}
