import CoreData

/// Core Data v3 → v4: суммы переезжают из `Double` (`amount`, `initialBalance`) в `Int64` в минимальных
/// единицах (`amountMinor`, `initialBalanceMinor`). Lightweight migration тип атрибута не меняет,
/// поэтому новые атрибуты добавлены рядом, а значения переносятся здесь, при запуске.
///
/// Перенесённое старое значение обнуляется, и мапперы его больше не пишут — повторный запуск ничего
/// не трогает. Старые атрибуты удалить в следующей версии модели.
enum MinorUnitsMigration {
    static func run(in context: NSManagedObjectContext) throws {
        try context.performAndWait {
            let entries = Entry.fetchRequest()
            entries.predicate = NSPredicate(format: "amount != 0")
            for entry in try context.fetch(entries) {
                entry.amountMinor = MinorUnits.toMinor(legacy: entry.amount, currency: entry.currency)
                entry.amount = 0
            }
            let accounts = Account.fetchRequest()
            accounts.predicate = NSPredicate(format: "initialBalance != 0")
            for account in try context.fetch(accounts) {
                account.initialBalanceMinor = MinorUnits.toMinor(legacy: account.initialBalance, currency: account.currency)
                account.initialBalance = 0
            }
            if context.hasChanges { try context.save() }
        }
    }
}
