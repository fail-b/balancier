import Testing
import Foundation
@testable import Balansir

/// Долги по контрагентам (§4.11, задача 14).
@Suite("DebtService")
@MainActor
struct DebtServiceTests {

    @Test func отправил_мне_должны_пришли_уменьшает() {
        let account = AccountModel.makeTest()
        let inga = CounterpartyModel.makeTest(name: "Инга")
        let entries: [EntryModel] = [
            .makeDebt(.sent, amount: 1000, account: account, counterparty: inga),
            .makeDebt(.received, amount: 500, account: account, counterparty: inga),
        ]
        #expect(DebtService.balances(entries: entries)[inga.id] == 500)
    }

    @Test func пришли_больше_я_должен() {
        let account = AccountModel.makeTest()
        let mom = CounterpartyModel.makeTest(name: "мама")
        let entries: [EntryModel] = [
            .makeDebt(.received, amount: 20000, account: account, counterparty: mom),
            .makeDebt(.sent, amount: 400, account: account, counterparty: mom),
        ]
        #expect(DebtService.balances(entries: entries)[mom.id] == -19600)
    }

    @Test func другие_типы_не_влияют_на_долги() {
        let account = AccountModel.makeTest()
        let entries: [EntryModel] = [
            .makeTest(type: .expense, amount: 300, from: account),
            .makeTest(type: .income, amount: 300, to: account),
        ]
        #expect(DebtService.balances(entries: entries).isEmpty)
    }

    @Test func итоги_мне_должны_и_я_должен() {
        let a = CounterpartyModel.makeTest(name: "A")
        let b = CounterpartyModel.makeTest(name: "B")
        let c = CounterpartyModel.makeTest(name: "C")
        let totals = DebtService.totals(of: [a, b, c], balances: [a.id: 500, b.id: -200, c.id: -100])
        #expect(totals.owedToMe == 500)
        #expect(totals.iOwe == 300)
        #expect(totals.net == 200)
    }

    @Test func удалённый_контрагент_не_в_итогах() {
        let a = CounterpartyModel.makeTest(name: "A")
        let gone = CounterpartyModel.makeTest(name: "Удалён", isArchived: true)
        let totals = DebtService.totals(of: [a, gone], balances: [a.id: 100, gone.id: -5000])
        #expect(totals == DebtService.Totals(owedToMe: 100, iOwe: 0))
    }

    @Test func направление_по_счёту_операции() {
        let account = AccountModel.makeTest()
        let cp = CounterpartyModel.makeTest()
        #expect(EntryModel.makeDebt(.sent, amount: 1, account: account, counterparty: cp).debtDirection == .sent)
        #expect(EntryModel.makeDebt(.received, amount: 1, account: account, counterparty: cp).debtDirection == .received)
        #expect(EntryModel.makeTest(type: .expense, amount: 1, from: account).debtDirection == nil)
    }

    // MARK: - Балансы счетов и статистика

    @Test func долг_меняет_баланс_счёта() {
        let account = AccountModel.makeTest(initialBalance: 1000)
        let cp = CounterpartyModel.makeTest()
        let entries: [EntryModel] = [
            .makeDebt(.sent, amount: 300, account: account, counterparty: cp),
            .makeDebt(.received, amount: 50, account: account, counterparty: cp),
        ]
        #expect(BalanceService.computeBalances(accounts: [account], entries: entries)[account.id] == 750)
    }

    @Test func долг_не_расход_и_не_доход() {
        let account = AccountModel.makeTest()
        let cp = CounterpartyModel.makeTest()
        let entries: [EntryModel] = [
            .makeDebt(.sent, amount: 300, account: account, counterparty: cp),
            .makeDebt(.received, amount: 50, account: account, counterparty: cp),
            .makeTest(type: .expense, amount: 10, from: account),
        ]
        let month = StatisticsService.monthInterval(containing: Date(), calendar: .current)
        #expect(StatisticsService.total(of: .expense, in: entries, interval: month) == 10)
        #expect(StatisticsService.total(of: .income, in: entries, interval: month) == 0)
        #expect(StatisticsService.expensesByCategory(in: entries, interval: month).map(\.total) == [10])
    }

    // MARK: - Формат

    @Test func формат_долга_со_знаком() {
        #expect(MoneyFormatter.debt(500, locale: TestLocale.ru).normalizedSpaces == "+500 ₽")
        #expect(MoneyFormatter.debt(-177219, locale: TestLocale.ru).normalizedSpaces == "\u{2212}177 219 ₽")
        #expect(MoneyFormatter.debt(0, locale: TestLocale.ru).normalizedSpaces == "0 ₽")
        #expect(MoneyFormatter.compactDebt(-1_200_000, locale: TestLocale.ru).normalizedSpaces == "\u{2212}1,2 млн ₽")
    }
}
