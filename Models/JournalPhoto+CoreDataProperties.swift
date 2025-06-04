//
//  JournalPhoto+CoreDataProperties.swift
//  v4 EchoJournal
//
//  Created by Papi on 26/05/2025.
//
//

import Foundation
import CoreData


extension JournalPhoto {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<JournalPhoto> {
        return NSFetchRequest<JournalPhoto>(entityName: "JournalPhoto")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var imageData: Data?
    @NSManaged public var timestamp: Date?
    @NSManaged public var caption: String?
    @NSManaged public var journalEntry: JournalEntryCD?

}

extension JournalPhoto : Identifiable {

}
