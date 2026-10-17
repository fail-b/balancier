import Testing
import Foundation
@testable import Balansir

@Suite("AccountsViewModel")
@MainActor
struct AccountsViewModelTests {

    @Test func load_заполняет_счета_и_категории() async {
        let accountRepo = MockAccountRepository()
        accountRepo.accounts = [.makeTest(name: "Счёт 1"), .makeTest(name: "Счёт 2")]
        let categoryRepo = MockCategoryRepository()
        categoryRepo.categories = [.makeTest(name: "Еда"), .makeTest(name: "Зарплата", type: .income)]
        let vm = AccountsViewModel(
            accountRepo: accountRepo,
            categoryRepo: categoryRepo,
            entryRepo: MockEntryRepository(),
            counterpartyRepo: MockCounterpartyRepository()
        )
        await vm.load()
        #expect(vm.accounts.count == 2)
        #expect(vm.categories.count == 2)
    }

    @Test func load_вычисляет_балансы() async {
        let account = AccountModel.makeTest(initialBalance: 1000)
        let accountRepo = MockAccountRepository()
        accountRepo.accounts = [account]
        let entryRepo = MockEntryRepository()
        entryRepo.entries = [.makeTest(type: .expense, amount: 300, from: account)]
        let vm = AccountsViewModel(
            accountRepo: accountRepo,
            categoryRepo: MockCategoryRepository(),
            entryRepo: entryRepo,
            counterpartyRepo: MockCounterpartyRepository()
        )
        await vm.load()
        #expect(vm.balances[account.id] == 700)
    }

    @Test func filteredCategories_фильтрует_по_типу() async {
        let categoryRepo = MockCategoryRepository()
        categoryRepo.categories = [
            .makeTest(name: "Еда", type: .expense),
            .makeTest(name: "Транспорт", type: .expense),
            .makeTest(name: "Зарплата", type: .income),
        ]
        let vm = AccountsViewModel(
            accountRepo: MockAccountRepository(),
            categoryRepo: categoryRepo,
            entryRepo: MockEntryRepository(),
            counterpartyRepo: MockCounterpartyRepository()
        )
        await vm.load()
        vm.selectedCategoryType = .expense
        #expect(vm.filteredCategories.count == 2)
        vm.selectedCategoryType = .income
        #expect(vm.filteredCategories.count == 1)
    }

    @Test func archive_счёт_удаляет_из_списка() async {
        let account = AccountModel.makeTest()
        let accountRepo = MockAccountRepository()
        accountRepo.accounts = [account]
        let vm = AccountsViewModel(
            accountRepo: accountRepo,
            categoryRepo: MockCategoryRepository(),
            entryRepo: MockEntryRepository(),
            counterpartyRepo: MockCounterpartyRepository()
        )
        await vm.load()
        await vm.archive(account)
        #expect(vm.accounts.isEmpty)
    }

    @Test func archive_категория_удаляет_из_списка() async {
        let category = CategoryModel.makeTest()
        let categoryRepo = MockCategoryRepository()
        categoryRepo.categories = [category]
        let vm = AccountsViewModel(
            accountRepo: MockAccountRepository(),
            categoryRepo: categoryRepo,
            entryRepo: MockEntryRepository(),
            counterpartyRepo: MockCounterpartyRepository()
        )
        await vm.load()
        await vm.archive(category)
        #expect(vm.categories.isEmpty)
    }

    @Test func ошибка_репозитория_устанавливает_errorMessage() async {
        let accountRepo = MockAccountRepository()
        accountRepo.shouldThrow = true
        let vm = AccountsViewModel(
            accountRepo: accountRepo,
            categoryRepo: MockCategoryRepository(),
            entryRepo: MockEntryRepository(),
            counterpartyRepo: MockCounterpartyRepository()
        )
        await vm.load()
        #expect(vm.errorMessage != nil)
    }

    // MARK: «Всего на счетах» и скрытие с отменой (§4.5)

    private func makeVM(_ accountRepo: MockAccountRepository, entries: [EntryModel] = []) -> AccountsViewModel {
        let entryRepo = MockEntryRepository()
        entryRepo.entries = entries
        return AccountsViewModel(accountRepo: accountRepo, categoryRepo: MockCategoryRepository(), entryRepo: entryRepo, counterpartyRepo: MockCounterpartyRepository())
    }

    @Test func totalBalance_суммирует_балансы_с_операциями() async {
        let a1 = AccountModel.makeTest(name: "A1", initialBalance: 1000)
        let a2 = AccountModel.makeTest(name: "A2", initialBalance: -200)
        let repo = MockAccountRepository()
        repo.accounts = [a1, a2]
        let vm = makeVM(repo, entries: [.makeTest(type: .expense, amount: 300, from: a1)])
        await vm.load()
        // 700 + (−200) = 500
        #expect(vm.totalBalance == 500)
    }

    @Test func archive_запоминает_счёт_для_отмены() async {
        let account = AccountModel.makeTest()
        let repo = MockAccountRepository()
        repo.accounts = [account]
        let vm = makeVM(repo)
        await vm.load()
        await vm.archive(account)
        #expect(vm.recentlyHidden?.id == account.id)
        await vm.load()
        #expect(vm.accounts.isEmpty)   // и в репозитории скрыт
    }

    @Test func undoArchive_возвращает_счёт() async {
        let account = AccountModel.makeTest()
        let repo = MockAccountRepository()
        repo.accounts = [account]
        let vm = makeVM(repo)
        await vm.load()
        await vm.archive(account)
        await vm.undoArchive()
        #expect(vm.accounts.map(\.id) == [account.id])
        #expect(vm.recentlyHidden == nil)
    }

    @Test func dismissUndo_оставляет_счёт_скрытым() async {
        let account = AccountModel.makeTest()
        let repo = MockAccountRepository()
        repo.accounts = [account]
        let vm = makeVM(repo)
        await vm.load()
        await vm.archive(account)
        vm.dismissUndo()
        await vm.undoArchive()   // плашки уже нет — ничего не делает
        await vm.load()
        #expect(vm.accounts.isEmpty)
        #expect(vm.recentlyHidden == nil)
    }

    @Test func ошибка_отмены_показывает_ошибку() async {
        let account = AccountModel.makeTest()
        let repo = MockAccountRepository()
        repo.accounts = [account]
        let vm = makeVM(repo)
        await vm.load()
        await vm.archive(account)
        repo.shouldThrow = true
        await vm.undoArchive()
        #expect(vm.errorMessage != nil)
    }

    @Test func archive_возвращает_результат_для_свайпа() async {
        let account = AccountModel.makeTest()
        let repo = MockAccountRepository()
        repo.accounts = [account]
        let vm = makeVM(repo)
        await vm.load()
        repo.shouldThrow = true
        let failed = await vm.archive(account)
        #expect(failed == false)
        #expect(vm.accounts.count == 1)   // строка остаётся
        #expect(vm.recentlyHidden == nil)
        repo.shouldThrow = false
        let hidden = await vm.archive(account)
        #expect(hidden == true)
    }

    // MARK: скрытие категорий с отменой

    // Без значения по умолчанию `MockAccountRepository()`: тестовый таргет не на MainActor,
    // и default-аргумент вычислялся бы вне главного актора (ошибка компиляции).
    private func makeVM(_ categoryRepo: MockCategoryRepository, accountRepo: MockAccountRepository? = nil) -> AccountsViewModel {
        AccountsViewModel(accountRepo: accountRepo ?? MockAccountRepository(), categoryRepo: categoryRepo, entryRepo: MockEntryRepository(), counterpartyRepo: MockCounterpartyRepository())
    }

    @Test func скрытие_категории_показывает_плашку() async {
        let category = CategoryModel.makeTest(name: "Кафе")
        let repo = MockCategoryRepository()
        repo.categories = [category]
        let vm = makeVM(repo)
        await vm.load()
        let hidden = await vm.archive(category)
        #expect(hidden)
        #expect(vm.categories.isEmpty)
        #expect(vm.recentlyHidden == .category(category))
        #expect(vm.recentlyHidden?.toastTitle == String(localized: "Category “\("Кафе")” hidden"))
    }

    @Test func отмена_возвращает_категорию_на_прежнее_место() async {
        let a = CategoryModel.makeTest(name: "A", sortOrder: 0)
        let b = CategoryModel.makeTest(name: "B", sortOrder: 1)
        let c = CategoryModel.makeTest(name: "C", sortOrder: 2)
        let repo = MockCategoryRepository()
        repo.categories = [a, b, c]
        let vm = makeVM(repo)
        await vm.load()
        await vm.archive(b)
        await vm.undoArchive()
        #expect(vm.filteredCategories.map(\.id) == [a.id, b.id, c.id])
        #expect(repo.categories.first { $0.id == b.id }?.sortOrder == 1)
        #expect(vm.recentlyHidden == nil)
    }

    @Test func отмена_переключает_сегмент_на_тип_категории() async {
        let salary = CategoryModel.makeTest(name: "Зарплата", type: .income)
        let repo = MockCategoryRepository()
        repo.categories = [salary]
        let vm = makeVM(repo)
        await vm.load()
        vm.selectedCategoryType = .income
        await vm.archive(salary)
        vm.selectedCategoryType = .expense   // пользователь ушёл на «Расходы»
        await vm.undoArchive()
        #expect(vm.selectedCategoryType == .income)
        #expect(vm.filteredCategories.map(\.id) == [salary.id])
    }

    @Test func отменяется_только_последнее_скрытие() async {
        let account = AccountModel.makeTest(name: "Сбер")
        let category = CategoryModel.makeTest(name: "Кафе")
        let accountRepo = MockAccountRepository()
        accountRepo.accounts = [account]
        let categoryRepo = MockCategoryRepository()
        categoryRepo.categories = [category]
        let vm = makeVM(categoryRepo, accountRepo: accountRepo)
        await vm.load()
        await vm.archive(account)
        await vm.archive(category)   // плашка счёта заменена плашкой категории
        #expect(vm.recentlyHidden == .category(category))
        await vm.undoArchive()
        #expect(vm.categories.map(\.id) == [category.id])
        #expect(vm.accounts.isEmpty)   // счёт остался скрытым
    }

    @Test func ошибка_скрытия_оставляет_категорию_и_прежнюю_плашку() async {
        let account = AccountModel.makeTest()
        let category = CategoryModel.makeTest()
        let accountRepo = MockAccountRepository()
        accountRepo.accounts = [account]
        let categoryRepo = MockCategoryRepository()
        categoryRepo.categories = [category]
        let vm = makeVM(categoryRepo, accountRepo: accountRepo)
        await vm.load()
        await vm.archive(account)
        categoryRepo.shouldThrow = true
        let hidden = await vm.archive(category)
        #expect(hidden == false)
        #expect(vm.categories.map(\.id) == [category.id])
        #expect(vm.recentlyHidden == .account(account))   // отмена счёта ещё доступна
        #expect(vm.errorMessage != nil)
    }

    @Test func ошибка_отмены_категории_оставляет_её_скрытой() async {
        let category = CategoryModel.makeTest()
        let repo = MockCategoryRepository()
        repo.categories = [category]
        let vm = makeVM(repo)
        await vm.load()
        await vm.archive(category)
        repo.shouldThrow = true
        await vm.undoArchive()
        #expect(vm.errorMessage != nil)
        #expect(vm.recentlyHidden == nil)
        #expect(vm.categories.isEmpty)
        #expect(repo.categories.first?.isArchived == true)
    }

    @Test func повторная_отмена_ничего_не_делает() async {
        let category = CategoryModel.makeTest()
        let repo = MockCategoryRepository()
        repo.categories = [category]
        let vm = makeVM(repo)
        await vm.load()
        await vm.archive(category)
        await vm.undoArchive()
        await vm.undoArchive()   // двойной тап по «Отменить»
        #expect(repo.unarchiveCallCount == 1)
        #expect(vm.errorMessage == nil)
    }

    @Test func отмена_работает_после_перезагрузки() async {
        // Между скрытием и отменой экран перезагрузился (закрыли шит) — плашка и отмена живы.
        let category = CategoryModel.makeTest()
        let repo = MockCategoryRepository()
        repo.categories = [category]
        let vm = makeVM(repo)
        await vm.load()
        await vm.archive(category)
        await vm.load()
        #expect(vm.categories.isEmpty)
        #expect(vm.recentlyHidden == .category(category))
        await vm.undoArchive()
        #expect(vm.categories.map(\.id) == [category.id])
    }

    @Test func dismissUndo_оставляет_категорию_скрытой() async {
        let category = CategoryModel.makeTest()
        let repo = MockCategoryRepository()
        repo.categories = [category]
        let vm = makeVM(repo)
        await vm.load()
        await vm.archive(category)
        vm.dismissUndo()
        await vm.undoArchive()
        await vm.load()
        #expect(vm.categories.isEmpty)
        #expect(repo.unarchiveCallCount == 0)
    }

    @Test func плашка_счёта_с_названием() async {
        let account = AccountModel.makeTest(name: "Тинькофф")
        let repo = MockAccountRepository()
        repo.accounts = [account]
        let vm = makeVM(repo)
        await vm.load()
        await vm.archive(account)
        #expect(vm.recentlyHidden?.toastTitle == String(localized: "Account “\("Тинькофф")” hidden"))
    }
}
