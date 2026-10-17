import Testing
import Foundation
@testable import Balansir

/// Выбор месяца в шапке Главной (§4.1): список месяцев, фильтр ленты, сводка hero.
@Suite("StatisticsService — месяцы для выбора")
@MainActor
struct MonthOptionsServiceTests {
    private let cal = StatsFixture.calendar

    private func monthStart(_ year: Int, _ month: Int) -> Date {
        cal.date(from: DateComponents(year: year, month: month, day: 1))!
    }

    @Test func месяцы_от_первой_операции_до_текущего_от_свежих_к_ранним() {
        let starts = StatisticsService.monthStarts(
            covering: [StatsFixture.date(8, 3), StatsFixture.date(6, 15)],
            now: StatsFixture.today, calendar: cal
        )
        #expect(starts == [10, 9, 8, 7, 6].map { monthStart(2026, $0) })
    }

    @Test func без_операций_только_текущий_месяц() {
        let starts = StatisticsService.monthStarts(covering: [], now: StatsFixture.today, calendar: cal)
        #expect(starts == [monthStart(2026, 10)])
    }

    @Test func операции_из_будущего_не_добавляют_месяцев() {
        let starts = StatisticsService.monthStarts(
            covering: [StatsFixture.date(12, 1)], now: StatsFixture.today, calendar: cal
        )
        #expect(starts == [monthStart(2026, 10)])
    }

    @Test func список_переходит_через_год() {
        let nov2025 = cal.date(from: DateComponents(year: 2025, month: 11, day: 20, hour: 12))!
        let starts = StatisticsService.monthStarts(covering: [nov2025], now: StatsFixture.today, calendar: cal)
        #expect(starts.count == 12)
        #expect(starts.last == monthStart(2025, 11))
    }

    @Test func подпись_месяца_прошлого_года_с_годом() {
        let now = StatsFixture.today
        #expect(StatisticsService.monthTitle(for: StatsFixture.date(9, 1), now: now, calendar: cal, locale: TestLocale.ru) == "Сентябрь")
        #expect(StatisticsService.monthTitle(for: monthStart(2025, 12), now: now, calendar: cal, locale: TestLocale.ru) == "Декабрь 2025")
        #expect(StatisticsService.monthTitle(for: monthStart(2025, 12), now: now, calendar: cal, locale: TestLocale.en) == "December 2025")
    }
}

@Suite("HomeViewModel — фильтр по месяцу")
@MainActor
struct HomeMonthFilterTests {
    private let cal = Calendar.current

    private var currentMonthStart: Date {
        cal.dateInterval(of: .month, for: Date())!.start
    }

    private var previousMonthStart: Date {
        cal.date(byAdding: .month, value: -1, to: currentMonthStart)!
    }

    /// Середина прошлого месяца — заведомо внутри него при любом «сегодня».
    private var previousMonthDate: Date {
        cal.date(byAdding: .day, value: 10, to: previousMonthStart)!
    }

    private func entry(
        _ type: EntryType, _ amount: Decimal, on date: Date,
        from: AccountModel? = nil, to: AccountModel? = nil, note: String? = nil
    ) -> EntryModel {
        EntryModel(
            id: UUID(), date: date, type: type, amount: amount, currency: "RUB",
            note: note, tags: [], isRecurring: false, isSoftDeleted: false,
            createdAt: date, updatedAt: date,
            fromAccount: from, toAccount: to, category: nil
        )
    }

    private func makeVM(_ entries: [EntryModel], accounts: [AccountModel]) async -> HomeViewModel {
        let accountRepo = MockAccountRepository()
        accountRepo.accounts = accounts
        let entryRepo = MockEntryRepository()
        entryRepo.entries = entries
        let vm = HomeViewModel(accountRepo: accountRepo, categoryRepo: MockCategoryRepository(), entryRepo: entryRepo, tagRepo: MockTagRepository(), counterpartyRepo: MockCounterpartyRepository(),
                               locale: TestLocale.ru)
        await vm.load()
        return vm
    }

    @Test func без_фильтра_вся_лента_и_сводка_текущего_месяца() async {
        let a = AccountModel.makeTest()
        let vm = await makeVM([
            entry(.expense, 100, on: Date(), from: a),
            entry(.expense, 700, on: previousMonthDate, from: a),
        ], accounts: [a])

        #expect(vm.selectedMonth == nil)
        #expect(vm.headerTitle == String(localized: "All transactions"))
        #expect(vm.filteredEntries.count == 2)
        #expect(vm.heroExpense == 100)
        // Месяц — из локали VM (ru: строчный), шаблон фразы — из каталога на языке симулятора.
        let month = StatisticsService.monthNameInPhrase(for: Date(), calendar: cal, locale: TestLocale.ru)
        #expect(vm.heroExpenseTitle == String(localized: "Expenses in \(month)"))
        #expect(vm.heroIncomeTitle == String(localized: "Income in \(month)"))
    }

    @Test func выбранный_месяц_фильтрует_ленту_и_сводку() async {
        let a = AccountModel.makeTest()
        let vm = await makeVM([
            entry(.expense, 100, on: Date(), from: a),
            entry(.expense, 700, on: previousMonthDate, from: a),
            entry(.income, 5000, on: previousMonthDate, to: a),
        ], accounts: [a])

        vm.selectedMonth = previousMonthStart

        #expect(vm.filteredEntries.count == 2)
        #expect(vm.heroExpense == 700)
        #expect(vm.heroIncome == 5000)
        #expect(vm.heroExpenseTitle == String(localized: "Expenses"))
        #expect(vm.heroIncomeTitle == String(localized: "Income"))
        #expect(vm.headerTitle == StatisticsService.monthTitle(for: previousMonthStart, now: Date(), calendar: cal, locale: TestLocale.ru))
        // Сводка у таб-бара — всегда текущий месяц.
        #expect(vm.monthExpense == 100)
    }

    @Test func месяц_и_счёт_фильтруют_вместе() async {
        let a1 = AccountModel.makeTest(name: "A1")
        let a2 = AccountModel.makeTest(name: "A2")
        let vm = await makeVM([
            entry(.expense, 100, on: previousMonthDate, from: a1),
            entry(.expense, 200, on: previousMonthDate, from: a2),
            entry(.expense, 300, on: Date(), from: a1),
        ], accounts: [a1, a2])

        vm.selectedMonth = previousMonthStart
        vm.selectedAccountId = a1.id

        #expect(vm.filteredEntries.map(\.amount) == [100])
    }

    @Test func поиск_ищет_по_всей_истории_без_учёта_месяца() async {
        let a = AccountModel.makeTest()
        let vm = await makeVM([
            entry(.expense, 100, on: Date(), from: a, note: "кофе"),
            entry(.expense, 700, on: previousMonthDate, from: a),
        ], accounts: [a])

        vm.selectedMonth = previousMonthStart
        vm.isSearchActive = true
        vm.searchQuery = "кофе"

        #expect(vm.filteredEntries.map(\.amount) == [100])
    }

    @Test func список_месяцев_от_текущего_до_месяца_первой_операции() async {
        let a = AccountModel.makeTest()
        let vm = await makeVM([entry(.expense, 700, on: previousMonthDate, from: a)], accounts: [a])

        #expect(vm.monthOptions.map(\.start) == [currentMonthStart, previousMonthStart])
    }

    @Test func пустая_лента_за_месяц_своё_сообщение() async {
        let a = AccountModel.makeTest()
        let vm = await makeVM([entry(.expense, 100, on: Date(), from: a)], accounts: [a])

        vm.selectedMonth = previousMonthStart

        #expect(vm.filteredEntries.isEmpty)
        #expect(vm.emptyFeedMessage == String(localized: "No transactions this month."))
        vm.selectedAccountId = a.id
        #expect(vm.emptyFeedMessage == String(localized: "No transactions for this account this month."))
    }
}

@Suite("AddEntryViewModel — дата операции")
@MainActor
struct AddEntryDateTests {

    private func makeVM(_ entryRepo: MockEntryRepository) async -> AddEntryViewModel {
        let accountRepo = MockAccountRepository()
        accountRepo.accounts = [AccountModel.makeTest()]
        let vm = AddEntryViewModel(accountRepo: accountRepo, categoryRepo: MockCategoryRepository(), entryRepo: entryRepo, tagRepo: MockTagRepository(), counterpartyRepo: MockCounterpartyRepository(), locale: TestLocale.ru)
        await vm.load()
        vm.amountString = "100"
        return vm
    }

    @Test func операцию_из_будущего_сохранить_нельзя() async {
        let entryRepo = MockEntryRepository()
        let vm = await makeVM(entryRepo)
        vm.date = Calendar.current.date(byAdding: .day, value: 1, to: Date())!

        await vm.save()

        #expect(vm.errorMessage != nil)
        #expect(entryRepo.entries.isEmpty)
    }

    @Test func вчерашнюю_операцию_сохранить_можно() async {
        let entryRepo = MockEntryRepository()
        let vm = await makeVM(entryRepo)
        vm.date = Calendar.current.date(byAdding: .day, value: -1, to: Date())!

        await vm.save()

        #expect(vm.errorMessage == nil)
        #expect(entryRepo.entries.count == 1)
    }
}
