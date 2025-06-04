//
//  JournalEntryCD+CoreDataProperties.swift
//  v4 EchoJournal
//
//  Created by Papi on 03/06/2025.
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
    @NSManaged public var highestStreak: Int16
    @NSManaged public var id: UUID?
    @NSManaged public var keywords: String?
    @NSManaged public var mood: String?
    @NSManaged public var headline: String?
    @NSManaged public var userSelectedFeelingCategory: String?
    @NSManaged public var aiSummary: String?
    @NSManaged public var followups: NSSet?
    @NSManaged public var messages: NSOrderedSet?
    @NSManaged public var photos: NSOrderedSet?
    @NSManaged public var identifiedFeelings: NSOrderedSet?

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

// MARK: Generated accessors for messages
extension JournalEntryCD {

    @objc(insertObject:inMessagesAtIndex:)
    @NSManaged public func insertIntoMessages(_ value: ConversationMessage, at idx: Int)

    @objc(removeObjectFromMessagesAtIndex:)
    @NSManaged public func removeFromMessages(at idx: Int)

    @objc(insertMessages:atIndexes:)
    @NSManaged public func insertIntoMessages(_ values: [ConversationMessage], at indexes: NSIndexSet)

    @objc(removeMessagesAtIndexes:)
    @NSManaged public func removeFromMessages(at indexes: NSIndexSet)

    @objc(replaceObjectInMessagesAtIndex:withObject:)
    @NSManaged public func replaceMessages(at idx: Int, with value: ConversationMessage)

    @objc(replaceMessagesAtIndexes:withMessages:)
    @NSManaged public func replaceMessages(at indexes: NSIndexSet, with values: [ConversationMessage])

    @objc(addMessagesObject:)
    @NSManaged public func addToMessages(_ value: ConversationMessage)

    @objc(removeMessagesObject:)
    @NSManaged public func removeFromMessages(_ value: ConversationMessage)

    @objc(addMessages:)
    @NSManaged public func addToMessages(_ values: NSOrderedSet)

    @objc(removeMessages:)
    @NSManaged public func removeFromMessages(_ values: NSOrderedSet)

}

// MARK: Generated accessors for photos
extension JournalEntryCD {

    @objc(insertObject:inPhotosAtIndex:)
    @NSManaged public func insertIntoPhotos(_ value: JournalPhoto, at idx: Int)

    @objc(removeObjectFromPhotosAtIndex:)
    @NSManaged public func removeFromPhotos(at idx: Int)

    @objc(insertPhotos:atIndexes:)
    @NSManaged public func insertIntoPhotos(_ values: [JournalPhoto], at indexes: NSIndexSet)

    @objc(removePhotosAtIndexes:)
    @NSManaged public func removeFromPhotos(at indexes: NSIndexSet)

    @objc(replaceObjectInPhotosAtIndex:withObject:)
    @NSManaged public func replacePhotos(at idx: Int, with value: JournalPhoto)

    @objc(replacePhotosAtIndexes:withPhotos:)
    @NSManaged public func replacePhotos(at indexes: NSIndexSet, with values: [JournalPhoto])

    @objc(addPhotosObject:)
    @NSManaged public func addToPhotos(_ value: JournalPhoto)

    @objc(removePhotosObject:)
    @NSManaged public func removeFromPhotos(_ value: JournalPhoto)

    @objc(addPhotos:)
    @NSManaged public func addToPhotos(_ values: NSOrderedSet)

    @objc(removePhotos:)
    @NSManaged public func removeFromPhotos(_ values: NSOrderedSet)

}

// MARK: Generated accessors for identifiedFeelings
extension JournalEntryCD {

    @objc(insertObject:inIdentifiedFeelingsAtIndex:)
    @NSManaged public func insertIntoIdentifiedFeelings(_ value: IdentifiedFeelingCD, at idx: Int)

    @objc(removeObjectFromIdentifiedFeelingsAtIndex:)
    @NSManaged public func removeFromIdentifiedFeelings(at idx: Int)

    @objc(insertIdentifiedFeelings:atIndexes:)
    @NSManaged public func insertIntoIdentifiedFeelings(_ values: [IdentifiedFeelingCD], at indexes: NSIndexSet)

    @objc(removeIdentifiedFeelingsAtIndexes:)
    @NSManaged public func removeFromIdentifiedFeelings(at indexes: NSIndexSet)

    @objc(replaceObjectInIdentifiedFeelingsAtIndex:withObject:)
    @NSManaged public func replaceIdentifiedFeelings(at idx: Int, with value: IdentifiedFeelingCD)

    @objc(replaceIdentifiedFeelingsAtIndexes:withIdentifiedFeelings:)
    @NSManaged public func replaceIdentifiedFeelings(at indexes: NSIndexSet, with values: [IdentifiedFeelingCD])

    @objc(addIdentifiedFeelingsObject:)
    @NSManaged public func addToIdentifiedFeelings(_ value: IdentifiedFeelingCD)

    @objc(removeIdentifiedFeelingsObject:)
    @NSManaged public func removeFromIdentifiedFeelings(_ value: IdentifiedFeelingCD)

    @objc(addIdentifiedFeelings:)
    @NSManaged public func addToIdentifiedFeelings(_ values: NSOrderedSet)

    @objc(removeIdentifiedFeelings:)
    @NSManaged public func removeFromIdentifiedFeelings(_ values: NSOrderedSet)

}

extension JournalEntryCD : Identifiable {

}
