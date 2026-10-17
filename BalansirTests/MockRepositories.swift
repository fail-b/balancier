import Foundation
@testable import Balansir

// Основной таргет собран с SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor,
// поэтому модели, протоколы и ViewModel изолированы на главном акторе.
// Тесты и моки тоже должны работать на MainActor, иначе — ошибки компиляции.

@MainActor
final class MockAccountRepository: AccountRepository {
    var accounts: [AccountModel] = []
    var shouldThrow = false

    /// Скрытые счета (как в Core Data) в `fetchAll` не попадают.
    func fetchAll() async throws -> [AccountModel] {
        if shouldThrow { throw NSError(domain: "test", code: 1) }
        return accounts.filter { !$0.isArchived }
    }

    func save(_ account: AccountModel) async throws {
        if shouldThrow { throw NSError(domain: "test", code: 1) }
        if let idx = accounts.firstIndex(where: { $0.id == account.id }) {
            accounts[idx] = account
        } else {
            accounts.append(account)
        }
    }

    func archive(_ id: UUID) async throws {
        if shouldThrow { throw NSError(domain: "test", code: 1) }
        setArchived(id, true)
    }

    func unarchive(_ id: UUID) async throws {
        if shouldThrow { throw NSError(domain: "test", code: 1) }
        setArchived(id, false)
    }

    private func setArchived(_ id: UUID, _ value: Bool) {
        if let idx = accounts.firstIndex(where: { $0.id == id }) { accounts[idx].isArchived = value }
    }
}

@MainActor
final class MockCategoryRepository: CategoryRepository {
    var categories: [CategoryModel] = []
    var shouldThrow = false
    var savedCategory: CategoryModel?

    /// Сколько раз вызывали `unarchive` — проверка, что повторная отмена ничего не делает.
    var unarchiveCallCount = 0

    /// Скрытые категории (как в Core Data) в `fetchAll` не попадают.
    func fetchAll() async throws -> [CategoryModel] {
        if shouldThrow { throw NSError(domain: "test", code: 1) }
        return categories.filter { !$0.isArchived }
    }

    func save(_ category: CategoryModel) async throws {
        if shouldThrow { throw NSError(domain: "test", code: 1) }
        savedCategory = category
    }

    func archive(_ id: UUID) async throws {
        if shouldThrow { throw NSError(domain: "test", code: 1) }
        setArchived(id, true)
    }

    func unarchive(_ id: UUID) async throws {
        unarchiveCallCount += 1
        if shouldThrow { throw NSError(domain: "test", code: 1) }
        setArchived(id, false)
    }

    private func setArchived(_ id: UUID, _ value: Bool) {
        if let idx = categories.firstIndex(where: { $0.id == id }) { categories[idx].isArchived = value }
    }
}

@MainActor
final class MockEntryRepository: EntryRepository {
    var entries: [EntryModel] = []
    var shouldThrow = false
    var savedEntry: EntryModel?
    var savedFromAccount: AccountModel?
    var savedToAccount: AccountModel?
    var savedCategory: CategoryModel?

    func fetchAll() async throws -> [EntryModel] {
        if shouldThrow { throw NSError(domain: "test", code: 1) }
        return entries
    }

    func save(_ entry: EntryModel, fromAccount: AccountModel?, toAccount: AccountModel?, category: CategoryModel?) async throws {
        if shouldThrow { throw NSError(domain: "test", code: 1) }
        savedEntry = entry
        savedFromAccount = fromAccount
        savedToAccount = toAccount
        savedCategory = category
        entries.append(entry)
    }

    /// Мягко удалённые — для `restore`.
    var deletedEntries: [EntryModel] = []

    func delete(_ id: UUID) async throws {
        if shouldThrow { throw NSError(domain: "test", code: 1) }
        deletedEntries += entries.filter { $0.id == id }
        entries.removeAll { $0.id == id }
    }

    func restore(_ id: UUID) async throws {
        if shouldThrow { throw NSError(domain: "test", code: 1) }
        entries += deletedEntries.filter { $0.id == id }
        deletedEntries.removeAll { $0.id == id }
    }
}

@MainActor
final class MockTagRepository: TagRepository {
    /// Все теги, включая скрытые (как в Core Data).
    var tags: [TagModel] = []
    var shouldThrow = false

    func fetchAll() async throws -> [TagModel] {
        if shouldThrow { throw NSError(domain: "test", code: 1) }
        return tags
    }

    func save(_ tag: TagModel) async throws {
        if shouldThrow { throw NSError(domain: "test", code: 1) }
        if let idx = tags.firstIndex(where: { $0.id == tag.id }) {
            tags[idx] = tag
        } else {
            tags.append(tag)
        }
    }

    func archive(_ id: UUID) async throws {
        if shouldThrow { throw NSError(domain: "test", code: 1) }
        if let idx = tags.firstIndex(where: { $0.id == id }) { tags[idx].isArchived = true }
    }
}

@MainActor
final class MockCounterpartyRepository: CounterpartyRepository {
    /// Все контрагенты, включая удалённых (как в Core Data).
    var counterparties: [CounterpartyModel] = []
    var shouldThrow = false

    func fetchAll() async throws -> [CounterpartyModel] {
        if shouldThrow { throw NSError(domain: "test", code: 1) }
        return counterparties
    }

    func save(_ counterparty: CounterpartyModel) async throws {
        if shouldThrow { throw NSError(domain: "test", code: 1) }
        if let idx = counterparties.firstIndex(where: { $0.id == counterparty.id }) {
            counterparties[idx] = counterparty
        } else {
            counterparties.append(counterparty)
        }
    }

    func archive(_ id: UUID) async throws {
        if shouldThrow { throw NSError(domain: "test", code: 1) }
        if let idx = counterparties.firstIndex(where: { $0.id == id }) { counterparties[idx].isArchived = true }
    }
}

// MARK: - Фабрики тестовых моделей

@MainActor
extension AccountModel {
    static func makeTest(
        name: String = "Счёт",
        initialBalance: Decimal = 0,
        accountType: AccountType = .debit,
        colorHex: String = "#FF0000",
        sortOrder: Int32 = 0
    ) -> AccountModel {
        AccountModel(
            id: UUID(), name: name, initialBalance: initialBalance, currency: "RUB",
            colorHex: colorHex, iconName: "creditcard", accountType: accountType,
            sortOrder: sortOrder, isArchived: false, createdAt: Date(), updatedAt: Date()
        )
    }
}

@MainActor
extension CategoryModel {
    static func makeTest(name: String = "Категория", type: CategoryType = .expense, sortOrder: Int32 = 0) -> CategoryModel {
        CategoryModel(
            id: UUID(), name: name, categoryType: type, colorHex: "#FF0000",
            iconName: "cart", sortOrder: sortOrder, isArchived: false, createdAt: Date(), updatedAt: Date()
        )
    }
}

@MainActor
extension EntryModel {
    static func makeTest(
        type: EntryType,
        amount: Decimal,
        daysAgo: Int = 0,
        from: AccountModel? = nil,
        to: AccountModel? = nil,
        category: CategoryModel? = nil,
        tags: [TagModel] = [],
        counterparty: CounterpartyModel? = nil
    ) -> EntryModel {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
        return EntryModel(
            id: UUID(), date: date, type: type, amount: amount, currency: "RUB",
            note: nil, tags: tags, isRecurring: false, isSoftDeleted: false,
            createdAt: Date(), updatedAt: Date(),
            fromAccount: from, toAccount: to, category: category, counterparty: counterparty
        )
    }
}

@MainActor
extension TagModel {
    static func makeTest(name: String = "Тег", isArchived: Bool = false) -> TagModel {
        TagModel(id: UUID(), name: name, isArchived: isArchived, createdAt: Date(), updatedAt: Date())
    }
}

@MainActor
extension CounterpartyModel {
    static func makeTest(name: String = "Контрагент", isArchived: Bool = false, sortOrder: Int32 = 0) -> CounterpartyModel {
        CounterpartyModel(id: UUID(), name: name, colorHex: "#FF0000", iconName: "person", sortOrder: sortOrder,
                          isArchived: isArchived, createdAt: Date(), updatedAt: Date())
    }
}

@MainActor
extension EntryModel {
    /// Операция-долг: «Я отправил» (`sent`) — со счёта, «Мне пришли» — на счёт.
    static func makeDebt(_ direction: DebtDirection, amount: Decimal, account: AccountModel,
                         counterparty: CounterpartyModel, daysAgo: Int = 0) -> EntryModel {
        makeTest(type: .debt, amount: amount, daysAgo: daysAgo,
                 from: direction == .sent ? account : nil,
                 to: direction == .received ? account : nil,
                 counterparty: counterparty)
    }
}
