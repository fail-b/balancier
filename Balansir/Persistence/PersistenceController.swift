import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        SeedData.populate(in: result.container.viewContext)
        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "Balansir")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        container.persistentStoreDescriptions.first?.shouldMigrateStoreAutomatically = true
        container.persistentStoreDescriptions.first?.shouldInferMappingModelAutomatically = true
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        // v3 → v4: суммы из Double в минимальные единицы (повторный запуск ничего не меняет).
        do {
            try MinorUnitsMigration.run(in: container.viewContext)
        } catch {
            fatalError("Minor units migration failed: \(error)")
        }

        if !inMemory {
            seedDefaultsIfNeeded(in: container.viewContext)
        }
    }

    private func seedDefaultsIfNeeded(in context: NSManagedObjectContext) {
        // Проверяем категории, а не счета: счетов до онбординга нет, иначе категории сеялись бы при каждом запуске.
        let request = Category.fetchRequest()
        guard (try? context.count(for: request)) == 0 else { return }
        SeedData.populate(in: context)
    }

    func save() {
        let ctx = container.viewContext
        guard ctx.hasChanges else { return }
        try? ctx.save()
    }
}
