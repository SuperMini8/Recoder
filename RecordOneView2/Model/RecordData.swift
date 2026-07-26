import Foundation
import CoreData
class RecordData : NSManagedObject {
    @NSManaged var recordID : String
    @NSManaged var title : String
    @NSManaged var qualityType : Int
    @NSManaged var recordTime : Float
    
    override func awakeFromInsert() {
        self.title = "New Record"
        self.qualityType = 0
        self.recordTime = 0
        self.recordID = UUID().uuidString
    }
    
}

extension RecordData {
    static let folderName = "Recordings"

    static func fileURL(for recordID: String, createDirectory: Bool = false) throws -> URL {
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

        return directoryURL.appendingPathComponent(recordID).appendingPathExtension("wav")
    }

    func fileURL() throws -> URL {
        try Self.fileURL(for: recordID)
    }
}
