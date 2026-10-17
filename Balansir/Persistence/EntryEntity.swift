import Foundation
import CoreData

@objc(Entry)
public class Entry: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var date: Date
    @NSManaged public var entryType: String
    /// Устарело (v1–v3), после `MinorUnitsMigration` всегда 0. Сумма — `amountMinor`.
    @NSManaged public var amount: Double
    /// Сумма в минимальных единицах валюты (копейках), Core Data v4.
    @NSManaged public var amountMinor: Int64
    @NSManaged public var currency: String
    @NSManaged public var note: String?
    @NSManaged public var isRecurring: Bool
    @NSManaged public var isSoftDeleted: Bool
    @NSManaged public var createdAt: Date
    @NSManaged public var updatedAt: Date?
    @NSManaged public var fromAccount: Account?
    @NSManaged public var toAccount: Account?
    @NSManaged public var category: Category?
    /// Контрагент операции-долга (§4.11).
    @NSManaged public var counterparty: Counterparty?
    /// Теги операции (связь «многие ко многим»). Обычно один; два — только у импортированных.
    @NSManaged public var tagSet: NSSet?

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Entry> {
        NSFetchRequest<Entry>(entityName: "Entry")
    }
}
