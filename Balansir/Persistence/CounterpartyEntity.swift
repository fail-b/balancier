import Foundation
import CoreData

/// Сущность Core Data «Counterparty» — контрагент долга (§4.11).
@objc(Counterparty)
public class Counterparty: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var colorHex: String
    @NSManaged public var iconName: String
    @NSManaged public var sortOrder: Int32
    @NSManaged public var isArchived: Bool
    @NSManaged public var createdAt: Date
    @NSManaged public var updatedAt: Date?
    @NSManaged public var entries: NSSet?

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Counterparty> {
        NSFetchRequest<Counterparty>(entityName: "Counterparty")
    }
}
