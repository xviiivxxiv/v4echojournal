//
//  ConversationMessage+CoreDataProperties.swift
//  v4 EchoJournal
//
//  Created by Papi on 26/05/2025.
//
//

import Foundation
import CoreData


extension ConversationMessage {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ConversationMessage> {
        return NSFetchRequest<ConversationMessage>(entityName: "ConversationMessage")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var text: String?
    @NSManaged public var sender: String?
    @NSManaged public var timestamp: Date?
    @NSManaged public var journalEntry: JournalEntryCD?

}

extension ConversationMessage : Identifiable {

}
