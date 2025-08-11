//
//  ChallengeAttempt+CoreDataProperties.swift
//  v4 EchoJournal
//
//  Created by Papi on 19/06/2025.
//
//

import Foundation
import CoreData


extension ChallengeAttempt {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ChallengeAttempt> {
        return NSFetchRequest<ChallengeAttempt>(entityName: "ChallengeAttempt")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var challengeID: String?
    @NSManaged public var startDate: Date?
    @NSManaged public var completedDays: String?
    @NSManaged public var journalEntries: NSSet?

}

// MARK: Generated accessors for journalEntries
extension ChallengeAttempt {

    @objc(addJournalEntriesObject:)
    @NSManaged public func addToJournalEntries(_ value: JournalEntryCD)

    @objc(removeJournalEntriesObject:)
    @NSManaged public func removeFromJournalEntries(_ value: JournalEntryCD)

    @objc(addJournalEntries:)
    @NSManaged public func addToJournalEntries(_ values: NSSet)

    @objc(removeJournalEntries:)
    @NSManaged public func removeFromJournalEntries(_ values: NSSet)

}

extension ChallengeAttempt : Identifiable {

}
