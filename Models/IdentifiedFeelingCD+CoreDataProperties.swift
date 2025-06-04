//
//  IdentifiedFeelingCD+CoreDataProperties.swift
//  v4 EchoJournal
//
//  Created by Papi on 27/05/2025.
//
//

import Foundation
import CoreData


extension IdentifiedFeelingCD {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<IdentifiedFeelingCD> {
        return NSFetchRequest<IdentifiedFeelingCD>(entityName: "IdentifiedFeelingCD")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var category: String?
    @NSManaged public var timestamp: Date?
    @NSManaged public var journalEntry: JournalEntryCD?

}

extension IdentifiedFeelingCD : Identifiable {

}
