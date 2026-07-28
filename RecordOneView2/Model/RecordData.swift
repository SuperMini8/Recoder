import Foundation
import CoreData
class RecordData : NSManagedObject {
    @NSManaged var recordID : String
    @NSManaged var title : String
    @NSManaged var qualityType : Int
    @NSManaged var recordTime : Float
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
