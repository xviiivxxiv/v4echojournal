//
//  JournalEntryCD+CoreDataProperties.swift
//  V3 Echojournal
//
//  Created by Papi on 21/04/2025.
//
//

import Foundation
import CoreData


extension JournalEntryCD {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<JournalEntryCD> {
        return NSFetchRequest<JournalEntryCD>(entityName: "JournalEntryCD")
    }

    @NSManaged public var audioURL: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var entryText: String?
    @NSManaged public var id: UUID?
    @NSManaged public var followups: NSSet?

}

// MARK: Generated accessors for followups
extension JournalEntryCD {

    @objc(addFollowupsObject:)
    @NSManaged public func addToFollowups(_ value: FollowUpCD)

    @objc(removeFollowupsObject:)
    @NSManaged public func removeFromFollowups(_ value: FollowUpCD)

    @objc(addFollowups:)
    @NSManaged public func addToFollowups(_ values: NSSet)

    @objc(removeFollowups:)
    @NSManaged public func removeFromFollowups(_ values: NSSet)

}

extension JournalEntryCD : Identifiable {

}
