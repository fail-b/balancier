import Foundation
import CoreData

@objc(Account)
public class Account: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    /// Устарело (v1–v3), после `MinorUnitsMigration` всегда 0. Баланс — `initialBalanceMinor`.
    @NSManaged public var initialBalance: Double
    /// Начальный баланс в минимальных единицах валюты, Core Data v4.
    @NSManaged public var initialBalanceMinor: Int64
    @NSManaged public var currency: String
    @NSManaged public var colorHex: String
    @NSManaged public var iconName: String
    @NSManaged public var accountType: String
    @NSManaged public var sortOrder: Int32
    @NSManaged public var createdAt: Date
    @NSManaged public var updatedAt: Date?
    @NSManaged public var isArchived: Bool
    @NSManaged public var outgoingEntries: NSSet?
    @NSManaged public var incomingEntries: NSSet?

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Account> {
        NSFetchRequest<Account>(entityName: "Account")
    }
}
