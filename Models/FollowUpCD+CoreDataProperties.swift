//
//  FollowUpCD+CoreDataProperties.swift
//  V3 Echojournal
//
//  Created by Papi on 21/04/2025.
//
//

import Foundation
import CoreData


extension FollowUpCD {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<FollowUpCD> {
        return NSFetchRequest<FollowUpCD>(entityName: "FollowUpCD")
    }

    @NSManaged public var id: UUID
    @NSManaged public var question: String
    @NSManaged public var answer: String?
    @NSManaged public var createdAt: Date
    @NSManaged public var journalEntry: JournalEntryCD?

}

extension FollowUpCD : Identifiable {

}
