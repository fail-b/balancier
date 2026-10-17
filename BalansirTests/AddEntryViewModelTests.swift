import Testing
import Foundation
@testable import Balansir

@Suite("AddEntryViewModel")
@MainActor
struct AddEntryViewModelTests {

    private func makeVM() -> AddEntryViewModel {
        let accountRepo = MockAccountRepository()
        accountRepo.accounts = [AccountModel.makeTest()]
        return AddEntryViewModel(accountRepo: accountRepo, categoryRepo: MockCategoryRepository(), entryRepo: MockEntryRepository(), tagRepo: MockTagRepository(), counterpartyRepo: MockCounterpartyRepository(), locale: TestLocale.ru)
    }

    // MARK: canSave

    @Test func перевод_можно_сохранить_при_разных_счетах() async {
        let a1 = AccountModel.makeTest(name: "A1")
        let a2 = AccountModel.makeTest(name: "A2")
        let accountRepo = MockAccountRepository()
        accountRepo.accounts = [a1, a2]

        let vm = AddEntryViewModel(accountRepo: accountRepo, categoryRepo: MockCategoryRepository(), entryRepo: MockEntryRepository(), tagRepo: MockTagRepository(), counterpartyRepo: MockCounterpartyRepository(), locale: TestLocale.ru)
        await vm.load()
        vm.selectedType = .transfer
        vm.amountString = "500"
        vm.selectedAccount = a1
        vm.selectedToAccount = a2

        #expect(vm.canSave == true)
    }

    @Test func перевод_нельзя_сохранить_при_одинаковых_счетах() async {
        let a1 = AccountModel.makeTest()
        let accountRepo = MockAccountRepository()
        accountRepo.accounts = [a1]

        let vm = AddEntryViewModel(accountRepo: accountRepo, categoryRepo: MockCategoryRepository(), entryRepo: MockEntryRepository(), tagRepo: MockTagRepository(), counterpartyRepo: MockCounterpartyRepository(), locale: TestLocale.ru)
        await vm.load()
        vm.selectedType = .transfer
        vm.amountString = "500"
        vm.selectedAccount = a1
        vm.selectedToAccount = a1

        #expect(vm.canSave == false)
    }

    @Test func расход_нельзя_сохранить_без_категории() async {
        let account = AccountModel.makeTest()
        let accountRepo = MockAccountRepository()
        accountRepo.accounts = [account]

        let vm = AddEntryViewModel(accountRepo: accountRepo, categoryRepo: MockCategoryRepository(), entryRepo: MockEntryRepository(), tagRepo: MockTagRepository(), counterpartyRepo: MockCounterpartyRepository(), locale: TestLocale.ru)
        await vm.load()
        vm.selectedType = .expense
        vm.amountString = "100"
        vm.selectedAccount = account
        vm.selectedCategory = nil

        #expect(vm.canSave == false)
    }

    @Test func нельзя_сохранить_с_нулевой_суммой() async {
        let account = AccountModel.makeTest()
        let category = CategoryModel.makeTest()
        let accountRepo = MockAccountRepository()
        accountRepo.accounts = [account]
        let categoryRepo = MockCategoryRepository()
        categoryRepo.categories = [category]

        let vm = AddEntryViewModel(accountRepo: accountRepo, categoryRepo: categoryRepo, entryRepo: MockEntryRepository(), tagRepo: MockTagRepository(), counterpartyRepo: MockCounterpartyRepository(), locale: TestLocale.ru)
        await vm.load()
        vm.selectedType = .expense
        vm.amountString = "0"
        vm.selectedAccount = account
        vm.selectedCategory = category

        #expect(vm.canSave == false)
    }

    // MARK: save — корректная передача счетов и категории

    @Test func save_расход_передаёт_fromAccount_и_категорию() async {
        let account = AccountModel.makeTest()
        let category = CategoryModel.makeTest(type: .expense)
        let accountRepo = MockAccountRepository()
        accountRepo.accounts = [account]
        let categoryRepo = MockCategoryRepository()
        categoryRepo.categories = [category]
        let entryRepo = MockEntryRepository()

        let vm = AddEntryViewModel(accountRepo: accountRepo, categoryRepo: categoryRepo, entryRepo: entryRepo, tagRepo: MockTagRepository(), counterpartyRepo: MockCounterpartyRepository(), locale: TestLocale.ru)
        await vm.load()
        vm.selectedType = .expense
        vm.amountString = "150"
        vm.selectedAccount = account
        vm.selectedCategory = category
        await vm.save()

        #expect(entryRepo.savedFromAccount?.id == account.id)
        #expect(entryRepo.savedToAccount == nil)
        #expect(entryRepo.savedCategory?.id == category.id)
    }

    @Test func save_доход_передаёт_toAccount_и_категорию() async {
        let account = AccountModel.makeTest()
        let category = CategoryModel.makeTest(type: .income)
        let accountRepo = MockAccountRepository()
        accountRepo.accounts = [account]
        let categoryRepo = MockCategoryRepository()
        categoryRepo.categories = [category]
        let entryRepo = MockEntryRepository()

        let vm = AddEntryViewModel(accountRepo: accountRepo, categoryRepo: categoryRepo, entryRepo: entryRepo, tagRepo: MockTagRepository(), counterpartyRepo: MockCounterpartyRepository(), locale: TestLocale.ru)
        await vm.load()
        vm.selectedType = .income
        vm.amountString = "300"
        vm.selectedAccount = account
        vm.selectedCategory = category
        await vm.save()

        #expect(entryRepo.savedFromAccount == nil)
        #expect(entryRepo.savedToAccount?.id == account.id)
        #expect(entryRepo.savedCategory?.id == category.id)
    }

    @Test func save_перевод_передаёт_оба_счёта_без_категории() async {
        let a1 = AccountModel.makeTest(name: "A1")
        let a2 = AccountModel.makeTest(name: "A2")
        let accountRepo = MockAccountRepository()
        accountRepo.accounts = [a1, a2]
        let entryRepo = MockEntryRepository()

        let vm = AddEntryViewModel(accountRepo: accountRepo, categoryRepo: MockCategoryRepository(), entryRepo: entryRepo, tagRepo: MockTagRepository(), counterpartyRepo: MockCounterpartyRepository(), locale: TestLocale.ru)
        await vm.load()
        vm.selectedType = .transfer
        vm.amountString = "200"
        vm.selectedAccount = a1
        vm.selectedToAccount = a2
        await vm.save()

        #expect(entryRepo.savedFromAccount?.id == a1.id)
        #expect(entryRepo.savedToAccount?.id == a2.id)
        #expect(entryRepo.savedCategory == nil)
    }

    // MARK: edit-режим

    @Test func редактирование_загружает_поля_записи() async {
        let account = AccountModel.makeTest()
        let category = CategoryModel.makeTest()
        let now = Date()
        let entry = EntryModel(
            id: UUID(), date: now, type: .expense, amount: 750, currency: "RUB",
            note: "тест заметка", tags: [], isRecurring: false, isSoftDeleted: false,
            createdAt: now, updatedAt: now,
            fromAccount: account, toAccount: nil, category: category
        )

        let accountRepo = MockAccountRepository()
        accountRepo.accounts = [account]
        let categoryRepo = MockCategoryRepository()
        categoryRepo.categories = [category]

        let vm = AddEntryViewModel(entry: entry, accountRepo: accountRepo, categoryRepo: categoryRepo, entryRepo: MockEntryRepository(), tagRepo: MockTagRepository(), counterpartyRepo: MockCounterpartyRepository(), locale: TestLocale.ru)
        await vm.load()

        #expect(vm.isEditing == true)
        #expect(vm.amount == 750)
        #expect(vm.note == "тест заметка")
        #expect(vm.selectedType == .expense)
        #expect(vm.selectedAccount?.id == account.id)
        #expect(vm.selectedCategory?.id == category.id)
    }

    // MARK: ввод суммы (правила — в AmountInputTests)

    @Test func press_передаёт_клавиши_в_ввод_суммы() async {
        let vm = makeVM()
        await vm.load()
        for key: NumpadKey in [.digit(1), .digit(2), .digit(3), .digit(4), .separator, .digit(5)] { vm.press(key) }
        vm.press(.minus)   // в операции минуса нет
        #expect(vm.amount == Decimal(string: "1234.5"))
        #expect(vm.formattedAmount.normalizedSpaces == "1 234,5")
    }

    // MARK: дефолты

    @Test func по_умолчанию_выбирается_первая_категория_типа() async {
        let account = AccountModel.makeTest()
        let c1 = CategoryModel.makeTest(name: "Еда", type: .expense)
        let c2 = CategoryModel.makeTest(name: "Транспорт", type: .expense)
        let accountRepo = MockAccountRepository()
        accountRepo.accounts = [account]
        let categoryRepo = MockCategoryRepository()
        categoryRepo.categories = [c1, c2]

        let vm = AddEntryViewModel(accountRepo: accountRepo, categoryRepo: categoryRepo, entryRepo: MockEntryRepository(), tagRepo: MockTagRepository(), counterpartyRepo: MockCounterpartyRepository(), locale: TestLocale.ru)
        await vm.load()

        #expect(vm.selectedCategory?.id == c1.id)
    }

    @Test func перевод_по_умолчанию_выбирает_первый_другой_счёт() async {
        let a1 = AccountModel.makeTest(name: "A1")
        let a2 = AccountModel.makeTest(name: "A2")
        let accountRepo = MockAccountRepository()
        accountRepo.accounts = [a1, a2]

        let vm = AddEntryViewModel(accountRepo: accountRepo, categoryRepo: MockCategoryRepository(), entryRepo: MockEntryRepository(), tagRepo: MockTagRepository(), counterpartyRepo: MockCounterpartyRepository(), locale: TestLocale.ru)
        await vm.load()
        vm.selectedType = .transfer
        vm.onTypeChanged()

        #expect(vm.selectedAccount?.id == a1.id)
        #expect(vm.selectedToAccount?.id == a2.id)
    }

    // MARK: ошибки

    @Test func ошибка_репозитория_устанавливает_errorMessage() async {
        let accountRepo = MockAccountRepository()
        accountRepo.shouldThrow = true

        let vm = AddEntryViewModel(accountRepo: accountRepo, categoryRepo: MockCategoryRepository(), entryRepo: MockEntryRepository(), tagRepo: MockTagRepository(), counterpartyRepo: MockCounterpartyRepository(), locale: TestLocale.ru)
        await vm.load()

        #expect(vm.errorMessage != nil)
    }

    // MARK: скрытые категории и счета (§4.5)

    @Test func редактирование_операции_со_скрытой_категорией_можно_сохранить() async {
        let account = AccountModel.makeTest()
        let visible = CategoryModel.makeTest(name: "Еда")
        let hidden = CategoryModel.makeTest(name: "Кафе")
        let entry = EntryModel.makeTest(type: .expense, amount: 300, from: account, category: hidden)
        let accountRepo = MockAccountRepository()
        accountRepo.accounts = [account]
        let categoryRepo = MockCategoryRepository()
        categoryRepo.categories = [visible, hidden]
        try? await categoryRepo.archive(hidden.id)
        let entryRepo = MockEntryRepository()

        let vm = AddEntryViewModel(entry: entry, accountRepo: accountRepo, categoryRepo: categoryRepo, entryRepo: entryRepo, tagRepo: MockTagRepository(), counterpartyRepo: MockCounterpartyRepository(), locale: TestLocale.ru)
        await vm.load()

        #expect(vm.selectedCategory?.id == hidden.id)
        #expect(vm.filteredCategories.map(\.id) == [visible.id, hidden.id])   // видна в выборе, в конце
        #expect(vm.canSave)
        await vm.save()
        #expect(entryRepo.savedCategory?.id == hidden.id)
    }

    @Test func повторная_загрузка_не_дублирует_скрытую_категорию() async {
        let account = AccountModel.makeTest()
        let hidden = CategoryModel.makeTest(name: "Кафе")
        let entry = EntryModel.makeTest(type: .expense, amount: 300, from: account, category: hidden)
        let accountRepo = MockAccountRepository()
        accountRepo.accounts = [account]
        let categoryRepo = MockCategoryRepository()
        categoryRepo.categories = [hidden]
        try? await categoryRepo.archive(hidden.id)

        let vm = AddEntryViewModel(entry: entry, accountRepo: accountRepo, categoryRepo: categoryRepo, entryRepo: MockEntryRepository(), tagRepo: MockTagRepository(), counterpartyRepo: MockCounterpartyRepository(), locale: TestLocale.ru)
        await vm.load()
        await vm.load()
        #expect(vm.categories.count == 1)
    }

    @Test func новая_операция_не_показывает_скрытые_категории() async {
        let account = AccountModel.makeTest()
        let visible = CategoryModel.makeTest(name: "Еда")
        let hidden = CategoryModel.makeTest(name: "Кафе")
        let accountRepo = MockAccountRepository()
        accountRepo.accounts = [account]
        let categoryRepo = MockCategoryRepository()
        categoryRepo.categories = [hidden, visible]
        try? await categoryRepo.archive(hidden.id)

        let vm = AddEntryViewModel(accountRepo: accountRepo, categoryRepo: categoryRepo, entryRepo: MockEntryRepository(), tagRepo: MockTagRepository(), counterpartyRepo: MockCounterpartyRepository(), locale: TestLocale.ru)
        await vm.load()
        #expect(vm.filteredCategories.map(\.id) == [visible.id])
        #expect(vm.selectedCategory?.id == visible.id)
    }

    @Test func редактирование_перевода_со_скрытым_счётом_можно_сохранить() async {
        let from = AccountModel.makeTest(name: "Карта")
        let to = AccountModel.makeTest(name: "Старый вклад")
        let entry = EntryModel.makeTest(type: .transfer, amount: 1000, from: from, to: to)
        let accountRepo = MockAccountRepository()
        accountRepo.accounts = [from, to]
        try? await accountRepo.archive(to.id)

        let vm = AddEntryViewModel(entry: entry, accountRepo: accountRepo, categoryRepo: MockCategoryRepository(), entryRepo: MockEntryRepository(), tagRepo: MockTagRepository(), counterpartyRepo: MockCounterpartyRepository(), locale: TestLocale.ru)
        await vm.load()
        #expect(vm.selectedAccount?.id == from.id)
        #expect(vm.selectedToAccount?.id == to.id)
        #expect(vm.canSave)
    }
}
