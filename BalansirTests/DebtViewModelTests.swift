import Testing
import Foundation
@testable import Balansir

/// Шит операции: тип «Долг» (§4.11, задача 14).
@Suite("AddEntryViewModel — долги")
@MainActor
struct AddEntryDebtTests {

    private struct Env {
        let vm: AddEntryViewModel
        let entryRepo: MockEntryRepository
        let counterpartyRepo: MockCounterpartyRepository
        let account: AccountModel
    }

    private func makeEnv(counterparties: [CounterpartyModel] = [], entries: [EntryModel] = [],
                         editing: EntryModel? = nil, initialType: EntryType? = nil,
                         initialCounterpartyId: UUID? = nil, account: AccountModel? = nil) async -> Env {
        // Без `.makeTest()` по умолчанию: default-аргумент вычислялся бы вне главного актора.
        let account = account ?? .makeTest(name: "Тинькофф")
        let accountRepo = MockAccountRepository()
        accountRepo.accounts = [account]
        let entryRepo = MockEntryRepository()
        entryRepo.entries = entries
        let counterpartyRepo = MockCounterpartyRepository()
        counterpartyRepo.counterparties = counterparties
        let vm = AddEntryViewModel(entry: editing, accountRepo: accountRepo, categoryRepo: MockCategoryRepository(),
                                   entryRepo: entryRepo, tagRepo: MockTagRepository(), counterpartyRepo: counterpartyRepo,
                                   initialType: initialType, initialCounterpartyId: initialCounterpartyId, locale: TestLocale.ru)
        await vm.load()
        return Env(vm: vm, entryRepo: entryRepo, counterpartyRepo: counterpartyRepo, account: account)
    }

    @Test func долг_без_контрагента_не_сохранить() async {
        let env = await makeEnv()
        env.vm.selectedType = .debt
        env.vm.onTypeChanged()
        env.vm.amountString = "500"
        #expect(env.vm.canSave == false)
    }

    @Test func я_отправил_уходит_со_счёта() async {
        let inga = CounterpartyModel.makeTest(name: "Инга")
        let env = await makeEnv(counterparties: [inga])
        env.vm.selectedType = .debt
        env.vm.onTypeChanged()
        env.vm.amountString = "500"
        env.vm.selectCounterparty(inga)
        #expect(env.vm.canSave)
        await env.vm.save()
        #expect(env.entryRepo.savedEntry?.type == .debt)
        #expect(env.entryRepo.savedEntry?.counterparty?.id == inga.id)
        #expect(env.entryRepo.savedFromAccount?.id == env.account.id)
        #expect(env.entryRepo.savedToAccount == nil)
        #expect(env.entryRepo.savedCategory == nil)
    }

    @Test func мне_пришли_приходят_на_счёт() async {
        let mom = CounterpartyModel.makeTest(name: "мама")
        let env = await makeEnv(counterparties: [mom])
        env.vm.selectedType = .debt
        env.vm.onTypeChanged()
        env.vm.debtDirection = .received
        env.vm.amountString = "20000"
        env.vm.selectCounterparty(mom)
        await env.vm.save()
        #expect(env.entryRepo.savedFromAccount == nil)
        #expect(env.entryRepo.savedToAccount?.id == env.account.id)
    }

    @Test func у_долга_нет_тегов_и_категории() async {
        let env = await makeEnv()
        env.vm.selectedType = .debt
        env.vm.onTypeChanged()
        #expect(env.vm.showsTags == false)
        #expect(env.vm.selectedCategory == nil)
    }

    @Test func новый_контрагент_создаётся_и_выбирается() async {
        let env = await makeEnv()
        env.vm.startAddingCounterparty()
        env.vm.newCounterpartyName = "  Саша "
        await env.vm.commitNewCounterparty()
        #expect(env.counterpartyRepo.counterparties.map(\.name) == ["Саша"])
        #expect(env.vm.selectedCounterparty?.name == "Саша")
        #expect(env.vm.isAddingCounterparty == false)
    }

    @Test func имя_удалённого_возвращает_его_без_дубля() async {
        let gone = CounterpartyModel.makeTest(name: "Гафт", isArchived: true)
        let env = await makeEnv(counterparties: [gone])
        #expect(env.vm.carouselCounterparties.isEmpty)
        env.vm.startAddingCounterparty()
        env.vm.newCounterpartyName = "гафт"
        await env.vm.commitNewCounterparty()
        #expect(env.counterpartyRepo.counterparties.count == 1)
        #expect(env.counterpartyRepo.counterparties.first?.isArchived == false)
        #expect(env.vm.selectedCounterparty?.id == gone.id)
    }

    @Test func подсказка_о_текущем_долге() async {
        let account = AccountModel.makeTest()
        let inga = CounterpartyModel.makeTest(name: "Инга")
        let mom = CounterpartyModel.makeTest(name: "мама")
        let env = await makeEnv(
            counterparties: [inga, mom],
            entries: [.makeDebt(.sent, amount: 500, account: account, counterparty: inga),
                      .makeDebt(.received, amount: 1000, account: account, counterparty: mom)],
            account: account
        )
        env.vm.selectCounterparty(inga)
        #expect(env.vm.selectedCounterpartyDebt == 500)
        let amount = MoneyFormatter.debt(500, locale: TestLocale.ru)
        #expect(env.vm.counterpartyHint == String(localized: "Owed to me \(amount)"))
        env.vm.selectCounterparty(mom)
        #expect(env.vm.selectedCounterpartyDebt == -1000)
    }

    @Test func шит_с_фильтра_долгов_открывается_на_долге() async {
        let inga = CounterpartyModel.makeTest(name: "Инга")
        let env = await makeEnv(counterparties: [inga], initialType: .debt, initialCounterpartyId: inga.id)
        #expect(env.vm.selectedType == .debt)
        #expect(env.vm.selectedCounterparty?.id == inga.id)
    }

    @Test func редактирование_долга_подставляет_направление_и_контрагента() async {
        let account = AccountModel.makeTest()
        let mom = CounterpartyModel.makeTest(name: "мама")
        let entry = EntryModel.makeDebt(.received, amount: 700, account: account, counterparty: mom)
        let env = await makeEnv(counterparties: [mom], entries: [entry], editing: entry, account: account)
        #expect(env.vm.selectedType == .debt)
        #expect(env.vm.debtDirection == .received)
        #expect(env.vm.selectedAccount?.id == account.id)
        #expect(env.vm.selectedCounterparty?.id == mom.id)
        // Подсказка — без учёта редактируемой операции.
        #expect(env.vm.selectedCounterpartyDebt == 0)
    }
}

/// Главная: чип «Долги» и карусель контрагентов (§4.11).
@Suite("HomeViewModel — долги")
@MainActor
struct HomeDebtFilterTests {

    private func makeVM(accounts: [AccountModel], entries: [EntryModel], counterparties: [CounterpartyModel]) async -> HomeViewModel {
        let accountRepo = MockAccountRepository()
        accountRepo.accounts = accounts
        let entryRepo = MockEntryRepository()
        entryRepo.entries = entries
        let counterpartyRepo = MockCounterpartyRepository()
        counterpartyRepo.counterparties = counterparties
        let vm = HomeViewModel(accountRepo: accountRepo, categoryRepo: MockCategoryRepository(), entryRepo: entryRepo,
                               tagRepo: MockTagRepository(), counterpartyRepo: counterpartyRepo, locale: TestLocale.ru)
        await vm.load()
        return vm
    }

    @Test func фильтр_долги_и_контрагент() async {
        let account = AccountModel.makeTest()
        let inga = CounterpartyModel.makeTest(name: "Инга")
        let mom = CounterpartyModel.makeTest(name: "мама")
        let expense = EntryModel.makeTest(type: .expense, amount: 100, from: account)
        let toInga = EntryModel.makeDebt(.sent, amount: 500, account: account, counterparty: inga)
        let fromMom = EntryModel.makeDebt(.received, amount: 1000, account: account, counterparty: mom)
        let vm = await makeVM(accounts: [account], entries: [expense, toInga, fromMom], counterparties: [inga, mom])

        #expect(vm.showsDebtsChip)
        vm.toggleDebts()
        #expect(Set(vm.filteredEntries.map(\.id)) == [toInga.id, fromMom.id])
        vm.toggleCounterparty(mom.id)
        #expect(vm.filteredEntries.map(\.id) == [fromMom.id])
        #expect(vm.heroDebtTotals == DebtService.Totals(owedToMe: 0, iOwe: 1000))
        vm.toggleCounterparty(mom.id)
        #expect(vm.filteredEntries.count == 2)
        #expect(vm.debtTotals == DebtService.Totals(owedToMe: 500, iOwe: 1000))
        vm.toggleDebts()
        #expect(vm.isAllSelected)
        #expect(vm.filteredEntries.count == 3)
    }

    @Test func счёт_и_долги_взаимоисключающие() async {
        let account = AccountModel.makeTest()
        let inga = CounterpartyModel.makeTest(name: "Инга")
        let vm = await makeVM(accounts: [account], entries: [], counterparties: [inga])
        vm.toggleDebts()
        vm.toggleCounterparty(inga.id)
        vm.toggleAccount(account.id)
        #expect(vm.isDebtFilterActive == false)
        #expect(vm.selectedCounterpartyId == nil)
        #expect(vm.selectedAccountId == account.id)
        vm.toggleDebts()
        #expect(vm.selectedAccountId == nil)
        #expect(vm.isDebtFilterActive)
    }

    @Test func без_контрагентов_чипа_нет() async {
        let vm = await makeVM(accounts: [.makeTest()], entries: [], counterparties: [.makeTest(isArchived: true)])
        #expect(vm.showsDebtsChip == false)
    }

    @Test func поиск_по_имени_контрагента() async {
        let account = AccountModel.makeTest(name: "Тинькофф")
        let inga = CounterpartyModel.makeTest(name: "Инга")
        let debt = EntryModel.makeDebt(.sent, amount: 500, account: account, counterparty: inga)
        let vm = await makeVM(accounts: [account], entries: [debt, .makeTest(type: .expense, amount: 1, from: account)],
                              counterparties: [inga])
        vm.isSearchActive = true
        vm.searchQuery = "инг"
        #expect(vm.filteredEntries.map(\.id) == [debt.id])
    }

    @Test func долги_не_в_hero_расходов() async {
        let account = AccountModel.makeTest()
        let inga = CounterpartyModel.makeTest(name: "Инга")
        let vm = await makeVM(accounts: [account],
                              entries: [.makeDebt(.sent, amount: 500, account: account, counterparty: inga),
                                        .makeTest(type: .expense, amount: 100, from: account)],
                              counterparties: [inga])
        #expect(vm.heroExpense == 100)
        #expect(vm.heroIncome == 0)
        #expect(vm.monthExpense == 100)
    }

    @Test func плюс_с_фильтра_долгов_открывает_шит_долга() async {
        let account = AccountModel.makeTest()
        let inga = CounterpartyModel.makeTest(name: "Инга")
        let vm = await makeVM(accounts: [account], entries: [], counterparties: [inga])
        vm.toggleDebts()
        vm.toggleCounterparty(inga.id)
        let sheet = vm.makeAddEntryViewModel()
        await sheet.load()
        #expect(sheet.selectedType == .debt)
        #expect(sheet.selectedCounterparty?.id == inga.id)
        // Редактирование обычной операции — без подстановки долга.
        let edit = vm.makeAddEntryViewModel(for: .makeTest(type: .expense, amount: 1, from: account))
        await edit.load()
        #expect(edit.selectedType == .expense)
    }
}

/// Экран «Контрагенты» и форма (§4.11).
@Suite("CounterpartiesViewModel")
@MainActor
struct CounterpartiesViewModelTests {

    private func makeVM(counterparties: [CounterpartyModel], entries: [EntryModel] = [])
        async -> (CounterpartiesViewModel, MockCounterpartyRepository) {
        let counterpartyRepo = MockCounterpartyRepository()
        counterpartyRepo.counterparties = counterparties
        let entryRepo = MockEntryRepository()
        entryRepo.entries = entries
        let vm = CounterpartiesViewModel(counterpartyRepo: counterpartyRepo, entryRepo: entryRepo, locale: TestLocale.ru)
        await vm.load()
        return (vm, counterpartyRepo)
    }

    @Test func без_долга_удаляется_сразу() async {
        let lena = CounterpartyModel.makeTest(name: "Лена")
        let (vm, repo) = await makeVM(counterparties: [lena])
        let deleted = await vm.requestDelete(lena)
        #expect(deleted)
        #expect(vm.counterparties.isEmpty)
        #expect(repo.counterparties.first?.isArchived == true)
    }

    @Test func с_долгом_нужно_подтверждение() async {
        let account = AccountModel.makeTest()
        let inga = CounterpartyModel.makeTest(name: "Инга")
        let (vm, repo) = await makeVM(counterparties: [inga],
                                      entries: [.makeDebt(.sent, amount: 500, account: account, counterparty: inga)])
        let deleted = await vm.requestDelete(inga)
        #expect(deleted == false)
        #expect(vm.pendingDeletion?.id == inga.id)
        #expect(repo.counterparties.first?.isArchived == false)
        await vm.confirmDelete()
        #expect(vm.pendingDeletion == nil)
        #expect(repo.counterparties.first?.isArchived == true)
        #expect(vm.totals == .zero)
    }

    @Test func отмена_удаления() async {
        let account = AccountModel.makeTest()
        let inga = CounterpartyModel.makeTest(name: "Инга")
        let (vm, repo) = await makeVM(counterparties: [inga],
                                      entries: [.makeDebt(.received, amount: 50, account: account, counterparty: inga)])
        await vm.requestDelete(inga)
        vm.cancelDelete()
        #expect(vm.pendingDeletion == nil)
        #expect(repo.counterparties.first?.isArchived == false)
    }

    @Test func форма_не_даёт_дубль_имени() async {
        let repo = MockCounterpartyRepository()
        repo.counterparties = [.makeTest(name: "Саша")]
        let form = CounterpartyFormViewModel(counterpartyRepo: repo, locale: TestLocale.ru)
        form.name = "саша "
        await form.save()
        #expect(form.errorMessage != nil)
        #expect(repo.counterparties.count == 1)
    }

    @Test func форма_создаёт_и_меняет() async {
        let repo = MockCounterpartyRepository()
        let form = CounterpartyFormViewModel(counterpartyRepo: repo, locale: TestLocale.ru)
        form.name = " кофе "
        form.selectedIcon = "cup.and.saucer"
        await form.save()
        #expect(repo.counterparties.map(\.name) == ["кофе"])
        #expect(repo.counterparties.first?.iconName == "cup.and.saucer")

        let edit = CounterpartyFormViewModel(counterparty: repo.counterparties[0], counterpartyRepo: repo, locale: TestLocale.ru)
        edit.name = "Кофе"
        await edit.save()
        #expect(repo.counterparties.map(\.name) == ["Кофе"])
    }
}
