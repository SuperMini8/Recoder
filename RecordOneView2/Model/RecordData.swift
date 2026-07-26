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
