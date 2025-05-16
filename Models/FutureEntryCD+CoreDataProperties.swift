import Foundation
import CoreData

extension FutureEntryCD {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<FutureEntryCD> {
        return NSFetchRequest<FutureEntryCD>(entityName: "FutureEntryCD")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var message: String?
    @NSManaged public var audioURL: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var deliveryDate: Date?
}

extension FutureEntryCD : Identifiable {
} 