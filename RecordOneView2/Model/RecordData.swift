import Foundation
import CoreData
class RecordData : NSManagedObject {
    @NSManaged var title : String
    @NSManaged var witchSetting : Int
    @NSManaged var recordTime : Float
    @NSManaged var recordID : String
    
    override func awakeFromInsert() {
        self.title = "New Record"
        self.witchSetting = 0
        self.recordTime = 0
        self.recordID = UUID().uuidString
    }
    
    override func prepareForDeletion() {
        let recordURL = URL(fileURLWithPath: NSHomeDirectory().appending("/Documents/\(recordID).wav"))
        do {
            try FileManager.default.removeItem(at: recordURL)
        } catch  {
            print("刪除檔案失敗\(error)")
        }
        
    }
}
