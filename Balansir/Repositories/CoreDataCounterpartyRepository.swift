import CoreData

final class CoreDataCounterpartyRepository: CounterpartyRepository {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func fetchAll() async throws -> [CounterpartyModel] {
        try await context.perform {
            let request = Counterparty.fetchRequest()
            request.sortDescriptors = [
                NSSortDescriptor(key: "sortOrder", ascending: true),
                NSSortDescriptor(key: "createdAt", ascending: true),
            ]
            return try self.context.fetch(request).map { $0.toModel() }
        }
    }

    func save(_ counterparty: CounterpartyModel) async throws {
        try await context.perform {
            let request = Counterparty.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", counterparty.id as CVarArg)
            let entity = (try self.context.fetch(request).first) ?? Counterparty(context: self.context)
            if entity.isInserted {
                entity.id = counterparty.id
                entity.createdAt = counterparty.createdAt
            }
            entity.update(from: counterparty)
            try self.context.save()
        }
    }

    func archive(_ id: UUID) async throws {
        try await context.perform {
            let request = Counterparty.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            if let entity = try self.context.fetch(request).first {
                entity.isArchived = true
                entity.updatedAt = Date()
                try self.context.save()
            }
        }
    }
}
